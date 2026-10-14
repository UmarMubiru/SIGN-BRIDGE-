// Recording condition models for capture setup
// Matches Excel checklist values

enum LightingCondition {
  daylight('Daylight (natural window light)'),
  indoorArtificial('Indoor Artificial'),
  lowLight('Low Light'),
  bright('Bright Light');

  final String displayName;
  const LightingCondition(this.displayName);
}

enum BackgroundCondition {
  plainWallLight('Plain Wall - Light'),
  plainWallDark('Plain Wall - Dark'),
  texturedCluttered('Textured Cluttered'),
  outdoor('Outdoor');

  final String displayName;
  const BackgroundCondition(this.displayName);
}

enum DistanceCondition {
  close('Close (0.5-1m)'),
  medium('Medium (1-2m)'),
  far('Far (2-3m)');

  final String displayName;
  const DistanceCondition(this.displayName);
}

enum CameraPosition {
  front('Front (0°)'),
  left15('Left (15°)'),
  right15('Right (15°)'),
  left30('Left (30°)'),
  right30('Right (30°)'),
  left45('Left (45°)'),
  right45('Right (45°)'),
  aboveEye('Above Eye Level'),
  belowEye('Below Eye Level'),
  frontCloser('Front Closer');

  final String displayName;
  const CameraPosition(this.displayName);
}

class RecordingCondition {
  final LightingCondition lighting;
  final BackgroundCondition background;
  final DistanceCondition distance;
  final CameraPosition cameraPosition;
  final String? notes;

  RecordingCondition({
    required this.lighting,
    required this.background,
    required this.distance,
    required this.cameraPosition,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'lighting': lighting.name,
      'background': background.name,
      'distance': distance.name,
      'camera_position': cameraPosition.name,
      'notes': notes,
    };
  }

  factory RecordingCondition.fromJson(Map<String, dynamic> json) {
    return RecordingCondition(
      lighting: LightingCondition.values.firstWhere(
        (e) => e.name == json['lighting'],
        orElse: () => LightingCondition.daylight,
      ),
      background: BackgroundCondition.values.firstWhere(
        (e) => e.name == json['background'],
        orElse: () => BackgroundCondition.plainWallLight,
      ),
      distance: DistanceCondition.values.firstWhere(
        (e) => e.name == json['distance'],
        orElse: () => DistanceCondition.medium,
      ),
      cameraPosition: CameraPosition.values.firstWhere(
        (e) => e.name == json['camera_position'],
        orElse: () => CameraPosition.front,
      ),
      notes: json['notes'],
    );
  }

  RecordingCondition copyWith({
    LightingCondition? lighting,
    BackgroundCondition? background,
    DistanceCondition? distance,
    CameraPosition? cameraPosition,
    String? notes,
  }) {
    return RecordingCondition(
      lighting: lighting ?? this.lighting,
      background: background ?? this.background,
      distance: distance ?? this.distance,
      cameraPosition: cameraPosition ?? this.cameraPosition,
      notes: notes ?? this.notes,
    );
  }
}
