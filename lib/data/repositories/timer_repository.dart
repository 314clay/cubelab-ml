import 'package:cubelab/data/models/timer_session.dart';
import 'package:cubelab/data/models/timer_solve.dart';
import 'package:cubelab/data/models/user.dart';

abstract class TimerRepository {
  // ============ Sessions ============

  Future<TimerSession> getTodaySession();

  Stream<TimerSession> watchTodaySession();

  Future<List<TimerSession>> getRecentSessions({int limit = 7});

  // ============ Solves ============

  Future<void> saveSolve(TimerSolve solve);

  Future<void> updateSolve(TimerSolve solve);

  Future<void> deleteSolve(String solveId);

  Future<List<TimerSolve>> getAllSolves();

  // ============ Stats ============

  Future<TimerStats> getAllTimeStats();

  Stream<TimerStats> watchAllTimeStats();
}
