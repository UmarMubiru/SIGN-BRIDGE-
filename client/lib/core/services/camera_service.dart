import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'dart:io';
import 'dart:typed_data';

import '../camera/camera_status.dart';

class CameraService {
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
      throw Exception('Camera not ready. Status: $_status');
    }

    if (_controller == null || !_controller!.value.isInitialized) {
      throw Exception('Camera not initialized');
    }

    if (_isRecording) {
      throw Exception('Already recording');
    }

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
      _status = CameraStatus.error;
      _errorMessage = 'Failed to start recording: $e';
      throw Exception('Failed to start recording: $e');
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
        print('Video data captured: ${_videoData?.length} bytes');
        _currentVideoPath =
            'web_recording_${DateTime.now().millisecondsSinceEpoch}.mp4';
        _status = CameraStatus.ready;
        return _currentVideoPath!;
      } else {
        // Mobile/Desktop: Return file path
        _currentVideoPath = file.path;
        _status = CameraStatus.ready;
        return file.path;
      }
    } catch (e) {
      _status = CameraStatus.error;
      _errorMessage = 'Failed to stop recording: $e';
      _isRecording = false;
      throw Exception('Failed to stop recording: $e');
    }
  }

  /// Dispose camera service
  Future<void> dispose() async {
    await _disposeController();
    _cameras = null;
    _availableDevices = [];
    _videoData = null;
    _status = CameraStatus.idle;
    _errorMessage = null;
  }

  Future<void> _disposeController() async {
    if (_controller != null) {
      if (_isRecording) {
        try {
          await _controller!.stopVideoRecording();
        } catch (e) {
          debugPrint('Error stopping recording during dispose: $e');
        }
        _isRecording = false;
      }
      await _controller!.dispose();
      _controller = null;
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
