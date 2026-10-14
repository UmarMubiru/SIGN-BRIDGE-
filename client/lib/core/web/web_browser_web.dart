import 'dart:async';
import 'dart:typed_data';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

String createObjectUrl(Uint8List bytes, String mimeType) =>
    html.Url.createObjectUrl(html.Blob([bytes], mimeType));

void revokeObjectUrl(String url) => html.Url.revokeObjectUrl(url);

void downloadBytes(Uint8List bytes, String filename, String mimeType) {
  final url = createObjectUrl(bytes, mimeType);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  unawaited(
    Future<void>.delayed(const Duration(seconds: 2), () {
      revokeObjectUrl(url);
    }),
  );
}

void registerVideoView(String viewType, String videoUrl) {
  ui_web.platformViewRegistry.registerViewFactory(
    viewType,
    (int viewId) => html.VideoElement()
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.border = 'none'
      ..style.objectFit = 'contain'
      ..style.backgroundColor = 'black'
      ..controls = true
      ..autoplay = false
      ..src = videoUrl,
  );
}
