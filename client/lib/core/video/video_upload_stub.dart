import 'dart:typed_data';

Future<void> putVideoObject(
  String url, {
  required String mimeType,
  required int contentLength,
  Uint8List? bytes,
  String? filePath,
}) async {
  throw UnsupportedError('Video uploads are not supported on this platform.');
}
