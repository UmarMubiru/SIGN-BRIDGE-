import 'dart:typed_data';

import 'video_bytes.dart';

/// Video asset abstraction - cross-platform video representation
class VideoAsset {
  final String id;
  final String? localPath;
  final Uint8List? bytes;
  final String mimeType;
  final Duration duration;
  final int fileSize;

  const VideoAsset({
    required this.id,
    this.localPath,
    this.bytes,
    required this.mimeType,
    required this.duration,
    required this.fileSize,
  });

  bool get isWebBased => bytes != null;
  bool get isFileBased => localPath != null;

  VideoAsset copyWith({
    String? id,
    String? localPath,
    Uint8List? bytes,
    String? mimeType,
    Duration? duration,
    int? fileSize,
  }) {
    return VideoAsset(
      id: id ?? this.id,
      localPath: localPath ?? this.localPath,
      bytes: bytes ?? this.bytes,
      mimeType: mimeType ?? this.mimeType,
      duration: duration ?? this.duration,
      fileSize: fileSize ?? this.fileSize,
    );
  }

  @override
  String toString() {
    return 'VideoAsset(id: $id, duration: $duration, size: $fileSize, type: ${isWebBased ? "web" : "file"})';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'localPath': localPath,
      'mimeType': mimeType,
      'duration': duration.inMilliseconds,
      'fileSize': fileSize,
      'isWebBased': isWebBased,
    };
  }

  factory VideoAsset.fromJson(Map<String, dynamic> json) {
    return VideoAsset(
      id: json['id'] as String,
      localPath: json['localPath'] as String?,
      mimeType: json['mimeType'] as String,
      duration: Duration(milliseconds: json['duration'] as int),
      fileSize: json['fileSize'] as int,
    );
  }

  static VideoAsset fromFile(String path, Duration duration, int fileSize) {
    return VideoAsset(
      id: path,
      localPath: path,
      mimeType: 'video/mp4',
      duration: duration,
      fileSize: fileSize,
    );
  }

  static VideoAsset fromBytes(
    Uint8List bytes,
    Duration duration,
    String id, {
    String? mimeType,
  }) {
    return VideoAsset(
      id: id,
      bytes: bytes,
      mimeType: detectVideoMimeType(bytes, fallback: mimeType ?? 'video/mp4'),
      duration: duration,
      fileSize: bytes.length,
    );
  }
}
