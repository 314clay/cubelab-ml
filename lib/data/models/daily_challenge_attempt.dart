// Daily challenge attempt model for tracking user submissions

class DailyChallengeAttempt {
  final String id;
  final String dailyChallengeId;
  final String userId;
  final bool recognized;
  final int timeMs;
  final bool addedToTraining;
  final DateTime timestamp;

  const DailyChallengeAttempt({
    required this.id,
    required this.dailyChallengeId,
    required this.userId,
    required this.recognized,
    required this.timeMs,
    this.addedToTraining = false,
    required this.timestamp,
  });

  factory DailyChallengeAttempt.fromJson(Map<String, dynamic> json) {
    return DailyChallengeAttempt(
      id: json['id'] as String,
      dailyChallengeId: json['dailyChallengeId'] as String,
      userId: json['userId'] as String,
      recognized: json['recognized'] as bool,
      timeMs: json['timeMs'] as int,
      addedToTraining: json['addedToTraining'] as bool? ?? false,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'dailyChallengeId': dailyChallengeId,
      'userId': userId,
      'recognized': recognized,
      'timeMs': timeMs,
      'addedToTraining': addedToTraining,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory DailyChallengeAttempt.fromSupabase(Map<String, dynamic> map) {
    return DailyChallengeAttempt(
      id: map['id'] as String,
      dailyChallengeId: map['daily_challenge_id'] as String,
      userId: map['user_id'] as String,
      recognized: map['success'] as bool? ?? true,
      timeMs: map['time_ms'] as int,
      addedToTraining: map['added_to_training'] as bool? ?? false,
      timestamp: DateTime.parse(map['completed_at'] as String),
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      'id': id,
      'daily_challenge_id': dailyChallengeId,
      'user_id': userId,
      'success': recognized,
      'time_ms': timeMs,
      'added_to_training': addedToTraining,
      'completed_at': timestamp.toIso8601String(),
    };
  }

  DailyChallengeAttempt copyWith({
    String? id,
    String? dailyChallengeId,
    String? userId,
    bool? recognized,
    int? timeMs,
    bool? addedToTraining,
    DateTime? timestamp,
  }) {
    return DailyChallengeAttempt(
      id: id ?? this.id,
      dailyChallengeId: dailyChallengeId ?? this.dailyChallengeId,
      userId: userId ?? this.userId,
      recognized: recognized ?? this.recognized,
      timeMs: timeMs ?? this.timeMs,
      addedToTraining: addedToTraining ?? this.addedToTraining,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyChallengeAttempt &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
