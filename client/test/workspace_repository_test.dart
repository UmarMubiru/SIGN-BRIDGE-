import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:signbridge/core/workspace/workspace_repository.dart';
import 'package:signbridge/core/workspace/workspace_database.dart';
import 'package:signbridge/core/workspace/workspace_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  late WorkspaceRepository repository;

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    temp = await Directory.systemTemp.createTemp('signbridge_repo_test_');
    final parent = Directory(p.join(temp.path, 'workspaces'))..createSync();
    final settings = Directory(p.join(temp.path, 'settings'))..createSync();
    final workspace = await WorkspaceService(settingsDirectory: settings)
        .createWorkspace(parentPath: parent.path, name: 'Study');
    repository = WorkspaceRepository(workspace);
  });

  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    await temp.delete(recursive: true);
  });

  test(
    'participant, sign, and session operations persist in this workspace',
    () async {
      final participant = await repository.createParticipant({
        'name': 'Local signer',
        'category': 'community_member',
        'age': 24,
        'gender': 'female',
      });
      expect(participant['signer_id'], 'S001');
      expect(participant['age'], 24);

      final sign = await repository.createSign({
        'sign_code': 'HELLO',
        'gloss': 'HELLO',
        'display_name': 'Hello',
        'target_formats': 3,
      });
      expect((await repository.listSigns()).single['label'], 'Hello');

      final session = await repository.createSession({
        'signer_id': participant['id'],
        'venue': 'Field site',
        'protocol_version': 'v1',
        'lighting_condition': 'Daylight',
        'background': 'Plain wall',
      });
      expect(session['signer_id'], participant['id']);
      expect(session['signer']['name'], 'Local signer');
      expect(session['protocol_version'], 'v1');
      expect((await repository.getSign(sign['id']))['sign_code'], 'HELLO');

      final started = await repository.setSessionStatus(
        session['id'],
        'in_progress',
      );
      expect(started['status'], 'in_progress');
      final completed = await repository.setSessionStatus(
        session['id'],
        'completed',
      );
      expect(completed['status'], 'completed');
      expect((await repository.listSessions()).single['id'], session['id']);
    },
  );

  test(
    'consent updates participant status and keeps an audit record',
    () async {
      final participant = await repository.createParticipant({
        'name': 'Consent signer',
        'category': 'student',
      });

      final updated = await repository.recordConsent(participant['id'], {
        'status': 'consented',
        'consent_version': 'field-v1',
        'notes': 'Paper form checked',
      });
      expect(updated['consent_status'], 'consented');

      final dbFile = File(
        p.join(repository.workspace.rootPath, 'database.sqlite3'),
      );
      expect(await dbFile.exists(), isTrue);
      final database = await WorkspaceDatabase.open(dbFile.path);
      try {
        final records = await database.query('consent_records');
        expect(records, hasLength(1));
        expect(records.single['status'], 'consented');
        expect(records.single['consent_version'], 'field-v1');
      } finally {
        await database.close();
      }
    },
  );

  test(
    'utterance annotations retain speaker attribution and revisions',
    () async {
      final participant = await repository.createParticipant({
        'name': 'Conversation speaker',
        'category': 'community_member',
      });
      final session = await repository.createSession({
        'signer_id': participant['id'],
        'venue': 'Field site',
      });
      final database = await WorkspaceDatabase.open(
        p.join(repository.workspace.rootPath, 'database.sqlite3'),
      );
      try {
        await database.insert('recordings', {
          'id': 'recording-annotation-test',
          'session_id': session['id'],
          'recording_type': 'conversation',
          'relative_video_path':
              'videos/recording-annotation-test/original.mp4',
          'file_name': 'conversation.mp4',
          'mime_type': 'video/mp4',
          'file_size_bytes': 1,
          'review_status': 'approved',
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
      } finally {
        await database.close();
      }

      await repository.saveAnnotation(
        recordingId: 'recording-annotation-test',
        sequenceNo: 1,
        startMs: 1200,
        endMs: 4300,
        boundaryStatus: 'uncertain',
        annotationStatus: 'uncertain',
        participantId: participant['id'],
        gloss: 'HELLO',
        translation: 'Good morning',
        languageTag: 'en',
        annotatorLabel: 'Collector A',
        notes: 'Boundary uncertain',
      );
      await repository.saveAnnotation(
        recordingId: 'recording-annotation-test',
        sequenceNo: 1,
        startMs: 1100,
        endMs: 4300,
        boundaryStatus: 'validated',
        annotationStatus: 'validated',
        participantId: participant['id'],
        gloss: 'HELLO-GREETING',
        translation: 'Hello',
        languageTag: 'en',
        annotatorLabel: 'Collector B',
        notes: 'Reviewed boundary',
      );

      final utterances = await repository.listAnnotations(
        'recording-annotation-test',
      );
      expect(utterances, hasLength(1));
      expect(utterances.single['start_ms'], 1100);
      expect(utterances.single['boundary_status'], 'validated');
      expect(
        (utterances.single['speakers'] as List).single['participant_id'],
        participant['id'],
      );
      final entries = utterances.single['annotations'] as List;
      expect(entries, hasLength(6));
      final revisedGloss = entries.lastWhere(
        (entry) => entry['text'] == 'HELLO-GREETING',
      );
      expect(revisedGloss['supersedes_id'], isNotNull);
      expect(revisedGloss['annotator_label'], 'Collector B');
      expect(revisedGloss['status'], 'validated');
    },
  );
}
