// Daily algorithm challenge model

import 'package:cubelab/data/models/algorithm_case.dart';
import 'package:cubelab/data/models/daily_challenge_attempt.dart';

class DailyAlgorithmChallenge {
  final String id;
  final DateTime date;
  final String algorithmId;
  final AlgorithmCase algorithmCase;
  final DailyChallengeAttempt? userAttempt;
  final bool isCompleted;

  const DailyAlgorithmChallenge({
    required this.id,
    required this.date,
    required this.algorithmId,
    required this.algorithmCase,
    this.userAttempt,
    this.isCompleted = false,
  });

  factory DailyAlgorithmChallenge.fromJson(Map<String, dynamic> json) {
    return DailyAlgorithmChallenge(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      algorithmId: json['algorithmId'] as String,
      algorithmCase: AlgorithmCase.fromJson(
          json['algorithmCase'] as Map<String, dynamic>),
      userAttempt: json['userAttempt'] != null
          ? DailyChallengeAttempt.fromJson(
              json['userAttempt'] as Map<String, dynamic>)
          : null,
      isCompleted: json['isCompleted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'algorithmId': algorithmId,
      'algorithmCase': algorithmCase.toJson(),
      'userAttempt': userAttempt?.toJson(),
      'isCompleted': isCompleted,
    };
  }

  factory DailyAlgorithmChallenge.fromSupabase(Map<String, dynamic> map) {
    return DailyAlgorithmChallenge(
      id: map['id'] as String,
      date: DateTime.parse(map['date'] as String),
      algorithmId: map['algorithm_id'] as String,
      algorithmCase: AlgorithmCase.fromSupabase(
          map['algorithm_case'] as Map<String, dynamic>),
      userAttempt: map['user_attempt'] != null
          ? DailyChallengeAttempt.fromSupabase(
              map['user_attempt'] as Map<String, dynamic>)
          : null,
      isCompleted: map['is_completed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'algorithm_id': algorithmId,
      'algorithm_case': algorithmCase.toSupabase(),
      'user_attempt': userAttempt?.toSupabase(),
      'is_completed': isCompleted,
    };
  }

  DailyAlgorithmChallenge copyWith({
    String? id,
    DateTime? date,
    String? algorithmId,
    AlgorithmCase? algorithmCase,
    DailyChallengeAttempt? userAttempt,
    bool? isCompleted,
  }) {
    return DailyAlgorithmChallenge(
      id: id ?? this.id,
      date: date ?? this.date,
      algorithmId: algorithmId ?? this.algorithmId,
      algorithmCase: algorithmCase ?? this.algorithmCase,
      userAttempt: userAttempt ?? this.userAttempt,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyAlgorithmChallenge &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
