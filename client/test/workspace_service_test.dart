import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signbridge/core/workspace/workspace_database.dart';
import 'package:signbridge/core/workspace/workspace_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDirectory;
  late Directory workspaceParent;
  late Directory settingsDirectory;
  late WorkspaceService service;

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tempDirectory = await Directory.systemTemp.createTemp(
      'signbridge_workspace_test_',
    );
    workspaceParent = Directory('${tempDirectory.path}/workspaces')
      ..createSync();
    settingsDirectory = Directory('${tempDirectory.path}/settings')
      ..createSync();
    service = WorkspaceService(settingsDirectory: settingsDirectory);
  });

  tearDown(() async {
    await tempDirectory.delete(recursive: true);
    debugDefaultTargetPlatformOverride = null;
  });

  test('creates, selects, and reopens a versioned workspace', () async {
    final workspace = await service.createWorkspace(
      parentPath: workspaceParent.path,
      name: 'Conversation Study',
    );

    expect(workspace.schemaVersion, WorkspaceDatabase.schemaVersion);
    expect(File('${workspace.rootPath}/workspace.json').existsSync(), isTrue);
    expect(File('${workspace.rootPath}/database.sqlite3').existsSync(), isTrue);
    expect(Directory('${workspace.rootPath}/videos').existsSync(), isTrue);
    expect(Directory('${workspace.rootPath}/exports').existsSync(), isTrue);
    expect(Directory('${workspace.rootPath}/backups').existsSync(), isTrue);

    final reopened = await service.loadActiveWorkspace();
    expect(reopened?.id, workspace.id);
    expect(reopened?.rootPath, workspace.rootPath);

    final database = await WorkspaceDatabase.open(
      '${workspace.rootPath}/database.sqlite3',
    );
    try {
      final versionRows = await database.rawQuery('PRAGMA user_version');
      expect(versionRows.single.values.single, WorkspaceDatabase.schemaVersion);
      final tables = await database.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      );
      final tableNames = tables.map((row) => row['name']).toSet();
      expect(
        tableNames,
        containsAll([
          'participants',
          'consent_records',
          'collection_sessions',
          'session_participants',
          'recordings',
          'recording_participants',
          'utterance_segments',
          'segment_speakers',
          'annotation_entries',
        ]),
      );

      final recordingsColumns = await database.rawQuery(
        'PRAGMA table_info(recordings)',
      );
      expect(
        recordingsColumns.map((column) => column['name']),
        contains('relative_video_path'),
      );
      expect(
        recordingsColumns.map((column) => column['name']),
        isNot(contains('video_bytes')),
      );

      await database.insert('collection_sessions', {
        'id': 'session-1',
        'session_type': 'conversation',
        'created_at': '2026-10-15T00:00:00Z',
        'updated_at': '2026-10-15T00:00:00Z',
      });
      await database.insert('recordings', {
        'id': 'recording-1',
        'session_id': 'session-1',
        'recording_type': 'conversation',
        'relative_video_path': 'videos/recording-1/original.mp4',
        'file_name': 'original.mp4',
        'mime_type': 'video/mp4',
        'file_size_bytes': 1024,
        'created_at': '2026-10-15T00:00:00Z',
        'updated_at': '2026-10-15T00:00:00Z',
      });
      await database.insert('utterance_segments', {
        'id': 'segment-1',
        'recording_id': 'recording-1',
        'sequence_no': 1,
        'boundary_status': 'uncertain',
        'created_at': '2026-10-15T00:00:00Z',
        'updated_at': '2026-10-15T00:00:00Z',
      });
      await database.insert('annotation_entries', {
        'id': 'annotation-1',
        'segment_id': 'segment-1',
        'annotation_kind': 'gloss',
        'status': 'pending',
        'created_at': '2026-10-15T00:00:00Z',
        'updated_at': '2026-10-15T00:00:00Z',
      });
      final annotation = await database.query('annotation_entries');
      expect(annotation.single['text'], isNull);
      expect(annotation.single['status'], 'pending');
    } finally {
      await database.close();
    }
  });

  test('rejects an existing folder as a new workspace target', () async {
    await Directory('${workspaceParent.path}/Already Here').create();

    expect(
      () => service.createWorkspace(
        parentPath: workspaceParent.path,
        name: 'Already Here',
      ),
      throwsA(isA<WorkspaceException>()),
    );
  });

  test('rejects folders that are not SignBridge workspaces', () async {
    final plainFolder = Directory('${tempDirectory.path}/plain')..createSync();
    await expectLater(
      service.selectWorkspace(plainFolder.path),
      throwsA(isA<WorkspaceException>()),
    );
  });
}
