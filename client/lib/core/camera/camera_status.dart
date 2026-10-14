/// Camera states for the recording workflow
enum CameraStatus {
  /// Camera service is idle, not yet initialized
  idle,
  
  /// Detecting available cameras
  detecting,
  
  /// Camera permission required from user
  permissionRequired,
  
  /// Initializing selected camera
  initializing,
  
  /// Camera ready to record
  ready,
  
  /// Currently recording
  recording,
  
  /// Stopping recording
  stopping,
  
  /// Camera error occurred
  error,
  
  /// No camera available
  unavailable,
}

/// Camera device abstraction - cross-platform representation
class CameraDevice {
  final String id;
  final String name;
  final String? direction;
  final bool isExternal;

  const CameraDevice({
    required this.id,
    required this.name,
    this.direction,
    required this.isExternal,
  });

  @override
  String toString() => 'CameraDevice(id: $id, name: $name, isExternal: $isExternal)';
}

/// Camera diagnostics information
class CameraDiagnostics {
  final CameraStatus status;
  final String? errorMessage;
  final CameraDevice? selectedCamera;
  final List<CameraDevice> availableCameras;
  final String? resolution;
  final String? orientation;
  final bool hasPermission;

  const CameraDiagnostics({
    required this.status,
    this.errorMessage,
    this.selectedCamera,
    this.availableCameras = const [],
    this.resolution,
    this.orientation,
    this.hasPermission = false,
  });

  bool get isReady => status == CameraStatus.ready;
  bool get hasError => status == CameraStatus.error;
  bool get isUnavailable => status == CameraStatus.unavailable;
  bool get needsPermission => status == CameraStatus.permissionRequired;

  @override
  String toString() {
    return 'CameraDiagnostics(status: $status, cameras: ${availableCameras.length}, selected: ${selectedCamera?.name})';
  }
}
