import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

import '../../app/theme/app_theme.dart';
import '../../app/widgets/app_card.dart';
import '../../app/widgets/navigation_back_button.dart';
import '../../core/cloud_auth_configuration.dart';
import '../../core/workspace/local_workspace.dart';
import '../../core/workspace/android_workspace_transfer.dart';
import '../../core/workspace/workspace_service.dart';
import '../../core/workspace/workspace_copy_service.dart';

class WorkspaceSettingsScreen extends ConsumerStatefulWidget {
  const WorkspaceSettingsScreen({super.key});

  @override
  ConsumerState<WorkspaceSettingsScreen> createState() =>
      _WorkspaceSettingsScreenState();
}

class _WorkspaceSettingsScreenState
    extends ConsumerState<WorkspaceSettingsScreen> {
  bool _isSelecting = false;
  String? _error;

  Future<void> _copyWorkspace(LocalWorkspace workspace, String purpose) async {
    await _runSelection(() async {
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _copyWorkspaceToAndroidDocumentTree(workspace, purpose);
        return true;
      }
      final destination = await getDirectoryPath(
        confirmButtonText: purpose == 'backup'
            ? 'Save Backup Here'
            : 'Export Here',
        canCreateDirectories: true,
      );
      if (destination == null) return false;
      final result = await WorkspaceCopyService().createCopy(
        workspace: workspace,
        destinationParent: destination,
        purpose: purpose,
      );
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verified $purpose created at ${result.path}')),
      );
      return true;
    });
  }

  Future<void> _copyWorkspaceToAndroidDocumentTree(
    LocalWorkspace workspace,
    String purpose,
  ) async {
    final temporaryParent = await Directory.systemTemp.createTemp(
      'signbridge-workspace-export-',
    );
    try {
      final snapshot = await WorkspaceCopyService().createCopy(
        workspace: workspace,
        destinationParent: temporaryParent.path,
        purpose: purpose,
      );
      final folderName = p.basename(snapshot.path);
      final result = await AndroidWorkspaceTransferService()
          .exportWorkspaceTree(
            sourcePath: snapshot.path,
            folderName: folderName,
          );
      if (result == null) return;
      await _verifyCopyManifest(snapshot, result.sha256ByRelativePath);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Verified $purpose copied to ${result.name} in the selected Android folder.',
          ),
        ),
      );
    } finally {
      if (await temporaryParent.exists()) {
        await temporaryParent.delete(recursive: true);
      }
    }
  }

  Future<void> _importAndroidWorkspace() async {
    await _runSelection(() async {
      final service = ref.read(workspaceServiceProvider);
      final parent = await service.defaultAndroidWorkspaceParent();
      final staging = Directory(
        p.join(
          parent.path,
          '.signbridge-import-${DateTime.now().microsecondsSinceEpoch}',
        ),
      );
      Directory? promoted;
      await staging.create();
      try {
        final checksums = await AndroidWorkspaceTransferService()
            .importWorkspaceTree(destinationPath: staging.path);
        if (checksums == null) return false;
        await _verifyCopyManifest(staging, checksums);
        final imported = await service.validateWorkspaceForImport(staging.path);
        final destination = await _uniqueRestoredDirectory(
          parent,
          imported.name,
        );
        promoted = await staging.rename(destination.path);
        final selected = await service.selectWorkspace(promoted.path);
        promoted = null;
        if (!mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restored and opened ${selected.name}.')),
        );
        return true;
      } finally {
        if (await staging.exists()) await staging.delete(recursive: true);
        if (promoted != null && await promoted.exists()) {
          await promoted.delete(recursive: true);
        }
      }
    }, openDashboardOnSuccess: true);
  }

  Future<Directory> _uniqueRestoredDirectory(
    Directory parent,
    String workspaceName,
  ) async {
    final safeName = workspaceName
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_')
        .replaceAll(RegExp(r'[. ]+$'), '')
        .trim();
    if (safeName.isEmpty) {
      throw const WorkspaceException('The workspace name is invalid.');
    }
    var candidate = Directory(p.join(parent.path, safeName));
    var suffix = 2;
    while (await candidate.exists()) {
      candidate = Directory(
        p.join(parent.path, '$safeName (restored $suffix)'),
      );
      suffix++;
    }
    return candidate;
  }

  Future<void> _verifyCopyManifest(
    Directory directory,
    Map<String, String> copiedHashes,
  ) async {
    final manifestFile = File(p.join(directory.path, 'copy-manifest.json'));
    if (!await manifestFile.exists()) return;
    final decoded = jsonDecode(await manifestFile.readAsString());
    if (decoded is! Map || decoded['files'] is! Map) {
      throw const WorkspaceException(
        'The workspace copy checksum manifest is invalid.',
      );
    }
    final files = decoded['files'] as Map;
    for (final entry in files.entries) {
      final relativePath = entry.key.toString().replaceAll('\\', '/');
      final expected = entry.value;
      final expectedHash = expected is Map
          ? expected['sha256']?.toString()
          : null;
      final copiedHash = copiedHashes[relativePath];
      if (expectedHash == null || copiedHash != expectedHash) {
        throw WorkspaceException(
          'The copied workspace failed SHA-256 verification for $relativePath. The original was left unchanged.',
        );
      }
    }
  }

  Future<void> _openExistingWorkspace() async {
    await _runSelection(() async {
      final service = ref.read(workspaceServiceProvider);
      if (defaultTargetPlatform == TargetPlatform.android) {
        final workspaces = await service.listAndroidWorkspaces();
        if (workspaces.isEmpty) {
          _showAndroidRestoreHint();
          return false;
        }
        if (!mounted) return false;
        final workspace = await showDialog<LocalWorkspace>(
          context: context,
          builder: (dialogContext) => SimpleDialog(
            title: const Text('Open a local workspace'),
            children: [
              for (final workspace in workspaces)
                SimpleDialogOption(
                  onPressed: () => Navigator.of(dialogContext).pop(workspace),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(workspace.name),
                    subtitle: Text(
                      workspace.rootPath,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
          ),
        );
        if (workspace != null) {
          await service.selectWorkspace(workspace.rootPath);
          return true;
        }
        return false;
      }
      final path = await getDirectoryPath(
        confirmButtonText: 'Open Workspace',
        canCreateDirectories: false,
      );
      if (path == null) return false;
      await service.selectWorkspace(path);
      return true;
    }, openDashboardOnSuccess: true);
  }

  void _showAndroidRestoreHint() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'No workspace is stored on this device. Use Restore workspace from folder to import a backup.',
        ),
      ),
    );
  }

  Future<void> _createWorkspace() async {
    final name = await _askWorkspaceName();
    if (!mounted || name == null) return;

    await _runSelection(() async {
      final service = ref.read(workspaceServiceProvider);
      if (defaultTargetPlatform == TargetPlatform.android) {
        final parent = await service.defaultAndroidWorkspaceParent();
        await service.createWorkspace(parentPath: parent.path, name: name);
        return true;
      }
      final parentPath = await getDirectoryPath(
        confirmButtonText: 'Choose Location',
        canCreateDirectories: true,
      );
      if (parentPath == null) return false;
      await service.createWorkspace(parentPath: parentPath, name: name);
      return true;
    }, openDashboardOnSuccess: true);
  }

  Future<String?> _askWorkspaceName() async {
    final controller = TextEditingController(text: 'SignBridge_Workspace');
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create a workspace'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Workspace folder name',
            hintText: 'e.g. USL Conversation Study',
            helperText: isAndroid
                ? 'Stored in SignBridge app storage on this device.'
                : null,
          ),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: Text(
              isAndroid ? 'Create Workspace' : 'Choose Parent Folder',
            ),
          ),
        ],
      ),
    );
    controller.dispose();
    return name;
  }

  Future<void> _runSelection(
    Future<bool> Function() action, {
    bool openDashboardOnSuccess = false,
  }) async {
    setState(() {
      _isSelecting = true;
      _error = null;
    });
    try {
      final succeeded = await action();
      ref.invalidate(activeWorkspaceProvider);
      if (succeeded && openDashboardOnSuccess && mounted) {
        context.go('/dashboard');
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isSelecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeWorkspace = ref.watch(activeWorkspaceProvider);
    return Scaffold(
      backgroundColor: AppTheme.primaryBackground,
      appBar: AppBar(
        leading: const NavigationBackButton(),
        title: const Text('Workspace'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Local collection workspace',
                    style: TextStyle(
                      color: AppTheme.ivory,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Local collection works without an account or internet connection. Create or open a local workspace to start recording and export datasets.',
                    style: TextStyle(
                      color: AppTheme.ivory.withValues(alpha: 0.78),
                    ),
                  ),
                  if (defaultTargetPlatform == TargetPlatform.android) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Android workspaces are stored in app-managed storage and may be removed if SignBridge is uninstalled or its data is cleared. Create a verified backup or portable copy to a folder you control, then use Restore workspace from folder to reopen it.',
                      style: TextStyle(color: AppTheme.gold),
                    ),
                  ],
                  const SizedBox(height: 20),
                  activeWorkspace.when(
                    loading: () => const AppCard(
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (error, _) => _ErrorCard(message: error.toString()),
                    data: (workspace) => workspace == null
                        ? const _NoWorkspaceCard()
                        : _ActiveWorkspaceCard(
                            workspace: workspace,
                            onBackup: () => _copyWorkspace(workspace, 'backup'),
                            onExport: () => _copyWorkspace(workspace, 'export'),
                          ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    _ErrorCard(message: _error!),
                  ],
                  const SizedBox(height: 20),
                  const Text(
                    'Workspace actions',
                    style: TextStyle(
                      color: AppTheme.ivory,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: _isSelecting ? null : _openExistingWorkspace,
                        icon: const Icon(Icons.folder_open),
                        label: const Text('OPEN EXISTING WORKSPACE'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _isSelecting ? null : _createWorkspace,
                        icon: const Icon(Icons.create_new_folder_outlined),
                        label: const Text('CREATE NEW WORKSPACE'),
                      ),
                      if (defaultTargetPlatform == TargetPlatform.android)
                        OutlinedButton.icon(
                          onPressed: _isSelecting
                              ? null
                              : _importAndroidWorkspace,
                          icon: const Icon(Icons.restore_page_outlined),
                          label: const Text('RESTORE WORKSPACE FROM FOLDER'),
                        ),
                      if (cloudAuthEnabled)
                        TextButton.icon(
                          onPressed: () => context.push('/account'),
                          icon: const Icon(Icons.cloud_outlined),
                          label: const Text('OPTIONAL CLOUD ACCOUNT'),
                        ),
                      if (_isSelecting)
                        const Padding(
                          padding: EdgeInsets.all(10),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActiveWorkspaceCard extends StatelessWidget {
  const _ActiveWorkspaceCard({
    required this.workspace,
    required this.onBackup,
    required this.onExport,
  });

  final LocalWorkspace workspace;
  final VoidCallback onBackup;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.folder_copy_outlined, color: AppTheme.teal),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                workspace.name,
                style: const TextStyle(
                  color: AppTheme.ivory,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            const Chip(label: Text('Selected')),
          ],
        ),
        const SizedBox(height: 8),
        SelectableText(
          workspace.rootPath,
          style: const TextStyle(color: AppTheme.mutedText),
        ),
        const SizedBox(height: 8),
        Text(
          'SQLite schema ${workspace.schemaVersion} · Created ${workspace.createdAt.toLocal()}',
          style: const TextStyle(color: AppTheme.mutedText),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: onBackup,
              icon: const Icon(Icons.backup_outlined),
              label: const Text('CREATE VERIFIED BACKUP'),
            ),
            OutlinedButton.icon(
              onPressed: onExport,
              icon: const Icon(Icons.drive_file_move_outlined),
              label: const Text('EXPORT PORTABLE WORKSPACE'),
            ),
          ],
        ),
      ],
    ),
  );
}

class _NoWorkspaceCard extends StatelessWidget {
  const _NoWorkspaceCard();

  @override
  Widget build(BuildContext context) => const AppCard(
    child: Row(
      children: [
        Icon(Icons.info_outline, color: AppTheme.gold),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            'No local workspace is selected yet. Create a workspace or open an existing SignBridge workspace to enable recording and dataset export.',
            style: TextStyle(color: AppTheme.ivory),
          ),
        ),
      ],
    ),
  );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.error_outline, color: AppTheme.error),
        const SizedBox(width: 10),
        Expanded(child: SelectableText(message)),
      ],
    ),
  );
}
