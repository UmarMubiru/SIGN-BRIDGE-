import 'dart:typed_data';

import 'web_browser_stub.dart'
    if (dart.library.html) 'web_browser_web.dart'
    as implementation;

String createObjectUrl(Uint8List bytes, String mimeType) =>
    implementation.createObjectUrl(bytes, mimeType);

void revokeObjectUrl(String url) => implementation.revokeObjectUrl(url);

void downloadBytes(Uint8List bytes, String filename, String mimeType) =>
    implementation.downloadBytes(bytes, filename, mimeType);

void registerVideoView(String viewType, String videoUrl) =>
    implementation.registerVideoView(viewType, videoUrl);
