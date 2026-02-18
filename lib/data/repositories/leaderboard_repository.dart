import 'package:cubelab/data/models/algorithm.dart';
import 'package:cubelab/data/models/leaderboard.dart';

abstract class LeaderboardRepository {
  // ============ Cross Leaderboard ============

  Future<CrossLeaderboard> getCrossLeaderboard({
    required int level,
    int limit = 50,
  });

  Future<int?> getUserCrossRank(int level);

  // ============ Algorithm Leaderboards ============

  Future<AlgorithmLeaderboard> getAlgorithmTimeLeaderboard({
    required AlgorithmSet set,
    int limit = 50,
  });

  Future<AlgorithmLeaderboard> getAlgorithmCountLeaderboard({
    int limit = 50,
  });

  Future<int?> getUserAlgorithmTimeRank(AlgorithmSet set);

  Future<int?> getUserAlgorithmCountRank();

  // ============ Eligibility ============

  Future<bool> isEligibleForAlgorithmLeaderboard(AlgorithmSet set);

  Future<Map<AlgorithmSet, bool>> getAllEligibility();
}
