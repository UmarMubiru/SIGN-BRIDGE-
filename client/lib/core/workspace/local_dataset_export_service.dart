import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'android_dataset_asset_extractor.dart';
import 'local_recording_service.dart';
import 'local_workspace.dart';
import 'workspace_database.dart';

typedef DatasetAssetExtractor = Future<Directory> Function(
  Directory temporaryDirectory,
  List<LocalWorkspaceRecording> recordings,
  void Function(DatasetExportProgress progress)? onProgress,
);

typedef DatasetExportProgressCallback = void Function(
  DatasetExportProgress progress,
);

class DatasetExportProgress {
  const DatasetExportProgress({
    required this.stage,
    this.processedFrames,
    this.totalFrames,
    this.recordingIndex,
    this.recordingCount,
    this.fileName,
  });

  final String stage;
  final int? processedFrames;
  final int? totalFrames;
  final int? recordingIndex;
  final int? recordingCount;
  final String? fileName;

  double? get fraction {
    final total = totalFrames;
    if (total == null || total <= 0 || processedFrames == null) return null;
    return (processedFrames! / total).clamp(0, 1).toDouble();
  }

  String get message {
    if (stage == 'extractingFrames' && processedFrames != null) {
      final total = totalFrames;
      final frames = total == null
          ? 'Processed $processedFrames frames'
          : 'Frames $processedFrames of $total';
      final recording = recordingIndex != null && recordingCount != null
          ? ' · Video $recordingIndex of $recordingCount'
          : '';
      return '$frames$recording';
    }
    return switch (stage) {
      'preparing' => 'Preparing selected videos…',
      'initializing' => 'Loading on-device face and hand models…',
      'packaging' => 'Writing the dataset ZIP…',
      'complete' => 'Dataset export complete.',
      _ => 'Processing dataset…',
    };
  }
}

/// Creates a portable dataset ZIP from files already stored in a workspace.
class LocalDatasetExportService {
  LocalDatasetExportService({this.assetExtractor});

  final DatasetAssetExtractor? assetExtractor;

  Future<List<File>> listDatasets(LocalWorkspace workspace) async {
    final directory = Directory(p.join(workspace.rootPath, 'exports'));
    if (!await directory.exists()) return const [];
    final files = await directory
        .list(followLinks: false)
        .where(
          (entity) =>
              entity is File &&
              p.extension(entity.path).toLowerCase() == '.zip',
        )
        .cast<File>()
        .toList();
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return files;
  }

  Future<File> createWorkspaceDataset({
    required LocalWorkspace workspace,
    required List<String> recordingIds,
    required String datasetName,
    bool? includeAnalysisAssets,
    DatasetExportProgressCallback? onProgress,
  }) async {
    final safeName = _safeName(datasetName.trim());
    if (safeName.isEmpty) {
      throw StateError('Enter a dataset name using letters or numbers.');
    }
    final directory = Directory(p.join(workspace.rootPath, 'exports'));
    await directory.create(recursive: true);
    var output = File(p.join(directory.path, '${safeName}_v1.0.0.zip'));
    var suffix = 2;
    while (await output.exists()) {
      output = File(p.join(directory.path, '${safeName}_v1.0.0_$suffix.zip'));
      suffix++;
    }
    await exportDataset(
      workspace: workspace,
      recordingIds: recordingIds,
      datasetName: datasetName,
      outputPath: output.path,
      includeAnalysisAssets:
          includeAnalysisAssets ?? (Platform.isWindows || Platform.isAndroid),
      onProgress: onProgress,
    );
    return output;
  }

  Future<void> exportDataset({
    required LocalWorkspace workspace,
    required List<String> recordingIds,
    required String datasetName,
    required String outputPath,
    bool includeAnalysisAssets = true,
    DatasetExportProgressCallback? onProgress,
  }) async {
    final cleanName = datasetName.trim();
    if (cleanName.isEmpty) throw StateError('Enter a dataset name.');
    if (recordingIds.isEmpty) {
      throw StateError('Select at least one recording to export.');
    }

    onProgress?.call(const DatasetExportProgress(stage: 'preparing'));

    final allRecordings = await LocalRecordingService().listRecordings(
      workspace,
    );
    final byId = {for (final item in allRecordings) item.id: item};
    final selected = <LocalWorkspaceRecording>[];
    for (final id in recordingIds) {
      final recording = byId[id];
      if (recording == null) {
        throw StateError('A selected recording was not found.');
      }
      if (!recording.videoExists) {
        throw StateError(
          'The video file for ${recording.fileName} is missing.',
        );
      }
      selected.add(recording);
    }

    if (_safeName(cleanName).isEmpty) {
      throw StateError('Enter a dataset name using letters or numbers.');
    }
    final exportDate = DateTime.now().toUtc();
    final manifest = StringBuffer()
      ..writeln('Dataset: $cleanName (v1.0.0)')
      ..writeln('Export Date: ${exportDate.toIso8601String()}')
      ..writeln('Dataset: $cleanName')
      ..writeln('Version: v1.0.0')
      ..writeln('Selected recordings: ${selected.length}')
      ..writeln('Selected recording rows found: ${selected.length}')
      ..writeln('All selected video files were found.')
      ..writeln()
      ..writeln('Recordings:');

    final usedNames = <String>{};
    final metadata = <Map<String, Object?>>[];
    final archivePathByRecordingId = <String, String>{};
    final entries = <_ZipEntry>[];
    for (final recording in selected) {
      var fileName = _safeName(p.basename(recording.fileName));
      if (fileName.isEmpty) fileName = '${recording.id}.mp4';
      if (!usedNames.add(fileName)) {
        fileName = '${recording.id}_$fileName';
        usedNames.add(fileName);
      }
      final archivePath = 'videos/$fileName';
      archivePathByRecordingId[recording.id] = archivePath;
      entries.add(
        _ZipEntry.file(archivePath, File(recording.absoluteVideoPath)),
      );
      manifest.writeln(
        '- $fileName (${recording.recordingType}, ${recording.reviewStatus}) - included as $archivePath',
      );
      metadata.add({
        'recording_id': recording.id,
        'file_name': recording.fileName,
        'mime_type': 'video/mp4',
        'file_size_bytes': recording.fileSizeBytes,
        'duration_ms': recording.durationMs,
        'recording_type': recording.recordingType,
        'review_status': recording.reviewStatus,
        'consent_status': recording.consentStatus,
        'sha256': recording.sha256,
        'recorded_at': recording.recordedAt?.toUtc().toIso8601String(),
        'created_at': recording.createdAt.toUtc().toIso8601String(),
        'video_path': archivePath,
      });
    }

    final annotations = await _annotationsFor(
      workspace,
      selected,
      archivePathByRecordingId,
    );
    manifest
      ..writeln(
        'Annotations included: ${annotations.length} recordings; participant names and demographics are excluded.',
      )
      ..writeln('Speaker attribution uses per-recording pseudonyms.')
      ..writeln(
        includeAnalysisAssets
            ? 'Sampled JPG frames and face/hand landmarks are included under frames/ and metadata/.'
            : 'Frame images and landmarks are not included in this portable export.',
      );

    entries.add(
      _ZipEntry.bytes('manifest.txt', utf8.encode(manifest.toString())),
    );
    entries.add(
      _ZipEntry.bytes(
        'metadata/recordings.json',
        utf8.encode(const JsonEncoder.withIndent('  ').convert(metadata)),
      ),
    );
    entries.add(
      _ZipEntry.bytes(
        'metadata/recordings.csv',
        utf8.encode(_recordingsCsv(metadata)),
      ),
    );
    entries.add(
      _ZipEntry.bytes(
        'metadata/annotations.json',
        utf8.encode(const JsonEncoder.withIndent('  ').convert(annotations)),
      ),
    );
    entries.add(
      _ZipEntry.bytes(
        'metadata/annotations.csv',
        utf8.encode(_annotationsCsv(annotations)),
      ),
    );

    if (includeAnalysisAssets) {
      final temp = await Directory.systemTemp.createTemp('signbridge-dataset-');
      try {
        final assets = await (assetExtractor ?? _extractFrames)(
          temp,
          selected,
          onProgress,
        );
        final frameRoot = Directory(p.join(assets.path, 'frames'));
        final frameFiles = <File>[];
        if (await frameRoot.exists()) {
          await for (final entity in frameRoot.list(
            recursive: true,
            followLinks: false,
          )) {
            if (entity is File &&
                p.extension(entity.path).toLowerCase() == '.jpg') {
              frameFiles.add(entity);
            }
          }
        }
        final orientationFile = File(
          p.join(assets.path, 'orientation_frames.csv'),
        );
        final landmarksFile = File(p.join(assets.path, 'landmarks.jsonl'));
        if (frameFiles.isEmpty ||
            !await orientationFile.exists() ||
            await orientationFile.length() == 0 ||
            !await landmarksFile.exists() ||
            await landmarksFile.length() == 0) {
          throw StateError(
            'Frame and landmark extraction returned incomplete output. No dataset ZIP was created.',
          );
        }
        entries.add(
          _ZipEntry.file('metadata/orientation_frames.csv', orientationFile),
        );
        entries.add(_ZipEntry.file('metadata/landmarks.jsonl', landmarksFile));
        for (final frame in frameFiles) {
          entries.add(
            _ZipEntry.file(
              p.relative(frame.path, from: assets.path).replaceAll('\\', '/'),
              frame,
            ),
          );
        }
        onProgress?.call(const DatasetExportProgress(stage: 'packaging'));
        await _writeArchive(outputPath, entries);
      } finally {
        await temp.delete(recursive: true);
      }
    } else {
      await _writeArchive(outputPath, entries);
    }
    onProgress?.call(const DatasetExportProgress(stage: 'complete'));
  }

  Future<void> _writeArchive(String outputPath, List<_ZipEntry> entries) async {
    final output = await File(outputPath).open(mode: FileMode.write);
    try {
      await _writeZip(output, entries);
      await output.flush();
    } finally {
      await output.close();
    }
  }

  Future<List<Map<String, Object?>>> _annotationsFor(
    LocalWorkspace workspace,
    List<LocalWorkspaceRecording> recordings,
    Map<String, String> archivePathByRecordingId,
  ) async {
    final database = await WorkspaceDatabase.open(
      p.join(workspace.rootPath, 'database.sqlite3'),
    );
    try {
      final all = <Map<String, Object?>>[];
      for (final recording in recordings) {
        final segments = await database.query(
          'utterance_segments',
          where: 'recording_id = ?',
          whereArgs: [recording.id],
          orderBy: 'sequence_no',
        );
        final pseudonyms = <String, String>{};
        final exportedSegments = <Map<String, Object?>>[];
        for (final segment in segments) {
          final speakers = await database.query(
            'segment_speakers',
            columns: ['participant_id', 'attribution_status'],
            where: 'segment_id = ?',
            whereArgs: [segment['id']],
            orderBy: 'rowid',
          );
          final exportedSpeakers = <Map<String, Object?>>[];
          for (final speaker in speakers) {
            final participantId = speaker['participant_id'] as String?;
            final pseudonym = participantId == null
                ? 'unknown'
                : pseudonyms.putIfAbsent(
                    participantId,
                    () =>
                        'speaker_${(pseudonyms.length + 1).toString().padLeft(3, '0')}',
                  );
            exportedSpeakers.add({
              'speaker_id': pseudonym,
              'attribution_status': speaker['attribution_status'],
            });
          }
          final entries = await database.query(
            'annotation_entries',
            columns: [
              'annotation_kind',
              'text',
              'language_tag',
              'status',
              'supersedes_id',
              'created_at',
              'updated_at',
            ],
            where: 'segment_id = ? AND annotation_kind != ?',
            whereArgs: [segment['id'], 'note'],
            orderBy: 'created_at, id',
          );
          exportedSegments.add({
            'sequence_no': segment['sequence_no'],
            'start_ms': segment['start_ms'],
            'end_ms': segment['end_ms'],
            'boundary_status': segment['boundary_status'],
            'speakers': exportedSpeakers,
            'annotations': entries,
          });
        }
        all.add({
          'recording_id': recording.id,
          'video_path': archivePathByRecordingId[recording.id],
          'segments': exportedSegments,
        });
      }
      return all;
    } finally {
      await database.close();
    }
  }

  static String _annotationsCsv(List<Map<String, Object?>> recordings) {
    String cell(Object? value) {
      final text = value?.toString() ?? '';
      return '"${text.replaceAll('"', '""')}"';
    }

    final out = StringBuffer(
      'recording_id,video_path,sequence_no,start_ms,end_ms,boundary_status,speaker_id,attribution_status,annotation_kind,text,language_tag,annotation_status,supersedes_id,created_at,updated_at\r\n',
    );
    for (final recording in recordings) {
      for (final rawSegment in recording['segments'] as List) {
        final segment = rawSegment as Map<String, Object?>;
        final speakers = segment['speakers'] as List;
        final annotations = segment['annotations'] as List;
        final speakerRows = speakers.isEmpty
            ? [
                <String, Object?>{
                  'speaker_id': 'unknown',
                  'attribution_status': 'unknown',
                },
              ]
            : speakers;
        final annotationRows = annotations.isEmpty
            ? [<String, Object?>{}]
            : annotations;
        for (final rawSpeaker in speakerRows) {
          final speaker = rawSpeaker as Map<String, Object?>;
          for (final rawAnnotation in annotationRows) {
            final annotation = rawAnnotation as Map<String, Object?>;
            out.writeln(
              [
                recording['recording_id'],
                recording['video_path'],
                segment['sequence_no'],
                segment['start_ms'],
                segment['end_ms'],
                segment['boundary_status'],
                speaker['speaker_id'],
                speaker['attribution_status'],
                annotation['annotation_kind'],
                annotation['text'],
                annotation['language_tag'],
                annotation['status'],
                annotation['supersedes_id'],
                annotation['created_at'],
                annotation['updated_at'],
              ].map(cell).join(','),
            );
          }
        }
      }
    }
    return out.toString();
  }

  Future<Directory> _extractFrames(
    Directory temp,
    List<LocalWorkspaceRecording> recordings,
    DatasetExportProgressCallback? onProgress,
  ) async {
    if (Platform.isAndroid) {
      final output = Directory(p.join(temp.path, 'assets'));
      await output.create(recursive: true);
      await AndroidDatasetAssetExtractor().extract(
        outputDirectory: output,
        recordings: recordings,
        onProgress: onProgress,
      );
      return output;
    }
    final executableDirectory = File(Platform.resolvedExecutable).parent;
    final bundledTools = Directory(
      p.join(executableDirectory.path, 'dataset_tools'),
    );
    final bundledRunner = File(
      p.join(bundledTools.path, 'signbridge_dataset_assets.exe'),
    );
    final bundledModels = Directory(p.join(bundledTools.path, 'models'));
    final bundledFaceModel = File(
      p.join(bundledModels.path, 'face_landmarker.task'),
    );
    final bundledHandModel = File(
      p.join(bundledModels.path, 'hand_landmarker.task'),
    );
    final hasBundledRuntime =
        Platform.isWindows &&
        await bundledRunner.exists() &&
        await bundledFaceModel.exists() &&
        await bundledHandModel.exists();

    final projectRoot = hasBundledRuntime ? null : _findProjectRoot();
    if (!hasBundledRuntime && projectRoot == null) {
      throw StateError(
        'The local frame-analysis tools are missing. Reinstall SignBridge or open it from a complete project checkout.',
      );
    }
    final backend = projectRoot == null
        ? null
        : Directory(p.join(projectRoot.path, 'backend'));
    final script = backend == null
        ? null
        : File(
            p.join(backend.path, 'scripts', 'extract_local_dataset_assets.py'),
          );
    final faceModel = backend == null
        ? bundledFaceModel
        : File(p.join(backend.path, 'models', 'face_landmarker.task'));
    final handModel = backend == null
        ? bundledHandModel
        : File(p.join(backend.path, 'models', 'hand_landmarker.task'));
    if ((script != null && !await script.exists()) ||
        !await faceModel.exists() ||
        !await handModel.exists()) {
      throw StateError(
        'Local frame extraction needs the video-processing script and MediaPipe face/hand models.',
      );
    }
    final pythonInVenv = backend == null
        ? null
        : File(
            p.join(
              backend.path,
              'venv',
              Platform.isWindows ? 'Scripts' : 'bin',
              Platform.isWindows ? 'python.exe' : 'python',
            ),
          );
    final python = pythonInVenv != null && await pythonInVenv.exists()
        ? pythonInVenv.path
        : (Platform.isWindows ? 'python' : 'python3');
    final input = File(p.join(temp.path, 'recordings.json'));
    await input.writeAsString(
      jsonEncode([
        for (final recording in recordings)
          {
            'recording_id': recording.id,
            'video_path': recording.absoluteVideoPath,
          },
      ]),
    );
    final output = Directory(p.join(temp.path, 'assets'));
    final args = [
      if (!hasBundledRuntime) script!.path,
      '--recordings-json',
      input.path,
      '--output-dir',
      output.path,
      '--face-model',
      faceModel.path,
      '--hand-model',
      handModel.path,
    ];
    final process = await Process.start(
      hasBundledRuntime ? bundledRunner.path : python,
      args,
      workingDirectory: hasBundledRuntime
          ? bundledTools.path
          : projectRoot!.path,
    );
    final errors = StringBuffer();
    final stderrDone = process.stderr
        .transform(utf8.decoder)
        .listen(errors.write)
        .asFuture<void>();
    await for (final line
        in process.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
      try {
        final event = jsonDecode(line);
        if (event is Map<String, dynamic>) {
          onProgress?.call(
            DatasetExportProgress(
              stage: event['stage'] as String? ?? 'extractingFrames',
              processedFrames: event['processedFrames'] as int?,
              totalFrames: event['totalFrames'] as int?,
              recordingIndex: event['recordingIndex'] as int?,
              recordingCount: event['recordingCount'] as int?,
              fileName: event['fileName'] as String?,
            ),
          );
        }
      } on FormatException {
        // Ignore ordinary diagnostic lines; structured progress is JSON.
      }
    }
    await stderrDone;
    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      final details = errors.toString().trim();
      throw StateError(
        details.isEmpty
            ? 'Video frame extraction failed (exit code $exitCode).'
            : 'Video frame extraction failed: $details',
      );
    }
    return output;
  }

  Directory? _findProjectRoot() {
    final starts = [
      Directory.current,
      File(Platform.resolvedExecutable).parent,
    ];
    for (final start in starts) {
      var current = start.absolute;
      for (var depth = 0; depth < 8; depth++) {
        final marker = File(
          p.join(
            current.path,
            'backend',
            'scripts',
            'extract_local_dataset_assets.py',
          ),
        );
        if (marker.existsSync()) return current;
        final parent = current.parent;
        if (parent.path == current.path) break;
        current = parent;
      }
    }
    return null;
  }

  static String _safeName(String value) => value
      .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
      .replaceAll(RegExp(r'^\.+|\.+$'), '');

  static String _recordingsCsv(List<Map<String, Object?>> metadata) {
    String cell(Object? value) {
      final text = value?.toString() ?? '';
      return '"${text.replaceAll('"', '""')}"';
    }

    final out = StringBuffer(
      'recording_id,file_name,mime_type,file_size_bytes,duration_ms,recording_type,review_status,consent_status,sha256,recorded_at,created_at,video_path\r\n',
    );
    for (var i = 0; i < metadata.length; i++) {
      out.writeln(metadata[i].values.map(cell).join(','));
    }
    return out.toString();
  }
}

class _ZipEntry {
  const _ZipEntry._(this.name, this.bytes, this.file);
  factory _ZipEntry.bytes(String name, List<int> bytes) =>
      _ZipEntry._(name, Uint8List.fromList(bytes), null);
  factory _ZipEntry.file(String name, File file) =>
      _ZipEntry._(name, null, file);

  final String name;
  final Uint8List? bytes;
  final File? file;

  Future<int> get length async => bytes?.length ?? await file!.length();
  Future<int> get crc async {
    var value = 0xffffffff;
    if (bytes != null) {
      for (final byte in bytes!) {
        value = _crcByte(value, byte);
      }
    } else {
      await for (final chunk in file!.openRead()) {
        for (final byte in chunk) {
          value = _crcByte(value, byte);
        }
      }
    }
    return (value ^ 0xffffffff) & 0xffffffff;
  }

  Future<void> writeData(RandomAccessFile output) async {
    if (bytes != null) {
      await output.writeFrom(bytes!);
    } else {
      await for (final chunk in file!.openRead()) {
        await output.writeFrom(chunk);
      }
    }
  }
}

final List<int> _crcTable = List<int>.generate(256, (index) {
  var value = index;
  for (var bit = 0; bit < 8; bit++) {
    value = (value & 1) == 1 ? (value >> 1) ^ 0xedb88320 : value >> 1;
  }
  return value;
}, growable: false);

int _crcByte(int crc, int byte) => (crc >> 8) ^ _crcTable[(crc ^ byte) & 0xff];

Future<void> _writeZip(RandomAccessFile output, List<_ZipEntry> entries) async {
  final central = <({Uint8List name, int crc, int size, int offset})>[];
  for (final entry in entries) {
    final name = Uint8List.fromList(utf8.encode(entry.name));
    final size = await entry.length;
    if (size > 0xffffffff || output.positionSync() > 0xffffffff) {
      throw StateError(
        'This dataset is too large for the supported ZIP format.',
      );
    }
    final crc = await entry.crc;
    final offset = await output.position();
    await output.writeFrom(
      _header(
        signature: 0x04034b50,
        nameLength: name.length,
        crc: crc,
        size: size,
      ),
    );
    await output.writeFrom(name);
    await entry.writeData(output);
    central.add((name: name, crc: crc, size: size, offset: offset));
  }

  final centralOffset = await output.position();
  for (final item in central) {
    await output.writeFrom(
      _header(
        signature: 0x02014b50,
        nameLength: item.name.length,
        crc: item.crc,
        size: item.size,
        localOffset: item.offset,
      ),
    );
    await output.writeFrom(item.name);
  }
  final centralSize = (await output.position()) - centralOffset;
  await output.writeFrom(
    _endRecord(central.length, centralSize, centralOffset),
  );
}

Uint8List _header({
  required int signature,
  required int nameLength,
  required int crc,
  required int size,
  int localOffset = 0,
}) {
  final data = ByteData(30);
  data.setUint32(0, signature, Endian.little);
  data.setUint16(4, 20, Endian.little);
  data.setUint16(6, 0x800, Endian.little);
  data.setUint16(8, 0, Endian.little);
  data.setUint16(10, 0, Endian.little);
  data.setUint16(12, 0, Endian.little);
  data.setUint32(14, crc, Endian.little);
  data.setUint32(18, size, Endian.little);
  data.setUint32(22, size, Endian.little);
  data.setUint16(26, nameLength, Endian.little);
  data.setUint16(28, 0, Endian.little);
  if (signature == 0x02014b50) {
    final central = ByteData(46);
    central.setUint32(0, signature, Endian.little);
    central.setUint16(4, 20, Endian.little);
    central.setUint16(6, 20, Endian.little);
    central.setUint16(8, 0x800, Endian.little);
    central.setUint16(10, 0, Endian.little);
    central.setUint16(12, 0, Endian.little);
    central.setUint16(14, 0, Endian.little);
    central.setUint32(16, crc, Endian.little);
    central.setUint32(20, size, Endian.little);
    central.setUint32(24, size, Endian.little);
    central.setUint16(28, nameLength, Endian.little);
    central.setUint16(30, 0, Endian.little);
    central.setUint16(32, 0, Endian.little);
    central.setUint16(34, 0, Endian.little);
    central.setUint16(36, 0, Endian.little);
    central.setUint32(38, 0, Endian.little);
    central.setUint32(42, localOffset, Endian.little);
    return central.buffer.asUint8List();
  }
  return data.buffer.asUint8List();
}

Uint8List _endRecord(int count, int size, int offset) {
  final data = ByteData(22);
  data.setUint32(0, 0x06054b50, Endian.little);
  data.setUint16(4, 0, Endian.little);
  data.setUint16(6, 0, Endian.little);
  data.setUint16(8, count, Endian.little);
  data.setUint16(10, count, Endian.little);
  data.setUint32(12, size, Endian.little);
  data.setUint32(16, offset, Endian.little);
  data.setUint16(20, 0, Endian.little);
  return data.buffer.asUint8List();
}
