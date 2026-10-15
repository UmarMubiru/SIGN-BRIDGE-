import 'dart:io';

import 'package:path/path.dart' as p;

/// Promotes the Windows camera plugin's temporary output without discarding
/// the source until a complete destination file has been verified.
class WindowsRecordingFilePromoter {
  const WindowsRecordingFilePromoter();

  Future<File> promote({
    required File source,
    required String destinationPath,
  }) async {
    if (!await source.exists()) {
      throw FileSystemException(
        'Camera plugin did not create the recorded video',
        source.path,
      );
    }

    final destination = File(destinationPath);
    await Directory(p.dirname(destinationPath)).create(recursive: true);
    if (await destination.exists()) {
      throw FileSystemException(
        'Recording destination already exists',
        destinationPath,
      );
    }

    final partial = File('$destinationPath.partial');
    try {
      if (await partial.exists()) await partial.delete();
      await source.copy(partial.path);
      final sourceStat = await source.stat();
      final partialStat = await partial.stat();
      if (sourceStat.size <= 0 || sourceStat.size != partialStat.size) {
        throw FileSystemException(
          'Recorded video copy is incomplete',
          partial.path,
        );
      }
      final completed = await partial.rename(destinationPath);
      // A cleanup failure must not invalidate an already verified recording.
      try {
        await source.delete();
      } on FileSystemException {
        // The verified destination is now authoritative; retain plugin source.
      }
      return completed;
    } catch (_) {
      if (await partial.exists()) await partial.delete();
      rethrow;
    }
  }
}
