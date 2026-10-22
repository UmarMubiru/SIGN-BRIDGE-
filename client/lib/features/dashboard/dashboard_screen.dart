import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_theme.dart';
import '../../app/widgets/app_card.dart';
import '../../core/api_client.dart';
import '../../core/workspace/local_recording_service.dart';
import '../../core/workspace/local_workspace.dart';
import '../../core/workspace/workspace_service.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(activeWorkspaceProvider);
    return Scaffold(
      backgroundColor: AppTheme.primaryBackground,
      appBar: AppBar(
        toolbarHeight: 90,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            RichText(
              text: const TextSpan(
                style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800),
                children: [
                  TextSpan(
                    text: 'Sign',
                    style: TextStyle(color: AppTheme.teal),
                  ),
                  TextSpan(
                    text: 'Bridge',
                    style: TextStyle(color: AppTheme.gold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'Different Hands • Same Voice',
              style: TextStyle(color: AppTheme.mutedText, fontSize: 12),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: workspace.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _Notice(
            icon: Icons.error_outline,
            message: 'Could not load the selected workspace: $error',
          ),
          data: (selected) => selected == null
              ? _NoWorkspace(onChoose: () => context.go('/workspace'))
              : _WorkspaceOverview(workspace: selected),
        ),
      ),
    );
  }
}

class _NoWorkspace extends StatelessWidget {
  const _NoWorkspace({required this.onChoose});
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 620),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: AppCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.folder_open, color: AppTheme.gold, size: 48),
              const SizedBox(height: 12),
              const Text(
                'Start with a local workspace',
                style: TextStyle(
                  color: AppTheme.ivory,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Create or open a workspace to collect video and metadata on this device. Cloud sign-in is optional.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.mutedText),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onChoose,
                icon: const Icon(Icons.folder),
                label: const Text('MANAGE WORKSPACE'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _WorkspaceOverview extends StatefulWidget {
  const _WorkspaceOverview({required this.workspace});
  final LocalWorkspace workspace;

  @override
  State<_WorkspaceOverview> createState() => _WorkspaceOverviewState();
}

class _WorkspaceOverviewState extends State<_WorkspaceOverview> {
  late Future<List<WorkspaceActivity>> _activity;
  late Future<List<LocalWorkspaceRecording>> _recordings;

  @override
  void initState() {
    super.initState();
    recordingsChanged.addListener(_refresh);
    _load();
  }

  @override
  void didUpdateWidget(covariant _WorkspaceOverview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspace.rootPath != widget.workspace.rootPath) _load();
  }

  @override
  void dispose() {
    recordingsChanged.removeListener(_refresh);
    super.dispose();
  }

  void _load() {
    _activity = LocalRecordingService().listRecentActivity(widget.workspace);
    _recordings = LocalRecordingService().listRecordings(widget.workspace);
  }

  void _refresh() {
    if (!mounted) return;
    setState(_load);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<WorkspaceActivity>>(
    future: _activity,
    builder: (context, snapshot) {
      final activity = snapshot.data ?? const <WorkspaceActivity>[];
      return LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 640;
          return ListView(
            padding: EdgeInsets.all(narrow ? 16 : 28),
            children: [
              AppCard(
                child: Row(
                  children: [
                    const Icon(
                      Icons.folder_copy_outlined,
                      color: AppTheme.teal,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.workspace.name,
                            style: const TextStyle(
                              color: AppTheme.ivory,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            widget.workspace.rootPath,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppTheme.mutedText),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go('/workspace'),
                      child: const Text('Manage'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              FutureBuilder<List<LocalWorkspaceRecording>>(
                future: _recordings,
                builder: (context, recordingSnapshot) {
                  final recordings =
                      recordingSnapshot.data ??
                      const <LocalWorkspaceRecording>[];
                  final approved = recordings
                      .where(
                        (recording) => recording.reviewStatus == 'approved',
                      )
                      .length;
                  final missing = recordings
                      .where((recording) => !recording.videoExists)
                      .length;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _MetricCard(
                        label: 'Saved videos',
                        value: recordingSnapshot.hasError
                            ? '—'
                            : '${recordings.length}',
                        icon: Icons.video_library_outlined,
                      ),
                      _MetricCard(
                        label: 'Approved',
                        value: recordingSnapshot.hasError ? '—' : '$approved',
                        icon: Icons.check_circle_outline,
                      ),
                      _MetricCard(
                        label: 'Missing files',
                        value: recordingSnapshot.hasError ? '—' : '$missing',
                        icon: Icons.warning_amber_outlined,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Continue collecting',
                      style: TextStyle(
                        color: AppTheme.ivory,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Choose a signer and signing conditions, select a word, then record and review it into this workspace.',
                      style: TextStyle(color: AppTheme.mutedText),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      children: [
                        FilledButton.icon(
                          onPressed: () => context.go('/sessions/create'),
                          icon: const Icon(Icons.fiber_manual_record),
                          label: const Text('NEW RECORDING'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Recent activity',
                      style: TextStyle(
                        color: AppTheme.ivory,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (snapshot.connectionState != ConnectionState.done)
                      const LinearProgressIndicator()
                    else if (snapshot.hasError)
                      Text(
                        'Could not read workspace activity: ${snapshot.error}',
                        style: const TextStyle(color: AppTheme.error),
                      )
                    else if (activity.isEmpty)
                      const Text(
                        'Workspace activity will appear here as you collect and review data.',
                        style: TextStyle(color: AppTheme.mutedText),
                      )
                    else
                      for (final event in activity.take(8))
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(event.icon, color: AppTheme.teal),
                          title: Text(
                            event.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppTheme.ivory),
                          ),
                          subtitle: Text(
                            '${event.details} · ${_activityDate(event.createdAt)}',
                            style: const TextStyle(color: AppTheme.mutedText),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right,
                            color: AppTheme.mutedText,
                          ),
                          onTap: event.recordingId == null
                              ? null
                              : () => context.push(
                                  '/workspace/recordings/${event.recordingId}',
                                  extra: {'workspace': widget.workspace},
                                ),
                        ),
                  ],
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 190,
    child: AppCard(
      child: Row(
        children: [
          Icon(icon, color: AppTheme.gold),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: AppTheme.ivory,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(label, style: const TextStyle(color: AppTheme.mutedText)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

String _activityDate(DateTime date) {
  final local = date.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: AppCard(
        child: Row(
          children: [
            Icon(icon, color: AppTheme.gold),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: AppTheme.ivory),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
