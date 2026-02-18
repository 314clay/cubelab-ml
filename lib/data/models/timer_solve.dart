// Timer solve model for individual timed solves

class TimerSolve {
  final String id;
  final String sessionId;
  final DateTime timestamp;
  final int timeMs;
  final int? penalty;
  final String scramble;

  const TimerSolve({
    required this.id,
    required this.sessionId,
    required this.timestamp,
    required this.timeMs,
    this.penalty,
    required this.scramble,
  });

  bool get isDNF => penalty == -1;

  int get displayTimeMs => penalty == 2 ? timeMs + 2000 : timeMs;

  factory TimerSolve.fromJson(Map<String, dynamic> json) {
    return TimerSolve(
      id: json['id'] as String,
      sessionId: json['sessionId'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      timeMs: json['timeMs'] as int,
      penalty: json['penalty'] as int?,
      scramble: json['scramble'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sessionId': sessionId,
      'timestamp': timestamp.toIso8601String(),
      'timeMs': timeMs,
      'penalty': penalty,
      'scramble': scramble,
    };
  }

  factory TimerSolve.fromSupabase(Map<String, dynamic> map) {
    return TimerSolve(
      id: map['id'] as String,
      sessionId: map['session_id'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      timeMs: map['time_ms'] as int,
      penalty: map['penalty'] as int?,
      scramble: map['scramble'] as String,
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      'id': id,
      'session_id': sessionId,
      'timestamp': timestamp.toIso8601String(),
      'time_ms': timeMs,
      'penalty': penalty,
      'scramble': scramble,
    };
  }

  TimerSolve copyWith({
    String? id,
    String? sessionId,
    DateTime? timestamp,
    int? timeMs,
    int? penalty,
    String? scramble,
  }) {
    return TimerSolve(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      timestamp: timestamp ?? this.timestamp,
      timeMs: timeMs ?? this.timeMs,
      penalty: penalty ?? this.penalty,
      scramble: scramble ?? this.scramble,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimerSolve &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
