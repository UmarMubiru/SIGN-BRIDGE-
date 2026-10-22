package com.example.signbridge

import android.content.Context
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.os.Handler
import android.os.Looper
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.facelandmarker.FaceLandmarker
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarker
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedWriter
import java.io.File
import java.io.FileOutputStream
import java.io.OutputStreamWriter
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.atan2
import kotlin.math.ceil
import kotlin.math.hypot
import kotlin.math.roundToInt

private const val DATASET_ANALYSIS_CHANNEL = "signbridge/dataset_analysis"
private const val DATASET_ANALYSIS_PROGRESS_CHANNEL = "signbridge/dataset_analysis/progress"
private const val SAMPLE_INTERVAL_MS = 1000L

internal class AndroidDatasetAnalysis(private val context: Context) {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val isRunning = AtomicBoolean(false)
    @Volatile private var progressSink: EventChannel.EventSink? = null

    fun register(messenger: io.flutter.plugin.common.BinaryMessenger) {
        EventChannel(messenger, DATASET_ANALYSIS_PROGRESS_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    progressSink = events
                }

                override fun onCancel(arguments: Any?) {
                    progressSink = null
                }
            })

        MethodChannel(messenger, DATASET_ANALYSIS_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method != "extractDatasetAssets") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                if (!isRunning.compareAndSet(false, true)) {
                    result.error("ANALYSIS_BUSY", "Another dataset is being processed.", null)
                    return@setMethodCallHandler
                }
                val arguments = call.arguments as? Map<*, *>
                val outputPath = arguments?.get("outputDirectory") as? String
                val recordings = arguments?.get("recordings") as? List<*>
                if (outputPath.isNullOrBlank() || recordings.isNullOrEmpty()) {
                    isRunning.set(false)
                    result.error("INVALID_REQUEST", "The dataset processing request is incomplete.", null)
                    return@setMethodCallHandler
                }
                Thread {
                    try {
                        process(File(outputPath), recordings)
                        mainHandler.post { result.success(null) }
                    } catch (error: Exception) {
                        mainHandler.post {
                            result.error(
                                "DATASET_ANALYSIS_FAILED",
                                error.message ?: "Android frame and landmark processing failed.",
                                null,
                            )
                        }
                    } finally {
                        isRunning.set(false)
                    }
                }.start()
            }
    }

    private fun process(output: File, rawRecordings: List<*>) {
        val recordings = rawRecordings.mapIndexed { index, raw ->
            val map = raw as? Map<*, *> ?: error("Video ${index + 1} has invalid metadata.")
            val id = map["recordingId"] as? String ?: error("Video ${index + 1} has no ID.")
            val path = map["videoPath"] as? String ?: error("Video ${index + 1} has no local file path.")
            val name = map["fileName"] as? String ?: File(path).name
            val duration = (map["durationMs"] as? Number)?.toLong()
            Recording(id, File(path), name, duration)
        }
        require(recordings.all { it.video.isFile }) { "A selected video is missing from the local workspace." }
        val measuredRecordings = recordings.map { recording ->
            if (recording.durationMs != null && recording.durationMs > 0) {
                recording
            } else {
                val retriever = MediaMetadataRetriever()
                try {
                    retriever.setDataSource(recording.video.absolutePath)
                    val measured = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                        ?.toLongOrNull()
                    recording.copy(durationMs = measured)
                } finally {
                    retriever.release()
                }
            }
        }
        val frameRoot = File(output, "frames")
        require(frameRoot.mkdirs() || frameRoot.isDirectory) { "Could not create the dataset frames folder." }
        val orientation = File(output, "orientation_frames.csv")
        val landmarks = File(output, "landmarks.jsonl")
        val totalFrames = measuredRecordings.sumOf { recording ->
            recording.durationMs?.let { ceil(it.coerceAtLeast(1L).toDouble() / SAMPLE_INTERVAL_MS).toInt() } ?: 0
        }
        require(totalFrames > 0) { "Could not determine the duration of the selected videos." }
        emitProgress("initializing", 0, totalFrames, 0, recordings.size, "")

        val face = createFaceLandmarker()
        val hands = try {
            createHandLandmarker()
        } catch (error: Exception) {
            face.close()
            throw error
        }
        var processed = 0
        try {
            BufferedWriter(OutputStreamWriter(FileOutputStream(orientation), Charsets.UTF_8)).use { csv ->
                BufferedWriter(OutputStreamWriter(FileOutputStream(landmarks), Charsets.UTF_8)).use { jsonl ->
                    csv.write("recording_id,file_name,frame_index,timestamp_ms,yaw_degrees,pitch_degrees,orientation_label,image_path\r\n")
                    measuredRecordings.forEachIndexed { recordingIndex, recording ->
                        processRecording(
                            recording = recording,
                            recordingIndex = recordingIndex + 1,
                            recordingCount = measuredRecordings.size,
                            totalFrames = totalFrames,
                            output = output,
                            face = face,
                            hands = hands,
                            csv = csv,
                            jsonl = jsonl,
                            processedBefore = processed,
                            onFrameProcessed = { processed++ },
                        ) { newProcessed ->
                            emitProgress(
                                "extractingFrames",
                                newProcessed,
                                totalFrames,
                                recordingIndex + 1,
                            measuredRecordings.size,
                                recording.name,
                            )
                        }
                    }
                }
            }
        } finally {
            try {
                face.close()
            } finally {
                hands.close()
            }
        }
        require(orientation.length() > 0 && landmarks.length() > 0) {
            "Android frame and landmark processing returned empty output."
        }
        emitProgress("complete", processed, totalFrames, recordings.size, recordings.size, "")
    }

    private fun processRecording(
        recording: Recording,
        recordingIndex: Int,
        recordingCount: Int,
        totalFrames: Int,
        output: File,
        face: FaceLandmarker,
        hands: HandLandmarker,
        csv: BufferedWriter,
        jsonl: BufferedWriter,
        processedBefore: Int,
        onFrameProcessed: () -> Unit,
        onProgress: (Int) -> Unit,
    ) {
        val retriever = MediaMetadataRetriever()
        retriever.setDataSource(recording.video.absolutePath)
        val metadataDuration = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull()
        val duration = recording.durationMs?.takeIf { it > 0 } ?: metadataDuration
            ?: error("Could not read the duration of ${recording.name}.")
        val recordingFrames = ceil(duration.coerceAtLeast(1L).toDouble() / SAMPLE_INTERVAL_MS).toInt()
        val recordingFrameRoot = File(File(output, "frames"), safePathPart(recording.id))
        require(recordingFrameRoot.mkdirs() || recordingFrameRoot.isDirectory) {
            "Could not create frames for ${recording.name}."
        }
        try {
            repeat(recordingFrames) { frameIndex ->
                val timestampMs = frameIndex * SAMPLE_INTERVAL_MS
        val decodedBitmap = retriever.getFrameAtTime(
                    timestampMs * 1000L,
                    MediaMetadataRetriever.OPTION_CLOSEST,
                ) ?: error("Could not decode frame ${frameIndex + 1} from ${recording.name}.")
                val bitmap = if (decodedBitmap.config == Bitmap.Config.ARGB_8888) {
                    decodedBitmap
                } else {
                    decodedBitmap.copy(Bitmap.Config.ARGB_8888, false).also { decodedBitmap.recycle() }
                        ?: error("Could not prepare frame ${frameIndex + 1} from ${recording.name}.")
                }
                try {
                    val image = BitmapImageBuilder(bitmap).build()
                    val faceResult = face.detect(image)
                    val handResult = hands.detect(image)
                    val facePoints = faceResult.faceLandmarks().firstOrNull()
                    val matrix = faceResult.facialTransformationMatrixes().orElse(emptyList()).firstOrNull()
                    val (yaw, pitch) = matrix?.let(::yawPitch) ?: (null to null)
                    val handPoints = handResult.landmarks()
                    val handedness = handResult.handedness()
                    val handObjects = JSONArray()
                    handPoints.forEachIndexed { handIndex, points ->
                        val category = handedness.getOrNull(handIndex)?.firstOrNull()
                        handObjects.put(JSONObject()
                            .put("handedness", category?.categoryName() ?: "unknown")
                            .put("landmarks", pointsJson(points)))
                    }

                    val frameName = "frame_%06d.jpg".format(frameIndex)
                    val frameFile = File(recordingFrameRoot, frameName)
                    FileOutputStream(frameFile).use { stream ->
                        if (!bitmap.compress(Bitmap.CompressFormat.JPEG, 88, stream)) {
                            error("Could not write frame $frameName.")
                        }
                    }
                    val imagePath = "frames/${safePathPart(recording.id)}/$frameName"
                    csv.write(listOf(
                        recording.id,
                        recording.name,
                        frameIndex.toString(),
                        timestampMs.toString(),
                        yaw?.let { "%.2f".format(java.util.Locale.US, it) } ?: "",
                        pitch?.let { "%.2f".format(java.util.Locale.US, it) } ?: "",
                        "unclassified",
                        imagePath,
                    ).joinToString(",", transform = ::csvCell) + "\r\n")
                    jsonl.write(JSONObject()
                        .put("recording_id", recording.id)
                        .put("frame_index", frameIndex)
                        .put("timestamp_ms", timestampMs)
                        .put("face_landmarks", facePoints?.let(::pointsJson) ?: JSONObject.NULL)
                        .put("hand_landmarks", handObjects)
                        .toString() + "\n")
                    csv.flush()
                    jsonl.flush()
                } finally {
                    bitmap.recycle()
                }
                onFrameProcessed()
                onProgress(processedBefore + frameIndex + 1)
            }
        } finally {
            retriever.release()
        }
    }

    private fun createFaceLandmarker(): FaceLandmarker {
        val base = BaseOptions.builder().setModelAssetPath("face_landmarker.task").build()
        val options = FaceLandmarker.FaceLandmarkerOptions.builder()
            .setBaseOptions(base)
            .setRunningMode(RunningMode.IMAGE)
            .setNumFaces(1)
            .setOutputFacialTransformationMatrixes(true)
            .build()
        return FaceLandmarker.createFromOptions(context, options)
    }

    private fun createHandLandmarker(): HandLandmarker {
        val base = BaseOptions.builder().setModelAssetPath("hand_landmarker.task").build()
        val options = HandLandmarker.HandLandmarkerOptions.builder()
            .setBaseOptions(base)
            .setRunningMode(RunningMode.IMAGE)
            .setNumHands(2)
            .build()
        return HandLandmarker.createFromOptions(context, options)
    }

    private fun pointsJson(points: List<com.google.mediapipe.tasks.components.containers.NormalizedLandmark>): JSONArray =
        JSONArray().also { array ->
            points.forEach { point ->
                array.put(JSONArray().put(point.x()).put(point.y()).put(point.z()))
            }
        }

    private fun yawPitch(columnMajor: FloatArray): Pair<Double, Double> {
        val rowMajor = DoubleArray(16) { index ->
            val row = index / 4
            val column = index % 4
            columnMajor[column * 4 + row].toDouble()
        }
        val yaw = Math.toDegrees(atan2(-rowMajor[8], hypot(rowMajor[0], rowMajor[4])))
        val pitch = Math.toDegrees(atan2(rowMajor[9], rowMajor[10]))
        return yaw to pitch
    }

    private fun csvCell(value: String): String = "\"${value.replace("\"", "\"\"")}\""

    private fun safePathPart(value: String): String = value
        .replace(Regex("[^A-Za-z0-9._-]+"), "_")
        .trim('.')
        .ifBlank { "recording" }

    private fun emitProgress(
        stage: String,
        processedFrames: Int,
        totalFrames: Int,
        recordingIndex: Int,
        recordingCount: Int,
        fileName: String,
    ) {
        val event = mapOf(
            "stage" to stage,
            "processedFrames" to processedFrames,
            "totalFrames" to totalFrames,
            "recordingIndex" to recordingIndex,
            "recordingCount" to recordingCount,
            "fileName" to fileName,
        )
        mainHandler.post { progressSink?.success(event) }
    }

    private data class Recording(
        val id: String,
        val video: File,
        val name: String,
        val durationMs: Long?,
    )
}
