import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:camera/camera.dart';

import '../../core/services/camera_service.dart';
import '../../core/api_client.dart';
import '../../app/theme/app_theme.dart';
import '../../app/widgets/navigation_back_button.dart';
import '../../app/widgets/app_button.dart';

class RecordingScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? data;

  const RecordingScreen({super.key, required this.data});

  @override
  ConsumerState<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends ConsumerState<RecordingScreen> {
  final CameraService _cameraService = CameraService();
  final _apiClient = ApiClient();
  bool _isLoading = true;
  bool _isRecording = false;
  String? _errorMessage;
  int _recordingDuration = 0;
  Timer? _timer;

  // Recording metadata
  String _sessionId = '';
  String _signId = '';
  int _repetition = 1;
  String _cameraAngle = '';
  String _lighting = '';
  String _background = '';
  String _signerId = '';
  String _signLabel = '';
  String _fileName = '';

  @override
  void initState() {
    super.initState();
    _loadRecordingContext();

    // The old recording screen is deprecated - use NewRecordingScreen instead
    // This is just a placeholder that shows an error
    setState(() {
      _errorMessage =
          'This screen is deprecated. Please use the new recording flow.';
      _isLoading = false;
    });
  }

  void _loadRecordingContext() {
    final data = widget.data;

    if (data == null) {
      setState(() {
        _errorMessage = 'Recording information was not provided.';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _sessionId = data['sessionId']?.toString() ?? '';
      _signId = data['signId']?.toString() ?? '';
      _repetition = data['repetition'] is int
          ? data['repetition'] as int
          : int.tryParse(data['repetition']?.toString() ?? '') ?? 1;
      _cameraAngle = data['cameraAngle']?.toString() ?? '';
      _lighting = data['lighting']?.toString() ?? '';
      _background = data['background']?.toString() ?? '';
      _signerId = data['signerId']?.toString() ?? '';
      _signLabel = data['signLabel']?.toString() ?? '';
      _fileName = data['fileName']?.toString() ?? '';
    });
  }

  void _startRecording() async {
    try {
      await _cameraService.startRecording();
      if (mounted) {
        setState(() {
          _isRecording = true;
          _recordingDuration = 0;
        });
        _startTimer();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start recording: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  void _stopRecording() async {
    _timer?.cancel();

    try {
      final videoPath = await _cameraService.stopRecording();

      if (mounted) {
        setState(() {
          _isRecording = false;
        });

        // Navigate to review screen with recording data
        context.push(
          '/review',
          extra: {
            'videoPath': videoPath,
            'sessionId': _sessionId,
            'signId': _signId,
            'repetition': _repetition,
            'cameraAngle': _cameraAngle,
            'lighting': _lighting,
            'background': _background,
            'signerId': _signerId,
            'signLabel': _signLabel,
            'fileName': _fileName,
            'duration': _recordingDuration,
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to stop recording: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _recordingDuration++;
        });
      }
    });
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cameraService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryBackground,
      appBar: AppBar(
        leading: NavigationBackButton(enabled: !_isRecording),
        title: const Text('Recording'),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.gold),
              )
            : _errorMessage != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
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
                        _errorMessage!,
                        style: const TextStyle(color: AppTheme.ivory),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      AppButton(
                        text: 'Go Back',
                        onPressed: () => context.pop(),
                      ),
                    ],
                  ),
                ),
              )
            : Column(
                children: [
                  // Recording Info Overlay
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.black.withOpacity(0.7),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Icon(
                              Icons.person,
                              color: AppTheme.gold,
                              size: 16,
                            ),
                            Text(
                              'Signer: $_signerId',
                              style: const TextStyle(
                                color: AppTheme.ivory,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Icon(
                              Icons.text_fields,
                              color: AppTheme.teal,
                              size: 16,
                            ),
                            Text(
                              'Sign: $_signLabel',
                              style: const TextStyle(
                                color: AppTheme.ivory,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Icon(
                              Icons.format_list_numbered,
                              color: AppTheme.gold,
                              size: 16,
                            ),
                            Text(
                              'Legacy recording screen',
                              style: const TextStyle(
                                color: AppTheme.ivory,
                                fontSize: 12,
                              ),
                            ),
                            const Icon(
                              Icons.camera_alt,
                              color: AppTheme.teal,
                              size: 16,
                            ),
                            Text(
                              'Camera: $_cameraAngle',
                              style: const TextStyle(
                                color: AppTheme.ivory,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Icon(
                              Icons.light_mode,
                              color: AppTheme.gold,
                              size: 16,
                            ),
                            Text(
                              'Lighting: $_lighting',
                              style: const TextStyle(
                                color: AppTheme.ivory,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Icon(
                              Icons.wallpaper,
                              color: AppTheme.teal,
                              size: 16,
                            ),
                            Text(
                              'Background: $_background',
                              style: const TextStyle(
                                color: AppTheme.ivory,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Camera Preview
                  Expanded(
                    child: _cameraService.controller != null
                        ? CameraPreview(_cameraService.controller!)
                        : const Center(
                            child: Text(
                              'Camera not available',
                              style: TextStyle(color: AppTheme.ivory),
                            ),
                          ),
                  ),

                  // Recording Status
                  if (_isRecording)
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: AppTheme.error.withOpacity(0.3),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.fiber_manual_record,
                            color: AppTheme.error,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'RECORDING',
                            style: const TextStyle(
                              color: AppTheme.error,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            _formatDuration(_recordingDuration),
                            style: const TextStyle(
                              color: AppTheme.error,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Controls
                  Container(
                    padding: const EdgeInsets.all(24),
                    color: AppTheme.secondarySurface,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (!_isRecording)
                          AppButton(text: 'RECORD', onPressed: _startRecording)
                        else
                          AppButton(text: 'STOP', onPressed: _stopRecording),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
