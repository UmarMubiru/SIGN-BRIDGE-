import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:signbridge/core/recording/recorded_video.dart';
import 'package:signbridge/core/recording/recording_context.dart';
import 'package:signbridge/core/video/video_asset.dart';
import 'package:signbridge/core/workspace/local_recording_service.dart';
import 'package:signbridge/core/workspace/local_workspace.dart';
import 'package:signbridge/core/workspace/workspace_copy_service.dart';
import 'package:signbridge/core/workspace/workspace_database.dart';
import 'package:signbridge/core/workspace/workspace_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temporary;
  late Directory destination;
  late Directory settings;
  late LocalWorkspace workspace;

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    temporary = await Directory.systemTemp.createTemp('signbridge_copy_test_');
    destination = Directory(p.join(temporary.path, 'destination'))
      ..createSync();
    final parent = Directory(p.join(temporary.path, 'workspaces'))
      ..createSync();
    settings = Directory(p.join(temporary.path, 'settings'))..createSync();
    workspace = await WorkspaceService(settingsDirectory: settings)
        .createWorkspace(parentPath: parent.path, name: 'Portable Study');
  });

  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    await temporary.delete(recursive: true);
  });

  test('copies a workspace and verifies copied file checksums', () async {
    final source = File(p.join(temporary.path, 'recording.mp4'));
    final bytes = List<int>.generate(4096, (index) => index % 251);
    await source.writeAsBytes(bytes);
    const context = RecordingContext(
      sessionId: '',
      signerId: '',
      signId: '',
      signLabel: 'Conversation',
      captureFormat: '',
      captureFormatLabel: 'Continuous recording',
      lightingCondition: '',
      background: '',
      fileName: 'copy-check.mp4',
    );
    final saved = await LocalRecordingService().approveAndSave(
      workspace: workspace,
      recording: RecordedVideo(
        context: context,
        video: VideoAsset.fromFile(
          source.path,
          const Duration(seconds: 2),
          bytes.length,
        ),
        duration: const Duration(seconds: 2),
        recordedAt: DateTime.utc(2026),
      ),
      sessionType: 'conversation',
      consentStatus: 'not_recorded',
    );
    final originalVideoPath = saved.absoluteVideoPath;

    final copied = await WorkspaceCopyService().createCopy(
      workspace: workspace,
      destinationParent: destination.path,
      purpose: 'backup',
    );
    expect(await File(p.join(copied.path, 'workspace.json')).exists(), isTrue);
    expect(
      await File(p.join(copied.path, 'database.sqlite3')).exists(),
      isTrue,
    );
    expect(
      await File(p.join(copied.path, saved.relativeVideoPath)).readAsBytes(),
      bytes,
    );
    final manifest = jsonDecode(
      await File(p.join(copied.path, 'copy-manifest.json')).readAsString(),
    ) as Map<String, dynamic>;
    expect(manifest['workspace_id'], workspace.id);
    final manifestVideoPath = saved.relativeVideoPath.replaceAll('\\', '/');
    expect(manifest['files'][manifestVideoPath]['sha256'], isNotEmpty);
    expect(manifest['files']['database.sqlite3']['sha256'], isNotEmpty);

    final originalDatabase = File(
      p.join(workspace.rootPath, 'database.sqlite3'),
    );
    final originalDatabaseHash = await sha256
        .bind(originalDatabase.openRead())
        .first;

    final copiedDb = await WorkspaceDatabase.open(
      p.join(copied.path, 'database.sqlite3'),
    );
    try {
      final rows = await copiedDb.query('recordings');
      expect(rows, hasLength(1));
      expect(rows.single['id'], saved.id);
      expect(rows.single['relative_video_path'], saved.relativeVideoPath);
    } finally {
      await copiedDb.close();
    }

    final reopened = await WorkspaceService(settingsDirectory: settings)
        .selectWorkspace(copied.path);
    expect(reopened.id, workspace.id);
    expect(reopened.name, 'Portable Study');
    expect(await File(originalVideoPath).readAsBytes(), bytes);
    expect(
      await sha256.bind(originalDatabase.openRead()).first,
      originalDatabaseHash,
    );
    final originalDb = await WorkspaceDatabase.open(
      p.join(workspace.rootPath, 'database.sqlite3'),
    );
    try {
      expect(await originalDb.query('recordings'), hasLength(1));
    } finally {
      await originalDb.close();
    }
  });

  test('refuses a destination inside the workspace', () async {
    await expectLater(
      WorkspaceCopyService().createCopy(
        workspace: workspace,
        destinationParent: p.join(workspace.rootPath, 'backups'),
        purpose: 'backup',
      ),
      throwsStateError,
    );
  });
}
