import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'theme/app_theme.dart';
import 'widgets/app_navigation.dart';
import '../core/workspace/workspace_service.dart';

/// Navigation frame used by the local collection modules once a workspace is
/// selected. Existing screens keep their own page scaffolds inside this frame.
class WorkspaceShell extends ConsumerWidget {
  const WorkspaceShell({
    super.key,
    required this.child,
    this.allowNoWorkspace = false,
  });

  final Widget child;
  final bool allowNoWorkspace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspaceState = ref.watch(activeWorkspaceProvider);
    final workspace = workspaceState.valueOrNull;
    if (!allowNoWorkspace && workspaceState.isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.primaryBackground,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!allowNoWorkspace && workspaceState.hasError) {
      return Scaffold(
        backgroundColor: AppTheme.primaryBackground,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Could not open the saved workspace. Select a valid local workspace to continue.\n\n${workspaceState.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.ivory),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => context.go('/workspace'),
                  icon: const Icon(Icons.folder_open),
                  label: const Text('OPEN WORKSPACE SETTINGS'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (!allowNoWorkspace && workspace == null) {
      return Scaffold(
        backgroundColor: AppTheme.primaryBackground,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.folder_outlined,
                    color: AppTheme.teal,
                    size: 56,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Choose a local workspace to begin',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.ivory,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Recording, saved collection data, and dataset export are available after you create or open a workspace folder.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.mutedText),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () => context.go('/workspace'),
                    icon: const Icon(Icons.folder_open),
                    label: const Text('CREATE OR OPEN WORKSPACE'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    final wide = MediaQuery.sizeOf(context).width > 900;
    final content = Column(
      children: [
        Material(
          color: AppTheme.secondarySurface,
          elevation: 3,
          shadowColor: Colors.black.withValues(alpha: 0.35),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppTheme.secondarySurface,
              border: Border(
                bottom: BorderSide(
                  color: AppTheme.teal.withValues(alpha: 0.55),
                  width: 1.5,
                ),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: 56,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      if (!wide)
                        Builder(
                          builder: (context) => IconButton(
                            tooltip: 'Open navigation',
                            onPressed: () => Scaffold.of(context).openDrawer(),
                            icon: const Icon(Icons.menu, color: AppTheme.ivory),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          workspace == null
                              ? 'No workspace selected'
                              : 'Local workspace · ${workspace.name}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppTheme.ivory),
                        ),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'Workspace options',
                        icon: const Icon(
                          Icons.folder_copy_outlined,
                          color: AppTheme.teal,
                        ),
                        onSelected: (action) {
                          if (action == 'manage') {
                            context.go('/workspace');
                          } else if (action == 'recordings' &&
                              workspace != null) {
                            context.push(
                              '/workspace/recordings',
                              extra: {'workspace': workspace},
                            );
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem<String>(
                            value: 'manage',
                            child: Row(
                              children: [
                                const Icon(Icons.settings_outlined),
                                const SizedBox(width: 10),
                                Text(
                                  workspace == null
                                      ? 'Create or open workspace'
                                      : 'Manage workspace',
                                ),
                              ],
                            ),
                          ),
                          if (workspace != null)
                            const PopupMenuItem<String>(
                              value: 'recordings',
                              child: Row(
                                children: [
                                  Icon(Icons.video_library_outlined),
                                  SizedBox(width: 10),
                                  Text('Workspace recordings'),
                                ],
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
        ),
        Expanded(child: child),
      ],
    );

    if (wide) {
      return Scaffold(
        backgroundColor: AppTheme.primaryBackground,
        body: Row(
          children: [
            const AppNavigation(),
            Expanded(child: content),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.primaryBackground,
      drawer: const AppNavigation(),
      body: SafeArea(top: false, child: content),
    );
  }
}
