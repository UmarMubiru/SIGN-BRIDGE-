// Sign validation models for correctness validation

enum SignCorrectness {
  correct('Correct'),
  mostlyCorrect('Mostly Correct'),
  partiallyCorrect('Partially Correct'),
  incorrect('Incorrect'),
  unclear('Unclear');

  final String displayName;
  const SignCorrectness(this.displayName);
}

class SignValidation {
  final String recordingId;
  final String signId;
  final SignCorrectness correctness;
  final String? issues;
  final String? suggestions;
  final DateTime validatedAt;
  final String? validatorId;

  SignValidation({
    required this.recordingId,
    required this.signId,
    required this.correctness,
    this.issues,
    this.suggestions,
    required this.validatedAt,
    this.validatorId,
  });

  bool get isAcceptable {
    return correctness == SignCorrectness.correct || 
           correctness == SignCorrectness.mostlyCorrect;
  }

  Map<String, dynamic> toJson() {
    return {
      'recording_id': recordingId,
      'sign_id': signId,
      'correctness': correctness.name,
      'issues': issues,
      'suggestions': suggestions,
      'validated_at': validatedAt.toIso8601String(),
      'validator_id': validatorId,
    };
  }

  factory SignValidation.fromJson(Map<String, dynamic> json) {
    return SignValidation(
      recordingId: json['recording_id'],
      signId: json['sign_id'],
      correctness: SignCorrectness.values.firstWhere(
        (e) => e.name == json['correctness'],
        orElse: () => SignCorrectness.unclear,
      ),
      issues: json['issues'],
      suggestions: json['suggestions'],
      validatedAt: DateTime.parse(json['validated_at']),
      validatorId: json['validator_id'],
    );
  }

  SignValidation copyWith({
    String? recordingId,
    String? signId,
    SignCorrectness? correctness,
    String? issues,
    String? suggestions,
    DateTime? validatedAt,
    String? validatorId,
  }) {
    return SignValidation(
      recordingId: recordingId ?? this.recordingId,
      signId: signId ?? this.signId,
      correctness: correctness ?? this.correctness,
      issues: issues ?? this.issues,
      suggestions: suggestions ?? this.suggestions,
      validatedAt: validatedAt ?? this.validatedAt,
      validatorId: validatorId ?? this.validatorId,
    );
  }
}
