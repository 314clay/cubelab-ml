import 'dart:typed_data';

import 'package:cubelab/data/models/cube_scan_result.dart';
import 'package:cubelab/data/services/cube_analysis_service.dart';

/// Stub implementation returning hardcoded OLL 27 → T-Perm for UI testing.
class StubCubeAnalysisService implements CubeAnalysisService {
  @override
  Future<CubeScanResult> analyze(Uint8List imageBytes) async {
    // Simulate network/processing delay
    await Future<void>.delayed(const Duration(seconds: 2));

    return const CubeScanResult(
      visible27: [
        // U face: OLL 27 (Sune) pattern - corners misoriented
        'R', 'W', 'W', 'W', 'W', 'O', 'W', 'W', 'B',
        // F face: top row shows misoriented stickers
        'W', 'R', 'R', 'R', 'R', 'R', 'R', 'R', 'R',
        // R face: top row shows misoriented stickers
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
    );
  }

  @override
  Future<bool> isAvailable() async => true;
}
