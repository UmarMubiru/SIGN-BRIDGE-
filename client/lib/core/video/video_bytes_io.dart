import 'dart:io';

Future<void> deleteVideoFile(String? path) async {
  if (path == null || path.isEmpty) return;
  final file = File(path);
  if (await file.exists()) await file.delete();
}
