// Algorithm solve model for tracking individual algorithm practice attempts

class AlgorithmSolve {
  final String id;
  final String userId;
  final String algorithmId;
  final int timeMs;
  final bool success;
  final String? scramble;
  final String? notes;
  final String? sessionId;
  final DateTime createdAt;

  const AlgorithmSolve({
    required this.id,
    required this.userId,
    required this.algorithmId,
    required this.timeMs,
    this.success = true,
    this.scramble,
    this.notes,
    this.sessionId,
    required this.createdAt,
  });

  factory AlgorithmSolve.fromJson(Map<String, dynamic> json) {
    return AlgorithmSolve(
      id: json['id'] as String,
      userId: json['userId'] as String,
      algorithmId: json['algorithmId'] as String,
      timeMs: json['timeMs'] as int,
      success: json['success'] as bool? ?? true,
      scramble: json['scramble'] as String?,
      notes: json['notes'] as String?,
      sessionId: json['sessionId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'algorithmId': algorithmId,
      'timeMs': timeMs,
      'success': success,
      'scramble': scramble,
      'notes': notes,
      'sessionId': sessionId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory AlgorithmSolve.fromSupabase(Map<String, dynamic> json) {
    return AlgorithmSolve(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      algorithmId: json['algorithm_id'] as String,
      timeMs: json['time_ms'] as int,
      success: json['success'] as bool? ?? true,
      scramble: json['scramble'] as String?,
      notes: json['notes'] as String?,
      sessionId: json['session_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      'id': id,
      'user_id': userId,
      'algorithm_id': algorithmId,
      'time_ms': timeMs,
      'success': success,
      'scramble': scramble,
      'notes': notes,
      'session_id': sessionId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  AlgorithmSolve copyWith({
    String? id,
    String? userId,
    String? algorithmId,
    int? timeMs,
    bool? success,
    String? scramble,
    String? notes,
    String? sessionId,
    DateTime? createdAt,
  }) {
    return AlgorithmSolve(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      algorithmId: algorithmId ?? this.algorithmId,
      timeMs: timeMs ?? this.timeMs,
      success: success ?? this.success,
      scramble: scramble ?? this.scramble,
      notes: notes ?? this.notes,
      sessionId: sessionId ?? this.sessionId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AlgorithmSolve &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
