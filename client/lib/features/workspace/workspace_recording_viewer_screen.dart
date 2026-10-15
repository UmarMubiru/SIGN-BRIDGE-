import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../app/widgets/app_card.dart';
import '../../app/widgets/navigation_back_button.dart';
import '../../core/video/local_video_player.dart';
import '../../core/workspace/local_recording_service.dart';
import '../../core/workspace/local_workspace.dart';
import 'workspace_annotation_panel.dart';

class WorkspaceRecordingViewerScreen extends StatefulWidget {
  const WorkspaceRecordingViewerScreen({
    super.key,
    required this.workspace,
    required this.recordingId,
  });

  final LocalWorkspace workspace;
  final String recordingId;

  @override
  State<WorkspaceRecordingViewerScreen> createState() =>
      _WorkspaceRecordingViewerScreenState();
}

class _WorkspaceRecordingViewerScreenState
    extends State<WorkspaceRecordingViewerScreen> {
  late Future<LocalWorkspaceRecording?> _recording;

  @override
  void initState() {
    super.initState();
    _recording = LocalRecordingService().getRecording(
      widget.workspace,
      widget.recordingId,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.primaryBackground,
    appBar: AppBar(
      leading: const NavigationBackButton(),
      title: const Text('Saved recording'),
    ),
    body: SafeArea(
      child: FutureBuilder<LocalWorkspaceRecording?>(
        future: _recording,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _error(
              'Could not open this workspace recording: ${snapshot.error}',
            );
          }
          final recording = snapshot.data;
          if (recording == null) {
            return _error('This recording is not in the selected workspace.');
          }
          if (!recording.videoExists) {
            return _error(
              'The metadata exists, but its original video is missing: ${recording.relativeVideoPath}',
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                child: SizedBox(
                  height: 380,
                  child: LocalVideoPlayer(
                    filePath: recording.absoluteVideoPath,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recording.fileName,
                      style: const TextStyle(
                        color: AppTheme.ivory,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _detail('Event type', recording.recordingType),
                    _detail('Duration', _duration(recording.durationMs)),
                    _detail('Review status', recording.reviewStatus),
                    _detail('Consent status', recording.consentStatus),
                    _detail('Relative video path', recording.relativeVideoPath),
                    _detail('File size', '${recording.fileSizeBytes} bytes'),
                    _detail('SHA-256', recording.sha256 ?? 'Unavailable'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AppCard(
                child: WorkspaceAnnotationPanel(
                  workspace: widget.workspace,
                  recordingId: recording.id,
                ),
              ),
            ],
          );
        },
      ),
    ),
  );

  Widget _error(String message) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppTheme.ivory),
      ),
    ),
  );

  Widget _detail(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 150,
          child: Text(label, style: const TextStyle(color: AppTheme.teal)),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: const TextStyle(color: AppTheme.ivory),
          ),
        ),
      ],
    ),
  );

  String _duration(int? milliseconds) {
    if (milliseconds == null) return 'Unavailable';
    final duration = Duration(milliseconds: milliseconds);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
