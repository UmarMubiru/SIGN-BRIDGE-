import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'local_workspace.dart';
import 'workspace_database.dart';

class WorkspaceCopyService {
  Future<Directory> createCopy({
    required LocalWorkspace workspace,
    required String destinationParent,
    required String purpose,
  }) async {
    if (!const {'backup', 'export'}.contains(purpose)) {
      throw ArgumentError.value(purpose, 'purpose');
    }
    final source = Directory(workspace.rootPath);
    final parent = Directory(destinationParent);
    if (!await source.exists() || !await parent.exists()) {
      throw StateError('Workspace or destination folder is unavailable.');
    }
    final sourcePath = p.normalize(await source.resolveSymbolicLinks());
    final parentPath = p.normalize(await parent.resolveSymbolicLinks());
    if (p.isWithin(sourcePath, parentPath) || sourcePath == parentPath) {
      throw StateError('Choose a destination outside the active workspace.');
    }

    final database = await WorkspaceDatabase.open(
      p.join(sourcePath, 'database.sqlite3'),
    );
    try {
      final checkpoint = await database.rawQuery('PRAGMA wal_checkpoint(FULL)');
      if (checkpoint.isNotEmpty &&
          (checkpoint.first['busy'] as int? ?? 0) != 0) {
        throw StateError(
          'The workspace database is busy. Close other SignBridge windows and retry the copy.',
        );
      }
    } finally {
      await database.close();
    }

    final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    final folderName = 'SignBridge_${purpose}_$stamp';
    final staging = Directory(p.join(parentPath, '.$folderName.incomplete'));
    final completed = Directory(p.join(parentPath, folderName));
    if (await staging.exists() || await completed.exists()) {
      throw StateError('A copy with this name already exists; try again.');
    }
    final checksums = <String, Map<String, Object>>{};
    try {
      await staging.create();
      await for (final entity in source.list(
        followLinks: false,
        recursive: true,
      )) {
        final relative = p.relative(entity.path, from: sourcePath);
        if (relative == 'copy-manifest.json') continue;
        final targetPath = p.join(staging.path, relative);
        if (entity is Directory) {
          await Directory(targetPath).create(recursive: true);
        } else if (entity is File) {
          await Directory(p.dirname(targetPath)).create(recursive: true);
          final copied = await entity.copy(targetPath);
          final digest = await sha256.bind(copied.openRead()).first;
          final sourceDigest = await sha256.bind(entity.openRead()).first;
          if (digest != sourceDigest) {
            throw StateError('Copy verification failed for $relative.');
          }
          checksums[relative.replaceAll('\\', '/')] = {
            'size_bytes': await copied.length(),
            'sha256': digest.toString(),
          };
        } else if (entity is Link) {
          throw StateError(
            'Workspace contains a linked path that cannot be safely copied: $relative',
          );
        }
      }
      await File(p.join(staging.path, 'copy-manifest.json')).writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'purpose': purpose,
          'workspace_id': workspace.id,
          'workspace_name': workspace.name,
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'files': checksums,
        }),
        flush: true,
      );
      return await staging.rename(completed.path);
    } catch (_) {
      if (await staging.exists()) await staging.delete(recursive: true);
      rethrow;
    }
  }
}
