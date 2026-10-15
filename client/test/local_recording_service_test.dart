import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:signbridge/core/recording/recorded_video.dart';
import 'package:signbridge/core/recording/recording_context.dart';
import 'package:signbridge/core/video/video_asset.dart';
import 'package:signbridge/core/workspace/local_recording_service.dart';
import 'package:signbridge/core/workspace/local_workspace.dart';
import 'package:signbridge/core/workspace/workspace_database.dart';
import 'package:signbridge/core/workspace/workspace_service.dart';
import 'package:signbridge/core/workspace/workspace_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDirectory;
  late Directory parentDirectory;
  late Directory sourceDirectory;
  late Directory settingsDirectory;
  late LocalWorkspace workspace;
  late File sourceFile;
  late RecordedVideo recordedVideo;

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tempDirectory = await Directory.systemTemp.createTemp(
      'signbridge_local_recording_test_',
    );
    parentDirectory = Directory(p.join(tempDirectory.path, 'workspaces'))
      ..createSync();
    sourceDirectory = Directory(p.join(tempDirectory.path, 'source'))
      ..createSync();
    settingsDirectory = Directory(p.join(tempDirectory.path, 'settings'))
      ..createSync();
    workspace = await WorkspaceService(settingsDirectory: settingsDirectory)
        .createWorkspace(parentPath: parentDirectory.path, name: 'Study');
    sourceFile = File(p.join(sourceDirectory.path, 'camera-output.mp4'));
    await sourceFile.writeAsBytes(List<int>.generate(4096, (i) => i % 251));
    const context = RecordingContext(
      sessionId: 'remote-session-id-is-not-used-as-local-session',
      signerId: '',
      signId: '',
      signLabel: '',
      captureFormat: '',
      captureFormatLabel: '',
      lightingCondition: 'Indoor artificial',
      background: 'Plain wall - light',
      fileName: 'continuous-event.mp4',
    );
    recordedVideo = RecordedVideo(
      context: context,
      video: VideoAsset.fromFile(
        sourceFile.path,
        const Duration(seconds: 11),
        4096,
      ),
      duration: const Duration(seconds: 11),
      recordedAt: DateTime.utc(2026, 10, 15, 12),
    );
  });

  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    await tempDirectory.delete(recursive: true);
  });

  test('saves verified video file and event metadata locally', () async {
    final service = LocalRecordingService();
    final saved = await service.approveAndSave(
      workspace: workspace,
      recording: recordedVideo,
      sessionType: 'conversation',
      consentStatus: 'not_recorded',
      notes: 'Field notes',
    );

    expect(saved.duplicate, isFalse);
    expect(saved.relativeVideoPath, 'videos/${saved.id}/original.mp4');
    expect(
      await File(saved.absoluteVideoPath).readAsBytes(),
      await sourceFile.readAsBytes(),
    );
    expect(await sourceFile.exists(), isTrue);

    final libraryEntries = await service.listRecordings(workspace);
    expect(libraryEntries, hasLength(1));
    expect(libraryEntries.single.id, saved.id);
    expect(libraryEntries.single.videoExists, isTrue);
    expect(libraryEntries.single.searchText, contains('field notes'));
    expect(libraryEntries.single.searchText, contains('conversation'));
    final opened = await service.getRecording(workspace, saved.id);
    expect(
      p.normalize(opened!.absoluteVideoPath),
      p.normalize(saved.absoluteVideoPath),
    );
    expect(opened.videoExists, isTrue);

    final database = await WorkspaceDatabase.open(
      p.join(workspace.rootPath, 'database.sqlite3'),
    );
    try {
      final recording = (await database.query('recordings')).single;
      expect(recording['relative_video_path'], saved.relativeVideoPath);
      expect(recording['recording_type'], 'conversation');
      expect(recording['consent_status'], 'not_recorded');
      expect(recording['file_size_bytes'], 4096);
      expect(recording['sha256'], saved.sha256);
      expect(recording['duration_ms'], 11000);
      expect(jsonDecode(recording['recording_conditions_json'] as String), {
        'lighting': 'Indoor artificial',
        'background': 'Plain wall - light',
      });
      final columns = await database.rawQuery('PRAGMA table_info(recordings)');
      expect(columns.map((row) => row['name']), isNot(contains('video_bytes')));
      expect(await database.query('recording_save_journal'), isEmpty);
    } finally {
      await database.close();
    }

    await File(saved.absoluteVideoPath).delete();
    final missingVideo = await service.getRecording(workspace, saved.id);
    expect(missingVideo?.videoExists, isFalse);
    final stillOneRow = await service.listRecordings(workspace);
    expect(stillOneRow, hasLength(1));
  });

  test('duplicate video content returns its existing record', () async {
    final service = LocalRecordingService();
    final first = await service.approveAndSave(
      workspace: workspace,
      recording: recordedVideo,
      sessionType: 'narrative',
      consentStatus: 'not_recorded',
    );
    final duplicate = await service.approveAndSave(
      workspace: workspace,
      recording: recordedVideo,
      sessionType: 'conversation',
      consentStatus: 'not_recorded',
    );

    expect(duplicate.duplicate, isTrue);
    expect(duplicate.id, first.id);
    final database = await WorkspaceDatabase.open(
      p.join(workspace.rootPath, 'database.sqlite3'),
    );
    try {
      expect(await database.query('recordings'), hasLength(1));
      expect(await database.query('collection_sessions'), hasLength(1));
    } finally {
      await database.close();
    }
  });

  test('approval links back to the local session and sign', () async {
    final repository = WorkspaceRepository(workspace);
    final participant = await repository.createParticipant({
      'name': 'Session signer',
      'category': 'community_member',
    });
    final sign = await repository.createSign({
      'sign_code': 'HELLO',
      'gloss': 'HELLO',
      'display_name': 'Hello',
    });
    final session = await repository.createSession({
      'signer_id': participant['id'],
      'lighting_condition': 'Daylight',
      'background': 'Plain wall',
    });
    final recording = recordedVideo.copyWith(
      context: recordedVideo.context.copyWith(
        sessionId: session['id'] as String,
        signerId: participant['id'] as String,
        signId: sign['id'] as String,
        captureFormat: 'standard_frontal',
        cueMarkers: const [
          {'timestamp_ms': 0, 'event_marker': 'recording_started'},
        ],
      ),
    );

    final saved = await LocalRecordingService().approveAndSave(
      workspace: workspace,
      recording: recording,
      sessionType: 'conversation',
      consentStatus: 'not_recorded',
    );
    final database = await WorkspaceDatabase.open(
      p.join(workspace.rootPath, 'database.sqlite3'),
    );
    try {
      final row = (await database.query('recordings')).single;
      expect(row['id'], saved.id);
      expect(row['session_id'], session['id']);
      expect(row['sign_id'], sign['id']);
      expect(row['capture_format'], 'standard_frontal');
      expect(jsonDecode(row['cue_markers_json'] as String), hasLength(1));
      expect(await database.query('collection_sessions'), hasLength(1));
    } finally {
      await database.close();
    }
  });

  test('missing source file leaves workspace unchanged', () async {
    await sourceFile.delete();
    await expectLater(
      LocalRecordingService().approveAndSave(
        workspace: workspace,
        recording: recordedVideo,
        sessionType: 'conversation',
        consentStatus: 'not_recorded',
      ),
      throwsA(isA<LocalRecordingException>()),
    );
    final database = await WorkspaceDatabase.open(
      p.join(workspace.rootPath, 'database.sqlite3'),
    );
    try {
      expect(await database.query('recordings'), isEmpty);
    } finally {
      await database.close();
    }
  });

  test('failed copy preserves source and removes partial output', () async {
    final service = LocalRecordingService(
      copyFile: (source, target) async {
        await File(target).writeAsBytes([1, 2, 3]);
        return File(target);
      },
    );
    await expectLater(
      service.approveAndSave(
        workspace: workspace,
        recording: recordedVideo,
        sessionType: 'conversation',
        consentStatus: 'not_recorded',
      ),
      throwsA(isA<LocalRecordingException>()),
    );
    expect(await sourceFile.exists(), isTrue);
    expect(Directory(p.join(workspace.rootPath, 'videos')).listSync(), isEmpty);
    final database = await WorkspaceDatabase.open(
      p.join(workspace.rootPath, 'database.sqlite3'),
    );
    try {
      expect(await database.query('recordings'), isEmpty);
      expect(await database.query('recording_save_journal'), isEmpty);
    } finally {
      await database.close();
    }
  });

  test(
    'database insert failure cleans copied file and preserves source',
    () async {
      final database = await WorkspaceDatabase.open(
        p.join(workspace.rootPath, 'database.sqlite3'),
      );
      await database.execute('''
      CREATE TRIGGER fail_recording_insert BEFORE INSERT ON recordings
      BEGIN SELECT RAISE(ABORT, 'simulated database write failure'); END
    ''');
      await database.close();

      await expectLater(
        LocalRecordingService().approveAndSave(
          workspace: workspace,
          recording: recordedVideo,
          sessionType: 'conversation',
          consentStatus: 'not_recorded',
        ),
        throwsA(anything),
      );
      expect(await sourceFile.exists(), isTrue);
      expect(
        Directory(p.join(workspace.rootPath, 'videos')).listSync(),
        isEmpty,
      );

      final reopened = await WorkspaceDatabase.open(
        p.join(workspace.rootPath, 'database.sqlite3'),
      );
      try {
        expect(await reopened.query('recordings'), isEmpty);
        expect(await reopened.query('recording_save_journal'), isEmpty);
      } finally {
        await reopened.close();
      }
    },
  );

  test(
    'consent status cannot be asserted without linked participants',
    () async {
      await expectLater(
        LocalRecordingService().approveAndSave(
          workspace: workspace,
          recording: recordedVideo,
          sessionType: 'conversation',
          consentStatus: 'consented',
        ),
        throwsA(isA<LocalRecordingException>()),
      );
      expect(await sourceFile.exists(), isTrue);
    },
  );

  test('upgrades an existing version 1 workspace before saving', () async {
    final databasePath = p.join(workspace.rootPath, 'database.sqlite3');
    final database = await WorkspaceDatabase.open(databasePath);
    await database.execute('ALTER TABLE recordings DROP COLUMN consent_status');
    await database.execute('DROP TABLE recording_save_journal');
    await database.update('workspace_info', {
      'schema_version': 1,
    }, where: 'id = 1');
    await database.execute('PRAGMA user_version = 1');
    await database.close();

    final manifestFile = File(p.join(workspace.rootPath, 'workspace.json'));
    final manifest =
        jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
    manifest['schema_version'] = 1;
    await manifestFile.writeAsString(jsonEncode(manifest));
    final selected = await WorkspaceService(
      settingsDirectory: settingsDirectory,
    ).selectWorkspace(workspace.rootPath);
    expect(selected.schemaVersion, WorkspaceDatabase.schemaVersion);

    final saved = await LocalRecordingService().approveAndSave(
      workspace: selected,
      recording: recordedVideo,
      sessionType: 'narrative',
      consentStatus: 'not_recorded',
    );
    expect(await File(saved.absoluteVideoPath).exists(), isTrue);
  });
}
