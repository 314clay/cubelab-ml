// Training solve model for individual algorithm training attempts

class TrainingSolve {
  final String id;
  final String algorithmId;
  final int recognitionTimeMs;
  final int executionTimeMs;
  final bool recognitionCorrect;
  final DateTime timestamp;

  const TrainingSolve({
    required this.id,
    required this.algorithmId,
    required this.recognitionTimeMs,
    required this.executionTimeMs,
    this.recognitionCorrect = true,
    required this.timestamp,
  });

  factory TrainingSolve.fromJson(Map<String, dynamic> json) {
    return TrainingSolve(
      id: json['id'] as String,
      algorithmId: json['algorithmId'] as String,
      recognitionTimeMs: json['recognitionTimeMs'] as int,
      executionTimeMs: json['executionTimeMs'] as int,
      recognitionCorrect: json['recognitionCorrect'] as bool? ?? true,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'algorithmId': algorithmId,
      'recognitionTimeMs': recognitionTimeMs,
      'executionTimeMs': executionTimeMs,
      'recognitionCorrect': recognitionCorrect,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory TrainingSolve.fromSupabase(Map<String, dynamic> map) {
    return TrainingSolve(
      id: map['id'] as String,
      algorithmId: map['algorithm_id'] as String,
      recognitionTimeMs: map['recognition_time_ms'] as int,
      executionTimeMs: map['execution_time_ms'] as int,
      recognitionCorrect: map['is_correct'] as bool? ?? true,
      timestamp: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      'id': id,
      'algorithm_id': algorithmId,
      'recognition_time_ms': recognitionTimeMs,
      'execution_time_ms': executionTimeMs,
      'is_correct': recognitionCorrect,
      'created_at': timestamp.toIso8601String(),
    };
  }

  TrainingSolve copyWith({
    String? id,
    String? algorithmId,
    int? recognitionTimeMs,
    int? executionTimeMs,
    bool? recognitionCorrect,
    DateTime? timestamp,
  }) {
    return TrainingSolve(
      id: id ?? this.id,
      algorithmId: algorithmId ?? this.algorithmId,
      recognitionTimeMs: recognitionTimeMs ?? this.recognitionTimeMs,
      executionTimeMs: executionTimeMs ?? this.executionTimeMs,
      recognitionCorrect: recognitionCorrect ?? this.recognitionCorrect,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrainingSolve &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
