import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'dart:math';

import '../../app/theme/app_theme.dart';
import '../../app/widgets/navigation_back_button.dart';
import '../../app/widgets/app_card.dart';
import '../../app/widgets/app_button.dart';
import '../../core/api_client.dart';
import '../../core/constants/recording_protocol.dart';
import '../../core/recording/recorded_video.dart';
import '../../core/web/web_browser.dart' as browser;
import '../../core/video/video_bytes.dart';
import '../../core/video/local_video_player.dart';
import '../../core/workspace/local_recording_service.dart';
import '../../core/workspace/local_workspace.dart';
import '../../core/workspace/workspace_service.dart';

class ReviewScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? data;

  const ReviewScreen({super.key, required this.data});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  final _apiClient = ApiClient();
  final TextEditingController _notesController = TextEditingController();
  bool _isSaving = false;
  bool _isSavingLocally = false;
  String? _saveError;
  String? _localSaveError;
  String? _createdRecordingId;
  String? _localSessionType = 'conversation';
  SavedLocalRecording? _localSavedRecording;

  RecordedVideo? _recordedVideo;
  LocalWorkspace? _recordingWorkspace;
  String? _videoUrl;

  @override
  void initState() {
    super.initState();
    _loadRecordingContext();
  }

  void _loadRecordingContext() {
    final data = widget.data;

    if (data == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Missing review parameters'),
            backgroundColor: AppTheme.error,
          ),
        );
        context.pop();
      }
      return;
    }

    setState(() {
      _recordedVideo = data['recordedVideo'] as RecordedVideo?;
      _recordingWorkspace = data['workspace'] as LocalWorkspace?;
      if (_recordedVideo?.context.captureFormat != 'continuous_event') {
        _localSessionType = null;
      }
    });

    final contextPrompt = _recordedVideo?.context.contextPrompt.trim() ?? '';
    if (contextPrompt.isNotEmpty && _notesController.text.isEmpty) {
      _notesController.text = 'Approved context/prompt: $contextPrompt';
    }

    // Create blob URL for web video playback
    if (kIsWeb &&
        _recordedVideo != null &&
        _recordedVideo!.video.bytes != null) {
      try {
        _videoUrl = browser.createObjectUrl(
          Uint8List.fromList(_recordedVideo!.video.bytes!),
          _recordedVideo!.video.mimeType,
        );

        // Register a unique view factory for this video
        browser.registerVideoView('video-player-$_videoUrl', _videoUrl!);

        setState(() {});
      } catch (e) {
        debugPrint('Failed to create video URL: $e');
      }
    }
  }

  Future<void> _approveRecording() async {
    if (_recordedVideo == null) return;

    setState(() {
      _isSaving = true;
      _saveError = null;
    });

    try {
      final recordingContext = _recordedVideo!.context;
      final videoAsset = _recordedVideo!.video;
      final videoBytes = videoAsset.bytes;
      final localPath = videoAsset.localPath;
      final fileSize = videoAsset.fileSize;
      if (fileSize <= 0 || (videoBytes == null && localPath == null)) {
        throw StateError(
          'The recorded video has no data to upload. Please retake it.',
        );
      }

      debugPrint('Saving recording with context: $recordingContext');

      // Generate unique IDs with random suffix to avoid duplicates
      final randomSuffix = Random().nextInt(999999).toString().padLeft(6, '0');
      final publicId =
          '${recordingContext.signerId}_${recordingContext.captureFormat}_$randomSuffix';
      final clientId = publicId;

      // Create recording in database
      final recordingData = {
        'public_id': publicId,
        'client_id': clientId,
        'session_id': recordingContext.sessionId,
        'signer_id': recordingContext.signerId,
        'sign_id': recordingContext.signId,
        'capture_format': recordingContext.captureFormat,
        'cue_markers': recordingContext.cueMarkers,
        'repetition_no':
            CAPTURE_FORMATS.indexWhere(
              (f) => f.id == recordingContext.captureFormat,
            ) +
            1,
        'camera_angle': recordingContext.captureFormatLabel,
        'lighting_condition': recordingContext.lightingCondition,
        'background': recordingContext.background,
        'file_name': recordingContext.fileName,
        'file_url': null, // Will be set after upload
        'duration': _recordedVideo!.duration.inSeconds,
        'recording_status': 'uploading',
        'validation_status': 'approved',
        'remarks': _notesController.text.isEmpty ? null : _notesController.text,
      };

      debugPrint('Recording data: $recordingData');

      if (_createdRecordingId == null) {
        final createdRecording = await _apiClient.createRecording(
          recordingData,
        );
        _createdRecordingId = createdRecording['id']?.toString();
        if (_createdRecordingId == null) {
          throw StateError('The server did not return the saved recording ID.');
        }
      }

      // Keep this screen open and reuse the same recording if upload fails so
      // the user can retry without creating a duplicate database row.
      final uploadedRecording = await _apiClient.uploadRecordingVideo(
        _createdRecordingId!,
        videoBytes: videoBytes,
        localPath: localPath,
        fileSize: fileSize,
        fileName: recordingContext.fileName,
        mimeType: videoBytes == null
            ? videoAsset.mimeType
            : detectVideoMimeType(videoBytes, fallback: videoAsset.mimeType),
      );
      if (uploadedRecording['file_url'] == null ||
          uploadedRecording['file_url'].toString().isEmpty) {
        throw StateError(
          'The server accepted the upload but did not save its video URL.',
        );
      }
      await deleteVideoFile(_recordedVideo!.video.localPath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recording saved successfully'),
            backgroundColor: AppTheme.success,
          ),
        );

        // Replace the recording/review stack in one navigation update. Chained
        // pops can race route disposal and leave stale pages in browser history.
        final signContext = _recordedVideo!.context;
        final destination = Uri(
          path: '/sessions/${signContext.sessionId}/signs',
          queryParameters: {'signId': signContext.signId},
        );
        context.go(destination.toString());
      }
    } catch (e) {
      debugPrint('Error saving recording: $e');
      if (mounted) {
        final message =
            'Could not save the recording video: ${describeApiError(e)}';
        setState(() {
          _isSaving = false;
          _saveError = message;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 15),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _approveAndSaveLocally() async {
    final recording = _recordedVideo;
    final workspace =
        _recordingWorkspace ?? ref.read(activeWorkspaceProvider).valueOrNull;
    if (recording == null || workspace == null || _localSessionType == null) {
      setState(() {
        _localSaveError = workspace == null
            ? 'Select a workspace before saving locally.'
            : 'Choose whether this event is a conversation, narrative, or other recording.';
      });
      return;
    }
    setState(() {
      _isSavingLocally = true;
      _localSaveError = null;
    });
    try {
      final saved = await LocalRecordingService().approveAndSave(
        workspace: workspace,
        recording: recording,
        sessionType: _localSessionType!,
        consentStatus: 'not_recorded',
        notes: _notesController.text,
      );
      if (!mounted) return;
      notifyRecordingsChanged();
      setState(() => _localSavedRecording = saved);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saved.duplicate
                ? 'This video is already saved in the selected workspace.'
                : 'Recording approved and saved to the selected workspace.',
          ),
          backgroundColor: AppTheme.success,
        ),
      );
    } catch (error) {
      if (mounted) {
        final message = error.toString().replaceFirst('Exception: ', '');
        setState(() => _localSaveError = 'Could not save locally: $message');
      }
    } finally {
      if (mounted) setState(() => _isSavingLocally = false);
    }
  }

  void _retakeRecording() {
    // Navigate back to recording screen for the same repetition
    context.pop(); // Pop review screen
    // User will be back at recording screen to record again
  }

  @override
  void dispose() {
    _notesController.dispose();
    if (kIsWeb && _videoUrl != null) {
      try {
        browser.revokeObjectUrl(_videoUrl!);
      } catch (e) {
        // Ignore cleanup errors
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedWorkspace =
        _recordingWorkspace ?? ref.watch(activeWorkspaceProvider).valueOrNull;
    return Scaffold(
      backgroundColor: AppTheme.primaryBackground,
      appBar: AppBar(
        leading: const NavigationBackButton(),
        title: const Text('Review Recording'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Video player
              AppCard(
                child: Container(
                  height: 300,
                  decoration: BoxDecoration(
                    color: AppTheme.secondarySurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _buildVideoPlayer(),
                ),
              ),
              const SizedBox(height: 24),

              // Recording Metadata
              const Text(
                'Recording Information',
                style: TextStyle(
                  color: AppTheme.ivory,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              if (_recordedVideo != null)
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow('Signer', _recordedVideo!.context.signerId),
                      _buildInfoRow('Sign', _recordedVideo!.context.signLabel),
                      _buildInfoRow(
                        'Capture format',
                        _recordedVideo!.context.captureFormatLabel,
                      ),
                      _buildInfoRow(
                        'Lighting',
                        _recordedVideo!.context.lightingCondition,
                      ),
                      _buildInfoRow(
                        'Background',
                        _recordedVideo!.context.background,
                      ),
                      _buildInfoRow(
                        'Filename',
                        _recordedVideo!.context.fileName,
                      ),
                      _buildInfoRow(
                        'Duration',
                        _formatDurationDisplay(_recordedVideo?.duration),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),

              // Remarks include the required approved prompt for contextual clips.
              Text(
                _recordedVideo?.context.captureFormat == 'contextual_utterance'
                    ? 'Context prompt and remarks'
                    : 'Remarks (Optional)',
                style: TextStyle(
                  color: AppTheme.ivory,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _notesController,
                maxLines: 3,
                maxLength: 5000,
                decoration: InputDecoration(
                  hintText: 'The approved context is prefilled; add any relevant notes...',
                  hintStyle: TextStyle(
                    color: AppTheme.ivory.withValues(alpha: 0.5),
                  ),
                  filled: true,
                  fillColor: AppTheme.secondarySurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: const TextStyle(color: AppTheme.ivory),
              ),
              const SizedBox(height: 24),

              if (_saveError != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.12),
                    border: Border.all(color: AppTheme.error),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline, color: AppTheme.error),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SelectableText(
                          _saveError!,
                          style: const TextStyle(color: AppTheme.ivory),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Copy error',
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          await Clipboard.setData(
                            ClipboardData(text: _saveError!),
                          );
                          if (!mounted || !messenger.mounted) return;
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Error copied'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy, color: AppTheme.gold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'SAVE TO WORKSPACE (OFFLINE)',
                      style: TextStyle(
                        color: AppTheme.teal,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      selectedWorkspace == null
                          ? 'No workspace is selected. Select or create one to save this recording locally.'
                          : 'Video and metadata will be saved to “${selectedWorkspace.name}”. No cloud upload will occur.',
                      style: const TextStyle(color: AppTheme.ivory),
                    ),
                    const SizedBox(height: 10),
                    if (selectedWorkspace == null)
                      OutlinedButton(
                        onPressed: (_isSaving || _isSavingLocally)
                            ? null
                            : () => context.push('/workspace'),
                        child: const Text('Select workspace'),
                      )
                    else ...[
                      DropdownButtonFormField<String>(
                        initialValue: _localSessionType,
                        decoration: const InputDecoration(
                          labelText: 'Recording event type (required)',
                          helperText:
                              'Choose an event type to enable local approval.',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'conversation',
                            child: Text('Continuous conversation'),
                          ),
                          DropdownMenuItem(
                            value: 'narrative',
                            child: Text('Narrative or monologue'),
                          ),
                          DropdownMenuItem(
                            value: 'other',
                            child: Text('Other continuous event'),
                          ),
                        ],
                        onChanged: (_isSaving || _isSavingLocally)
                            ? null
                            : (value) => setState(() {
                                _localSessionType = value;
                                _localSaveError = null;
                              }),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Participants and consent details were not provided for this recording; consent is stored as “not recorded”.',
                        style: TextStyle(
                          color: AppTheme.ivory.withValues(alpha: 0.75),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_localSaveError != null) ...[
                        Text(
                          _localSaveError!,
                          style: const TextStyle(color: AppTheme.error),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (_localSavedRecording != null) ...[
                        Text(
                          'Saved video: ${_localSavedRecording!.relativeVideoPath}',
                          style: const TextStyle(color: AppTheme.success),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () => context.push(
                            '/workspace/recordings',
                            extra: {'workspace': selectedWorkspace},
                          ),
                          icon: const Icon(Icons.video_library_outlined),
                          label: const Text('Open workspace library'),
                        ),
                        const SizedBox(height: 8),
                      ],
                      AppButton(
                        text: _localSavedRecording == null
                            ? 'APPROVE & SAVE LOCALLY'
                            : 'SAVED TO WORKSPACE',
                        onPressed:
                            (_isSaving ||
                                _isSavingLocally ||
                                _localSessionType == null ||
                                _localSavedRecording != null)
                            ? null
                            : _approveAndSaveLocally,
                        isLoading: _isSavingLocally,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (_localSaveError != null && selectedWorkspace == null) ...[
                Text(
                  _localSaveError!,
                  style: const TextStyle(color: AppTheme.error),
                ),
                const SizedBox(height: 12),
              ],

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      text: 'RETAKE',
                      onPressed: (_isSaving || _isSavingLocally)
                          ? null
                          : _retakeRecording,
                      isSecondary: true,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: AppButton(
                      text: _recordedVideo?.context.signId.isNotEmpty == true
                          ? 'APPROVE & UPLOAD'
                          : 'CLOUD UPLOAD NEEDS A SIGN SESSION',
                      onPressed:
                          (_isSaving ||
                              _isSavingLocally ||
                              _recordedVideo?.context.signId.isNotEmpty != true)
                          ? null
                          : _approveRecording,
                      isLoading: _isSaving,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: AppTheme.teal,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: AppTheme.ivory, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatDurationDisplay(Duration? duration) {
    if (duration == null) return '0:00';
    return _formatDuration(duration);
  }

  Widget _buildVideoPlayer() {
    if (kIsWeb && _videoUrl != null) {
      // Web: Use HTML5 video element via platform view
      return HtmlElementView(viewType: 'video-player-$_videoUrl');
    } else if (!kIsWeb && _recordedVideo?.video.localPath != null) {
      return LocalVideoPlayer(filePath: _recordedVideo!.video.localPath!);
    } else {
      return const Center(child: CircularProgressIndicator());
    }
  }
}
