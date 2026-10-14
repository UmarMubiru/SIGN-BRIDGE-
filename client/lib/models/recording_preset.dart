// Recording preset models for capture configuration
// Matches Excel checklist repetition presets

import 'recording_condition.dart';

enum RecordingPreset {
  rep1Front0('REP_1_FRONT_0', 'Front (0°)'),
  rep2Left15('REP_2_LEFT_15', 'Left (15°)'),
  rep3Right15('REP_3_RIGHT_15', 'Right (15°)'),
  rep4Left30('REP_4_LEFT_30', 'Left (30°)'),
  rep5Right30('REP_5_RIGHT_30', 'Right (30°)'),
  rep6Left45('REP_6_LEFT_45', 'Left (45°)'),
  rep7Right45('REP_7_RIGHT_45', 'Right (45°)'),
  rep8AboveEye('REP_8_ABOVE_EYE_LEVEL', 'Above Eye Level'),
  rep9BelowEye('REP_9_BELOW_EYE_LEVEL', 'Below Eye Level'),
  rep10FrontCloser('REP_10_FRONT_CLOSER', 'Front Closer');

  final String displayName;
  final String description;
  const RecordingPreset(this.displayName, this.description);

  // Recommended settings for each preset
  Map<String, dynamic> get recommendedSettings {
    switch (this) {
      case RecordingPreset.rep1Front0:
      case RecordingPreset.rep2Left15:
      case RecordingPreset.rep3Right15:
      case RecordingPreset.rep4Left30:
      case RecordingPreset.rep5Right30:
      case RecordingPreset.rep6Left45:
      case RecordingPreset.rep7Right45:
      case RecordingPreset.rep8AboveEye:
      case RecordingPreset.rep9BelowEye:
      case RecordingPreset.rep10FrontCloser:
        return {
          'resolution': '720p',
          'fps': 30,
          'duration': 5,
        };
    }
  }
}

class RecordingMetadata {
  final String recordingId;
  final String sessionId;
  final String signId;
  final int repetition;
  final RecordingPreset preset;
  final RecordingCondition condition;
  final DateTime createdAt;
  final String? localVideoPath;
  final int? durationMs;
  final int? fileSize;
  final String? resolution;
  final int? fps;

  RecordingMetadata({
    required this.recordingId,
    required this.sessionId,
    required this.signId,
    required this.repetition,
    required this.preset,
    required this.condition,
    required this.createdAt,
    this.localVideoPath,
    this.durationMs,
    this.fileSize,
    this.resolution,
    this.fps,
  });

  Map<String, dynamic> toJson() {
    return {
      'recording_id': recordingId,
      'session_id': sessionId,
      'sign_id': signId,
      'repetition': repetition,
      'preset': preset.name,
      'condition': condition.toJson(),
      'created_at': createdAt.toIso8601String(),
      'local_video_path': localVideoPath,
      'duration_ms': durationMs,
      'file_size': fileSize,
      'resolution': resolution,
      'fps': fps,
    };
  }

  factory RecordingMetadata.fromJson(Map<String, dynamic> json) {
    return RecordingMetadata(
      recordingId: json['recording_id'],
      sessionId: json['session_id'],
      signId: json['sign_id'],
      repetition: json['repetition'],
      preset: RecordingPreset.values.firstWhere(
        (e) => e.name == json['preset'],
        orElse: () => RecordingPreset.rep1Front0,
      ),
      condition: RecordingCondition.fromJson(json['condition']),
      createdAt: DateTime.parse(json['created_at']),
      localVideoPath: json['local_video_path'],
      durationMs: json['duration_ms'],
      fileSize: json['file_size'],
      resolution: json['resolution'],
      fps: json['fps'],
    );
  }

  RecordingMetadata copyWith({
    String? recordingId,
    String? sessionId,
    String? signId,
    int? repetition,
    RecordingPreset? preset,
    RecordingCondition? condition,
    DateTime? createdAt,
    String? localVideoPath,
    int? durationMs,
    int? fileSize,
    String? resolution,
    int? fps,
  }) {
    return RecordingMetadata(
      recordingId: recordingId ?? this.recordingId,
      sessionId: sessionId ?? this.sessionId,
      signId: signId ?? this.signId,
      repetition: repetition ?? this.repetition,
      preset: preset ?? this.preset,
      condition: condition ?? this.condition,
      createdAt: createdAt ?? this.createdAt,
      localVideoPath: localVideoPath ?? this.localVideoPath,
      durationMs: durationMs ?? this.durationMs,
      fileSize: fileSize ?? this.fileSize,
      resolution: resolution ?? this.resolution,
      fps: fps ?? this.fps,
    );
  }
}
