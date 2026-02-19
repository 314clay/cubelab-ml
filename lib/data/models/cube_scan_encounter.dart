/// Model for tracking Cube Scan history.
class CubeScanEncounter {
  final String id;
  final String userId;
  final String? algorithmId;
  final String phase;
  final String? caseName;
  final double confidence;
  final String? srsRating;
  final bool addedToQueue;
  final DateTime scannedAt;

  const CubeScanEncounter({
    required this.id,
    required this.userId,
    this.algorithmId,
    required this.phase,
    this.caseName,
    required this.confidence,
    this.srsRating,
    this.addedToQueue = false,
    required this.scannedAt,
  });

  factory CubeScanEncounter.fromJson(Map<String, dynamic> json) {
    return CubeScanEncounter(
      id: json['id'] as String,
      userId: json['userId'] as String,
      algorithmId: json['algorithmId'] as String?,
      phase: json['phase'] as String,
      caseName: json['caseName'] as String?,
      confidence: (json['confidence'] as num).toDouble(),
      srsRating: json['srsRating'] as String?,
      addedToQueue: json['addedToQueue'] as bool? ?? false,
      scannedAt: DateTime.parse(json['scannedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'algorithmId': algorithmId,
      'phase': phase,
      'caseName': caseName,
      'confidence': confidence,
      'srsRating': srsRating,
      'addedToQueue': addedToQueue,
      'scannedAt': scannedAt.toIso8601String(),
    };
  }

  factory CubeScanEncounter.fromSupabase(Map<String, dynamic> json) {
    return CubeScanEncounter(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      algorithmId: json['algorithm_id'] as String?,
      phase: json['phase'] as String,
      caseName: json['case_name'] as String?,
      confidence: (json['confidence'] as num).toDouble(),
      srsRating: json['srs_rating'] as String?,
      addedToQueue: json['added_to_queue'] as bool? ?? false,
      scannedAt: DateTime.parse(json['scanned_at'] as String),
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      'id': id,
      'user_id': userId,
      'algorithm_id': algorithmId,
      'phase': phase,
      'case_name': caseName,
      'confidence': confidence,
      'srs_rating': srsRating,
      'added_to_queue': addedToQueue,
      'scanned_at': scannedAt.toIso8601String(),
    };
  }

  CubeScanEncounter copyWith({
    String? id,
    String? userId,
    String? algorithmId,
    String? phase,
    String? caseName,
    double? confidence,
    String? srsRating,
    bool? addedToQueue,
    DateTime? scannedAt,
  }) {
    return CubeScanEncounter(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      algorithmId: algorithmId ?? this.algorithmId,
      phase: phase ?? this.phase,
      caseName: caseName ?? this.caseName,
      confidence: confidence ?? this.confidence,
      srsRating: srsRating ?? this.srsRating,
      addedToQueue: addedToQueue ?? this.addedToQueue,
      scannedAt: scannedAt ?? this.scannedAt,
    );
  }
}
