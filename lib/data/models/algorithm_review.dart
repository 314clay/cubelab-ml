// Algorithm review model for SRS review history

import 'package:cubelab/data/models/srs_state.dart';

class AlgorithmReview {
  final String id;
  final String userId;
  final String userAlgorithmId;
  final SRSRating rating;
  final int timeMs;
  final SRSState stateBefore;
  final SRSState stateAfter;
  final DateTime createdAt;

  const AlgorithmReview({
    required this.id,
    required this.userId,
    required this.userAlgorithmId,
    required this.rating,
    this.timeMs = 0,
    required this.stateBefore,
    required this.stateAfter,
    required this.createdAt,
  });

  factory AlgorithmReview.fromJson(Map<String, dynamic> json) {
    return AlgorithmReview(
      id: json['id'] as String,
      userId: json['userId'] as String,
      userAlgorithmId: json['userAlgorithmId'] as String,
      rating: ReviewRatingExtension.fromString(json['rating'] as String),
      timeMs: json['timeMs'] as int? ?? 0,
      stateBefore: json['stateBefore'] != null
          ? SRSState.fromJson(json['stateBefore'] as Map<String, dynamic>)
          : SRSState.initial(),
      stateAfter: json['stateAfter'] != null
          ? SRSState.fromJson(json['stateAfter'] as Map<String, dynamic>)
          : SRSState.initial(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userAlgorithmId': userAlgorithmId,
      'rating': rating.name,
      'timeMs': timeMs,
      'stateBefore': stateBefore.toJson(),
      'stateAfter': stateAfter.toJson(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory AlgorithmReview.fromSupabase(Map<String, dynamic> json) {
    return AlgorithmReview(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      userAlgorithmId: json['algorithm_id'] as String,
      rating: ReviewRatingExtension.fromString(json['rating'] as String),
      timeMs: json['time_ms'] as int? ?? 0,
      stateBefore: SRSState.initial(),
      stateAfter: SRSState(
        easeFactor: (json['ease_factor'] as num?)?.toDouble() ?? 2.5,
        interval: json['interval_days'] as int? ?? 0,
        repetitions: json['repetitions'] as int? ?? 0,
      ),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      'id': id,
      'user_id': userId,
      'algorithm_id': userAlgorithmId,
      'rating': rating.name,
      'interval_days': stateAfter.interval,
      'ease_factor': stateAfter.easeFactor,
      'repetitions': stateAfter.repetitions,
      'created_at': createdAt.toIso8601String(),
    };
  }

  AlgorithmReview copyWith({
    String? id,
    String? userId,
    String? userAlgorithmId,
    SRSRating? rating,
    int? timeMs,
    SRSState? stateBefore,
    SRSState? stateAfter,
    DateTime? createdAt,
  }) {
    return AlgorithmReview(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userAlgorithmId: userAlgorithmId ?? this.userAlgorithmId,
      rating: rating ?? this.rating,
      timeMs: timeMs ?? this.timeMs,
      stateBefore: stateBefore ?? this.stateBefore,
      stateAfter: stateAfter ?? this.stateAfter,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AlgorithmReview &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
