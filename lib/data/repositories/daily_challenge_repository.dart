import 'package:cubelab/data/models/algorithm_solve.dart';
import 'package:cubelab/data/models/daily_challenge.dart';
import 'package:cubelab/data/models/pro_solve.dart';
import 'package:cubelab/data/models/solve_comment.dart';

abstract class DailyChallengeRepository {
  // ============ Daily Challenge ============

  Future<DailyChallenge> getTodaysChallenge();

  Future<DailyChallenge?> getChallengeForDate(DateTime date);

  // ============ Daily Scramble ============

  Future<bool> hasCompletedDailyScramble(DateTime date);

  Future<void> saveDailyScrambleSolve(DailyScrambleSolve solve);

  Future<DailyScrambleSolve?> getDailyScrambleSolve(DateTime date);

  // ============ Daily Algorithm ============

  Future<bool> hasCompletedDailyAlgorithm(DateTime date);

  Future<void> saveDailyAlgorithmSolve(AlgorithmSolve solve);

  Future<AlgorithmSolve?> getDailyAlgorithmSolve(DateTime date);

  // ============ Pro Solves ============

  Future<ProSolve?> getProSolveForScramble(String scramble);

  Future<List<ProSolve>> getAllProSolvesForScramble(String scramble);

  // ============ Community Solves ============

  Future<List<DailyScrambleSolve>> getCommunitySolves(
    DateTime date, {
    int limit = 20,
  });

  Future<int> getCommunityCount(DateTime date);

  // ============ Comments ============

  Future<List<SolveComment>> getCommentsForSolve(String solveId);

  Future<int> getCommentCount(String solveId);

  Future<void> addComment(SolveComment comment);
}
