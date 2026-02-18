import 'dart:typed_data';

import 'package:cubelab/data/models/cube_scan_result.dart';

/// Abstract interface for cube photo analysis.
/// Implementations may be remote (server) or local (on-device ML).
abstract class CubeAnalysisService {
  Future<CubeScanResult> analyze(Uint8List imageBytes);
  Future<bool> isAvailable();
}
