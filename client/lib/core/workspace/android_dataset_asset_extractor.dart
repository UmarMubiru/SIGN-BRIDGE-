import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import 'local_dataset_export_service.dart';
import 'local_recording_service.dart';

class AndroidDatasetAssetExtractor {
  static const _methods = MethodChannel('signbridge/dataset_analysis');
  static const _events = EventChannel('signbridge/dataset_analysis/progress');

  Future<void> extract({
    required Directory outputDirectory,
    required List<LocalWorkspaceRecording> recordings,
    DatasetExportProgressCallback? onProgress,
  }) async {
    final subscription = _events.receiveBroadcastStream().listen((event) {
      if (event is! Map) return;
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
    });
    try {
      await _methods.invokeMethod<void>('extractDatasetAssets', {
        'outputDirectory': outputDirectory.path,
        'recordings': [
          for (final recording in recordings)
            {
              'recordingId': recording.id,
              'videoPath': recording.absoluteVideoPath,
              'fileName': recording.fileName,
              'durationMs': recording.durationMs,
            },
        ],
      });
    } on MissingPluginException {
      throw StateError(
        'Android frame and landmark extraction is unavailable in this build. Reinstall the current SignBridge release.',
      );
    } on PlatformException catch (error) {
      throw StateError(error.message ?? 'Android dataset analysis failed.');
    } finally {
      await subscription.cancel();
    }
  }
}
