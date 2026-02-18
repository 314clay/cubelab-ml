import 'package:cubelab/data/models/cross_session.dart';
import 'package:cubelab/data/models/cross_solve.dart';
import 'package:cubelab/data/models/cross_srs_item.dart';
import 'package:cubelab/data/models/stats.dart';

abstract class CrossTrainerRepository {
  // ============ Session Management ============

  Future<CrossSession?> getActiveSession();

  Future<CrossSession> startSession();

  Future<void> endSession(String sessionId);

  // ============ Solves ============

  Future<void> saveSolve(CrossSolve solve);

  Future<List<CrossSolve>> getRecentSolves({int limit = 10});

  Future<List<CrossSolve>> getSolvesBySession(String sessionId);

  // ============ Stats ============

  Future<CrossStats> getStats({DateRange? range});

  Future<List<CrossSession>> getSessionHistory({int limit = 20});

  // ============ Scrambles ============

  Future<String> generateScramble({required int moves});

  Future<List<String>> getScramblePool();

  // ============ SRS Items ============

  Future<void> addSRSItem(CrossSRSItem item);

  Future<List<CrossSRSItem>> getActiveSRSItems();

  Future<CrossSRSItem?> getNextDueSRSItem();

  Future<void> updateSRSItem(CrossSRSItem item);

  Future<void> deleteSRSItem(String id);
}
