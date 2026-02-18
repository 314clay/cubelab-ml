// Stats-related models: DateRange, AlgorithmStats, CrossStats, LevelStats,
// TrendDataPoint, DrillSession, AlgorithmSetStats

import 'package:cubelab/data/models/algorithm.dart';

class DateRange {
  final DateTime start;
  final DateTime end;

  const DateRange({
    required this.start,
    required this.end,
  });

  factory DateRange.fromJson(Map<String, dynamic> json) {
    return DateRange(
      start: DateTime.parse(json['start'] as String),
      end: DateTime.parse(json['end'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'start': start.toIso8601String(),
      'end': end.toIso8601String(),
    };
  }

  factory DateRange.fromSupabase(Map<String, dynamic> json) {
    return DateRange(
      start: DateTime.parse(json['start'] as String),
      end: DateTime.parse(json['end'] as String),
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      'start': start.toIso8601String(),
      'end': end.toIso8601String(),
    };
  }

  DateRange copyWith({
    DateTime? start,
    DateTime? end,
  }) {
    return DateRange(
      start: start ?? this.start,
      end: end ?? this.end,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DateRange &&
          runtimeType == other.runtimeType &&
          start == other.start &&
          end == other.end;

  @override
  int get hashCode => Object.hash(start, end);
}

class AlgorithmSetStats {
  final AlgorithmSet set;
  final int learned;
  final int total;
  final int avgTimeMs;

  const AlgorithmSetStats({
    required this.set,
    required this.learned,
    required this.total,
    this.avgTimeMs = 0,
  });

  factory AlgorithmSetStats.fromJson(Map<String, dynamic> json) {
    return AlgorithmSetStats(
      set: AlgorithmSetExtension.fromString(json['set'] as String),
      learned: json['learned'] as int? ?? 0,
      total: json['total'] as int? ?? 0,
      avgTimeMs: json['avgTimeMs'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'set': set.name,
      'learned': learned,
      'total': total,
      'avgTimeMs': avgTimeMs,
    };
  }

  factory AlgorithmSetStats.fromSupabase(Map<String, dynamic> json) {
    return AlgorithmSetStats(
      set: AlgorithmSetExtension.fromString(json['set'] as String),
      learned: json['learned'] as int? ?? 0,
      total: json['total'] as int? ?? 0,
      avgTimeMs: json['avg_time_ms'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      'set': set.name,
      'learned': learned,
      'total': total,
      'avg_time_ms': avgTimeMs,
    };
  }

  AlgorithmSetStats copyWith({
    AlgorithmSet? set,
    int? learned,
    int? total,
    int? avgTimeMs,
  }) {
    return AlgorithmSetStats(
      set: set ?? this.set,
      learned: learned ?? this.learned,
      total: total ?? this.total,
      avgTimeMs: avgTimeMs ?? this.avgTimeMs,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AlgorithmSetStats &&
          runtimeType == other.runtimeType &&
          set == other.set &&
          learned == other.learned &&
          total == other.total;

  @override
  int get hashCode => Object.hash(set, learned, total);
}

class AlgorithmStats {
  final int totalLearned;
  final int totalDrills;
  final int avgTimeMs;
  final int dueToday;
  final Map<AlgorithmSet, AlgorithmSetStats> bySet;
  final List<String> weakestCases;

  const AlgorithmStats({
    required this.totalLearned,
    required this.totalDrills,
    required this.avgTimeMs,
    required this.dueToday,
    required this.bySet,
    required this.weakestCases,
  });

  factory AlgorithmStats.empty() {
    return const AlgorithmStats(
      totalLearned: 0,
      totalDrills: 0,
      avgTimeMs: 0,
      dueToday: 0,
      bySet: {},
      weakestCases: [],
    );
  }

  factory AlgorithmStats.fromJson(Map<String, dynamic> json) {
    final bySetMap = <AlgorithmSet, AlgorithmSetStats>{};
    if (json['bySet'] != null) {
      final bySetJson = json['bySet'] as Map<String, dynamic>;
      for (final entry in bySetJson.entries) {
        final set = AlgorithmSetExtension.fromString(entry.key);
        bySetMap[set] = AlgorithmSetStats.fromJson(entry.value as Map<String, dynamic>);
      }
    }

    return AlgorithmStats(
      totalLearned: json['totalLearned'] as int? ?? 0,
      totalDrills: json['totalDrills'] as int? ?? 0,
      avgTimeMs: json['avgTimeMs'] as int? ?? 0,
      dueToday: json['dueToday'] as int? ?? 0,
      bySet: bySetMap,
      weakestCases: (json['weakestCases'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalLearned': totalLearned,
      'totalDrills': totalDrills,
      'avgTimeMs': avgTimeMs,
      'dueToday': dueToday,
      'bySet': bySet.map((k, v) => MapEntry(k.name, v.toJson())),
      'weakestCases': weakestCases,
    };
  }

  AlgorithmStats copyWith({
    int? totalLearned,
    int? totalDrills,
    int? avgTimeMs,
    int? dueToday,
    Map<AlgorithmSet, AlgorithmSetStats>? bySet,
    List<String>? weakestCases,
  }) {
    return AlgorithmStats(
      totalLearned: totalLearned ?? this.totalLearned,
      totalDrills: totalDrills ?? this.totalDrills,
      avgTimeMs: avgTimeMs ?? this.avgTimeMs,
      dueToday: dueToday ?? this.dueToday,
      bySet: bySet ?? this.bySet,
      weakestCases: weakestCases ?? this.weakestCases,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AlgorithmStats &&
          runtimeType == other.runtimeType &&
          totalLearned == other.totalLearned &&
          totalDrills == other.totalDrills;

  @override
  int get hashCode => Object.hash(totalLearned, totalDrills);
}

class CrossStats {
  final int totalSolves;
  final double successRate;
  final int avgInspectionTimeMs;
  final int avgExecutionTimeMs;
  final int sessionCount;
  final Map<int, LevelStats> byLevel;

  const CrossStats({
    required this.totalSolves,
    required this.successRate,
    required this.avgInspectionTimeMs,
    required this.avgExecutionTimeMs,
    required this.sessionCount,
    required this.byLevel,
  });

  factory CrossStats.empty() {
    return const CrossStats(
      totalSolves: 0,
      successRate: 0.0,
      avgInspectionTimeMs: 0,
      avgExecutionTimeMs: 0,
      sessionCount: 0,
      byLevel: {},
    );
  }

  factory CrossStats.fromJson(Map<String, dynamic> json) {
    final byLevelMap = <int, LevelStats>{};
    if (json['byLevel'] != null) {
      final byLevelJson = json['byLevel'] as Map<String, dynamic>;
      for (final entry in byLevelJson.entries) {
        byLevelMap[int.parse(entry.key)] =
            LevelStats.fromJson(entry.value as Map<String, dynamic>);
      }
    }

    return CrossStats(
      totalSolves: json['totalSolves'] as int? ?? 0,
      successRate: (json['successRate'] as num?)?.toDouble() ?? 0.0,
      avgInspectionTimeMs: json['avgInspectionTimeMs'] as int? ?? 0,
      avgExecutionTimeMs: json['avgExecutionTimeMs'] as int? ?? 0,
      sessionCount: json['sessionCount'] as int? ?? 0,
      byLevel: byLevelMap,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalSolves': totalSolves,
      'successRate': successRate,
      'avgInspectionTimeMs': avgInspectionTimeMs,
      'avgExecutionTimeMs': avgExecutionTimeMs,
      'sessionCount': sessionCount,
      'byLevel': byLevel.map((k, v) => MapEntry(k.toString(), v.toJson())),
    };
  }

  CrossStats copyWith({
    int? totalSolves,
    double? successRate,
    int? avgInspectionTimeMs,
    int? avgExecutionTimeMs,
    int? sessionCount,
    Map<int, LevelStats>? byLevel,
  }) {
    return CrossStats(
      totalSolves: totalSolves ?? this.totalSolves,
      successRate: successRate ?? this.successRate,
      avgInspectionTimeMs: avgInspectionTimeMs ?? this.avgInspectionTimeMs,
      avgExecutionTimeMs: avgExecutionTimeMs ?? this.avgExecutionTimeMs,
      sessionCount: sessionCount ?? this.sessionCount,
      byLevel: byLevel ?? this.byLevel,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CrossStats &&
          runtimeType == other.runtimeType &&
          totalSolves == other.totalSolves &&
          sessionCount == other.sessionCount;

  @override
  int get hashCode => Object.hash(totalSolves, sessionCount);
}

class LevelStats {
  final int solveCount;
  final int avgInspectionTimeMs;
  final int avgExecutionTimeMs;
  final double successRate;

  const LevelStats({
    required this.solveCount,
    required this.avgInspectionTimeMs,
    required this.avgExecutionTimeMs,
    required this.successRate,
  });

  factory LevelStats.fromJson(Map<String, dynamic> json) {
    return LevelStats(
      solveCount: json['solveCount'] as int? ?? 0,
      avgInspectionTimeMs: json['avgInspectionTimeMs'] as int? ?? 0,
      avgExecutionTimeMs: json['avgExecutionTimeMs'] as int? ?? 0,
      successRate: (json['successRate'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'solveCount': solveCount,
      'avgInspectionTimeMs': avgInspectionTimeMs,
      'avgExecutionTimeMs': avgExecutionTimeMs,
      'successRate': successRate,
    };
  }

  factory LevelStats.fromSupabase(Map<String, dynamic> json) {
    return LevelStats(
      solveCount: json['solve_count'] as int? ?? 0,
      avgInspectionTimeMs: json['avg_inspection_time_ms'] as int? ?? 0,
      avgExecutionTimeMs: json['avg_execution_time_ms'] as int? ?? 0,
      successRate: (json['success_rate'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      'solve_count': solveCount,
      'avg_inspection_time_ms': avgInspectionTimeMs,
      'avg_execution_time_ms': avgExecutionTimeMs,
      'success_rate': successRate,
    };
  }

  LevelStats copyWith({
    int? solveCount,
    int? avgInspectionTimeMs,
    int? avgExecutionTimeMs,
    double? successRate,
  }) {
    return LevelStats(
      solveCount: solveCount ?? this.solveCount,
      avgInspectionTimeMs: avgInspectionTimeMs ?? this.avgInspectionTimeMs,
      avgExecutionTimeMs: avgExecutionTimeMs ?? this.avgExecutionTimeMs,
      successRate: successRate ?? this.successRate,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LevelStats &&
          runtimeType == other.runtimeType &&
          solveCount == other.solveCount &&
          successRate == other.successRate;

  @override
  int get hashCode => Object.hash(solveCount, successRate);
}

class TrendDataPoint {
  final DateTime date;
  final double avgTimeSeconds;

  const TrendDataPoint({
    required this.date,
    required this.avgTimeSeconds,
  });

  factory TrendDataPoint.fromJson(Map<String, dynamic> json) {
    return TrendDataPoint(
      date: DateTime.parse(json['date'] as String),
      avgTimeSeconds: (json['avgTimeSeconds'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'avgTimeSeconds': avgTimeSeconds,
    };
  }

  factory TrendDataPoint.fromSupabase(Map<String, dynamic> json) {
    return TrendDataPoint(
      date: DateTime.parse(json['date'] as String),
      avgTimeSeconds: (json['avg_time_seconds'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      'date': date.toIso8601String(),
      'avg_time_seconds': avgTimeSeconds,
    };
  }

  TrendDataPoint copyWith({
    DateTime? date,
    double? avgTimeSeconds,
  }) {
    return TrendDataPoint(
      date: date ?? this.date,
      avgTimeSeconds: avgTimeSeconds ?? this.avgTimeSeconds,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrendDataPoint &&
          runtimeType == other.runtimeType &&
          date == other.date &&
          avgTimeSeconds == other.avgTimeSeconds;

  @override
  int get hashCode => Object.hash(date, avgTimeSeconds);
}

class DrillSession {
  final String id;
  final DateTime date;
  final int casesCompleted;
  final double accuracy;
  final int avgTimeMs;

  const DrillSession({
    required this.id,
    required this.date,
    required this.casesCompleted,
    required this.accuracy,
    required this.avgTimeMs,
  });

  factory DrillSession.fromJson(Map<String, dynamic> json) {
    return DrillSession(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      casesCompleted: json['casesCompleted'] as int? ?? 0,
      accuracy: (json['accuracy'] as num?)?.toDouble() ?? 0.0,
      avgTimeMs: json['avgTimeMs'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'casesCompleted': casesCompleted,
      'accuracy': accuracy,
      'avgTimeMs': avgTimeMs,
    };
  }

  factory DrillSession.fromSupabase(Map<String, dynamic> json) {
    return DrillSession(
      id: json['id'] as String,
      date: DateTime.parse(json['created_at'] as String),
      casesCompleted: json['cases_completed'] as int? ?? 0,
      accuracy: (json['accuracy'] as num?)?.toDouble() ?? 0.0,
      avgTimeMs: json['avg_time_ms'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      'id': id,
      'created_at': date.toIso8601String(),
      'cases_completed': casesCompleted,
      'accuracy': accuracy,
      'avg_time_ms': avgTimeMs,
    };
  }

  DrillSession copyWith({
    String? id,
    DateTime? date,
    int? casesCompleted,
    double? accuracy,
    int? avgTimeMs,
  }) {
    return DrillSession(
      id: id ?? this.id,
      date: date ?? this.date,
      casesCompleted: casesCompleted ?? this.casesCompleted,
      accuracy: accuracy ?? this.accuracy,
      avgTimeMs: avgTimeMs ?? this.avgTimeMs,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DrillSession &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
