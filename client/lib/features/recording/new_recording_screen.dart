import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:camera/camera.dart';

import '../../app/theme/app_theme.dart';
import '../../app/widgets/app_button.dart';
import '../../core/services/camera_service.dart';
import '../../core/camera/camera_status.dart';
import '../../core/constants/recording_protocol.dart';
import '../../core/recording/recording_context.dart';
import '../../core/recording/recorded_video.dart';
import '../../core/video/video_asset.dart';

class NewRecordingScreen extends ConsumerStatefulWidget {
  final RecordingContext context;

  const NewRecordingScreen({super.key, required this.context});

  @override
  ConsumerState<NewRecordingScreen> createState() => _NewRecordingScreenState();
}

class _NewRecordingScreenState extends ConsumerState<NewRecordingScreen> {
  final CameraService _cameraService = CameraService();
  CameraDiagnostics? _diagnostics;
  bool _isRecording = false;
  Timer? _recordingTimer;
  int _recordingDuration = 0;
  RecordedVideo? _recordedVideo;
  final List<Map<String, dynamic>> _cueMarkers = [];
  final Stopwatch _recordingStopwatch = Stopwatch();

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    // First detect cameras
    final diagnostics = await _cameraService.detectCameras();

    if (!mounted) return;

    setState(() {
      _diagnostics = diagnostics;
    });

    // Prefer a connected external camera when available. On Android phones,
    // prefer the rear lens when no external camera is attached.
    if (diagnostics.availableCameras.isNotEmpty) {
      final preferredCamera = diagnostics.availableCameras.firstWhere(
        (camera) => camera.isExternal,
        orElse: () => defaultTargetPlatform == TargetPlatform.android
            ? diagnostics.availableCameras.firstWhere(
                (camera) =>
                    camera.direction?.toLowerCase().contains('back') ?? false,
                orElse: () => diagnostics.availableCameras.first,
              )
            : diagnostics.availableCameras.first,
      );
      final initDiagnostics = await _cameraService.initializeCamera(
        preferredCamera.id,
      );

      if (!mounted) return;

      setState(() {
        _diagnostics = initDiagnostics;
      });
    }
  }

  Future<void> _refreshCameras() async {
    setState(() {
      _diagnostics = null;
    });

    await _cameraService.dispose();
    await _initializeCamera();
  }

  Future<void> _selectCamera(String deviceId) async {
    if (_isRecording) return; // Cannot switch during recording

    final diagnostics = await _cameraService.initializeCamera(deviceId);

    if (!mounted) return;

    setState(() {
      _diagnostics = diagnostics;
    });
  }

  Future<void> _startRecording() async {
    if (_diagnostics?.status != CameraStatus.ready) return;

    try {
      await _cameraService.startRecording();

      if (!mounted) return;

      setState(() {
        _isRecording = true;
        _recordingDuration = 0;
        _cueMarkers
          ..clear()
          ..add(_markerForStep(0, 0));
      });
      _recordingStopwatch
        ..reset()
        ..start();

      _startCueTimer();
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

  void _startCueTimer() {
    _recordingTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted) {
        final elapsedMs = _recordingStopwatch.elapsedMilliseconds;
        setState(() {
          _recordingDuration = elapsedMs ~/ 1000;
        });
      }
    });
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    _recordingTimer?.cancel();
    var cameraStopped = false;

    try {
      final videoPath = await _cameraService.stopRecording();
      cameraStopped = true;
      _recordingStopwatch.stop();

      if (!mounted) return;

      setState(() {
        _isRecording = false;
      });

      // Get video file info
      final fileInfo = await _cameraService.getVideoFileInfo(videoPath);
      final duration = Duration(
        milliseconds: _recordingStopwatch.elapsedMilliseconds,
      );

      // Create video asset
      VideoAsset videoAsset;
      if (videoPath.startsWith('web_recording')) {
        videoAsset = VideoAsset.fromBytes(
          _cameraService.videoData!,
          duration,
          videoPath,
        );
      } else {
        videoAsset = VideoAsset.fromFile(
          videoPath,
          duration,
          fileInfo['size'] as int,
        );
      }

      // Create recorded video
      _recordedVideo = RecordedVideo(
        context: widget.context.copyWith(
          cueMarkers: List.unmodifiable(_cueMarkers),
        ),
        video: videoAsset,
        duration: duration,
        recordedAt: DateTime.now(),
      );

      // Navigate to review
      if (mounted) {
        final reviewLocation = Uri(
          path: '/review',
          queryParameters: {
            'sessionId': widget.context.sessionId,
            'signId': widget.context.signId,
          },
        ).toString();
        context.push(reviewLocation, extra: {'recordedVideo': _recordedVideo});
      }
    } catch (e) {
      if (mounted) {
        if (!cameraStopped) {
          _recordingStopwatch.start();
          _startCueTimer();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to stop recording: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Map<String, dynamic> _markerForStep(int step, int timestampMs) {
    final format = captureFormatById(widget.context.captureFormat)!;
    final target = switch (format.id) {
      'standard_frontal' => 'standard_sign',
      'repeat_frontal' => 'natural_repeat',
      'contextual_utterance' => 'contextual_signing',
      _ => 'legacy_capture',
    };
    return {
      'step_index': step,
      'instruction': format.guidanceSteps[step],
      'orientation_target': target,
      'elapsed_seconds': timestampMs / 1000,
      'timestamp_ms': timestampMs,
    };
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _cameraService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryBackground,
      appBar: AppBar(
        title: Text(_isRecording ? '● RECORDING' : '← RECORDING'),
        actions: [
          Text(
            widget.context.captureFormatLabel,
            style: const TextStyle(
              color: AppTheme.gold,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_diagnostics == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.gold),
      );
    }

    final diagnostics = _diagnostics!;

    if (diagnostics.isUnavailable) {
      return _buildUnavailableCamera(diagnostics);
    }

    if (diagnostics.hasError) {
      return _buildCameraError(diagnostics);
    }

    if (!diagnostics.isReady) {
      return _buildInitializing();
    }

    // Keep the same view structure for both ready and recording states
    // Only the overlays change, not the CameraPreview itself
    return _buildCameraView(diagnostics);
  }

  Widget _buildUnavailableCamera(CameraDiagnostics diagnostics) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.videocam_off, color: AppTheme.error, size: 64),
            const SizedBox(height: 16),
            const Text(
              'NO CAMERA DETECTED',
              style: TextStyle(
                color: AppTheme.ivory,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              diagnostics.errorMessage ?? 'No camera device is available',
              style: const TextStyle(color: AppTheme.ivory),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            const Text('Check:', style: TextStyle(color: AppTheme.ivory)),
            const Text('• USB webcam connection'),
            const Text('• Browser permission'),
            const Text('• Camera privacy settings'),
            const SizedBox(height: 24),
            AppButton(text: 'REFRESH', onPressed: _refreshCameras),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraError(CameraDiagnostics diagnostics) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppTheme.error, size: 64),
            const SizedBox(height: 16),
            const Text(
              'CAMERA ERROR',
              style: TextStyle(
                color: AppTheme.ivory,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              diagnostics.errorMessage ?? 'An error occurred',
              style: const TextStyle(color: AppTheme.ivory),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            AppButton(text: 'TRY AGAIN', onPressed: _refreshCameras),
          ],
        ),
      ),
    );
  }

  Widget _buildInitializing() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppTheme.gold),
          SizedBox(height: 16),
          Text(
            'Initializing camera...',
            style: TextStyle(color: AppTheme.ivory),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraView(CameraDiagnostics diagnostics) {
    return Column(
      children: [
        // Recording metadata
        _buildMetadata(),

        // Camera preview with recording overlay
        Expanded(
          child: Stack(
            children: [
              // Camera preview - stays mounted continuously
              _cameraService.controller != null
                  ? CameraPreview(_cameraService.controller!)
                  : const Center(child: Text('Camera preview not available')),

              if (!_isRecording) _buildFramingReminder(),
              // Recording timer overlay (only during recording)
              if (_isRecording)
                Positioned(
                  top: 20,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _formatDuration(_recordingDuration),
                        style: const TextStyle(
                          color: AppTheme.ivory,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Camera controls or stop button
        _buildControls(diagnostics),
      ],
    );
  }

  Widget _buildControls(CameraDiagnostics diagnostics) {
    if (_isRecording) {
      // Stop button during recording
      return Padding(
        padding: const EdgeInsets.all(24),
        child: ElevatedButton(
          onPressed: _stopRecording,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.error,
            foregroundColor: AppTheme.ivory,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          ),
          child: const Text('■ STOP'),
        ),
      );
    } else {
      // Camera controls when ready
      return _buildCameraControls(diagnostics);
    }
  }

  Widget _buildMetadata() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryBackground,
        border: Border(
          bottom: BorderSide(color: AppTheme.gold.withValues(alpha: 0.3)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.context.signLabel,
            style: const TextStyle(
              color: AppTheme.ivory,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                widget.context.signerId,
                style: const TextStyle(color: AppTheme.ivory),
              ),
              const Text(' • ', style: TextStyle(color: AppTheme.ivory)),
              Text(
                widget.context.captureFormatLabel,
                style: const TextStyle(color: AppTheme.ivory),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFramingReminder() {
    return Positioned(
      top: 12,
      left: 12,
      right: 12,
      child: IgnorePointer(
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Before recording: frame your face, both hands, and full signing space',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.ivory,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCameraControls(CameraDiagnostics diagnostics) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryBackground,
        border: Border(
          top: BorderSide(color: AppTheme.gold.withValues(alpha: 0.3)),
        ),
      ),
      child: Column(
        children: [
          // Camera selection
          Row(
            children: [
              const Text(
                'Capture camera',
                style: TextStyle(color: AppTheme.ivory),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButton<String>(
                  value: diagnostics.selectedCamera?.id,
                  items: diagnostics.availableCameras.map((camera) {
                    return DropdownMenuItem(
                      value: camera.id,
                      child: Text(
                        camera.isExternal
                            ? 'External • ${camera.name}'
                            : camera.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      _selectCamera(value);
                    }
                  },
                  dropdownColor: AppTheme.primaryBackground,
                  style: const TextStyle(color: AppTheme.ivory),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _refreshCameras,
                color: AppTheme.gold,
              ),
            ],
          ),

          const SizedBox(height: 4),
          const Text(
            'To use a phone as this PC’s camera, connect it in USB webcam mode or use a phone webcam app, then tap refresh. On Android, choose the rear or connected USB camera here.',
            style: TextStyle(color: AppTheme.mutedText, fontSize: 12),
          ),

          const SizedBox(height: 12),

          // Camera diagnostics
          Row(
            children: [
              const Icon(Icons.check_circle, color: AppTheme.success, size: 16),
              const SizedBox(width: 4),
              const Text(
                'Camera ready',
                style: TextStyle(color: AppTheme.ivory),
              ),
              const SizedBox(width: 16),
              if (diagnostics.resolution != null) ...[
                const Icon(Icons.hd, color: AppTheme.gold, size: 16),
                const SizedBox(width: 4),
                Text(
                  diagnostics.resolution!,
                  style: const TextStyle(color: AppTheme.ivory),
                ),
              ],
            ],
          ),

          const SizedBox(height: 16),

          // Record button
          ElevatedButton(
            onPressed: _startRecording,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: AppTheme.ivory,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
            child: const Text('● RECORD'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}
