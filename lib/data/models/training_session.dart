// Training session model for algorithm drill sessions

import 'package:cubelab/data/models/training_solve.dart';

enum SessionMode {
  srs,
  random,
  custom,
}

class TrainingSession {
  final String id;
  final DateTime startTime;
  final DateTime? endTime;
  final List<TrainingSolve> solves;
  final SessionMode mode;

  const TrainingSession({
    required this.id,
    required this.startTime,
    this.endTime,
    required this.solves,
    this.mode = SessionMode.srs,
  });

  int get totalCases => solves.length;

  double get recognitionAccuracy {
    if (solves.isEmpty) return 0.0;
    final correct = solves.where((s) => s.recognitionCorrect).length;
    return correct / solves.length;
  }

  double get avgTime {
    if (solves.isEmpty) return 0.0;
    final totalMs = solves.fold<int>(
        0, (sum, s) => sum + s.recognitionTimeMs + s.executionTimeMs);
    return totalMs / solves.length / 1000.0;
  }

  factory TrainingSession.fromJson(Map<String, dynamic> json) {
    return TrainingSession(
      id: json['id'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] != null
          ? DateTime.parse(json['endTime'] as String)
          : null,
      solves: (json['solves'] as List<dynamic>?)
              ?.map(
                  (e) => TrainingSolve.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      mode: SessionMode.values.firstWhere(
        (m) => m.name == json['mode'],
        orElse: () => SessionMode.srs,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'solves': solves.map((s) => s.toJson()).toList(),
      'mode': mode.name,
    };
  }

  factory TrainingSession.fromSupabase(Map<String, dynamic> map) {
    return TrainingSession(
      id: map['id'] as String,
      startTime: DateTime.parse(map['started_at'] as String),
      endTime: map['ended_at'] != null
          ? DateTime.parse(map['ended_at'] as String)
          : null,
      solves: (map['solves'] as List<dynamic>?)
              ?.map(
                  (e) => TrainingSolve.fromSupabase(e as Map<String, dynamic>))
              .toList() ??
          [],
      mode: SessionMode.values.firstWhere(
        (m) => m.name == map['session_type'],
        orElse: () => SessionMode.srs,
      ),
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      'id': id,
      'started_at': startTime.toIso8601String(),
      'ended_at': endTime?.toIso8601String(),
      'session_type': mode.name,
      'total_cases': totalCases,
      'correct_count': solves.where((s) => s.recognitionCorrect).length,
      'accuracy_percent': recognitionAccuracy * 100,
      'avg_time_ms': avgTime > 0 ? (avgTime * 1000).round() : null,
    };
  }

  TrainingSession copyWith({
    String? id,
    DateTime? startTime,
    DateTime? endTime,
    List<TrainingSolve>? solves,
    SessionMode? mode,
  }) {
    return TrainingSession(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      solves: solves ?? this.solves,
      mode: mode ?? this.mode,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrainingSession &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
