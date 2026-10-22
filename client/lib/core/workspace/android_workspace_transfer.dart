import 'package:flutter/services.dart';

class AndroidWorkspaceTransfer {
  const AndroidWorkspaceTransfer({
    required this.name,
    required this.sha256ByRelativePath,
  });

  final String name;
  final Map<String, String> sha256ByRelativePath;
}

/// Uses Android's Storage Access Framework for copies outside app storage.
class AndroidWorkspaceTransferService {
  static const _channel = MethodChannel('signbridge/workspace_transfer');

  Future<Map<String, String>?> importWorkspaceTree({
    required String destinationPath,
  }) async {
    final result = await _channel.invokeMapMethod<Object?, Object?>(
      'importWorkspaceTree',
      {'destinationPath': destinationPath},
    );
    if (result == null) return null;
    return _stringMap(result['files']);
  }

  Future<AndroidWorkspaceTransfer?> exportWorkspaceTree({
    required String sourcePath,
    required String folderName,
  }) async {
    final result = await _channel.invokeMapMethod<Object?, Object?>(
      'exportWorkspaceTree',
      {'sourcePath': sourcePath, 'folderName': folderName},
    );
    if (result == null) return null;
    return AndroidWorkspaceTransfer(
      name: result['folderName']?.toString() ?? folderName,
      sha256ByRelativePath: _stringMap(result['files']),
    );
  }

  Future<AndroidWorkspaceTransfer?> exportDatasetZip({
    required String sourcePath,
    required String fileName,
  }) async {
    final result = await _channel.invokeMapMethod<Object?, Object?>(
      'exportDatasetZip',
      {'sourcePath': sourcePath, 'fileName': fileName},
    );
    if (result == null) return null;
    return AndroidWorkspaceTransfer(
      name: result['fileName']?.toString() ?? fileName,
      sha256ByRelativePath: {'': result['sha256']?.toString() ?? ''},
    );
  }

  static Map<String, String> _stringMap(Object? value) {
    if (value is! Map) {
      throw const FormatException('Invalid transfer checksum data.');
    }
    return {
      for (final entry in value.entries)
        entry.key.toString().replaceAll('\\', '/'): entry.value.toString(),
    };
  }
}
