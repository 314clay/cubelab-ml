// Algorithm mastery tracking model

class AlgorithmMastery {
  final String id;
  final String userId;
  final String algorithmId;
  final int totalAttempts;
  final int successCount;
  final int bestTimeMs;
  final int avgTimeMs;
  final double masteryScore;
  final DateTime lastPracticedAt;
  final DateTime createdAt;

  const AlgorithmMastery({
    required this.id,
    required this.userId,
    required this.algorithmId,
    this.totalAttempts = 0,
    this.successCount = 0,
    this.bestTimeMs = 0,
    this.avgTimeMs = 0,
    this.masteryScore = 0.0,
    required this.lastPracticedAt,
    required this.createdAt,
  });

  factory AlgorithmMastery.fromJson(Map<String, dynamic> json) {
    return AlgorithmMastery(
      id: json['id'] as String,
      userId: json['userId'] as String,
      algorithmId: json['algorithmId'] as String,
      totalAttempts: json['totalAttempts'] as int? ?? 0,
      successCount: json['successCount'] as int? ?? 0,
      bestTimeMs: json['bestTimeMs'] as int? ?? 0,
      avgTimeMs: json['avgTimeMs'] as int? ?? 0,
      masteryScore: (json['masteryScore'] as num?)?.toDouble() ?? 0.0,
      lastPracticedAt: DateTime.parse(json['lastPracticedAt'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'algorithmId': algorithmId,
      'totalAttempts': totalAttempts,
      'successCount': successCount,
      'bestTimeMs': bestTimeMs,
      'avgTimeMs': avgTimeMs,
      'masteryScore': masteryScore,
      'lastPracticedAt': lastPracticedAt.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory AlgorithmMastery.fromSupabase(Map<String, dynamic> json) {
    return AlgorithmMastery(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      algorithmId: json['algorithm_id'] as String,
      totalAttempts: json['total_attempts'] as int? ?? 0,
      successCount: json['success_count'] as int? ?? 0,
      bestTimeMs: json['best_time_ms'] as int? ?? 0,
      avgTimeMs: json['avg_time_ms'] as int? ?? 0,
      masteryScore: (json['mastery_score'] as num?)?.toDouble() ?? 0.0,
      lastPracticedAt: DateTime.parse(json['last_practiced_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      'id': id,
      'user_id': userId,
      'algorithm_id': algorithmId,
      'total_attempts': totalAttempts,
      'success_count': successCount,
      'best_time_ms': bestTimeMs,
      'avg_time_ms': avgTimeMs,
      'mastery_score': masteryScore,
      'last_practiced_at': lastPracticedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  AlgorithmMastery copyWith({
    String? id,
    String? userId,
    String? algorithmId,
    int? totalAttempts,
    int? successCount,
    int? bestTimeMs,
    int? avgTimeMs,
    double? masteryScore,
    DateTime? lastPracticedAt,
    DateTime? createdAt,
  }) {
    return AlgorithmMastery(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      algorithmId: algorithmId ?? this.algorithmId,
      totalAttempts: totalAttempts ?? this.totalAttempts,
      successCount: successCount ?? this.successCount,
      bestTimeMs: bestTimeMs ?? this.bestTimeMs,
      avgTimeMs: avgTimeMs ?? this.avgTimeMs,
      masteryScore: masteryScore ?? this.masteryScore,
      lastPracticedAt: lastPracticedAt ?? this.lastPracticedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AlgorithmMastery &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
