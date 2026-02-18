// Cross training session model

class CrossSession {
  final String id;
  final String userId;
  final int solveCount;
  final int successCount;
  final int? avgInspectionTimeMs;
  final int? avgExecutionTimeMs;
  final DateTime startedAt;
  final DateTime? endedAt;

  const CrossSession({
    required this.id,
    required this.userId,
    this.solveCount = 0,
    this.successCount = 0,
    this.avgInspectionTimeMs,
    this.avgExecutionTimeMs,
    required this.startedAt,
    this.endedAt,
  });

  factory CrossSession.fromJson(Map<String, dynamic> json) {
    return CrossSession(
      id: json['id'] as String,
      userId: json['userId'] as String,
      solveCount: json['solveCount'] as int? ?? 0,
      successCount: json['successCount'] as int? ?? 0,
      avgInspectionTimeMs: json['avgInspectionTimeMs'] as int?,
      avgExecutionTimeMs: json['avgExecutionTimeMs'] as int?,
      startedAt: DateTime.parse(json['startedAt'] as String),
      endedAt: json['endedAt'] != null
          ? DateTime.parse(json['endedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'solveCount': solveCount,
      'successCount': successCount,
      'avgInspectionTimeMs': avgInspectionTimeMs,
      'avgExecutionTimeMs': avgExecutionTimeMs,
      'startedAt': startedAt.toIso8601String(),
      'endedAt': endedAt?.toIso8601String(),
    };
  }

  factory CrossSession.fromSupabase(Map<String, dynamic> json) {
    return CrossSession(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      solveCount: json['solve_count'] as int? ?? 0,
      successCount: json['success_count'] as int? ?? 0,
      avgInspectionTimeMs: json['avg_inspection_time_ms'] as int?,
      avgExecutionTimeMs: json['avg_execution_time_ms'] as int?,
      startedAt: DateTime.parse(json['started_at'] as String),
      endedAt: json['ended_at'] != null
          ? DateTime.parse(json['ended_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      'id': id,
      'user_id': userId,
      'solve_count': solveCount,
      'success_count': successCount,
      'avg_inspection_time_ms': avgInspectionTimeMs,
      'avg_execution_time_ms': avgExecutionTimeMs,
      'started_at': startedAt.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
    };
  }

  CrossSession copyWith({
    String? id,
    String? userId,
    int? solveCount,
    int? successCount,
    int? avgInspectionTimeMs,
    int? avgExecutionTimeMs,
    DateTime? startedAt,
    DateTime? endedAt,
  }) {
    return CrossSession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      solveCount: solveCount ?? this.solveCount,
      successCount: successCount ?? this.successCount,
      avgInspectionTimeMs: avgInspectionTimeMs ?? this.avgInspectionTimeMs,
      avgExecutionTimeMs: avgExecutionTimeMs ?? this.avgExecutionTimeMs,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CrossSession &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
