// User algorithm model tracking per-user algorithm state

import 'package:cubelab/data/models/srs_state.dart';

class UserAlgorithm {
  final String userId;
  final String algorithmId;
  final bool enabled;
  final String? customAlg;
  final bool isLearned;
  final SRSState? srsState;
  final DateTime? lastReviewedAt;
  final int totalReviews;

  const UserAlgorithm({
    required this.userId,
    required this.algorithmId,
    this.enabled = false,
    this.customAlg,
    this.isLearned = false,
    this.srsState,
    this.lastReviewedAt,
    this.totalReviews = 0,
  });

  factory UserAlgorithm.fromJson(Map<String, dynamic> json) {
    return UserAlgorithm(
      userId: json['userId'] as String,
      algorithmId: json['algorithmId'] as String,
      enabled: json['enabled'] as bool? ?? false,
      customAlg: json['customAlg'] as String?,
      isLearned: json['isLearned'] as bool? ?? false,
      srsState: json['srsState'] != null
          ? SRSState.fromJson(json['srsState'] as Map<String, dynamic>)
          : null,
      lastReviewedAt: json['lastReviewedAt'] != null
          ? DateTime.parse(json['lastReviewedAt'] as String)
          : null,
      totalReviews: json['totalReviews'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'algorithmId': algorithmId,
      'enabled': enabled,
      'customAlg': customAlg,
      'isLearned': isLearned,
      'srsState': srsState?.toJson(),
      'lastReviewedAt': lastReviewedAt?.toIso8601String(),
      'totalReviews': totalReviews,
    };
  }

  factory UserAlgorithm.fromSupabase(Map<String, dynamic> json) {
    return UserAlgorithm(
      userId: json['user_id'] as String,
      algorithmId: json['algorithm_id'] as String,
      enabled: json['enabled'] as bool? ?? false,
      customAlg: json['custom_alg'] as String?,
      isLearned: json['is_learned'] as bool? ?? false,
      srsState: SRSState(
        easeFactor: (json['ease_factor'] as num?)?.toDouble() ?? 2.5,
        interval: json['interval_days'] as int? ?? 0,
        repetitions: json['repetitions'] as int? ?? 0,
        nextReviewDate: json['next_review_date'] != null
            ? DateTime.parse(json['next_review_date'] as String)
            : null,
        stability: (json['stability'] as num?)?.toDouble() ?? 0,
        difficulty: (json['srs_difficulty'] as num?)?.toDouble() ?? 5.0,
        desiredRetention: (json['desired_retention'] as num?)?.toDouble() ?? 0.9,
        cardState: json['card_state'] != null
            ? SRSCardStateExtension.fromString(json['card_state'] as String)
            : SRSCardState.newCard,
        remainingSteps: json['remaining_steps'] as int?,
        learningDueAt: json['learning_due_at'] != null
            ? DateTime.parse(json['learning_due_at'] as String)
            : null,
        lapses: json['lapses'] as int? ?? 0,
        lastReviewedAt: json['last_reviewed_at'] != null
            ? DateTime.parse(json['last_reviewed_at'] as String)
            : null,
      ),
      lastReviewedAt: json['last_reviewed_at'] != null
          ? DateTime.parse(json['last_reviewed_at'] as String)
          : null,
      totalReviews: json['total_reviews'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      'user_id': userId,
      'algorithm_id': algorithmId,
      'enabled': enabled,
      'custom_alg': customAlg,
      'is_learned': isLearned,
      'ease_factor': srsState?.easeFactor,
      'interval_days': srsState?.interval,
      'repetitions': srsState?.repetitions,
      'next_review_date': srsState?.nextReviewDate?.toIso8601String(),
      'stability': srsState?.stability,
      'srs_difficulty': srsState?.difficulty,
      'desired_retention': srsState?.desiredRetention,
      'card_state': srsState?.cardState.jsonValue,
      'remaining_steps': srsState?.remainingSteps,
      'learning_due_at': srsState?.learningDueAt?.toIso8601String(),
      'lapses': srsState?.lapses,
      'last_reviewed_at': lastReviewedAt?.toIso8601String(),
      'total_reviews': totalReviews,
    };
  }

  UserAlgorithm copyWith({
    String? userId,
    String? algorithmId,
    bool? enabled,
    String? customAlg,
    bool? isLearned,
    SRSState? srsState,
    DateTime? lastReviewedAt,
    int? totalReviews,
  }) {
    return UserAlgorithm(
      userId: userId ?? this.userId,
      algorithmId: algorithmId ?? this.algorithmId,
      enabled: enabled ?? this.enabled,
      customAlg: customAlg ?? this.customAlg,
      isLearned: isLearned ?? this.isLearned,
      srsState: srsState ?? this.srsState,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
      totalReviews: totalReviews ?? this.totalReviews,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserAlgorithm &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          algorithmId == other.algorithmId;

  @override
  int get hashCode => Object.hash(userId, algorithmId);
}
