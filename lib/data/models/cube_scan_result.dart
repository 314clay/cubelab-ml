/// Models for the Cube Scan ML pipeline output.

class SolveStep {
  final String algorithmSet;
  final String caseName;
  final String algorithm;
  final int moveCount;

  const SolveStep({
    required this.algorithmSet,
    required this.caseName,
    required this.algorithm,
    required this.moveCount,
  });

  factory SolveStep.fromJson(Map<String, dynamic> json) {
    return SolveStep(
      algorithmSet: json['algorithmSet'] as String,
      caseName: json['caseName'] as String,
      algorithm: json['algorithm'] as String,
      moveCount: json['moveCount'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'algorithmSet': algorithmSet,
      'caseName': caseName,
      'algorithm': algorithm,
      'moveCount': moveCount,
    };
  }
}

class SolvePath {
  final List<SolveStep> steps;
  final int totalMoves;
  final String description;

  const SolvePath({
    required this.steps,
    required this.totalMoves,
    required this.description,
  });

  factory SolvePath.fromJson(Map<String, dynamic> json) {
    return SolvePath(
      steps: (json['steps'] as List)
          .map((s) => SolveStep.fromJson(s as Map<String, dynamic>))
          .toList(),
      totalMoves: json['totalMoves'] as int,
      description: json['description'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'steps': steps.map((s) => s.toJson()).toList(),
      'totalMoves': totalMoves,
      'description': description,
    };
  }
}

class CubeScanResult {
  final List<String> visible27;
  final Map<String, List<String>> state54;
  final String phase;
  final String? caseName;
  final String? caseSet;
  final double confidence;
  final List<SolvePath> solvePaths;

  const CubeScanResult({
    required this.visible27,
    required this.state54,
    required this.phase,
    this.caseName,
    this.caseSet,
    required this.confidence,
    required this.solvePaths,
  });

  factory CubeScanResult.fromJson(Map<String, dynamic> json) {
    return CubeScanResult(
      visible27: List<String>.from(json['visible27'] as List),
      state54: (json['state54'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, List<String>.from(value as List)),
      ),
      phase: json['phase'] as String,
      caseName: json['caseName'] as String?,
      caseSet: json['caseSet'] as String?,
      confidence: (json['confidence'] as num).toDouble(),
      solvePaths: (json['solvePaths'] as List)
          .map((p) => SolvePath.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'visible27': visible27,
      'state54': state54,
      'phase': phase,
      'caseName': caseName,
      'caseSet': caseSet,
      'confidence': confidence,
      'solvePaths': solvePaths.map((p) => p.toJson()).toList(),
    };
  }
}
