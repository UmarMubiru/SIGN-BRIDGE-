import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_theme.dart';
import '../../app/widgets/app_card.dart';
import '../../app/widgets/navigation_back_button.dart';
import '../../core/workspace/local_recording_service.dart';
import '../../core/workspace/local_workspace.dart';

class WorkspaceRecordingsScreen extends StatefulWidget {
  const WorkspaceRecordingsScreen({super.key, required this.workspace});

  final LocalWorkspace workspace;

  @override
  State<WorkspaceRecordingsScreen> createState() =>
      _WorkspaceRecordingsScreenState();
}

class _WorkspaceRecordingsScreenState extends State<WorkspaceRecordingsScreen> {
  late Future<List<LocalWorkspaceRecording>> _recordings;
  final _search = TextEditingController();
  String _typeFilter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _recordings = LocalRecordingService().listRecordings(widget.workspace);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.primaryBackground,
    appBar: AppBar(
      leading: const NavigationBackButton(),
      title: const Text('Workspace recordings'),
    ),
    body: SafeArea(
      child: FutureBuilder<List<LocalWorkspaceRecording>>(
        future: _recordings,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _Message(
              icon: Icons.error_outline,
              message: 'Could not read this workspace: ${snapshot.error}',
            );
          }
          final recordings = snapshot.data ?? const [];
          if (recordings.isEmpty && _search.text.isEmpty) {
            return const _Message(
              icon: Icons.video_library_outlined,
              message: 'No approved local recordings are saved in this workspace yet.',
            );
          }
          final query = _search.text.trim().toLowerCase();
          final filtered = recordings
              .where(
                (recording) =>
                    query.isEmpty || recording.searchText.contains(query),
              )
              .where(
                (recording) =>
                    _typeFilter == 'all' ||
                    recording.recordingType == _typeFilter,
              )
              .toList();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(color: AppTheme.ivory),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  labelText:
                      'Search recordings, type, path, status, or checksum',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _typeFilter,
                decoration: const InputDecoration(labelText: 'Event type'),
                items: const [
                  DropdownMenuItem(
                    value: 'all',
                    child: Text('All continuous events'),
                  ),
                  DropdownMenuItem(
                    value: 'conversation',
                    child: Text('Conversation'),
                  ),
                  DropdownMenuItem(
                    value: 'narrative',
                    child: Text('Narrative'),
                  ),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (value) =>
                    setState(() => _typeFilter = value ?? 'all'),
              ),
              const SizedBox(height: 12),
              if (filtered.isEmpty)
                const _Message(
                  icon: Icons.search_off,
                  message: 'No recordings match this search.',
                ),
              for (final recording in filtered) ...[
                AppCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      recording.videoExists
                          ? Icons.play_circle_outline
                          : Icons.warning_amber_rounded,
                      color: recording.videoExists
                          ? AppTheme.teal
                          : AppTheme.gold,
                      size: 34,
                    ),
                    title: Text(
                      recording.fileName,
                      style: const TextStyle(
                        color: AppTheme.ivory,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '${_eventTypeLabel(recording.recordingType)} · ${_duration(recording.durationMs)} · ${recording.videoExists ? 'Video available' : 'Video file missing'}\n${recording.relativeVideoPath}',
                        style: const TextStyle(color: AppTheme.mutedText),
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: AppTheme.ivory,
                    ),
                    onTap: () => context.push(
                      '/workspace/recordings/${recording.id}',
                      extra: {'workspace': widget.workspace},
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ],
          );
        },
      ),
    ),
  );

  static String _eventTypeLabel(String value) => switch (value) {
    'conversation' => 'Conversation',
    'narrative' => 'Narrative',
    _ => 'Other continuous event',
  };

  static String _duration(int? milliseconds) {
    if (milliseconds == null) return 'Duration unavailable';
    final duration = Duration(milliseconds: milliseconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52, color: AppTheme.teal),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.ivory),
          ),
        ],
      ),
    ),
  );
}
