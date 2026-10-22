import 'dart:convert';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'local_workspace.dart';
import 'workspace_database.dart';

/// Workspace-scoped metadata operations shared by the existing collection UI.
/// Videos stay in files; this repository writes only relative paths and fields.
class WorkspaceRepository {
  const WorkspaceRepository(this.workspace);

  final LocalWorkspace workspace;

  Future<T> _withDatabase<T>(Future<T> Function(Database db) action) async {
    final db = await WorkspaceDatabase.open(
      p.join(workspace.rootPath, 'database.sqlite3'),
    );
    try {
      return await action(db);
    } finally {
      await db.close();
    }
  }

  Future<List<Map<String, dynamic>>> listParticipants({
    int skip = 0,
    int limit = 100,
  }) => _withDatabase((db) async {
    final rows = await db.query(
      'participants',
      orderBy: 'created_at DESC, id DESC',
      limit: limit,
      offset: skip,
    );
    return rows.map(_participantMap).toList();
  });

  Future<Map<String, dynamic>> createParticipant(Map<String, dynamic> data) =>
      _withDatabase((db) async {
        final name = _requiredText(data, 'name');
        final category = _requiredText(data, 'category');
        final now = DateTime.now().toUtc().toIso8601String();
        final id = _newId();
        final code = data['signer_id']?.toString().trim().isNotEmpty == true
            ? data['signer_id'].toString().trim()
            : await _nextParticipantCode(db);
        await db.insert('participants', {
          'id': id,
          'participant_code': code,
          'display_label': name,
          'category': category,
          'age': _asInt(data['age']),
          'gender': _nullableText(data['gender']),
          'education_level': _nullableText(data['education_level']),
          'consent_status': data['consent_status']?.toString() ?? 'pending',
          'status': data['status']?.toString() ?? 'active',
          'notes': _nullableText(data['notes']),
          'created_at': now,
          'updated_at': now,
        });
        return _participantMap(
          (await db.query(
            'participants',
            where: 'id = ?',
            whereArgs: [id],
          )).single,
        );
      });

  Future<Map<String, dynamic>> getParticipant(String id) =>
      _withDatabase((db) async {
        final rows = await db.query(
          'participants',
          where: 'id = ?',
          whereArgs: [id],
        );
        if (rows.isEmpty) throw StateError('Participant $id was not found.');
        return _participantMap(rows.single);
      });

  Future<Map<String, dynamic>> recordConsent(
    String participantId,
    Map<String, dynamic> data,
  ) => _withDatabase((db) async {
    final status =
        data['status']?.toString() ??
        data['consent_status']?.toString() ??
        'pending';
    const valid = {
      'pending',
      'consented',
      'declined',
      'withdrawn',
      'uncertain',
    };
    if (!valid.contains(status)) throw StateError('Invalid consent status.');
    final now = DateTime.now().toUtc().toIso8601String();
    final consentId = _newId();
    await db.transaction((txn) async {
      final participant = await txn.query(
        'participants',
        where: 'id = ?',
        whereArgs: [participantId],
        limit: 1,
      );
      if (participant.isEmpty) throw StateError('Participant was not found.');
      await txn.insert('consent_records', {
        'id': consentId,
        'participant_id': participantId,
        'consent_version': data['consent_version']?.toString() ?? 'local-v1',
        'consent_scope_json': jsonEncode(data['scope'] ?? const {}),
        'status': status,
        'consented_at': status == 'consented' ? now : null,
        'withdrawn_at': status == 'withdrawn' ? now : null,
        'document_path': _nullableText(data['document_path']),
        'recorded_by': _nullableText(data['recorded_by']),
        'notes': _nullableText(data['notes']),
        'created_at': now,
      });
      await txn.update(
        'participants',
        {'consent_status': status, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [participantId],
      );
    });
    return getParticipant(participantId);
  });

  Future<List<Map<String, dynamic>>> listSigns({
    int skip = 0,
    int limit = 100,
  }) => _withDatabase((db) async {
    final rows = await db.query(
      'signs',
      orderBy: 'display_name COLLATE NOCASE',
      limit: limit,
      offset: skip,
    );
    return rows.map(_signMap).toList();
  });

  Future<Map<String, dynamic>> createSign(Map<String, dynamic> data) =>
      _withDatabase((db) async {
        final now = DateTime.now().toUtc().toIso8601String();
        final gloss = _requiredText(data, 'gloss');
        final code = (data['sign_code']?.toString().trim().isNotEmpty ?? false)
            ? data['sign_code'].toString().trim()
            : gloss.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]+'), '_');
        final id = _newId();
        await db.insert('signs', {
          'id': id,
          'sign_code': code,
          'gloss': gloss,
          'display_name':
              data['display_name']?.toString().trim().isNotEmpty == true
              ? data['display_name'].toString().trim()
              : gloss,
          'category': _nullableText(data['category']),
          'description': _nullableText(data['description']),
          'instruction': _nullableText(data['instruction']),
          'active': data['active'] == false ? 0 : 1,
          'target_formats':
              _asInt(data['target_formats'] ?? data['target_repetitions']) ?? 3,
          'created_at': now,
          'updated_at': now,
        });
        return _signMap(
          (await db.query('signs', where: 'id = ?', whereArgs: [id])).single,
        );
      });

  Future<Map<String, dynamic>> getSign(String id) => _withDatabase((db) async {
    final rows = await db.query('signs', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) throw StateError('Sign $id was not found.');
    return _signMap(rows.single);
  });

  Future<Map<String, dynamic>> getSignByCode(String code) =>
      _withDatabase((db) async {
        final rows = await db.query(
          'signs',
          where: 'sign_code = ?',
          whereArgs: [code],
        );
        if (rows.isEmpty) throw StateError('Sign $code was not found.');
        return _signMap(rows.single);
      });

  Future<Map<String, dynamic>> createSession(Map<String, dynamic> data) =>
      _withDatabase((db) async {
        final participantId = data['signer_id']?.toString();
        if (participantId == null || participantId.isEmpty) {
          throw StateError('Select a participant before creating a session.');
        }
        final participant = await db.query(
          'participants',
          where: 'id = ?',
          whereArgs: [participantId],
          limit: 1,
        );
        if (participant.isEmpty) {
          throw StateError(
            'Selected participant was not found in this workspace.',
          );
        }
        final id = _newId();
        final now = DateTime.now().toUtc().toIso8601String();
        final conditions = jsonEncode({
          'lighting': data['lighting_condition'],
          'background': data['background'],
        });
        await db.transaction((txn) async {
          await txn.insert('collection_sessions', {
            'id': id,
            'session_type': data['session_type']?.toString() ?? 'conversation',
            'venue': data['venue']?.toString() ?? '',
            'protocol_version': data['protocol_version']?.toString() ?? 'v1',
            'recording_conditions_json': conditions,
            'status': 'planned',
            'notes': _nullableText(data['notes']),
            'created_at': now,
            'updated_at': now,
          });
          await txn.insert('session_participants', {
            'session_id': id,
            'participant_id': participantId,
            'role': 'signer',
          });
        });
        return _sessionMap(db, id);
      });

  Future<List<Map<String, dynamic>>> listSessions({
    int skip = 0,
    int limit = 100,
  }) => _withDatabase((db) async {
    final rows = await db.query(
      'collection_sessions',
      orderBy: 'created_at DESC',
      limit: limit,
      offset: skip,
    );
    return Future.wait(rows.map((row) => _sessionMap(db, row['id'] as String)));
  });

  Future<Map<String, dynamic>> getSession(String id) =>
      _withDatabase((db) => _sessionMap(db, id));

  Future<Map<String, dynamic>> updateSession(
    String id,
    Map<String, dynamic> data,
  ) => _withDatabase((db) async {
    final update = <String, Object?>{
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    for (final field in ['venue', 'notes', 'started_at', 'completed_at']) {
      if (data.containsKey(field)) {
        update[field] = data[field];
      }
    }
    if (data.containsKey('status')) {
      update['status'] = _sessionStatus(data['status'].toString());
    }
    await db.update(
      'collection_sessions',
      update,
      where: 'id = ?',
      whereArgs: [id],
    );
    return _sessionMap(db, id);
  });

  Future<Map<String, dynamic>> setSessionStatus(String id, String status) =>
      updateSession(id, {
        'status': status,
        if (status == 'in_progress')
          'started_at': DateTime.now().toUtc().toIso8601String(),
        if (status == 'completed')
          'completed_at': DateTime.now().toUtc().toIso8601String(),
      });

  Future<List<Map<String, dynamic>>> listRecordings({
    int skip = 0,
    int limit = 100,
  }) => _withDatabase((db) async {
    final rows = await db.query(
      'recordings',
      orderBy: 'created_at DESC',
      limit: limit,
      offset: skip,
    );
    return rows.map(_recordingMap).toList();
  });

  Future<Map<String, dynamic>> getRecording(String id) => _withDatabase((
    db,
  ) async {
    final rows = await db.query('recordings', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) throw StateError('Recording $id was not found.');
    return _recordingMap(rows.single);
  });

  /// Returns ordered utterance segments with their speaker and annotations.
  Future<List<Map<String, dynamic>>> listAnnotations(String recordingId) =>
      _withDatabase((db) async {
        final segments = await db.query(
          'utterance_segments',
          where: 'recording_id = ?',
          whereArgs: [recordingId],
          orderBy: 'sequence_no',
        );
        final result = <Map<String, dynamic>>[];
        for (final segment in segments) {
          final speakers = await db.rawQuery(
            '''
            SELECT ss.*, p.participant_code, p.display_label
            FROM segment_speakers ss
            LEFT JOIN participants p ON p.id = ss.participant_id
            WHERE ss.segment_id = ? ORDER BY ss.rowid
          ''',
            [segment['id']],
          );
          final entries = await db.query(
            'annotation_entries',
            where: 'segment_id = ?',
            whereArgs: [segment['id']],
            orderBy: 'created_at, id',
          );
          result.add({
            ...segment,
            'speakers': speakers,
            'annotations': entries,
          });
        }
        return result;
      });

  /// Saves an utterance and appends gloss/translation revisions without
  /// overwriting previous annotation text.
  Future<Map<String, dynamic>> saveAnnotation({
    required String recordingId,
    required int sequenceNo,
    required int? startMs,
    required int? endMs,
    required String boundaryStatus,
    required String annotationStatus,
    required String? participantId,
    required String? gloss,
    required String? translation,
    required String? languageTag,
    required String? annotatorLabel,
    required String? notes,
  }) => _withDatabase((db) async {
    if (sequenceNo < 1 ||
        (startMs != null && startMs < 0) ||
        (endMs != null && endMs < 0) ||
        (startMs != null && endMs != null && endMs < startMs)) {
      throw StateError('Check the utterance number and timestamp range.');
    }
    if (!const {'pending', 'uncertain', 'validated'}.contains(boundaryStatus)) {
      throw StateError('Invalid utterance boundary status.');
    }
    if (!const {
      'pending',
      'uncertain',
      'draft',
      'validated',
      'rejected',
    }.contains(annotationStatus)) {
      throw StateError('Invalid annotation status.');
    }
    final cleanGloss = _nullableText(gloss);
    final cleanTranslation = _nullableText(translation);
    if (cleanGloss == null &&
        cleanTranslation == null &&
        _nullableText(notes) == null) {
      throw StateError('Enter a gloss, translation, or annotation note.');
    }
    final now = DateTime.now().toUtc().toIso8601String();
    final segmentId = _newId();
    await db.transaction((txn) async {
      final recording = await txn.query(
        'recordings',
        where: 'id = ?',
        whereArgs: [recordingId],
        limit: 1,
      );
      if (recording.isEmpty) {
        throw StateError('Recording was not found in this workspace.');
      }
      if (participantId != null) {
        final participant = await txn.query(
          'participants',
          where: 'id = ?',
          whereArgs: [participantId],
          limit: 1,
        );
        if (participant.isEmpty) {
          throw StateError('Selected speaker was not found in this workspace.');
        }
      }
      final prior = await txn.query(
        'utterance_segments',
        where: 'recording_id = ? AND sequence_no = ?',
        whereArgs: [recordingId, sequenceNo],
        limit: 1,
      );
      String? previousGlossId;
      String? previousTranslationId;
      String? previousNoteId;
      if (prior.isNotEmpty) {
        final oldId = prior.single['id'] as String;
        final oldEntries = await txn.query(
          'annotation_entries',
          where: 'segment_id = ? AND status != ?',
          whereArgs: [oldId, 'rejected'],
        );
        for (final old in oldEntries) {
          if (old['annotation_kind'] == 'gloss') {
            previousGlossId = old['id'] as String;
          }
          if (old['annotation_kind'] == 'translation') {
            previousTranslationId = old['id'] as String;
          }
          if (old['annotation_kind'] == 'note') {
            previousNoteId = old['id'] as String;
          }
        }
        await txn.update(
          'utterance_segments',
          {
            'start_ms': startMs,
            'end_ms': endMs,
            'boundary_status': boundaryStatus,
            'notes': _nullableText(notes),
            'updated_at': now,
          },
          where: 'id = ?',
          whereArgs: [oldId],
        );
        await txn.delete(
          'segment_speakers',
          where: 'segment_id = ?',
          whereArgs: [oldId],
        );
        await txn.insert('segment_speakers', {
          'id': _newId(),
          'segment_id': oldId,
          'participant_id': participantId,
          'attribution_status': participantId == null
              ? 'unknown'
              : 'attributed',
        });
        if (cleanGloss != null) {
          await _insertAnnotation(
            txn,
            oldId,
            'gloss',
            cleanGloss,
            null,
            annotatorLabel,
            previousGlossId,
            annotationStatus,
            now,
          );
        }
        if (cleanTranslation != null) {
          await _insertAnnotation(
            txn,
            oldId,
            'translation',
            cleanTranslation,
            languageTag,
            annotatorLabel,
            previousTranslationId,
            annotationStatus,
            now,
          );
        }
        final cleanNotes = _nullableText(notes);
        if (cleanNotes != null) {
          await _insertAnnotation(
            txn,
            oldId,
            'note',
            cleanNotes,
            null,
            annotatorLabel,
            previousNoteId,
            annotationStatus,
            now,
          );
        }
        await txn.update(
          'recordings',
          {'annotation_status': 'in_progress', 'updated_at': now},
          where: 'id = ?',
          whereArgs: [recordingId],
        );
        return;
      }
      await txn.insert('utterance_segments', {
        'id': segmentId,
        'recording_id': recordingId,
        'sequence_no': sequenceNo,
        'start_ms': startMs,
        'end_ms': endMs,
        'boundary_status': boundaryStatus,
        'notes': _nullableText(notes),
        'created_at': now,
        'updated_at': now,
      });
      await txn.insert('segment_speakers', {
        'id': _newId(),
        'segment_id': segmentId,
        'participant_id': participantId,
        'attribution_status': participantId == null ? 'unknown' : 'attributed',
      });
      if (cleanGloss != null) {
        await _insertAnnotation(
          txn,
          segmentId,
          'gloss',
          cleanGloss,
          null,
          annotatorLabel,
          null,
          annotationStatus,
          now,
        );
      }
      if (cleanTranslation != null) {
        await _insertAnnotation(
          txn,
          segmentId,
          'translation',
          cleanTranslation,
          languageTag,
          annotatorLabel,
          null,
          annotationStatus,
          now,
        );
      }
      final cleanNotes = _nullableText(notes);
      if (cleanNotes != null) {
        await _insertAnnotation(
          txn,
          segmentId,
          'note',
          cleanNotes,
          null,
          annotatorLabel,
          null,
          annotationStatus,
          now,
        );
      }
      await txn.update(
        'recordings',
        {'annotation_status': 'in_progress', 'updated_at': now},
        where: 'id = ?',
        whereArgs: [recordingId],
      );
    });
    return (await listAnnotations(recordingId))
        .firstWhere((row) => row['sequence_no'] == sequenceNo);
  });

  static Future<void> _insertAnnotation(
    Transaction txn,
    String segmentId,
    String kind,
    String text,
    String? language,
    String? annotator,
    String? supersedesId,
    String annotationStatus,
    String now,
  ) async {
    await txn.insert('annotation_entries', {
      'id': _newId(),
      'segment_id': segmentId,
      'annotation_kind': kind,
      'text': text,
      'language_tag': language,
      'status': annotationStatus,
      'annotator_label': _nullableText(annotator),
      'supersedes_id': supersedesId,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<Map<String, dynamic>> _sessionMap(Database db, String id) async {
    final rows = await db.query(
      'collection_sessions',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) throw StateError('Session $id was not found.');
    final row = rows.single;
    final links = await db.query(
      'session_participants',
      where: 'session_id = ?',
      whereArgs: [id],
    );
    final participant = links.isEmpty
        ? <String, Object?>{}
        : _participantMap(
            (await db.query(
              'participants',
              where: 'id = ?',
              whereArgs: [links.first['participant_id']],
            )).first,
          );
    final recordings = await db.query(
      'recordings',
      where: 'session_id = ?',
      whereArgs: [id],
    );
    final decodedConditions = jsonDecode(
      row['recording_conditions_json']?.toString() ?? '{}',
    );
    final conditions = decodedConditions is Map
        ? Map<String, dynamic>.from(decodedConditions)
        : <String, dynamic>{};
    final status = row['status']?.toString() ?? 'planned';
    return {
      ...row,
      'public_id': id,
      'status': _apiSessionStatus(status),
      'signer_id': participant['id'],
      'signer': participant,
      'primary_signer': participant,
      'protocol_version': row['protocol_version'] ?? 'v1',
      'lighting_condition': conditions['lighting'] ?? '',
      'background': conditions['background'] ?? '',
      'total_recordings': recordings.length,
      'successful_recordings': recordings
          .where((r) => r['review_status'] == 'approved')
          .length,
      'created_at': row['created_at'],
    };
  }

  static Map<String, dynamic> _participantMap(Map<String, Object?> row) => {
    ...row,
    'signer_id': row['participant_code'],
    'name': row['display_label'],
    'consent_status': row['consent_status'] ?? 'pending',
  };

  static Map<String, dynamic> _signMap(Map<String, Object?> row) => {
    ...row,
    'label': row['display_name'],
    'active': row['active'] == 1,
    'target_repetitions': row['target_formats'],
  };

  static Map<String, dynamic> _recordingMap(Map<String, Object?> row) => {
    ...row,
    'public_id': row['id'],
    'client_id': row['id'],
    'file_url': row['relative_video_path'],
    'storage_path': row['relative_video_path'],
    'file_size': row['file_size_bytes'],
    'duration': ((row['duration_ms'] as int?) ?? 0) ~/ 1000,
    'recording_status': 'uploaded',
    'validation_status': row['review_status'],
    'remarks': row['notes'],
  };

  static String _sessionStatus(String status) => switch (status) {
    'created' => 'planned',
    'cancelled' => 'cancelled',
    'completed' => 'completed',
    'in_progress' => 'in_progress',
    _ => status,
  };

  static String _apiSessionStatus(String status) => switch (status) {
    'planned' => 'created',
    _ => status,
  };

  static String _requiredText(Map<String, dynamic> data, String key) {
    final value = data[key]?.toString().trim() ?? '';
    if (value.isEmpty) throw StateError('$key is required.');
    return value;
  }

  static String? _nullableText(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static int? _asInt(Object? value) =>
      value is int ? value : int.tryParse(value?.toString() ?? '');

  static Future<String> _nextParticipantCode(Database db) async {
    final rows = await db.rawQuery(
      "SELECT participant_code FROM participants WHERE participant_code GLOB 'S[0-9]*'",
    );
    final maxNumber = rows
        .map(
          (row) =>
              RegExp(r'^S(\d+)$')
                  .firstMatch(row['participant_code']?.toString() ?? ''),
        )
        .whereType<RegExpMatch>()
        .map((match) => int.parse(match.group(1)!))
        .fold<int>(0, (max, value) => value > max ? value : max);
    return 'S${(maxNumber + 1).toString().padLeft(3, '0')}';
  }

  static String _newId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
