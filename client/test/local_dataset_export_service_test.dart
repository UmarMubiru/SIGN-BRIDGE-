import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:signbridge/core/recording/recorded_video.dart';
import 'package:signbridge/core/recording/recording_context.dart';
import 'package:signbridge/core/video/video_asset.dart';
import 'package:signbridge/core/workspace/local_dataset_export_service.dart';
import 'package:signbridge/core/workspace/local_recording_service.dart';
import 'package:signbridge/core/workspace/local_workspace.dart';
import 'package:signbridge/core/workspace/workspace_repository.dart';
import 'package:signbridge/core/workspace/workspace_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temporary;
  late LocalWorkspace workspace;
  late File sourceVideo;

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    temporary = await Directory.systemTemp.createTemp(
      'signbridge_export_test_',
    );
    final workspaceParent = Directory(p.join(temporary.path, 'workspaces'))
      ..createSync();
    final settings = Directory(p.join(temporary.path, 'settings'))
      ..createSync();
    workspace = await WorkspaceService(settingsDirectory: settings)
        .createWorkspace(
          parentPath: workspaceParent.path,
          name: 'Portable export',
        );
    sourceVideo = File(p.join(temporary.path, 'source.mp4'));
    await sourceVideo.writeAsBytes(List<int>.generate(256, (i) => i % 251));
  });

  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    await temporary.delete(recursive: true);
  });

  test('portable ZIP includes video annotations but excludes participant details', () async {
    final participant = await WorkspaceRepository(workspace).createParticipant({
      'name': 'Sensitive Participant Name',
      'category': 'signer',
    });
    final video = RecordedVideo(
      context: const RecordingContext(
        sessionId: '',
        signerId: '',
        signId: '',
        signLabel: 'Conversation',
        captureFormat: '',
        captureFormatLabel: 'Continuous recording',
        lightingCondition: '',
        background: '',
        fileName: 'conversation.mp4',
      ),
      video: VideoAsset.fromFile(
        sourceVideo.path,
        const Duration(seconds: 2),
        256,
      ),
      duration: const Duration(seconds: 2),
      recordedAt: DateTime.utc(2026, 10, 16),
    );
    final saved = await LocalRecordingService().approveAndSave(
      workspace: workspace,
      recording: video,
      sessionType: 'conversation',
      consentStatus: 'not_recorded',
    );
    await WorkspaceRepository(workspace).saveAnnotation(
      recordingId: saved.id,
      sequenceNo: 1,
      startMs: 250,
      endMs: 900,
      boundaryStatus: 'uncertain',
      annotationStatus: 'uncertain',
      participantId: participant['id'] as String,
      gloss: 'HELLO',
      translation: 'How are you?',
      languageTag: 'en',
      annotatorLabel: 'Private collector label',
      notes: 'Private field note',
    );

    final progressUpdates = <DatasetExportProgress>[];
    final archive =
        await LocalDatasetExportService(
          assetExtractor: (temporaryDirectory, recordings, onProgress) async {
            onProgress?.call(
              const DatasetExportProgress(
                stage: 'extractingFrames',
                processedFrames: 2,
                totalFrames: 8,
                recordingIndex: 1,
                recordingCount: 1,
                fileName: 'conversation.mp4',
              ),
            );
            final assets = Directory(p.join(temporaryDirectory.path, 'assets'));
            final frames = Directory(
              p.join(assets.path, 'frames', recordings.single.id),
            );
            await frames.create(recursive: true);
            await File(p.join(frames.path, 'frame_000000.jpg'))
                .writeAsBytes([0xff, 0xd8, 0xff, 0xd9]);
            await File(p.join(assets.path, 'orientation_frames.csv'))
                .writeAsString('recording_id,frame_index,image_path\r\n');
            await File(p.join(assets.path, 'landmarks.jsonl')).writeAsString(
              '{"recording_id":"${recordings.single.id}","face_landmarks":null,"hand_landmarks":[]}\n',
            );
            return assets;
          },
        ).createWorkspaceDataset(
          workspace: workspace,
          recordingIds: [saved.id],
          datasetName: 'Team sample',
          includeAnalysisAssets: true,
          onProgress: progressUpdates.add,
        );
    final contents = utf8.decode(
      await archive.readAsBytes(),
      allowMalformed: true,
    );
    expect(contents, contains('videos/conversation.mp4'));
    expect(contents, contains('metadata/recordings.json'));
    expect(contents, contains('metadata/recordings.csv'));
    expect(contents, contains('metadata/annotations.json'));
    expect(contents, contains('metadata/annotations.csv'));
    expect(contents, contains('"video_path": "videos/conversation.mp4"'));
    expect(contents, contains('speaker_001'));
    expect(contents, contains('HELLO'));
    expect(contents, contains('How are you?'));
    expect(contents, contains('uncertain'));
    expect(contents, isNot(contains('Sensitive Participant Name')));
    expect(contents, isNot(contains('Private collector label')));
    expect(contents, isNot(contains('Private field note')));
    expect(contents, contains('frames/${saved.id}/frame_000000.jpg'));
    expect(contents, contains('metadata/orientation_frames.csv'));
    expect(contents, contains('metadata/landmarks.jsonl'));
    expect(contents, contains('"face_landmarks":null'));
    expect(progressUpdates.any((item) => item.message == 'Frames 2 of 8 · Video 1 of 1'), isTrue);
    expect(progressUpdates.firstWhere((item) => item.stage == 'extractingFrames').fraction, 0.25);
    expect(
      (await LocalDatasetExportService().listDatasets(workspace))
          .map((file) => file.path)
          .toList(),
      [archive.path],
    );
  });
}
