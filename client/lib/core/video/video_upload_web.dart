import 'dart:typed_data';

import 'package:dio/dio.dart';

Future<void> putVideoObject(
  String url, {
  required String mimeType,
  required int contentLength,
  Uint8List? bytes,
  String? filePath,
}) async {
  if (bytes == null) throw StateError('Browser video bytes are unavailable.');
  await Dio().put<void>(
    url,
    data: bytes,
    options: Options(
      headers: {'Content-Type': mimeType},
      contentType: mimeType,
      sendTimeout: const Duration(minutes: 5),
      receiveTimeout: const Duration(minutes: 2),
    ),
  );
}
