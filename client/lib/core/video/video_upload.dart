import 'dart:typed_data';

import 'video_upload_stub.dart'
    if (dart.library.html) 'video_upload_web.dart'
    if (dart.library.io) 'video_upload_io.dart'
    as platform;

Future<void> putVideoObject(
  String url, {
  required String mimeType,
  required int contentLength,
  Uint8List? bytes,
  String? filePath,
}) => platform.putVideoObject(
  url,
  mimeType: mimeType,
  contentLength: contentLength,
  bytes: bytes,
  filePath: filePath,
);
