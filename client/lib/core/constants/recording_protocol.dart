/// Three complementary video samples captured once per sign.
class CaptureFormat {
  final String id;
  final String label;
  final String filenameToken;
  final String description;
  final List<String> guidanceSteps;

  const CaptureFormat({
    required this.id,
    required this.label,
    required this.filenameToken,
    required this.description,
    required this.guidanceSteps,
  });
}

const List<CaptureFormat> CAPTURE_FORMATS = [
  CaptureFormat(
    id: 'standard_frontal',
    label: 'Standard Frontal Sign',
    filenameToken: 'standard',
    description: 'Record one clear, isolated sign while facing the camera naturally.',
    guidanceSteps: [
      'Face the camera comfortably. Keep your face, both hands, upper body, and full signing space in frame.',
      'Perform the sign once at your natural pace, with its natural facial and body movements.',
      'Return to a comfortable rest position and hold briefly.',
    ],
  ),
  CaptureFormat(
    id: 'repeat_frontal',
    label: 'Natural Repeat',
    filenameToken: 'repeat',
    description: 'Record a second independent, natural performance from the same frontal camera position.',
    guidanceSteps: [
      'Keep the same frontal framing: face, both hands, upper body, and full signing space visible.',
      'Perform the same sign once more at your natural pace. Do not exaggerate or deliberately slow it down.',
      'Return to a comfortable rest position and hold briefly.',
    ],
  ),
  CaptureFormat(
    id: 'contextual_utterance',
    label: 'Sign in Context',
    filenameToken: 'context',
    description: 'Use the sign naturally in a short phrase or exchange approved by a fluent USL signer.',
    guidanceSteps: [
      'Keep the same frontal framing and sign naturally in the agreed short phrase or exchange.',
      'Use natural facial expression, body movement, and signing space. Do not turn to demonstrate camera angles.',
      'Pause briefly before and after the phrase.',
    ],
  ),
];

// Preserve readable labels for recordings made under the previous protocol.
const Map<String, String> _legacyCaptureFormatLabels = {
  'horizontal_sweep': 'Legacy Horizontal Sweep',
  'vertical_sweep': 'Legacy Vertical Sweep',
  'natural_performance': 'Legacy Natural Performance',
};

CaptureFormat? captureFormatById(String? id) {
  for (final format in CAPTURE_FORMATS) {
    if (format.id == id) return format;
  }
  return null;
}

String captureFormatLabel(String? id) =>
    captureFormatById(id)?.label ?? _legacyCaptureFormatLabels[id] ?? 'Legacy recording';

String generateRecordingFilename(
  String signerId,
  String signLabel,
  String formatId,
) {
  final label = signLabel.trim().replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
  final token = captureFormatById(formatId)?.filenameToken ?? formatId;
  return '${signerId}_${label}_$token.mp4';
}

enum LightingCondition {
  daylight('Daylight'),
  indoorArtificial('Indoor Artificial'),
  lowLight('Low Light / Dim');

  final String displayName;
  const LightingCondition(this.displayName);
}

enum BackgroundCondition {
  plainWallLight('Plain Wall — Light'),
  plainWallDark('Plain Wall — Dark'),
  texturedCluttered('Textured / Cluttered Background');

  final String displayName;
  const BackgroundCondition(this.displayName);
}

enum RecordingStatus {
  pendingReview('pending_review'),
  uploading('uploading'),
  uploaded('uploaded'),
  failed('failed'),
  rejected('rejected');

  final String value;
  const RecordingStatus(this.value);
}

enum ValidationStatus {
  pending('pending'),
  approved('approved'),
  rejected('rejected');

  final String value;
  const ValidationStatus(this.value);
}
