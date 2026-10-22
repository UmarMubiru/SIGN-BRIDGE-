import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart' show IconData, Icons;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../recording/recorded_video.dart';
import 'local_workspace.dart';
import 'workspace_database.dart';

typedef RecordingFileCopier = Future<File> Function(File source, String target);

class LocalRecordingException implements Exception {
  const LocalRecordingException(this.message);
  final String message;

  @override
  String toString() => message;
}

class SavedLocalRecording {
  const SavedLocalRecording({
    required this.id,
    required this.relativeVideoPath,
    required this.absoluteVideoPath,
    required this.sha256,
    required this.fileSizeBytes,
    required this.duplicate,
  });

  final String id;
  final String relativeVideoPath;
  final String absoluteVideoPath;
  final String sha256;
  final int fileSizeBytes;
  final bool duplicate;
}

class LocalWorkspaceRecording {
  const LocalWorkspaceRecording({
    required this.id,
    required this.relativeVideoPath,
    required this.absoluteVideoPath,
    required this.fileName,
    required this.recordingType,
    required this.fileSizeBytes,
    required this.durationMs,
    required this.sha256,
    required this.reviewStatus,
    required this.consentStatus,
    required this.recordedAt,
    required this.createdAt,
    required this.videoExists,
    required this.searchText,
  });

  final String id;
  final String relativeVideoPath;
  final String absoluteVideoPath;
  final String fileName;
  final String recordingType;
  final int fileSizeBytes;
  final int? durationMs;
  final String? sha256;
  final String reviewStatus;
  final String consentStatus;
  final DateTime? recordedAt;
  final DateTime createdAt;
  final bool videoExists;
  final String searchText;
}

class WorkspaceActivity {
  const WorkspaceActivity({
    required this.title,
    required this.details,
    required this.createdAt,
    required this.icon,
    this.recordingId,
  });

  final String title;
  final String details;
  final DateTime createdAt;
  final IconData icon;
  final String? recordingId;
}

/// Saves one continuous event video to the selected workspace without touching
/// its source or communicating with the cloud API.
class LocalRecordingService {
  LocalRecordingService({RecordingFileCopier? copyFile})
    : _copyFile = copyFile ?? _copy;

  final RecordingFileCopier _copyFile;

  Future<List<WorkspaceActivity>> listRecentActivity(
    LocalWorkspace workspace,
  ) async {
    final database = await WorkspaceDatabase.open(
      p.join(workspace.rootPath, 'database.sqlite3'),
    );
    try {
      final rows = await database.rawQuery('''
        SELECT 'Recording approved and saved' AS title,
               COALESCE(file_name, 'Recording') AS details,
               COALESCE(updated_at, created_at) AS activity_at,
               'recording' AS kind, id AS recording_id
          FROM recordings
        UNION ALL
        SELECT 'Session created', session_type,
               COALESCE(updated_at, created_at), 'session', NULL
          FROM collection_sessions
        UNION ALL
        SELECT 'Annotation added', COALESCE(text, annotation_kind),
               COALESCE(updated_at, created_at), 'annotation',
               (SELECT u.recording_id FROM utterance_segments u
                 WHERE u.id = annotation_entries.segment_id)
          FROM annotation_entries
        UNION ALL
        SELECT 'Participant added', display_label, updated_at,
               'participant', NULL FROM participants
        UNION ALL
        SELECT 'Sign added', display_name, updated_at, 'sign', NULL FROM signs
        UNION ALL
        SELECT 'Consent updated', status, COALESCE(consented_at, created_at),
               'consent', NULL FROM consent_records
        ORDER BY activity_at DESC LIMIT 12
      ''');
      return rows.map((row) {
        final kind = row['kind']?.toString();
        return WorkspaceActivity(
          title: row['title']?.toString() ?? 'Workspace updated',
          details: row['details']?.toString() ?? '',
          createdAt: DateTime.tryParse(row['activity_at']?.toString() ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0),
          recordingId: row['recording_id']?.toString(),
          icon: switch (kind) {
            'recording' => Icons.video_library_outlined,
            'session' => Icons.event_note_outlined,
            'annotation' => Icons.notes_outlined,
            'participant' => Icons.person_outline,
            'sign' => Icons.sign_language,
            'consent' => Icons.verified_user_outlined,
            _ => Icons.history,
          },
        );
      }).toList();
    } finally {
      await database.close();
    }
  }

  Future<List<LocalWorkspaceRecording>> listRecordings(
    LocalWorkspace workspace,
  ) async {
    final database = await WorkspaceDatabase.open(
      p.join(workspace.rootPath, 'database.sqlite3'),
    );
    try {
      final rows = await database.rawQuery('''
        SELECT r.*,
          s.venue AS session_venue,
          s.notes AS session_notes,
          GROUP_CONCAT(DISTINCT p.display_label) AS participant_names,
          GROUP_CONCAT(DISTINCT p.participant_code) AS participant_codes,
          (SELECT GROUP_CONCAT(a.text, ' ')
             FROM utterance_segments u
             JOIN annotation_entries a ON a.segment_id = u.id
            WHERE u.recording_id = r.id) AS annotation_text
        FROM recordings r
        LEFT JOIN collection_sessions s ON s.id = r.session_id
        LEFT JOIN session_participants sp ON sp.session_id = s.id
        LEFT JOIN participants p ON p.id = sp.participant_id
        GROUP BY r.id
        ORDER BY r.created_at DESC, r.id DESC
      ''');
      return await Future.wait(
        rows.map((row) => _mapRecording(workspace, row)),
      );
    } finally {
      await database.close();
    }
  }

  Future<LocalWorkspaceRecording?> getRecording(
    LocalWorkspace workspace,
    String recordingId,
  ) async {
    final database = await WorkspaceDatabase.open(
      p.join(workspace.rootPath, 'database.sqlite3'),
    );
    try {
      final rows = await database.query(
        'recordings',
        where: 'id = ?',
        whereArgs: [recordingId],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return await _mapRecording(workspace, rows.single);
    } finally {
      await database.close();
    }
  }

  Future<LocalWorkspaceRecording> _mapRecording(
    LocalWorkspace workspace,
    Map<String, Object?> row,
  ) async {
    final id = row['id'] as String;
    final relativePath = row['relative_video_path'] as String;
    final expectedPath = 'videos/$id/original.mp4';
    if (relativePath != expectedPath) {
      throw const LocalRecordingException(
        'A workspace recording has an invalid relative video path.',
      );
    }
    final absolutePath = p.join(workspace.rootPath, relativePath);
    final recordedAtText = row['recorded_at'] as String?;
    return LocalWorkspaceRecording(
      id: id,
      relativeVideoPath: relativePath,
      absoluteVideoPath: absolutePath,
      fileName: row['file_name'] as String,
      recordingType: row['recording_type'] as String,
      fileSizeBytes: row['file_size_bytes'] as int,
      durationMs: row['duration_ms'] as int?,
      sha256: row['sha256'] as String?,
      reviewStatus: row['review_status'] as String,
      consentStatus: row['consent_status'] as String? ?? 'not_recorded',
      recordedAt: recordedAtText == null
          ? null
          : DateTime.tryParse(recordedAtText),
      createdAt: DateTime.parse(row['created_at'] as String),
      videoExists: await File(absolutePath).exists(),
      searchText: [
        row['file_name'],
        row['recording_type'],
        row['relative_video_path'],
        row['sha256'],
        row['review_status'],
        row['consent_status'],
        row['notes'],
        row['session_venue'],
        row['session_notes'],
        row['participant_names'],
        row['participant_codes'],
        row['annotation_text'],
      ].whereType<Object>().join(' ').toLowerCase(),
    );
  }

  Future<SavedLocalRecording> approveAndSave({
    required LocalWorkspace workspace,
    required RecordedVideo recording,
    required String sessionType,
    required String consentStatus,
    String? notes,
    List<String> participantIds = const [],
  }) async {
    if (!const {'conversation', 'narrative', 'other'}.contains(sessionType)) {
      throw const LocalRecordingException('Select a recording event type.');
    }
    if (!const {
      'not_recorded',
      'pending',
      'consented',
      'declined',
      'withdrawn',
      'uncertain',
    }.contains(consentStatus)) {
      throw const LocalRecordingException('The consent status is invalid.');
    }
    if (participantIds.isEmpty && consentStatus != 'not_recorded') {
      throw const LocalRecordingException(
        'Consent status cannot be recorded without linked participant information.',
      );
    }
    final sourcePath = recording.video.localPath;
    if (sourcePath == null || sourcePath.isEmpty) {
      throw const LocalRecordingException(
        'This recording has no local source file to save to the workspace.',
      );
    }
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw const LocalRecordingException(
        'The original recording file is missing. It has not been removed.',
      );
    }
    final sourceStat = await source.stat();
    if (sourceStat.type != FileSystemEntityType.file || sourceStat.size <= 0) {
      throw const LocalRecordingException(
        'The original recording is empty or is not a file.',
      );
    }

    final databasePath = p.join(workspace.rootPath, 'database.sqlite3');
    final database = await WorkspaceDatabase.open(databasePath);
    try {
      await recoverInterruptedSaves(workspace, database: database);
      final sourceDigest = await _digest(source);
      final matches = await database.query(
        'recordings',
        columns: ['id', 'relative_video_path', 'file_size_bytes', 'sha256'],
        where: 'sha256 = ?',
        whereArgs: [sourceDigest],
        limit: 1,
      );
      if (matches.isNotEmpty) {
        final existing = matches.single;
        final existingId = existing['id'] as String;
        final relativePath = existing['relative_video_path'] as String;
        final expectedPath = 'videos/$existingId/original.mp4';
        if (relativePath != expectedPath) {
          throw const LocalRecordingException(
            'A matching workspace record has an invalid video path. The source recording is preserved.',
          );
        }
        final existingFile = File(p.join(workspace.rootPath, relativePath));
        if (!await existingFile.exists() ||
            (await existingFile.stat()).size !=
                (existing['file_size_bytes'] as int) ||
            await _digest(existingFile) != sourceDigest) {
          throw const LocalRecordingException(
            'A matching workspace record already exists, but its video file is missing or damaged. The source recording is preserved.',
          );
        }
        return SavedLocalRecording(
          id: existingId,
          relativeVideoPath: relativePath,
          absoluteVideoPath: p.join(workspace.rootPath, relativePath),
          sha256: sourceDigest,
          fileSizeBytes: existing['file_size_bytes'] as int,
          duplicate: true,
        );
      }

      final id = _newId();
      final temporaryRelativePath = 'videos/.pending-$id';
      final finalRelativePath = 'videos/$id';
      final temporaryDirectory = Directory(
        p.join(workspace.rootPath, temporaryRelativePath),
      );
      final finalDirectory = Directory(
        p.join(workspace.rootPath, finalRelativePath),
      );
      final relativeVideoPath = '$finalRelativePath/original.mp4';
      final temporaryFile = File(
        p.join(temporaryDirectory.path, 'original.mp4'),
      );
      final finalFile = File(p.join(finalDirectory.path, 'original.mp4'));
      final createdAt = DateTime.now().toUtc().toIso8601String();
      var published = false;

      await database.insert('recording_save_journal', {
        'recording_id': id,
        'temporary_relative_path': temporaryRelativePath,
        'final_relative_path': finalRelativePath,
        'created_at': createdAt,
      });

      try {
        await temporaryDirectory.create();
        await _copyFile(source, temporaryFile.path);
        final copiedStat = await temporaryFile.stat();
        if (copiedStat.size != sourceStat.size ||
            await _digest(temporaryFile) != sourceDigest) {
          throw const LocalRecordingException(
            'The copied video did not pass verification. The original is preserved.',
          );
        }
        await temporaryDirectory.rename(finalDirectory.path);
        published = true;

        final conditions = jsonEncode({
          'lighting': recording.context.lightingCondition,
          'background': recording.context.background,
        });
        final mimeType = recording.video.mimeType.isEmpty
            ? 'video/mp4'
            : recording.video.mimeType;
        await database.transaction((txn) async {
          final requestedSessionId = recording.context.sessionId.trim();
          final linkedSession = requestedSessionId.isEmpty
              ? const <Map<String, Object?>>[]
              : await txn.query(
                  'collection_sessions',
                  where: 'id = ?',
                  whereArgs: [requestedSessionId],
                  limit: 1,
                );
          final hasLinkedSession = linkedSession.isNotEmpty;
          final sessionId = hasLinkedSession ? requestedSessionId : 'event-$id';
          final signerParticipantId = await _ensureLocalParticipant(
            txn,
            recording.context.signerId,
            createdAt,
          );
          final localSignId = await _ensureLocalSign(
            txn,
            recording.context.signId,
            recording.context.signLabel,
            createdAt,
          );
          final requestedParticipants = <String>{
            ...participantIds,
            ...?(signerParticipantId == null
                ? null
                : <String>[signerParticipantId]),
          };
          final linkedParticipants = <String>{...requestedParticipants};
          if (hasLinkedSession) {
            final sessionParticipantRows = await txn.query(
              'session_participants',
              columns: ['participant_id'],
              where: 'session_id = ?',
              whereArgs: [sessionId],
            );
            linkedParticipants.addAll(
              sessionParticipantRows.map(
                (row) => row['participant_id'] as String,
              ),
            );
          }
          if (!hasLinkedSession) {
            await txn.insert('collection_sessions', {
              'id': sessionId,
              'session_type': sessionType,
              'recording_conditions_json': conditions,
              'status': 'completed',
              'started_at': recording.recordedAt.toUtc().toIso8601String(),
              'completed_at': createdAt,
              'notes': _nonEmpty(notes),
              'created_at': createdAt,
              'updated_at': createdAt,
            });
          }
          for (final participantId in requestedParticipants) {
            await txn.insert('session_participants', {
              'session_id': sessionId,
              'participant_id': participantId,
            }, conflictAlgorithm: ConflictAlgorithm.ignore);
          }
          await txn.insert('recordings', {
            'id': id,
            'session_id': sessionId,
            'recording_type': sessionType,
            'sign_id': localSignId,
            'capture_format': recording.context.captureFormat,
            'cue_markers_json': jsonEncode(recording.context.cueMarkers),
            'relative_video_path': relativeVideoPath,
            'file_name': p.basename(recording.context.fileName).isEmpty
                ? 'original.mp4'
                : p.basename(recording.context.fileName),
            'mime_type': mimeType,
            'file_size_bytes': copiedStat.size,
            'duration_ms': recording.duration.inMilliseconds,
            'sha256': sourceDigest,
            'recording_conditions_json': conditions,
            'consent_status': consentStatus,
            'review_status': 'approved',
            'annotation_status': 'not_started',
            'notes': _nonEmpty(notes),
            'recorded_at': recording.recordedAt.toUtc().toIso8601String(),
            'created_at': createdAt,
            'updated_at': createdAt,
          });
          for (final participantId in linkedParticipants) {
            await txn.insert('recording_participants', {
              'recording_id': id,
              'participant_id': participantId,
              'role': null,
            });
          }
          await txn.delete(
            'recording_save_journal',
            where: 'recording_id = ?',
            whereArgs: [id],
          );
        });

        return SavedLocalRecording(
          id: id,
          relativeVideoPath: relativeVideoPath,
          absoluteVideoPath: finalFile.path,
          sha256: sourceDigest,
          fileSizeBytes: copiedStat.size,
          duplicate: false,
        );
      } catch (_) {
        // The journal is deliberately retained if cleanup fails; the next
        // open/save can retry cleanup without ever touching the source.
        var cleaned = true;
        try {
          if (published && await finalDirectory.exists()) {
            await finalDirectory.delete(recursive: true);
          }
          if (await temporaryDirectory.exists()) {
            await temporaryDirectory.delete(recursive: true);
          }
        } catch (_) {
          cleaned = false;
        }
        if (cleaned) {
          try {
            await database.delete(
              'recording_save_journal',
              where: 'recording_id = ?',
              whereArgs: [id],
            );
          } catch (_) {
            // Recovery will use the journal on the next attempt.
          }
        }
        rethrow;
      }
    } finally {
      await database.close();
    }
  }

  Future<void> recoverInterruptedSaves(
    LocalWorkspace workspace, {
    Database? database,
  }) async {
    final db =
        database ??
        await WorkspaceDatabase.open(
          p.join(workspace.rootPath, 'database.sqlite3'),
        );
    final shouldClose = database == null;
    try {
      final journals = await db.query('recording_save_journal');
      for (final journal in journals) {
        final id = journal['recording_id'] as String;
        final finalRelative = journal['final_relative_path'] as String;
        final temporaryRelative = journal['temporary_relative_path'] as String;
        if (finalRelative != 'videos/$id' ||
            temporaryRelative != 'videos/.pending-$id') {
          continue;
        }
        final hasRecording = await db.query(
          'recordings',
          columns: ['id'],
          where: 'id = ?',
          whereArgs: [id],
          limit: 1,
        );
        if (hasRecording.isEmpty) {
          final finalDirectory = Directory(
            p.join(workspace.rootPath, finalRelative),
          );
          final temporaryDirectory = Directory(
            p.join(workspace.rootPath, temporaryRelative),
          );
          if (await finalDirectory.exists()) {
            await finalDirectory.delete(recursive: true);
          }
          if (await temporaryDirectory.exists()) {
            await temporaryDirectory.delete(recursive: true);
          }
        }
        await db.delete(
          'recording_save_journal',
          where: 'recording_id = ?',
          whereArgs: [id],
        );
      }
    } finally {
      if (shouldClose) await db.close();
    }
  }

  static Future<File> _copy(File source, String target) => source.copy(target);

  static Future<String?> _ensureLocalSign(
    Transaction txn,
    String sourceSignId,
    String signLabel,
    String timestamp,
  ) async {
    final signId = sourceSignId.trim();
    final label = _nonEmpty(signLabel) ?? signId;
    if (label.isEmpty) return null;
    final signs = await txn.query(
      'signs',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [signId],
      limit: 1,
    );
    if (signs.isNotEmpty) return signs.single['id'] as String;

    final code = label
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    if (code.isEmpty) return null;
    final existing = await txn.query(
      'signs',
      columns: ['id'],
      where: 'sign_code = ?',
      whereArgs: [code],
      limit: 1,
    );
    if (existing.isNotEmpty) return existing.single['id'] as String;

    final id = _newId();
    await txn.insert('signs', {
      'id': id,
      'sign_code': code,
      'gloss': label,
      'display_name': label,
      'created_at': timestamp,
      'updated_at': timestamp,
    });
    return id;
  }

  static Future<String?> _ensureLocalParticipant(
    Transaction txn,
    String sourceSignerId,
    String timestamp,
  ) async {
    final code = sourceSignerId.trim();
    if (code.isEmpty) return null;
    final localId = await txn.query(
      'participants',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [code],
      limit: 1,
    );
    if (localId.isNotEmpty) return localId.single['id'] as String;
    final existing = await txn.query(
      'participants',
      columns: ['id'],
      where: 'participant_code = ?',
      whereArgs: [code],
      limit: 1,
    );
    if (existing.isNotEmpty) return existing.single['id'] as String;

    final id = _newId();
    await txn.insert('participants', {
      'id': id,
      'participant_code': code,
      'display_label': code,
      'category': 'signer',
      'consent_status': 'pending',
      'status': 'active',
      'created_at': timestamp,
      'updated_at': timestamp,
    });
    return id;
  }

  static Future<String> _digest(File file) async =>
      (await sha256.bind(file.openRead()).first).toString();

  static String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static String _newId() {
    final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
