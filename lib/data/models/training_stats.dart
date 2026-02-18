// Training stats model for algorithm training overview

import 'package:cubelab/data/models/training_session.dart';

class TrainingStats {
  final int casesDue;
  final double avgRecognitionTime;
  final double successRate;
  final List<TrainingSession> recentSessions;

  const TrainingStats({
    this.casesDue = 0,
    this.avgRecognitionTime = 0.0,
    this.successRate = 0.0,
    this.recentSessions = const [],
  });

  factory TrainingStats.fromJson(Map<String, dynamic> json) {
    return TrainingStats(
      casesDue: json['casesDue'] as int? ?? 0,
      avgRecognitionTime:
          (json['avgRecognitionTime'] as num?)?.toDouble() ?? 0.0,
      successRate: (json['successRate'] as num?)?.toDouble() ?? 0.0,
      recentSessions: (json['recentSessions'] as List<dynamic>?)
              ?.map((e) =>
                  TrainingSession.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'casesDue': casesDue,
      'avgRecognitionTime': avgRecognitionTime,
      'successRate': successRate,
      'recentSessions': recentSessions.map((s) => s.toJson()).toList(),
    };
  }

  factory TrainingStats.fromSupabase(Map<String, dynamic> map) {
    return TrainingStats(
      casesDue: map['cases_due'] as int? ?? 0,
      avgRecognitionTime:
          (map['avg_recognition_time'] as num?)?.toDouble() ?? 0.0,
      successRate: (map['success_rate'] as num?)?.toDouble() ?? 0.0,
      recentSessions: (map['recent_sessions'] as List<dynamic>?)
              ?.map((e) =>
                  TrainingSession.fromSupabase(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      'cases_due': casesDue,
      'avg_recognition_time': avgRecognitionTime,
      'success_rate': successRate,
      'recent_sessions':
          recentSessions.map((s) => s.toSupabase()).toList(),
    };
  }

  TrainingStats copyWith({
    int? casesDue,
    double? avgRecognitionTime,
    double? successRate,
    List<TrainingSession>? recentSessions,
  }) {
    return TrainingStats(
      casesDue: casesDue ?? this.casesDue,
      avgRecognitionTime: avgRecognitionTime ?? this.avgRecognitionTime,
      successRate: successRate ?? this.successRate,
      recentSessions: recentSessions ?? this.recentSessions,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrainingStats &&
          runtimeType == other.runtimeType &&
          casesDue == other.casesDue &&
          avgRecognitionTime == other.avgRecognitionTime &&
          successRate == other.successRate;

  @override
  int get hashCode =>
      Object.hash(casesDue, avgRecognitionTime, successRate);
}
