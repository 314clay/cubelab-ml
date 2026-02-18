import 'package:cubelab/data/models/cube_scan_encounter.dart';
import 'package:cubelab/data/repositories/cube_scan_repository.dart';

/// In-memory stub implementation for Cube Scan history.
class StubCubeScanRepository implements CubeScanRepository {
  final List<CubeScanEncounter> _encounters = [];

  @override
  Future<void> saveEncounter(CubeScanEncounter encounter) async {
    _encounters.add(encounter);
  }

  @override
  Future<List<CubeScanEncounter>> getRecentEncounters(String userId) async {
    return _encounters
        .where((e) => e.userId == userId)
        .toList()
      ..sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
  }
}
