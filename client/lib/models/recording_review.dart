// Recording review models for technical quality validation

enum TechnicalQuality {
  excellent('Excellent'),
  good('Good'),
  acceptable('Acceptable'),
  poor('Poor'),
  unusable('Unusable');

  final String displayName;
  const TechnicalQuality(this.displayName);
}

class TechnicalReviewItem {
  final String id;
  final String label;
  final String description;
  bool passed;
  String? notes;

  TechnicalReviewItem({
    required this.id,
    required this.label,
    required this.description,
    this.passed = false,
    this.notes,
  });

  TechnicalReviewItem copyWith({
    String? id,
    String? label,
    String? description,
    bool? passed,
    String? notes,
  }) {
    return TechnicalReviewItem(
      id: id ?? this.id,
      label: label ?? this.label,
      description: description ?? this.description,
      passed: passed ?? this.passed,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'description': description,
      'passed': passed,
      'notes': notes,
    };
  }

  factory TechnicalReviewItem.fromJson(Map<String, dynamic> json) {
    return TechnicalReviewItem(
      id: json['id'],
      label: json['label'],
      description: json['description'],
      passed: json['passed'],
      notes: json['notes'],
    );
  }
}

class RecordingReview {
  final String recordingId;
  final List<TechnicalReviewItem> checklist;
  final TechnicalQuality overallQuality;
  final String? reviewerNotes;
  final DateTime reviewedAt;
  final String? reviewerId;

  RecordingReview({
    required this.recordingId,
    required this.checklist,
    required this.overallQuality,
    this.reviewerNotes,
    required this.reviewedAt,
    this.reviewerId,
  });

  // Default technical quality checklist
  static List<TechnicalReviewItem> defaultChecklist() {
    return [
      TechnicalReviewItem(
        id: 'lighting',
        label: 'Lighting',
        description: 'Adequate lighting, no glare or shadows',
      ),
      TechnicalReviewItem(
        id: 'background',
        label: 'Background',
        description: 'Clean, uncluttered background',
      ),
      TechnicalReviewItem(
        id: 'framing',
        label: 'Framing',
        description: 'Proper framing of signer and hands',
      ),
      TechnicalReviewItem(
        id: 'stability',
        label: 'Stability',
        description: 'Camera stable, no shaking',
      ),
      TechnicalReviewItem(
        id: 'focus',
        label: 'Focus',
        description: 'Clear focus on hands and face',
      ),
      TechnicalReviewItem(
        id: 'audio',
        label: 'Audio',
        description: 'Clear audio if applicable',
      ),
      TechnicalReviewItem(
        id: 'duration',
        label: 'Duration',
        description: 'Appropriate recording duration',
      ),
      TechnicalReviewItem(
        id: 'clarity',
        label: 'Clarity',
        description: 'Sign movements clearly visible',
      ),
    ];
  }

  bool get isAcceptable {
    final failedItems = checklist.where((item) => !item.passed).length;
    return failedItems <= 2 && overallQuality != TechnicalQuality.unusable;
  }

  Map<String, dynamic> toJson() {
    return {
      'recording_id': recordingId,
      'checklist': checklist.map((item) => item.toJson()).toList(),
      'overall_quality': overallQuality.name,
      'reviewer_notes': reviewerNotes,
      'reviewed_at': reviewedAt.toIso8601String(),
      'reviewer_id': reviewerId,
    };
  }

  factory RecordingReview.fromJson(Map<String, dynamic> json) {
    return RecordingReview(
      recordingId: json['recording_id'],
      checklist: (json['checklist'] as List)
          .map((item) => TechnicalReviewItem.fromJson(item))
          .toList(),
      overallQuality: TechnicalQuality.values.firstWhere(
        (e) => e.name == json['overall_quality'],
        orElse: () => TechnicalQuality.acceptable,
      ),
      reviewerNotes: json['reviewer_notes'],
      reviewedAt: DateTime.parse(json['reviewed_at']),
      reviewerId: json['reviewer_id'],
    );
  }

  RecordingReview copyWith({
    String? recordingId,
    List<TechnicalReviewItem>? checklist,
    TechnicalQuality? overallQuality,
    String? reviewerNotes,
    DateTime? reviewedAt,
    String? reviewerId,
  }) {
    return RecordingReview(
      recordingId: recordingId ?? this.recordingId,
      checklist: checklist ?? this.checklist,
      overallQuality: overallQuality ?? this.overallQuality,
      reviewerNotes: reviewerNotes ?? this.reviewerNotes,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewerId: reviewerId ?? this.reviewerId,
    );
  }
}
