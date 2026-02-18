import 'package:cubelab/data/models/algorithm.dart';
import 'package:cubelab/data/models/algorithm_review.dart';
import 'package:cubelab/data/models/algorithm_solve.dart';
import 'package:cubelab/data/models/daily_algorithm_challenge.dart';
import 'package:cubelab/data/models/daily_challenge_attempt.dart';
import 'package:cubelab/data/models/srs_state.dart';
import 'package:cubelab/data/models/stats.dart';
import 'package:cubelab/data/models/training_session.dart';
import 'package:cubelab/data/models/training_solve.dart';
import 'package:cubelab/data/models/training_stats.dart';
import 'package:cubelab/data/models/user_algorithm.dart';
import 'package:cubelab/data/models/zbll_subset.dart';

abstract class AlgorithmRepository {
  // ============ Algorithm Catalog ============

  Future<List<Algorithm>> getAllAlgorithms();

  Future<List<Algorithm>> getAlgorithmsBySet(AlgorithmSet set);

  Future<List<Algorithm>> getAlgorithmsBySubset(
    AlgorithmSet set,
    String subset,
  );

  Future<Algorithm?> getAlgorithm(String id);

  Future<List<String>> getZBLLSubsets();

  Future<ZBLLStructure> getZBLLStructure();

  // ============ User Algorithms ============

  Future<List<UserAlgorithm>> getUserAlgorithms();

  Future<UserAlgorithm?> getUserAlgorithm(String algorithmId);

  Future<void> setAlgorithmEnabled(String algorithmId, bool enabled);

  Future<void> setCustomAlgorithm(String algorithmId, String? customAlg);

  Future<void> enableAllInSet(AlgorithmSet set);

  Future<void> disableAllInSet(AlgorithmSet set);

  Future<void> enableAllInSubset(AlgorithmSet set, String subset);

  Future<void> disableAllInSubset(AlgorithmSet set, String subset);

  // ============ Solves ============

  Future<void> saveSolve(AlgorithmSolve solve);

  Future<List<AlgorithmSolve>> getRecentSolves({int limit = 20});

  Future<List<AlgorithmSolve>> getSolvesForAlgorithm(
    String algorithmId, {
    int limit = 20,
  });

  // ============ Stats ============

  Future<AlgorithmStats> getStats({DateRange? range});

  Future<int> getLearnedCount(AlgorithmSet set);

  Future<int> getEnabledCount(AlgorithmSet set);

  Future<int> getDueCount();

  Future<List<DrillSession>> getDrillHistory({int limit = 10});

  Future<List<TrendDataPoint>> getPerformanceTrend({int limit = 30});

  // ============ SRS ============

  Future<List<UserAlgorithm>> getDueAlgorithms();

  Future<UserAlgorithm?> getNextDueAlgorithm();

  Future<void> recordReview(AlgorithmReview review);

  Future<List<AlgorithmReview>> getReviewHistory(
    String algorithmId, {
    int limit = 20,
  });

  // ============ Training Sessions ============

  Future<TrainingStats> getTrainingStats();

  Future<List<TrainingSession>> getRecentSessions({int limit = 5});

  Future<TrainingSession?> getCurrentSession();

  Future<void> saveSession(TrainingSession session);

  Future<void> saveTrainingSolve(TrainingSolve solve, String sessionId);

  // ============ Training Queue ============

  Future<List<Algorithm>> getDueTrainingCases();

  Future<List<Algorithm>> getRandomTrainingCases({int count = 20});

  Future<List<String>> getMultipleChoiceOptions(String algorithmId);

  Future<SRSRating> autoRatePerformance(String algorithmId, int totalTimeMs);

  // ============ Daily Challenges ============

  Future<DailyAlgorithmChallenge> getDailyAlgorithmChallenge(DateTime date);

  Future<void> saveDailyChallengeAttempt(DailyChallengeAttempt attempt);

  Future<List<DailyAlgorithmChallenge>> getRecentDailyChallenges({
    int limit = 7,
  });
}
