import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_theme.dart';
import '../../app/widgets/app_button.dart';
import '../../app/widgets/app_card.dart';
import '../../app/widgets/navigation_back_button.dart';
import '../../core/recording/recording_context.dart';
import '../../core/workspace/workspace_service.dart';

class LocalRecordingLaunchScreen extends ConsumerWidget {
  const LocalRecordingLaunchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(activeWorkspaceProvider);
    return Scaffold(
      backgroundColor: AppTheme.primaryBackground,
      appBar: AppBar(
        leading: const NavigationBackButton(),
        title: const Text('New recording'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: workspace.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => AppCard(
                  child: Text(
                    'Could not load the selected workspace: $error',
                    style: const TextStyle(color: AppTheme.ivory),
                  ),
                ),
                data: (selected) => AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.videocam_outlined,
                        color: AppTheme.gold,
                        size: 52,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Record a continuous conversation or narrative',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.ivory,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        selected == null
                            ? 'Choose a workspace first. Recordings are saved to that workspace after local approval.'
                            : 'Active workspace: ${selected.name}\n${selected.rootPath}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppTheme.mutedText),
                      ),
                      const SizedBox(height: 20),
                      AppButton(
                        text: selected == null
                            ? 'CHOOSE WORKSPACE'
                            : 'OPEN CAMERA',
                        onPressed: () {
                          if (selected == null) {
                            context.go('/workspace');
                            return;
                          }
                          context.push(
                            '/recording/camera',
                            extra: {
                              'workspace': selected,
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
                          );
                        },
                      ),
                      if (selected != null) ...[
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () => context.push(
                            '/workspace/recordings',
                            extra: {'workspace': selected},
                          ),
                          icon: const Icon(Icons.video_library_outlined),
                          label: const Text('Browse saved recordings'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
