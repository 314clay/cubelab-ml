// Cross solve model for tracking individual cross training attempts

class CrossSolve {
  final String id;
  final String userId;
  final String scramble;
  final int difficulty;
  final String crossColor;
  final int pairsAttempting;
  final int pairsPlanned;
  final bool crossSuccess;
  final bool blindfolded;
  final int inspectionTimeMs;
  final int executionTimeMs;
  final bool usedUnlimitedTime;
  final String? notes;
  final String? sessionId;
  final DateTime createdAt;

  const CrossSolve({
    required this.id,
    required this.userId,
    required this.scramble,
    required this.difficulty,
    this.crossColor = 'white',
    required this.pairsAttempting,
    required this.pairsPlanned,
    this.crossSuccess = true,
    this.blindfolded = false,
    required this.inspectionTimeMs,
    required this.executionTimeMs,
    this.usedUnlimitedTime = false,
    this.notes,
    this.sessionId,
    required this.createdAt,
  });

  factory CrossSolve.fromJson(Map<String, dynamic> json) {
    return CrossSolve(
      id: json['id'] as String,
      userId: json['userId'] as String,
      scramble: json['scramble'] as String,
      difficulty: json['difficulty'] as int,
      crossColor: json['crossColor'] as String? ?? 'white',
      pairsAttempting: json['pairsAttempting'] as int,
      pairsPlanned: json['pairsPlanned'] as int,
      crossSuccess: json['crossSuccess'] as bool? ?? true,
      blindfolded: json['blindfolded'] as bool? ?? false,
      inspectionTimeMs: json['inspectionTimeMs'] as int,
      executionTimeMs: json['executionTimeMs'] as int,
      usedUnlimitedTime: json['usedUnlimitedTime'] as bool? ?? false,
      notes: json['notes'] as String?,
      sessionId: json['sessionId'] as String?,
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
      'pairsPlanned': pairsPlanned,
      'crossSuccess': crossSuccess,
      'blindfolded': blindfolded,
      'inspectionTimeMs': inspectionTimeMs,
      'executionTimeMs': executionTimeMs,
      'usedUnlimitedTime': usedUnlimitedTime,
      'notes': notes,
      'sessionId': sessionId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory CrossSolve.fromSupabase(Map<String, dynamic> map) {
    return CrossSolve(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      scramble: map['scramble'] as String,
      difficulty: map['difficulty'] as int,
      crossColor: map['cross_color'] as String? ?? 'white',
      pairsAttempting: map['pairs_attempting'] as int,
      pairsPlanned: map['pairs_planned'] as int,
      crossSuccess: map['cross_success'] as bool? ?? true,
      blindfolded: map['blindfolded'] as bool? ?? false,
      inspectionTimeMs: map['inspection_time_ms'] as int,
      executionTimeMs: map['execution_time_ms'] as int,
      usedUnlimitedTime: map['used_unlimited_time'] as bool? ?? false,
      notes: map['notes'] as String?,
      sessionId: map['session_id'] as String?,
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
      'pairs_planned': pairsPlanned,
      'cross_success': crossSuccess,
      'blindfolded': blindfolded,
      'inspection_time_ms': inspectionTimeMs,
      'execution_time_ms': executionTimeMs,
      'used_unlimited_time': usedUnlimitedTime,
      'notes': notes,
      'session_id': sessionId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  CrossSolve copyWith({
    String? id,
    String? userId,
    String? scramble,
    int? difficulty,
    String? crossColor,
    int? pairsAttempting,
    int? pairsPlanned,
    bool? crossSuccess,
    bool? blindfolded,
    int? inspectionTimeMs,
    int? executionTimeMs,
    bool? usedUnlimitedTime,
    String? notes,
    String? sessionId,
    DateTime? createdAt,
  }) {
    return CrossSolve(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      scramble: scramble ?? this.scramble,
      difficulty: difficulty ?? this.difficulty,
      crossColor: crossColor ?? this.crossColor,
      pairsAttempting: pairsAttempting ?? this.pairsAttempting,
      pairsPlanned: pairsPlanned ?? this.pairsPlanned,
      crossSuccess: crossSuccess ?? this.crossSuccess,
      blindfolded: blindfolded ?? this.blindfolded,
      inspectionTimeMs: inspectionTimeMs ?? this.inspectionTimeMs,
      executionTimeMs: executionTimeMs ?? this.executionTimeMs,
      usedUnlimitedTime: usedUnlimitedTime ?? this.usedUnlimitedTime,
      notes: notes ?? this.notes,
      sessionId: sessionId ?? this.sessionId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CrossSolve &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
