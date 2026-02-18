import 'dart:math';
import 'dart:typed_data';

import 'package:cubelab/data/models/cube_scan_result.dart';
import 'package:cubelab/data/services/cube_analysis_service.dart';

/// Stub implementation returning randomized results for UI testing.
/// Picks from OLL 27, PLL T-Perm, OLL 45, PLL H-Perm, and solved state.
class StubCubeAnalysisService implements CubeAnalysisService {
  final _random = Random();

  @override
  Future<CubeScanResult> analyze(Uint8List imageBytes) async {
    // Simulate network/processing delay
    await Future<void>.delayed(const Duration(seconds: 2));

    final index = _random.nextInt(_stubResults.length);
    return _stubResults[index];
  }

  @override
  Future<bool> isAvailable() async => true;
}

const _stubResults = [
  // ============ OLL 27 (Sune) ============
  CubeScanResult(
    visible27: [
      'R', 'W', 'W', 'W', 'W', 'O', 'W', 'W', 'B',
      'W', 'R', 'R', 'R', 'R', 'R', 'R', 'R', 'R',
      'W', 'B', 'B', 'B', 'B', 'B', 'B', 'B', 'B',
    ],
    state54: {
      'U': ['R', 'W', 'W', 'W', 'W', 'O', 'W', 'W', 'B'],
      'F': ['W', 'R', 'R', 'R', 'R', 'R', 'R', 'R', 'R'],
      'R': ['W', 'B', 'B', 'B', 'B', 'B', 'B', 'B', 'B'],
      'D': ['Y', 'Y', 'Y', 'Y', 'Y', 'Y', 'Y', 'Y', 'Y'],
      'B': ['O', 'O', 'O', 'O', 'O', 'O', 'O', 'O', 'O'],
      'L': ['G', 'G', 'G', 'G', 'G', 'G', 'G', 'G', 'G'],
    },
    phase: 'oll',
    caseName: 'OLL 27',
    caseSet: 'OLL',
    confidence: 0.97,
    solvePaths: [
      SolvePath(
        description: 'OLL 27 → T-Perm',
        totalMoves: 19,
        steps: [
          SolveStep(
            algorithmSet: 'OLL',
            caseName: 'OLL 27',
            algorithm: "R U R' U R U2 R'",
            moveCount: 7,
          ),
          SolveStep(
            algorithmSet: 'PLL',
            caseName: 'T-Perm',
            algorithm: "R U R' U' R' F R2 U' R' U' R U R' F'",
            moveCount: 12,
          ),
        ],
      ),
      SolvePath(
        description: 'OLL 27 → J-Perm (b)',
        totalMoves: 21,
        steps: [
          SolveStep(
            algorithmSet: 'OLL',
            caseName: 'OLL 27',
            algorithm: "R U R' U R U2 R'",
            moveCount: 7,
          ),
          SolveStep(
            algorithmSet: 'PLL',
            caseName: 'J-Perm (b)',
            algorithm: "R U R' F' R U R' U' R' F R2 U' R'",
            moveCount: 14,
          ),
        ],
      ),
    ],
  ),

  // ============ OLL 45 ============
  CubeScanResult(
    visible27: [
      'O', 'W', 'R', 'W', 'W', 'W', 'B', 'W', 'G',
      'W', 'R', 'R', 'R', 'R', 'R', 'W', 'R', 'R',
      'W', 'B', 'B', 'B', 'B', 'B', 'B', 'B', 'W',
    ],
    state54: {
      'U': ['O', 'W', 'R', 'W', 'W', 'W', 'B', 'W', 'G'],
      'F': ['W', 'R', 'R', 'R', 'R', 'R', 'W', 'R', 'R'],
      'R': ['W', 'B', 'B', 'B', 'B', 'B', 'B', 'B', 'W'],
      'D': ['Y', 'Y', 'Y', 'Y', 'Y', 'Y', 'Y', 'Y', 'Y'],
      'B': ['O', 'O', 'O', 'O', 'O', 'O', 'O', 'O', 'O'],
      'L': ['G', 'G', 'G', 'G', 'G', 'G', 'G', 'G', 'G'],
    },
    phase: 'oll',
    caseName: 'OLL 45',
    caseSet: 'OLL',
    confidence: 0.92,
    solvePaths: [
      SolvePath(
        description: 'OLL 45 → U-Perm (a)',
        totalMoves: 20,
        steps: [
          SolveStep(
            algorithmSet: 'OLL',
            caseName: 'OLL 45',
            algorithm: "F R U R' U' F'",
            moveCount: 6,
          ),
          SolveStep(
            algorithmSet: 'PLL',
            caseName: 'U-Perm (a)',
            algorithm: "R U' R U R U R U' R' U' R2",
            moveCount: 14,
          ),
        ],
      ),
    ],
  ),

  // ============ PLL T-Perm ============
  CubeScanResult(
    visible27: [
      'W', 'W', 'W', 'W', 'W', 'W', 'W', 'W', 'W',
      'R', 'R', 'B', 'R', 'R', 'R', 'R', 'R', 'R',
      'R', 'B', 'B', 'B', 'B', 'B', 'B', 'B', 'B',
    ],
    state54: {
      'U': ['W', 'W', 'W', 'W', 'W', 'W', 'W', 'W', 'W'],
      'F': ['R', 'R', 'B', 'R', 'R', 'R', 'R', 'R', 'R'],
      'R': ['R', 'B', 'B', 'B', 'B', 'B', 'B', 'B', 'B'],
      'D': ['Y', 'Y', 'Y', 'Y', 'Y', 'Y', 'Y', 'Y', 'Y'],
      'B': ['O', 'O', 'O', 'O', 'O', 'O', 'O', 'O', 'O'],
      'L': ['G', 'G', 'B', 'G', 'G', 'G', 'G', 'G', 'G'],
    },
    phase: 'pll',
    caseName: 'T-Perm',
    caseSet: 'PLL',
    confidence: 0.95,
    solvePaths: [
      SolvePath(
        description: 'T-Perm',
        totalMoves: 12,
        steps: [
          SolveStep(
            algorithmSet: 'PLL',
            caseName: 'T-Perm',
            algorithm: "R U R' U' R' F R2 U' R' U' R U R' F'",
            moveCount: 12,
          ),
        ],
      ),
    ],
  ),

  // ============ PLL H-Perm ============
  CubeScanResult(
    visible27: [
      'W', 'W', 'W', 'W', 'W', 'W', 'W', 'W', 'W',
      'B', 'R', 'B', 'R', 'R', 'R', 'R', 'R', 'R',
      'R', 'B', 'R', 'B', 'B', 'B', 'B', 'B', 'B',
    ],
    state54: {
      'U': ['W', 'W', 'W', 'W', 'W', 'W', 'W', 'W', 'W'],
      'F': ['B', 'R', 'B', 'R', 'R', 'R', 'R', 'R', 'R'],
      'R': ['R', 'B', 'R', 'B', 'B', 'B', 'B', 'B', 'B'],
      'D': ['Y', 'Y', 'Y', 'Y', 'Y', 'Y', 'Y', 'Y', 'Y'],
      'B': ['G', 'O', 'G', 'O', 'O', 'O', 'O', 'O', 'O'],
      'L': ['O', 'G', 'O', 'G', 'G', 'G', 'G', 'G', 'G'],
    },
    phase: 'pll',
    caseName: 'H-Perm',
    caseSet: 'PLL',
    confidence: 0.99,
    solvePaths: [
      SolvePath(
        description: 'H-Perm',
        totalMoves: 12,
        steps: [
          SolveStep(
            algorithmSet: 'PLL',
            caseName: 'H-Perm',
            algorithm: "M2 U M2 U2 M2 U M2",
            moveCount: 12,
          ),
        ],
      ),
    ],
  ),

  // ============ Solved State ============
  CubeScanResult(
    visible27: [
      'W', 'W', 'W', 'W', 'W', 'W', 'W', 'W', 'W',
      'R', 'R', 'R', 'R', 'R', 'R', 'R', 'R', 'R',
      'B', 'B', 'B', 'B', 'B', 'B', 'B', 'B', 'B',
    ],
    state54: {
      'U': ['W', 'W', 'W', 'W', 'W', 'W', 'W', 'W', 'W'],
      'F': ['R', 'R', 'R', 'R', 'R', 'R', 'R', 'R', 'R'],
      'R': ['B', 'B', 'B', 'B', 'B', 'B', 'B', 'B', 'B'],
      'D': ['Y', 'Y', 'Y', 'Y', 'Y', 'Y', 'Y', 'Y', 'Y'],
      'B': ['O', 'O', 'O', 'O', 'O', 'O', 'O', 'O', 'O'],
      'L': ['G', 'G', 'G', 'G', 'G', 'G', 'G', 'G', 'G'],
    },
    phase: 'solved',
    caseName: null,
    caseSet: null,
    confidence: 1.0,
    solvePaths: [],
  ),
];
