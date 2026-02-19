import 'package:cubelab/data/models/cube_scan_encounter.dart';

/// Abstract interface for Cube Scan history persistence.
abstract class CubeScanRepository {
  Future<void> saveEncounter(CubeScanEncounter encounter);
  Future<List<CubeScanEncounter>> getRecentEncounters(String userId);
}
