import 'dart:typed_data';

import 'video_bytes_stub.dart'
    if (dart.library.io) 'video_bytes_io.dart'
    as platform;

Future<void> deleteVideoFile(String? path) => platform.deleteVideoFile(path);

String detectVideoMimeType(Uint8List bytes, {String fallback = 'video/mp4'}) {
  if (bytes.length >= 4 &&
      bytes[0] == 0x1a &&
      bytes[1] == 0x45 &&
      bytes[2] == 0xdf &&
      bytes[3] == 0xa3) {
    return 'video/webm';
  }
  if (bytes.length >= 8 &&
      bytes[4] == 0x66 &&
      bytes[5] == 0x74 &&
      bytes[6] == 0x79 &&
      bytes[7] == 0x70) {
    return 'video/mp4';
  }
  return fallback;
}
