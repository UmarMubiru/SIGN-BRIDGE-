import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_theme.dart';
import '../../app/widgets/app_card.dart';
import '../../app/widgets/navigation_back_button.dart';
import '../../core/workspace/local_workspace.dart';
import '../../core/workspace/workspace_service.dart';
import '../../core/workspace/workspace_copy_service.dart';
import '../../core/recording/recording_context.dart';

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
      final destination = await getDirectoryPath(
        confirmButtonText: purpose == 'backup'
            ? 'Save Backup Here'
            : 'Export Here',
        canCreateDirectories: true,
      );
      if (destination == null) return;
      final result = await WorkspaceCopyService().createCopy(
        workspace: workspace,
        destinationParent: destination,
        purpose: purpose,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verified $purpose created at ${result.path}')),
      );
    });
  }

  Future<void> _openExistingWorkspace() async {
    await _runSelection(() async {
      final service = ref.read(workspaceServiceProvider);
      if (defaultTargetPlatform == TargetPlatform.android) {
        final workspaces = await service.listAndroidWorkspaces();
        if (!mounted) return;
        if (workspaces.isEmpty) {
          throw const WorkspaceException(
            'No workspace folders were found in SignBridge app storage. Create one first.',
          );
        }
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
        }
        return;
      }
      final path = await getDirectoryPath(
        confirmButtonText: 'Open Workspace',
        canCreateDirectories: false,
      );
      if (path == null) return;
      await service.selectWorkspace(path);
    });
  }

  Future<void> _createWorkspace() async {
    final name = await _askWorkspaceName();
    if (!mounted || name == null) return;

    await _runSelection(() async {
      final service = ref.read(workspaceServiceProvider);
      if (defaultTargetPlatform == TargetPlatform.android) {
        final parent = await service.defaultAndroidWorkspaceParent();
        await service.createWorkspace(parentPath: parent.path, name: name);
        return;
      }
      final parentPath = await getDirectoryPath(
        confirmButtonText: 'Choose Location',
        canCreateDirectories: true,
      );
      if (parentPath != null) {
        await service.createWorkspace(parentPath: parentPath, name: name);
      }
    });
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

  Future<void> _runSelection(Future<void> Function() action) async {
    setState(() {
      _isSelecting = true;
      _error = null;
    });
    try {
      await action();
      ref.invalidate(activeWorkspaceProvider);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isSelecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeWorkspace = ref.watch(activeWorkspaceProvider);
    final selectedWorkspace = activeWorkspace.valueOrNull;
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
                    'Local collection works without an account or internet connection. Choose a folder for your videos and SQLite metadata. Cloud sign-in is optional.',
                    style: TextStyle(
                      color: AppTheme.ivory.withValues(alpha: 0.78),
                    ),
                  ),
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
                  if (selectedWorkspace != null) ...[
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: _isSelecting
                          ? null
                          : () => context.push(
                              '/recording/camera',
                              extra: {
                                'workspace': selectedWorkspace,
                                'recordingContext': RecordingContext(
                                  sessionId: '',
                                  signerId: '',
                                  signId: '',
                                  signLabel: '',
                                  captureFormat: 'continuous_event',
                                  captureFormatLabel: 'Continuous recording',
                                  lightingCondition: '',
                                  background: '',
                                  fileName:
                                      'event_${DateTime.now().toUtc().millisecondsSinceEpoch}.mp4',
                                ),
                              },
                            ),
                      icon: const Icon(Icons.videocam_outlined),
                      label: const Text('START CONTINUOUS RECORDING'),
                    ),
                    Text(
                      'Record a conversation or narrative without assigning sign IDs. Choose the event type on the review screen.',
                      style: TextStyle(
                        color: AppTheme.ivory.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    _ErrorCard(message: _error!),
                  ],
                  const SizedBox(height: 20),
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
                      TextButton.icon(
                        onPressed: () => context.push('/login'),
                        icon: const Icon(Icons.cloud_outlined),
                        label: const Text('OPTIONAL CLOUD SIGN-IN'),
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
                  const SizedBox(height: 24),
                  const _FolderLayoutCard(),
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
              onPressed: () => context.push(
                '/workspace/recordings',
                extra: {'workspace': workspace},
              ),
              icon: const Icon(Icons.video_library_outlined),
              label: const Text('BROWSE WORKSPACE RECORDINGS'),
            ),
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
            'No local workspace is selected. Existing cloud features continue to work as before.',
            style: TextStyle(color: AppTheme.ivory),
          ),
        ),
      ],
    ),
  );
}

class _FolderLayoutCard extends StatelessWidget {
  const _FolderLayoutCard();

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Workspace folders',
          style: TextStyle(color: AppTheme.ivory, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        for (final entry in const [
          ('database.sqlite3', 'Recording and annotation metadata'),
          ('videos/', 'Original continuous video files'),
          ('exports/', 'Optional workspace exports'),
          ('backups/', 'Workspace backup storage'),
        ])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 150,
                  child: Text(
                    entry.$1,
                    style: const TextStyle(color: AppTheme.teal),
                  ),
                ),
                Expanded(
                  child: Text(
                    entry.$2,
                    style: const TextStyle(color: AppTheme.ivory),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        const Text(
          'Videos will remain regular files; no video bytes are stored in SQLite.',
          style: TextStyle(color: AppTheme.mutedText),
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
