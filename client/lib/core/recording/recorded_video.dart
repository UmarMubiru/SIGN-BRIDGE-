import 'package:flutter/foundation.dart';
import '../recording/recording_context.dart';
import '../video/video_asset.dart';

/// Recorded video - combines recording context with video asset
class RecordedVideo {
  final RecordingContext context;
  final VideoAsset video;
  final Duration duration;
  final DateTime recordedAt;
  final String? deviceId;
  final String? protocolVersion;

  const RecordedVideo({
    required this.context,
    required this.video,
    required this.duration,
    required this.recordedAt,
    this.deviceId,
    this.protocolVersion = '1.0',
  });

  RecordedVideo copyWith({
    RecordingContext? context,
    VideoAsset? video,
    Duration? duration,
    DateTime? recordedAt,
    String? deviceId,
    String? protocolVersion,
  }) {
    return RecordedVideo(
      context: context ?? this.context,
      video: video ?? this.video,
      duration: duration ?? this.duration,
      recordedAt: recordedAt ?? this.recordedAt,
      deviceId: deviceId ?? this.deviceId,
      protocolVersion: protocolVersion ?? this.protocolVersion,
    );
  }

  @override
  String toString() {
    return 'RecordedVideo(${context.signLabel} ${context.captureFormat}, duration: $duration)';
  }

  Map<String, dynamic> toJson() {
    return {
      'context': context.toJson(),
      'video': video.toJson(),
      'duration': duration.inMilliseconds,
      'recordedAt': recordedAt.toIso8601String(),
      'deviceId': deviceId,
      'protocolVersion': protocolVersion,
    };
  }

  factory RecordedVideo.fromJson(Map<String, dynamic> json) {
    return RecordedVideo(
      context: RecordingContext.fromJson(json['context'] as Map<String, dynamic>),
      video: VideoAsset.fromJson(json['video'] as Map<String, dynamic>),
      duration: Duration(milliseconds: json['duration'] as int),
      recordedAt: DateTime.parse(json['recordedAt'] as String),
      deviceId: json['deviceId'] as String?,
      protocolVersion: json['protocolVersion'] as String?,
    );
  }

  String get signerId => context.signerId;
  String get signLabel => context.signLabel;
  String get captureFormat => context.captureFormat;
  String get captureFormatLabel => context.captureFormatLabel;
  String get lightingCondition => context.lightingCondition;
  String get background => context.background;
  String get fileName => context.fileName;
}
