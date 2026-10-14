import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

Future<void> putVideoObject(
  String url, {
  required String mimeType,
  required int contentLength,
  Uint8List? bytes,
  String? filePath,
}) async {
  final Object body;
  if (filePath != null && filePath.isNotEmpty) {
    body = File(filePath).openRead();
  } else if (bytes != null) {
    body = bytes;
  } else {
    throw StateError('Video file is unavailable.');
  }
  await Dio().put<void>(
    url,
    data: body,
    options: Options(
      headers: {
        'Content-Type': mimeType,
        Headers.contentLengthHeader: contentLength,
      },
      contentType: mimeType,
      sendTimeout: const Duration(minutes: 5),
      receiveTimeout: const Duration(minutes: 2),
    ),
  );
}
