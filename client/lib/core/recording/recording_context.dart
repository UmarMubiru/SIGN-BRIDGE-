/// Metadata shared by camera, review and upload screens for a single video.
class RecordingContext {
  final String sessionId;
  final String signerId;
  final String signId;
  final String signLabel;
  final String captureFormat;
  final String captureFormatLabel;
  final String lightingCondition;
  final String background;
  final String fileName;
  final String contextPrompt;
  final List<Map<String, dynamic>> cueMarkers;

  const RecordingContext({
    required this.sessionId,
    required this.signerId,
    required this.signId,
    required this.signLabel,
    required this.captureFormat,
    required this.captureFormatLabel,
    required this.lightingCondition,
    required this.background,
    required this.fileName,
    this.contextPrompt = '',
    this.cueMarkers = const [],
  });

  RecordingContext copyWith({
    String? sessionId,
    String? signerId,
    String? signId,
    String? signLabel,
    String? captureFormat,
    String? captureFormatLabel,
    String? lightingCondition,
    String? background,
    String? fileName,
    String? contextPrompt,
    List<Map<String, dynamic>>? cueMarkers,
  }) => RecordingContext(
    sessionId: sessionId ?? this.sessionId,
    signerId: signerId ?? this.signerId,
    signId: signId ?? this.signId,
    signLabel: signLabel ?? this.signLabel,
    captureFormat: captureFormat ?? this.captureFormat,
    captureFormatLabel: captureFormatLabel ?? this.captureFormatLabel,
    lightingCondition: lightingCondition ?? this.lightingCondition,
    background: background ?? this.background,
    fileName: fileName ?? this.fileName,
    contextPrompt: contextPrompt ?? this.contextPrompt,
    cueMarkers: cueMarkers ?? this.cueMarkers,
  );

  @override
  String toString() =>
      'RecordingContext(signer: $signerId, sign: $signLabel, format: $captureFormat)';

  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'signerId': signerId,
    'signId': signId,
    'signLabel': signLabel,
    'captureFormat': captureFormat,
    'captureFormatLabel': captureFormatLabel,
    'lightingCondition': lightingCondition,
    'background': background,
    'fileName': fileName,
    'contextPrompt': contextPrompt,
    'cueMarkers': cueMarkers,
  };

  factory RecordingContext.fromJson(Map<String, dynamic> json) =>
      RecordingContext(
        sessionId: json['sessionId'] as String,
        signerId: json['signerId'] as String,
        signId: json['signId'] as String,
        signLabel: json['signLabel'] as String,
        captureFormat: json['captureFormat'] as String,
        captureFormatLabel: json['captureFormatLabel'] as String,
        lightingCondition: json['lightingCondition'] as String,
        background: json['background'] as String,
        fileName: json['fileName'] as String,
        contextPrompt: json['contextPrompt'] as String? ?? '',
        cueMarkers: (json['cueMarkers'] as List<dynamic>? ?? const [])
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList(),
      );
}
