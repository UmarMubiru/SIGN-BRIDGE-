import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart' as mobile_sqlite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class WorkspaceDatabase {
  WorkspaceDatabase._();

  static const schemaVersion = 3;

  static Future<Database> open(String databasePath) async {
    final DatabaseFactory factory;
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux)) {
      sqfliteFfiInit();
      factory = databaseFactoryFfi;
    } else {
      factory = mobile_sqlite.databaseFactory;
    }

    return factory.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (database) => database.execute('PRAGMA foreign_keys = ON'),
        onCreate: _createSchema,
        onUpgrade: _upgradeSchema,
      ),
    );
  }

  static Future<void> _createSchema(Database database, int version) {
    return database.transaction((txn) async {
      await txn.execute('''
        CREATE TABLE workspace_info (
          id INTEGER PRIMARY KEY CHECK (id = 1),
          workspace_id TEXT NOT NULL UNIQUE,
          schema_version INTEGER NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');
      await txn.execute('''
        CREATE TABLE participants (
          id TEXT PRIMARY KEY,
          participant_code TEXT NOT NULL UNIQUE,
          display_label TEXT NOT NULL,
          category TEXT,
          age INTEGER,
          gender TEXT,
          education_level TEXT,
          consent_status TEXT NOT NULL DEFAULT 'pending',
          status TEXT NOT NULL DEFAULT 'active',
          notes TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
      await txn.execute('''
        CREATE TABLE consent_records (
          id TEXT PRIMARY KEY,
          participant_id TEXT NOT NULL REFERENCES participants(id),
          consent_version TEXT NOT NULL,
          consent_scope_json TEXT NOT NULL DEFAULT '{}',
          status TEXT NOT NULL CHECK (status IN
            ('pending', 'consented', 'declined', 'withdrawn', 'uncertain')),
          consented_at TEXT,
          withdrawn_at TEXT,
          document_path TEXT,
          recorded_by TEXT,
          notes TEXT,
          created_at TEXT NOT NULL
        )
      ''');
      await txn.execute('''
        CREATE TABLE collection_sessions (
          id TEXT PRIMARY KEY,
          session_type TEXT NOT NULL CHECK
            (session_type IN ('conversation', 'narrative', 'other')),
          venue TEXT,
          collector_label TEXT,
          protocol_version TEXT NOT NULL DEFAULT 'v1',
          recording_conditions_json TEXT NOT NULL DEFAULT '{}',
          status TEXT NOT NULL DEFAULT 'planned' CHECK
            (status IN ('planned', 'in_progress', 'completed', 'cancelled')),
          started_at TEXT,
          completed_at TEXT,
          notes TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
      await txn.execute('''
        CREATE TABLE signs (
          id TEXT PRIMARY KEY,
          sign_code TEXT NOT NULL UNIQUE,
          gloss TEXT NOT NULL,
          display_name TEXT NOT NULL,
          category TEXT,
          description TEXT,
          instruction TEXT,
          active INTEGER NOT NULL DEFAULT 1,
          target_formats INTEGER NOT NULL DEFAULT 3,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
      await txn.execute('''
        CREATE TABLE session_participants (
          session_id TEXT NOT NULL REFERENCES collection_sessions(id)
            ON DELETE CASCADE,
          participant_id TEXT NOT NULL REFERENCES participants(id),
          role TEXT,
          notes TEXT,
          PRIMARY KEY (session_id, participant_id)
        )
      ''');
      await txn.execute('''
        CREATE TABLE recordings (
          id TEXT PRIMARY KEY,
          session_id TEXT NOT NULL REFERENCES collection_sessions(id),
          recording_type TEXT NOT NULL CHECK
            (recording_type IN ('conversation', 'narrative', 'other')),
          sign_id TEXT REFERENCES signs(id),
          capture_format TEXT,
          cue_markers_json TEXT NOT NULL DEFAULT '[]',
          relative_video_path TEXT NOT NULL UNIQUE,
          file_name TEXT NOT NULL,
          mime_type TEXT NOT NULL,
          file_size_bytes INTEGER NOT NULL CHECK (file_size_bytes > 0),
          duration_ms INTEGER CHECK (duration_ms IS NULL OR duration_ms >= 0),
          sha256 TEXT,
          width INTEGER,
          height INTEGER,
          frame_rate REAL,
          recording_conditions_json TEXT NOT NULL DEFAULT '{}',
          consent_status TEXT NOT NULL DEFAULT 'not_recorded' CHECK
            (consent_status IN
              ('not_recorded', 'pending', 'consented', 'declined', 'withdrawn', 'uncertain')),
          review_status TEXT NOT NULL DEFAULT 'pending' CHECK
            (review_status IN ('pending', 'approved', 'rejected')),
          annotation_status TEXT NOT NULL DEFAULT 'not_started' CHECK
            (annotation_status IN
              ('not_started', 'pending', 'in_progress', 'uncertain', 'complete')),
          notes TEXT,
          recorded_at TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
      await txn.execute('''
        CREATE TABLE recording_participants (
          recording_id TEXT NOT NULL REFERENCES recordings(id)
            ON DELETE CASCADE,
          participant_id TEXT NOT NULL REFERENCES participants(id),
          role TEXT,
          PRIMARY KEY (recording_id, participant_id)
        )
      ''');
      await txn.execute('''
        CREATE TABLE recording_save_journal (
          recording_id TEXT PRIMARY KEY,
          temporary_relative_path TEXT NOT NULL,
          final_relative_path TEXT NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');
      await txn.execute('''
        CREATE UNIQUE INDEX idx_recordings_sha256_unique
        ON recordings(sha256) WHERE sha256 IS NOT NULL
      ''');
      await txn.execute('''
        CREATE TABLE utterance_segments (
          id TEXT PRIMARY KEY,
          recording_id TEXT NOT NULL REFERENCES recordings(id)
            ON DELETE CASCADE,
          sequence_no INTEGER NOT NULL CHECK (sequence_no > 0),
          start_ms INTEGER CHECK (start_ms IS NULL OR start_ms >= 0),
          end_ms INTEGER CHECK (end_ms IS NULL OR end_ms >= 0),
          boundary_status TEXT NOT NULL DEFAULT 'pending' CHECK
            (boundary_status IN ('pending', 'uncertain', 'validated')),
          notes TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          CHECK (start_ms IS NULL OR end_ms IS NULL OR end_ms >= start_ms),
          UNIQUE (recording_id, sequence_no)
        )
      ''');
      await txn.execute('''
        CREATE TABLE segment_speakers (
          id TEXT PRIMARY KEY,
          segment_id TEXT NOT NULL REFERENCES utterance_segments(id)
            ON DELETE CASCADE,
          participant_id TEXT REFERENCES participants(id),
          attribution_status TEXT NOT NULL DEFAULT 'pending' CHECK
            (attribution_status IN
              ('pending', 'uncertain', 'attributed', 'unknown')),
          notes TEXT
        )
      ''');
      await txn.execute('''
        CREATE TABLE annotation_entries (
          id TEXT PRIMARY KEY,
          segment_id TEXT NOT NULL REFERENCES utterance_segments(id)
            ON DELETE CASCADE,
          annotation_kind TEXT NOT NULL CHECK
            (annotation_kind IN ('gloss', 'translation', 'note')),
          text TEXT,
          language_tag TEXT,
          status TEXT NOT NULL DEFAULT 'pending' CHECK
            (status IN ('pending', 'uncertain', 'draft', 'validated', 'rejected')),
          annotator_label TEXT,
          reviewer_label TEXT,
          supersedes_id TEXT REFERENCES annotation_entries(id),
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          CHECK (text IS NOT NULL OR status IN ('pending', 'uncertain'))
        )
      ''');
      await txn.execute(
        'CREATE INDEX idx_consent_participant ON consent_records(participant_id, created_at)',
      );
      await txn.execute(
        'CREATE INDEX idx_session_participants_participant ON session_participants(participant_id)',
      );
      await txn.execute(
        'CREATE INDEX idx_recordings_session ON recordings(session_id, recorded_at)',
      );
      await txn.execute(
        'CREATE INDEX idx_recordings_annotation_status ON recordings(annotation_status)',
      );
      await txn.execute(
        'CREATE INDEX idx_recording_participants_participant ON recording_participants(participant_id)',
      );
      await txn.execute(
        'CREATE INDEX idx_segments_recording_timeline ON utterance_segments(recording_id, start_ms, end_ms)',
      );
      await txn.execute(
        'CREATE INDEX idx_annotations_segment_status ON annotation_entries(segment_id, status)',
      );
      await txn.insert('workspace_info', {
        'id': 1,
        'workspace_id': '',
        'schema_version': schemaVersion,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      await txn.execute('PRAGMA user_version = $schemaVersion');
    });
  }

  static Future<void> setWorkspaceId(
    Database database,
    String workspaceId,
  ) async {
    await database.update('workspace_info', {
      'workspace_id': workspaceId,
    }, where: 'id = 1');
  }

  static Future<void> _upgradeSchema(
    Database database,
    int oldVersion,
    int newVersion,
  ) async {
    if (newVersion > schemaVersion) {
      throw StateError(
        'Workspace database version $newVersion is newer than supported '
        'version $schemaVersion.',
      );
    }
    if (oldVersion < 1) {
      await _createSchema(database, schemaVersion);
      return;
    }
    if (oldVersion < 2) {
      await database.execute('''
        ALTER TABLE recordings ADD COLUMN consent_status TEXT NOT NULL
          DEFAULT 'not_recorded' CHECK
          (consent_status IN
            ('not_recorded', 'pending', 'consented', 'declined', 'withdrawn', 'uncertain'))
      ''');
      await database.execute('''
        CREATE TABLE recording_save_journal (
          recording_id TEXT PRIMARY KEY,
          temporary_relative_path TEXT NOT NULL,
          final_relative_path TEXT NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');
      await database.update('workspace_info', {
        'schema_version': schemaVersion,
      }, where: 'id = 1');
    }
    if (oldVersion < 3) {
      await _ensureColumn(database, 'participants', 'age', 'INTEGER');
      await _ensureColumn(database, 'participants', 'gender', 'TEXT');
      await _ensureColumn(database, 'participants', 'education_level', 'TEXT');
      await _ensureColumn(
        database,
        'participants',
        'consent_status',
        "TEXT NOT NULL DEFAULT 'pending'",
      );
      await _ensureColumn(
        database,
        'participants',
        'status',
        "TEXT NOT NULL DEFAULT 'active'",
      );
      await _ensureColumn(
        database,
        'collection_sessions',
        'protocol_version',
        "TEXT NOT NULL DEFAULT 'v1'",
      );
      await database.execute('''
        CREATE TABLE IF NOT EXISTS signs (
          id TEXT PRIMARY KEY,
          sign_code TEXT NOT NULL UNIQUE,
          gloss TEXT NOT NULL,
          display_name TEXT NOT NULL,
          category TEXT,
          description TEXT,
          instruction TEXT,
          active INTEGER NOT NULL DEFAULT 1,
          target_formats INTEGER NOT NULL DEFAULT 3,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
      await database.execute('''
        CREATE UNIQUE INDEX IF NOT EXISTS idx_recordings_sha256_unique
        ON recordings(sha256) WHERE sha256 IS NOT NULL
      ''');
      await _ensureColumn(
        database,
        'recordings',
        'sign_id',
        'TEXT REFERENCES signs(id)',
      );
      await _ensureColumn(database, 'recordings', 'capture_format', 'TEXT');
      await _ensureColumn(
        database,
        'recordings',
        'cue_markers_json',
        "TEXT NOT NULL DEFAULT '[]'",
      );
      await database.update('workspace_info', {
        'schema_version': schemaVersion,
      }, where: 'id = 1');
    }
  }

  static Future<void> _ensureColumn(
    Database database,
    String table,
    String column,
    String declaration,
  ) async {
    final columns = await database.rawQuery('PRAGMA table_info($table)');
    if (columns.any((row) => row['name'] == column)) return;
    await database.execute(
      'ALTER TABLE $table ADD COLUMN $column $declaration',
    );
  }
}
