/// Snapshot of timer stats at a point in time (for historical PBs)
class TimerStatsSnapshot {
  final String id;
  final String userId;
  final DateTime recordedAt;
  final int totalSolves;
  final int? pbSingleMs;
  final int? pbAo5Ms;
  final int? pbAo12Ms;
  final DateTime createdAt;

  const TimerStatsSnapshot({
    required this.id,
    required this.userId,
    required this.recordedAt,
    required this.totalSolves,
    this.pbSingleMs,
    this.pbAo5Ms,
    this.pbAo12Ms,
    required this.createdAt,
  });

  factory TimerStatsSnapshot.fromJson(Map<String, dynamic> json) {
    return TimerStatsSnapshot(
      id: json['id'] as String,
      userId: json['userId'] as String,
      recordedAt: DateTime.parse(json['recordedAt'] as String),
      totalSolves: json['totalSolves'] as int? ?? 0,
      pbSingleMs: json['pbSingleMs'] as int?,
      pbAo5Ms: json['pbAo5Ms'] as int?,
      pbAo12Ms: json['pbAo12Ms'] as int?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'recordedAt': recordedAt.toIso8601String(),
      'totalSolves': totalSolves,
      'pbSingleMs': pbSingleMs,
      'pbAo5Ms': pbAo5Ms,
      'pbAo12Ms': pbAo12Ms,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Create from Supabase response (snake_case fields)
  factory TimerStatsSnapshot.fromSupabase(Map<String, dynamic> json) {
    return TimerStatsSnapshot(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      recordedAt: DateTime.parse(json['recorded_at'] as String),
      totalSolves: json['total_solves'] as int? ?? 0,
      pbSingleMs: json['pb_single_ms'] as int?,
      pbAo5Ms: json['pb_ao5_ms'] as int?,
      pbAo12Ms: json['pb_ao12_ms'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Convert to Supabase format (snake_case fields)
  Map<String, dynamic> toSupabase() {
    return {
      'id': id,
      'user_id': userId,
      'recorded_at': recordedAt.toIso8601String(),
      'total_solves': totalSolves,
      'pb_single_ms': pbSingleMs,
      'pb_ao5_ms': pbAo5Ms,
      'pb_ao12_ms': pbAo12Ms,
    };
  }

  TimerStatsSnapshot copyWith({
    String? id,
    String? userId,
    DateTime? recordedAt,
    int? totalSolves,
    int? pbSingleMs,
    int? pbAo5Ms,
    int? pbAo12Ms,
    DateTime? createdAt,
  }) {
    return TimerStatsSnapshot(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      recordedAt: recordedAt ?? this.recordedAt,
      totalSolves: totalSolves ?? this.totalSolves,
      pbSingleMs: pbSingleMs ?? this.pbSingleMs,
      pbAo5Ms: pbAo5Ms ?? this.pbAo5Ms,
      pbAo12Ms: pbAo12Ms ?? this.pbAo12Ms,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimerStatsSnapshot &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
