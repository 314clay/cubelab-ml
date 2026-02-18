// Timer session model grouping solves by day

import 'package:cubelab/data/models/timer_solve.dart';

class TimerSession {
  final String id;
  final DateTime date;
  final List<TimerSolve> solves;

  const TimerSession({
    required this.id,
    required this.date,
    required this.solves,
  });

  factory TimerSession.empty(DateTime date) {
    final dateKey =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return TimerSession(
      id: 'session_$dateKey',
      date: date,
      solves: const [],
    );
  }

  int get solveCount => solves.length;

  int? get bestSingle {
    final validSolves = solves.where((s) => !s.isDNF).toList();
    if (validSolves.isEmpty) return null;
    final times = validSolves.map((s) => s.displayTimeMs).toList();
    times.sort();
    return times.first;
  }

  int? get currentAo5 {
    if (solves.length < 5) return null;
    final recent = solves.take(5).toList();
    return _calculateTrimmedAverage(recent);
  }

  int? get currentAo12 {
    if (solves.length < 12) return null;
    final recent = solves.take(12).toList();
    return _calculateTrimmedAverage(recent);
  }

  int? _calculateTrimmedAverage(List<TimerSolve> window) {
    final dnfCount = window.where((s) => s.isDNF).length;
    if (dnfCount > 1) return null;

    final times = window
        .map((s) => s.isDNF ? double.maxFinite.toInt() : s.displayTimeMs)
        .toList();
    times.sort();

    // Remove best and worst
    final trimmed = times.sublist(1, times.length - 1);

    if (trimmed.any((t) => t == double.maxFinite.toInt())) return null;

    final sum = trimmed.fold<int>(0, (sum, t) => sum + t);
    return (sum / trimmed.length).round();
  }

  factory TimerSession.fromJson(Map<String, dynamic> json) {
    return TimerSession(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      solves: (json['solves'] as List<dynamic>?)
              ?.map(
                  (e) => TimerSolve.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'solves': solves.map((s) => s.toJson()).toList(),
    };
  }

  factory TimerSession.fromSupabase(Map<String, dynamic> map) {
    return TimerSession(
      id: map['id'] as String,
      date: DateTime.parse(map['date'] as String),
      solves: (map['solves'] as List<dynamic>?)
              ?.map(
                  (e) => TimerSolve.fromSupabase(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'solves': solves.map((s) => s.toSupabase()).toList(),
    };
  }

  TimerSession copyWith({
    String? id,
    DateTime? date,
    List<TimerSolve>? solves,
  }) {
    return TimerSession(
      id: id ?? this.id,
      date: date ?? this.date,
      solves: solves ?? this.solves,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimerSession &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
