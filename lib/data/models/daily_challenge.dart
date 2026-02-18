// Daily challenge and daily scramble solve models

import 'package:cubelab/data/models/algorithm.dart';

class DailyChallenge {
  final String id;
  final DateTime date;
  final String scramble;
  final String? algorithmId;
  final AlgorithmSet? algorithmSet;

  const DailyChallenge({
    required this.id,
    required this.date,
    required this.scramble,
    this.algorithmId,
    this.algorithmSet,
  });

  factory DailyChallenge.fromJson(Map<String, dynamic> json) {
    return DailyChallenge(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      scramble: json['scramble'] as String,
      algorithmId: json['algorithmId'] as String?,
      algorithmSet: json['algorithmSet'] != null
          ? AlgorithmSetExtension.fromString(json['algorithmSet'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'scramble': scramble,
      'algorithmId': algorithmId,
      'algorithmSet': algorithmSet?.name,
    };
  }

  factory DailyChallenge.fromSupabase(Map<String, dynamic> map) {
    return DailyChallenge(
      id: map['id'] as String,
      date: DateTime.parse(map['released_at'] as String),
      scramble: map['scramble'] as String,
      algorithmId: map['algorithm_id'] as String?,
      algorithmSet: map['algorithm_set'] != null
          ? AlgorithmSetExtension.fromString(map['algorithm_set'] as String)
          : null,
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      'id': id,
      'released_at': date.toIso8601String(),
      'scramble': scramble,
      'algorithm_id': algorithmId,
      'algorithm_set': algorithmSet?.name,
    };
  }

  DailyChallenge copyWith({
    String? id,
    DateTime? date,
    String? scramble,
    String? algorithmId,
    AlgorithmSet? algorithmSet,
  }) {
    return DailyChallenge(
      id: id ?? this.id,
      date: date ?? this.date,
      scramble: scramble ?? this.scramble,
      algorithmId: algorithmId ?? this.algorithmId,
      algorithmSet: algorithmSet ?? this.algorithmSet,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyChallenge &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class DailyScrambleSolve {
  final String id;
  final String userId;
  final String? username;
  final DateTime date;
  final String scramble;
  final int timeMs;
  final String? notes;
  final int? pairsPlanned;
  final bool? wasXcross;
  final bool? wasZbll;
  final String? algUsed;
  final DateTime createdAt;

  const DailyScrambleSolve({
    required this.id,
    required this.userId,
    this.username,
    required this.date,
    required this.scramble,
    required this.timeMs,
    this.notes,
    this.pairsPlanned,
    this.wasXcross,
    this.wasZbll,
    this.algUsed,
    required this.createdAt,
  });

  factory DailyScrambleSolve.fromJson(Map<String, dynamic> json) {
    return DailyScrambleSolve(
      id: json['id'] as String,
      userId: json['userId'] as String,
      username: json['username'] as String?,
      date: DateTime.parse(json['date'] as String),
      scramble: json['scramble'] as String,
      timeMs: json['timeMs'] as int,
      notes: json['notes'] as String?,
      pairsPlanned: json['pairsPlanned'] as int?,
      wasXcross: json['wasXcross'] as bool?,
      wasZbll: json['wasZbll'] as bool?,
      algUsed: json['algUsed'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'username': username,
      'date': date.toIso8601String(),
      'scramble': scramble,
      'timeMs': timeMs,
      'notes': notes,
      'pairsPlanned': pairsPlanned,
      'wasXcross': wasXcross,
      'wasZbll': wasZbll,
      'algUsed': algUsed,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory DailyScrambleSolve.fromSupabase(Map<String, dynamic> map) {
    return DailyScrambleSolve(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      username: map['username'] as String?,
      date: DateTime.parse(map['challenge_date'] as String),
      scramble: map['scramble'] as String,
      timeMs: map['time_ms'] as int,
      notes: map['notes'] as String?,
      pairsPlanned: map['pairs_planned'] as int?,
      wasXcross: map['was_xcross'] as bool?,
      wasZbll: map['was_zbll'] as bool?,
      algUsed: map['alg_used'] as String?,
      createdAt: DateTime.parse(map['completed_at'] as String),
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      'id': id,
      'user_id': userId,
      'username': username,
      'challenge_date': date.toIso8601String().split('T')[0],
      'scramble': scramble,
      'time_ms': timeMs,
      'notes': notes,
      'pairs_planned': pairsPlanned,
      'was_xcross': wasXcross,
      'was_zbll': wasZbll,
      'alg_used': algUsed,
      'completed_at': createdAt.toIso8601String(),
    };
  }

  DailyScrambleSolve copyWith({
    String? id,
    String? userId,
    String? username,
    DateTime? date,
    String? scramble,
    int? timeMs,
    String? notes,
    int? pairsPlanned,
    bool? wasXcross,
    bool? wasZbll,
    String? algUsed,
    DateTime? createdAt,
  }) {
    return DailyScrambleSolve(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      date: date ?? this.date,
      scramble: scramble ?? this.scramble,
      timeMs: timeMs ?? this.timeMs,
      notes: notes ?? this.notes,
      pairsPlanned: pairsPlanned ?? this.pairsPlanned,
      wasXcross: wasXcross ?? this.wasXcross,
      wasZbll: wasZbll ?? this.wasZbll,
      algUsed: algUsed ?? this.algUsed,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyScrambleSolve &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
