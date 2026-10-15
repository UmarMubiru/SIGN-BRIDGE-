import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'theme/app_theme.dart';
import 'widgets/app_navigation.dart';
import '../core/workspace/workspace_service.dart';

/// Navigation frame used by the local collection modules once a workspace is
/// selected. Existing screens keep their own page scaffolds inside this frame.
class WorkspaceShell extends ConsumerWidget {
  const WorkspaceShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(activeWorkspaceProvider).valueOrNull;
    final wide = MediaQuery.sizeOf(context).width > 900;
    final currentPath = GoRouterState.of(context).uri.path;
    final isRecordingLocked =
        currentPath == '/recording/camera' || currentPath == '/review';
    final content = Column(
      children: [
        if (!isRecordingLocked && (workspace != null || !wide))
          Material(
            color: AppTheme.secondarySurface,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  if (!wide && !isRecordingLocked)
                    Builder(
                      builder: (context) => IconButton(
                        tooltip: 'Open navigation',
                        onPressed: () => Scaffold.of(context).openDrawer(),
                        icon: const Icon(Icons.menu, color: AppTheme.ivory),
                      ),
                    ),
                  const Icon(Icons.folder_copy_outlined, color: AppTheme.teal),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      workspace == null
                          ? 'Select a local workspace to begin collection'
                          : 'Local workspace: ${workspace.name}  ·  ${workspace.rootPath}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppTheme.ivory),
                    ),
                  ),
                  const Chip(label: Text('WORKSPACE')),
                ],
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
            if (!isRecordingLocked) const AppNavigation(),
            Expanded(child: content),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.primaryBackground,
      drawer: isRecordingLocked ? null : const AppNavigation(),
      body: SafeArea(child: content),
    );
  }
}
