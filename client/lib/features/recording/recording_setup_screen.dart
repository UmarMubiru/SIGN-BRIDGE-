import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_theme.dart';
import '../../app/widgets/app_card.dart';
import '../../app/widgets/app_button.dart';
import '../../core/constants/recording_protocol.dart';
import '../../core/recording/recording_context.dart';

class RecordingSetupScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? data;

  const RecordingSetupScreen({super.key, required this.data});

  @override
  ConsumerState<RecordingSetupScreen> createState() =>
      _RecordingSetupScreenState();
}

class _RecordingSetupScreenState extends ConsumerState<RecordingSetupScreen> {
  final TextEditingController _contextPromptController = TextEditingController();
  String _sessionId = '';
  String _signId = '';
  String _captureFormat = CAPTURE_FORMATS.first.id;
  String _lighting = '';
  String _background = '';
  String _signerId = '';
  String _signLabel = '';
  String _errorMessage = '';

  @override
  void dispose() {
    _contextPromptController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadRecordingContext();
  }

  void _loadRecordingContext() {
    final data = widget.data;

    if (data == null) {
      setState(() {
        _errorMessage = 'Recording information was not provided.';
      });
      return;
    }

    setState(() {
      _sessionId = data['sessionId']?.toString() ?? '';
      _signId = data['signId']?.toString() ?? '';

      _captureFormat =
          captureFormatById(data['captureFormat']?.toString())?.id ??
          CAPTURE_FORMATS.first.id;
      _contextPromptController.text =
          data['contextPrompt']?.toString() ?? '';
      _lighting = data['lighting']?.toString() ?? '';
      _background = data['background']?.toString() ?? '';
      _signerId = data['signerId']?.toString() ?? '';
      _signLabel = data['signLabel']?.toString() ?? '';
    });
  }

  String _generateFilename() {
    final signerId = _signerId.isEmpty ? 'S00' : _signerId;
    final signLabel = _signLabel.isEmpty ? 'Unknown' : _signLabel;
    return generateRecordingFilename(signerId, signLabel, _captureFormat);
  }

  void _startRecording() {
    if (_sessionId.isEmpty || _signId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Missing required recording information'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    if (_captureFormat == 'contextual_utterance' &&
        _contextPromptController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter the agreed context or prompt from a fluent USL signer before recording.',
          ),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    // Create RecordingContext
    final recordingContext = RecordingContext(
      sessionId: _sessionId,
      signerId: _signerId,
      signId: _signId,
      signLabel: _signLabel,
      captureFormat: _captureFormat,
      captureFormatLabel: captureFormatById(_captureFormat)!.label,
      lightingCondition: _lighting,
      background: _background,
      fileName: _generateFilename(),
      contextPrompt: _contextPromptController.text.trim(),
    );

    context.push(
      '/recording/camera',
      extra: {'recordingContext': recordingContext},
    );
  }

  @override
  Widget build(BuildContext context) {
    final filename = _generateFilename();

    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        backgroundColor: AppTheme.primaryBackground,
        appBar: AppBar(title: const Text('Recording Setup')),
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: AppTheme.error,
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage,
                  style: const TextStyle(color: AppTheme.ivory),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                AppButton(text: 'Go Back', onPressed: () => context.pop()),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.primaryBackground,
      appBar: AppBar(title: const Text('Recording Setup')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Recording Information',
                style: TextStyle(
                  color: AppTheme.ivory,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              // Sign Info
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SIGN',
                      style: TextStyle(
                        color: AppTheme.teal,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _signLabel.isEmpty ? 'Unknown' : _signLabel,
                      style: const TextStyle(
                        color: AppTheme.ivory,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Capture format
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SAMPLE TYPE',
                      style: TextStyle(
                        color: AppTheme.teal,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      captureFormatById(_captureFormat)!.label,
                      style: const TextStyle(
                        color: AppTheme.ivory,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ONE CLIP • RECORDING CHECKLIST',
                      style: TextStyle(
                        color: AppTheme.teal,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.camera_alt,
                          color: AppTheme.gold,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            captureFormatById(_captureFormat)!.description,
                            style: const TextStyle(
                              color: AppTheme.ivory,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...captureFormatById(_captureFormat)!.guidanceSteps
                        .asMap()
                        .entries
                        .map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${entry.key + 1}. ',
                                  style: const TextStyle(
                                    color: AppTheme.gold,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    entry.value,
                                    style: const TextStyle(
                                      color: AppTheme.ivory,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (_captureFormat == 'contextual_utterance') ...[
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'APPROVED USL CONTEXT / PROMPT',
                        style: TextStyle(
                          color: AppTheme.teal,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Use a short phrase or scenario agreed with a fluent USL signer. Record the prompt or a concise description here; avoid word-for-word English translation.',
                        style: TextStyle(color: AppTheme.ivory, fontSize: 14),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _contextPromptController,
                        maxLines: 3,
                        maxLength: 1000,
                        decoration: InputDecoration(
                          hintText: 'Enter the agreed phrase or context...',
                          hintStyle: TextStyle(
                            color: AppTheme.ivory.withOpacity(0.5),
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
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Lighting
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'LIGHTING',
                      style: TextStyle(
                        color: AppTheme.teal,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.light_mode,
                          color: AppTheme.gold,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _lighting,
                            style: const TextStyle(
                              color: AppTheme.ivory,
                              fontSize: 18,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Background
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'BACKGROUND',
                      style: TextStyle(
                        color: AppTheme.teal,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.wallpaper,
                          color: AppTheme.teal,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _background,
                            style: const TextStyle(
                              color: AppTheme.ivory,
                              fontSize: 18,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Filename
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'FILE NAME',
                      style: TextStyle(
                        color: AppTheme.teal,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      filename,
                      style: const TextStyle(
                        color: AppTheme.ivory,
                        fontSize: 16,
                        fontFamily: 'monospace',
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Start Recording Button
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  text: 'START RECORDING',
                  onPressed: _startRecording,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
