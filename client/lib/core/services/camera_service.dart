import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'dart:io';

import '../camera/camera_status.dart';
import 'windows_recording_file_promoter.dart';

class CameraService {
  static Future<void> _releaseBarrier = Future<void>.value();

  CameraController? _controller;
  List<CameraDescription>? _cameras;
  List<CameraDevice> _availableDevices = [];
  int _currentCameraIndex = 0;
  bool _isRecording = false;
  String? _currentVideoPath;
  Uint8List? _videoData;
  CameraStatus _status = CameraStatus.idle;
  String? _errorMessage;

  // Getters
  CameraStatus get status => _status;
  bool get isRecording => _isRecording;
  bool get isInitialized =>
      _controller != null && _controller!.value.isInitialized;
  CameraController? get controller => _controller;
  String? get currentVideoPath => _currentVideoPath;
  Uint8List? get videoData => _videoData;
  String? get errorMessage => _errorMessage;
  List<CameraDevice> get availableDevices => _availableDevices;
  CameraDevice? get selectedDevice => _availableDevices.isNotEmpty
      ? _availableDevices[_currentCameraIndex]
      : null;

  /// Get video bytes for upload
  Uint8List? getVideoBytes() {
    return _videoData;
  }

  /// Detect available cameras
  Future<CameraDiagnostics> detectCameras() async {
    await _releaseBarrier;
    _status = CameraStatus.detecting;
    _errorMessage = null;

    try {
      _cameras = await availableCameras();

      if (_cameras == null || _cameras!.isEmpty) {
        _status = CameraStatus.unavailable;
        return CameraDiagnostics(
          status: _status,
          errorMessage: 'No camera devices found',
          availableCameras: [],
        );
      }

      // Convert to CameraDevice abstraction
      _availableDevices = _cameras!.asMap().entries.map((entry) {
        final index = entry.key;
        final camera = entry.value;
        return CameraDevice(
          id: index.toString(),
          name: camera.name,
          direction: camera.lensDirection.toString(),
          isExternal: _nameToExternal(camera.name),
        );
      }).toList();

      _status = CameraStatus.permissionRequired;

      return CameraDiagnostics(
        status: _status,
        availableCameras: _availableDevices,
      );
    } catch (e) {
      _status = CameraStatus.error;
      _errorMessage = 'Failed to detect cameras: $e';
      return CameraDiagnostics(
        status: _status,
        errorMessage: _errorMessage,
        availableCameras: [],
      );
    }
  }

  /// Initialize a specific camera by device ID
  Future<CameraDiagnostics> initializeCamera(String deviceId) async {
    await _releaseBarrier;
    if (_availableDevices.isEmpty) {
      _status = CameraStatus.unavailable;
      return CameraDiagnostics(
        status: _status,
        errorMessage:
            'No cameras available. Please connect a camera and refresh.',
        availableCameras: [],
      );
    }

    final deviceIndex = _availableDevices.indexWhere((d) => d.id == deviceId);
    if (deviceIndex < 0) {
      _status = CameraStatus.error;
      _errorMessage = 'Camera device not found';
      return CameraDiagnostics(
        status: _status,
        errorMessage: _errorMessage,
        availableCameras: _availableDevices,
        selectedCamera: _availableDevices[0],
      );
    }

    _currentCameraIndex = deviceIndex;
    _status = CameraStatus.initializing;
    _errorMessage = null;

    try {
      await _disposeController();

      _controller = CameraController(
        _cameras![deviceIndex],
        ResolutionPreset.veryHigh,
        enableAudio: true,
      );

      await _controller!.initialize();

      // Get camera resolution (if available)
      String resolutionStr = '1280x720'; // Default
      try {
        final size = _controller!.value.previewSize;
        if (size != null) {
          resolutionStr = '${size.width.toInt()}x${size.height.toInt()}';
        }
      } catch (e) {
        // Fall back to default
      }

      _status = CameraStatus.ready;

      return CameraDiagnostics(
        status: _status,
        selectedCamera: _availableDevices[deviceIndex],
        availableCameras: _availableDevices,
        resolution: resolutionStr,
        orientation: 'Landscape',
        hasPermission: true,
      );
    } catch (e) {
      _status = CameraStatus.error;
      _errorMessage = 'Failed to initialize camera: $e';
      return CameraDiagnostics(
        status: _status,
        errorMessage: _errorMessage,
        availableCameras: _availableDevices,
        selectedCamera: _availableDevices[deviceIndex],
      );
    }
  }

  /// Start recording
  Future<String> startRecording() async {
    if (_status != CameraStatus.ready) {
      throw CameraException(
        'camera_not_ready',
        _errorMessage ?? 'Camera not ready. Status: $_status',
      );
    }

    if (_controller == null || !_controller!.value.isInitialized) {
      throw Exception('Camera not initialized');
    }

    if (_isRecording) {
      throw Exception('Already recording');
    }

    _currentVideoPath = null;
    _videoData = null;
    _errorMessage = null;
    _isRecording = false;
    try {
      _status = CameraStatus.recording;

      if (kIsWeb) {
        // Web: Recording will be handled by browser
        await _controller!.startVideoRecording();
        _isRecording = true;
        return 'web_recording_${DateTime.now().millisecondsSinceEpoch}';
      } else {
        // Mobile/Desktop: Save to file system
        final directory = await getApplicationDocumentsDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final path = p.join(directory.path, 'recordings');

        // Create recordings directory if it doesn't exist
        final recordingsDir = Directory(path);
        if (!await recordingsDir.exists()) {
          await recordingsDir.create(recursive: true);
        }

        final filePath = p.join(path, 'recording_$timestamp.mp4');

        await _controller!.startVideoRecording();
        _isRecording = true;
        _currentVideoPath = filePath;

        return filePath;
      }
    } catch (e) {
      _errorMessage = 'Failed to start recording: $e';
      // Keep the initialized preview available for a retry. The original
      // CameraException is useful here: Windows can initialize a preview but
      // still reject the selected video/audio capture format at record start.
      _status = isInitialized ? CameraStatus.ready : CameraStatus.error;
      if (e is CameraException) rethrow;
      throw CameraException('start_recording_failed', _errorMessage);
    }
  }

  /// Stop recording
  Future<String> stopRecording() async {
    if (_status != CameraStatus.recording) {
      throw Exception('Not recording. Status: $_status');
    }

    try {
      _status = CameraStatus.stopping;

      final file = await _controller!.stopVideoRecording();
      _isRecording = false;

      if (kIsWeb) {
        // Web: Store video data in memory
        _videoData = await file.readAsBytes();
        debugPrint('Video data captured: ${_videoData?.length} bytes');
        _currentVideoPath =
            'web_recording_${DateTime.now().millisecondsSinceEpoch}.mp4';
        _status = CameraStatus.ready;
        return _currentVideoPath!;
      } else {
        // Mobile/Desktop: Return file path
        if (Platform.isWindows) {
          // camera_windows records to a temporary path by default. Keep a
          // durable copy under the app's Documents folder for local-first use.
          final destinationPath = _currentVideoPath;
          if (destinationPath == null) {
            throw StateError('Recording destination was not prepared');
          }

          final source = File(file.path);
          if (p.normalize(source.path) != p.normalize(destinationPath)) {
            try {
              await const WindowsRecordingFilePromoter().promote(
                source: source,
                destinationPath: destinationPath,
              );
            } catch (_) {
              // Preserve the plugin output and expose its path for recovery.
              _currentVideoPath = source.path;
              rethrow;
            }
          } else if (!await source.exists() || await source.length() == 0) {
            throw FileSystemException(
              'Camera produced an empty video',
              source.path,
            );
          }
          _currentVideoPath = destinationPath;
        } else {
          _currentVideoPath = file.path;
        }
        _status = CameraStatus.ready;
        return _currentVideoPath!;
      }
    } catch (e) {
      _status = CameraStatus.error;
      _errorMessage = _currentVideoPath == null
          ? 'Failed to stop recording: $e'
          : 'Failed to finalize recording: $e. The camera output remains at $_currentVideoPath.';
      _isRecording = false;
      throw CameraException('stop_recording_failed', _errorMessage!);
    }
  }

  /// Dispose camera service
  Future<void> dispose() async {
    final release = _releaseBarrier.then((_) => _disposeController());
    _releaseBarrier = release.catchError((Object _) {});
    await release;
    _cameras = null;
    _availableDevices = [];
    _videoData = null;
    _status = CameraStatus.idle;
    _errorMessage = null;
  }

  Future<void> _disposeController() async {
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      if (_isRecording) {
        try {
          await controller.stopVideoRecording();
        } catch (e) {
          debugPrint('Error stopping recording during dispose: $e');
        }
        _isRecording = false;
      }
      _isRecording = false;
      await controller.dispose();
    }
  }

  /// Helper: determine if camera name suggests external/USB
  bool _nameToExternal(String name) {
    final lowerName = name.toLowerCase();
    return lowerName.contains('usb') ||
        lowerName.contains('webcam') ||
        lowerName.contains('external') ||
        lowerName.contains('logitech') ||
        lowerName.contains('microsoft') ||
        lowerName.contains('lifecam') ||
        lowerName.contains('android') ||
        lowerName.contains('phone') ||
        lowerName.contains('droidcam') ||
        lowerName.contains('iriun') ||
        lowerName.contains('camo') ||
        lowerName.contains('epoccam') ||
        lowerName.contains('virtual camera');
  }

  /// Get video file info
  Future<Map<String, dynamic>> getVideoFileInfo(String path) async {
    if (kIsWeb) {
      // Web: Return info from memory data
      return {
        'path': path,
        'size': _videoData?.length ?? 0,
        'modified': DateTime.now(),
      };
    } else {
      // Mobile/Desktop: Get file stats
      final file = File(path);
      if (!await file.exists()) {
        throw Exception('Video file does not exist');
      }

      final stat = await file.stat();
      return {'path': path, 'size': stat.size, 'modified': stat.modified};
    }
  }

  /// Delete video file
  Future<void> deleteVideo(String path) async {
    if (kIsWeb) {
      // Web: Clear memory data
      _videoData = null;
    } else {
      // Mobile/Desktop: Delete file
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }
}
