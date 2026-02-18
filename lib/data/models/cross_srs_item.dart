// Cross SRS item model for spaced repetition of cross training scrambles

import 'package:cubelab/data/models/srs_state.dart';

class CrossSRSItem {
  final String id;
  final String userId;
  final String scramble;
  final int difficulty;
  final String crossColor;
  final int pairsAttempting;
  final SRSState srsState;
  final DateTime? lastReviewedAt;
  final int totalReviews;
  final DateTime createdAt;

  const CrossSRSItem({
    required this.id,
    required this.userId,
    required this.scramble,
    required this.difficulty,
    this.crossColor = 'white',
    required this.pairsAttempting,
    required this.srsState,
    this.lastReviewedAt,
    this.totalReviews = 0,
    required this.createdAt,
  });

  factory CrossSRSItem.fromJson(Map<String, dynamic> json) {
    return CrossSRSItem(
      id: json['id'] as String,
      userId: json['userId'] as String,
      scramble: json['scramble'] as String,
      difficulty: json['difficulty'] as int,
      crossColor: json['crossColor'] as String? ?? 'white',
      pairsAttempting: json['pairsAttempting'] as int,
      srsState: SRSState.fromJson(json['srsState'] as Map<String, dynamic>),
      lastReviewedAt: json['lastReviewedAt'] != null
          ? DateTime.parse(json['lastReviewedAt'] as String)
          : null,
      totalReviews: json['totalReviews'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'scramble': scramble,
      'difficulty': difficulty,
      'crossColor': crossColor,
      'pairsAttempting': pairsAttempting,
      'srsState': srsState.toJson(),
      'lastReviewedAt': lastReviewedAt?.toIso8601String(),
      'totalReviews': totalReviews,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory CrossSRSItem.fromSupabase(Map<String, dynamic> map) {
    return CrossSRSItem(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      scramble: map['scramble'] as String,
      difficulty: map['difficulty'] as int,
      crossColor: map['cross_color'] as String? ?? 'white',
      pairsAttempting: map['pairs_attempting'] as int,
      srsState: SRSState(
        easeFactor: (map['ease_factor'] as num?)?.toDouble() ?? 2.5,
        interval: map['interval_days'] as int? ?? 0,
        repetitions: map['repetitions'] as int? ?? 0,
        nextReviewDate: map['next_review_date'] != null
            ? DateTime.parse(map['next_review_date'] as String)
            : null,
        stability: (map['stability'] as num?)?.toDouble() ?? 0,
        difficulty: (map['srs_difficulty'] as num?)?.toDouble() ?? 5.0,
        desiredRetention:
            (map['desired_retention'] as num?)?.toDouble() ?? 0.9,
        cardState: map['card_state'] != null
            ? SRSCardStateExtension.fromString(map['card_state'] as String)
            : SRSCardState.newCard,
        remainingSteps: map['remaining_steps'] as int?,
        learningDueAt: map['learning_due_at'] != null
            ? DateTime.parse(map['learning_due_at'] as String)
            : null,
        lapses: map['lapses'] as int? ?? 0,
        lastReviewedAt: map['last_reviewed_at'] != null
            ? DateTime.parse(map['last_reviewed_at'] as String)
            : null,
      ),
      lastReviewedAt: map['last_reviewed_at'] != null
          ? DateTime.parse(map['last_reviewed_at'] as String)
          : null,
      totalReviews: map['total_reviews'] as int? ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      'id': id,
      'user_id': userId,
      'scramble': scramble,
      'difficulty': difficulty,
      'cross_color': crossColor,
      'pairs_attempting': pairsAttempting,
      'ease_factor': srsState.easeFactor,
      'interval_days': srsState.interval,
      'repetitions': srsState.repetitions,
      'next_review_date': srsState.nextReviewDate?.toIso8601String(),
      'stability': srsState.stability,
      'srs_difficulty': srsState.difficulty,
      'desired_retention': srsState.desiredRetention,
      'card_state': srsState.cardState.jsonValue,
      'remaining_steps': srsState.remainingSteps,
      'learning_due_at': srsState.learningDueAt?.toIso8601String(),
      'lapses': srsState.lapses,
      'last_reviewed_at': lastReviewedAt?.toIso8601String(),
      'total_reviews': totalReviews,
      'created_at': createdAt.toIso8601String(),
    };
  }

  CrossSRSItem copyWith({
    String? id,
    String? userId,
    String? scramble,
    int? difficulty,
    String? crossColor,
    int? pairsAttempting,
    SRSState? srsState,
    DateTime? lastReviewedAt,
    int? totalReviews,
    DateTime? createdAt,
  }) {
    return CrossSRSItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      scramble: scramble ?? this.scramble,
      difficulty: difficulty ?? this.difficulty,
      crossColor: crossColor ?? this.crossColor,
      pairsAttempting: pairsAttempting ?? this.pairsAttempting,
      srsState: srsState ?? this.srsState,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
      totalReviews: totalReviews ?? this.totalReviews,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CrossSRSItem &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
