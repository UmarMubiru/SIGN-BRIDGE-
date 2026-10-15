import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'local_workspace.dart';
import 'workspace_database.dart';

class WorkspaceException implements Exception {
  const WorkspaceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class WorkspaceService {
  WorkspaceService({this.settingsDirectory});

  static const workspaceFormatVersion = 1;
  static const workspaceFolderName = 'SignBridge_Workspace';
  static const workspaceManifestName = 'workspace.json';
  static const workspaceDatabaseName = 'database.sqlite3';
  static const videoFolderName = 'videos';

  final Directory? settingsDirectory;

  Future<LocalWorkspace?> loadActiveWorkspace() async {
    if (kIsWeb || !_isSupportedPlatform) {
      return null;
    }
    final settingsFile = await _activeWorkspaceFile();
    if (!await settingsFile.exists()) return null;

    final saved = await _readJson(settingsFile);
    final path = saved['root_path'];
    if (path is! String || path.isEmpty) {
      throw const WorkspaceException(
        'The saved workspace location is invalid.',
      );
    }
    return _validateWorkspace(path);
  }

  Future<LocalWorkspace> selectWorkspace(String rootPath) async {
    _ensureSupportedPlatform();
    final workspace = await _validateWorkspace(rootPath);
    await _writeActiveWorkspace(workspace.rootPath);
    return workspace;
  }

  Future<LocalWorkspace> createWorkspace({
    required String parentPath,
    required String name,
  }) async {
    _ensureSupportedPlatform();
    final trimmedName = name.trim();
    if (trimmedName.isEmpty ||
        trimmedName == '.' ||
        trimmedName == '..' ||
        p.basename(trimmedName) != trimmedName ||
        trimmedName.contains(RegExp(r'[<>:"/\\|?*\x00-\x1f]'))) {
      throw const WorkspaceException(
        'Enter a workspace name that does not contain Windows path characters.',
      );
    }

    final parent = Directory(parentPath);
    if (!await parent.exists()) {
      throw const WorkspaceException(
        'The selected parent folder no longer exists.',
      );
    }
    final canonicalParent = await parent.resolveSymbolicLinks();
    final root = Directory(p.join(canonicalParent, trimmedName));
    if (await root.exists()) {
      throw WorkspaceException(
        'A folder named "$trimmedName" already exists in the selected location.',
      );
    }

    final staging = Directory(
      p.join(canonicalParent, '.signbridge-creating-${_newId()}'),
    );
    final workspaceId = _newId();
    final createdAt = DateTime.now().toUtc();
    try {
      await staging.create();
      for (final folder in const [videoFolderName, 'exports', 'backups']) {
        await Directory(p.join(staging.path, folder)).create();
      }

      final manifest = <String, Object>{
        'format_version': workspaceFormatVersion,
        'schema_version': WorkspaceDatabase.schemaVersion,
        'workspace_id': workspaceId,
        'name': trimmedName,
        'created_at': createdAt.toIso8601String(),
        'protocol_version': 'continuous_conversation_v1',
      };
      await File(p.join(staging.path, workspaceManifestName))
          .writeAsString(jsonEncode(manifest), flush: true);

      final database = await WorkspaceDatabase.open(
        p.join(staging.path, workspaceDatabaseName),
      );
      try {
        await WorkspaceDatabase.setWorkspaceId(database, workspaceId);
      } finally {
        await database.close();
      }

      final completedRoot = await staging.rename(root.path);
      final workspace = LocalWorkspace(
        id: workspaceId,
        name: trimmedName,
        rootPath: await completedRoot.resolveSymbolicLinks(),
        schemaVersion: WorkspaceDatabase.schemaVersion,
        createdAt: createdAt,
      );
      await _writeActiveWorkspace(workspace.rootPath);
      return workspace;
    } catch (error) {
      if (await staging.exists()) {
        await staging.delete(recursive: true);
      }
      if (error is WorkspaceException) rethrow;
      throw WorkspaceException('Could not create the workspace: $error');
    }
  }

  Future<Directory> defaultAndroidWorkspaceParent() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw const WorkspaceException(
        'App storage workspaces are only available on Android.',
      );
    }
    final documents = await getApplicationDocumentsDirectory();
    final parent = Directory(
      p.join(documents.path, 'SignBridge', 'Workspaces'),
    );
    await parent.create(recursive: true);
    return parent;
  }

  Future<List<LocalWorkspace>> listAndroidWorkspaces() async {
    final parent = await defaultAndroidWorkspaceParent();
    final workspaces = <LocalWorkspace>[];
    await for (final entity in parent.list(followLinks: false)) {
      if (entity is! Directory) continue;
      try {
        workspaces.add(await _validateWorkspace(entity.path));
      } on WorkspaceException {
        // Ignore non-workspace folders; they can be left untouched.
      }
    }
    workspaces.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return workspaces;
  }

  Future<LocalWorkspace> _validateWorkspace(String rootPath) async {
    final root = Directory(rootPath);
    if (!await root.exists()) {
      throw const WorkspaceException(
        'The selected workspace folder does not exist.',
      );
    }
    final canonicalRoot = await root.resolveSymbolicLinks();
    final manifestFile = File(p.join(canonicalRoot, workspaceManifestName));
    if (!await manifestFile.exists()) {
      throw const WorkspaceException(
        'This folder is not a SignBridge workspace. Select a folder containing workspace.json.',
      );
    }

    final manifest = await _readJson(manifestFile);
    final formatVersion = manifest['format_version'];
    final schemaVersion = manifest['schema_version'];
    final workspaceId = manifest['workspace_id'];
    final name = manifest['name'];
    final createdAtText = manifest['created_at'];
    if (formatVersion != workspaceFormatVersion ||
        schemaVersion is! int ||
        schemaVersion < 1 ||
        schemaVersion > WorkspaceDatabase.schemaVersion ||
        workspaceId is! String ||
        workspaceId.isEmpty ||
        name is! String ||
        name.isEmpty ||
        createdAtText is! String) {
      throw const WorkspaceException(
        'This workspace has an unsupported or incomplete format.',
      );
    }

    final createdAt = DateTime.tryParse(createdAtText);
    if (createdAt == null) {
      throw const WorkspaceException('The workspace creation date is invalid.');
    }

    for (final folder in const [videoFolderName, 'exports', 'backups']) {
      if (!await Directory(p.join(canonicalRoot, folder)).exists()) {
        throw WorkspaceException(
          'The workspace is missing its $folder folder.',
        );
      }
    }
    final databaseFile = File(p.join(canonicalRoot, workspaceDatabaseName));
    if (!await databaseFile.exists()) {
      throw const WorkspaceException('The workspace database is missing.');
    }

    final database = await WorkspaceDatabase.open(databaseFile.path);
    try {
      final rows = await database.query('workspace_info', where: 'id = 1');
      if (rows.length != 1 || rows.single['workspace_id'] != workspaceId) {
        throw const WorkspaceException(
          'The workspace manifest and database do not match.',
        );
      }
      final versionRows = await database.rawQuery('PRAGMA user_version');
      final databaseVersion = versionRows.single.values.single;
      if (databaseVersion != WorkspaceDatabase.schemaVersion) {
        throw const WorkspaceException(
          'The workspace database could not be upgraded to the supported version.',
        );
      }
      if (rows.single['schema_version'] != WorkspaceDatabase.schemaVersion) {
        await database.update('workspace_info', {
          'schema_version': WorkspaceDatabase.schemaVersion,
        }, where: 'id = 1');
      }
    } finally {
      await database.close();
    }

    if (schemaVersion != WorkspaceDatabase.schemaVersion) {
      manifest['schema_version'] = WorkspaceDatabase.schemaVersion;
      await manifestFile.writeAsString(jsonEncode(manifest), flush: true);
    }

    return LocalWorkspace(
      id: workspaceId,
      name: name,
      rootPath: canonicalRoot,
      schemaVersion: WorkspaceDatabase.schemaVersion,
      createdAt: createdAt.toUtc(),
    );
  }

  Future<File> _activeWorkspaceFile() async {
    final settingsDirectory =
        this.settingsDirectory ?? await getApplicationSupportDirectory();
    final signBridgeDirectory = Directory(
      p.join(settingsDirectory.path, 'SignBridge'),
    );
    await signBridgeDirectory.create(recursive: true);
    return File(p.join(signBridgeDirectory.path, 'active_workspace.json'));
  }

  Future<Map<String, dynamic>> _readJson(File file) async {
    try {
      final value = jsonDecode(await file.readAsString());
      if (value is Map<String, dynamic>) return value;
      throw const FormatException('Expected a JSON object.');
    } on FormatException catch (error) {
      throw WorkspaceException(
        'Invalid workspace JSON in ${file.path}: $error',
      );
    }
  }

  Future<void> _writeActiveWorkspace(String rootPath) async {
    final file = await _activeWorkspaceFile();
    await file.writeAsString(jsonEncode({'root_path': rootPath}), flush: true);
  }

  void _ensureSupportedPlatform() {
    if (kIsWeb || !_isSupportedPlatform) {
      throw const WorkspaceException(
        'Workspace folder management is unavailable on this platform.',
      );
    }
  }

  bool get _isSupportedPlatform =>
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.android;

  static String _newId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}

final workspaceServiceProvider = Provider<WorkspaceService>(
  (ref) => WorkspaceService(),
);

final activeWorkspaceProvider = FutureProvider<LocalWorkspace?>((ref) {
  return ref.read(workspaceServiceProvider).loadActiveWorkspace();
});
