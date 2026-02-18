// Pro solve model for GOAT reconstructions loaded from JSON assets

class ProSolve {
  final String id;
  final String scramble;
  final String solver;
  final int timeMs;
  final String? reconstruction;
  final String? videoUrl;
  final String? notes;

  const ProSolve({
    required this.id,
    required this.scramble,
    required this.solver,
    required this.timeMs,
    this.reconstruction,
    this.videoUrl,
    this.notes,
  });

  factory ProSolve.fromJson(Map<String, dynamic> json) {
    return ProSolve(
      id: json['id'] as String,
      scramble: json['scramble'] as String,
      solver: json['solver'] as String,
      timeMs: json['timeMs'] as int,
      reconstruction: json['reconstruction'] as String?,
      videoUrl: json['videoUrl'] as String?,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'scramble': scramble,
      'solver': solver,
      'timeMs': timeMs,
      'reconstruction': reconstruction,
      'videoUrl': videoUrl,
      'notes': notes,
    };
  }

  factory ProSolve.fromSupabase(Map<String, dynamic> map) {
    return ProSolve(
      id: map['id'] as String,
      scramble: map['scramble'] as String,
      solver: map['solver'] as String,
      timeMs: map['time_ms'] as int,
      reconstruction: map['reconstruction'] as String?,
      videoUrl: map['video_url'] as String?,
      notes: map['notes'] as String?,
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      'id': id,
      'scramble': scramble,
      'solver': solver,
      'time_ms': timeMs,
      'reconstruction': reconstruction,
      'video_url': videoUrl,
      'notes': notes,
    };
  }

  ProSolve copyWith({
    String? id,
    String? scramble,
    String? solver,
    int? timeMs,
    String? reconstruction,
    String? videoUrl,
    String? notes,
  }) {
    return ProSolve(
      id: id ?? this.id,
      scramble: scramble ?? this.scramble,
      solver: solver ?? this.solver,
      timeMs: timeMs ?? this.timeMs,
      reconstruction: reconstruction ?? this.reconstruction,
      videoUrl: videoUrl ?? this.videoUrl,
      notes: notes ?? this.notes,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProSolve &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
