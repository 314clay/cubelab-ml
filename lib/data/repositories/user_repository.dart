import 'package:cubelab/data/models/algorithm.dart';
import 'package:cubelab/data/models/user.dart';

abstract class UserRepository {
  // ============ Auth State ============

  Future<AppUser?> getCurrentUser();

  Future<bool> isSignedIn();

  Stream<AppUser?> watchCurrentUser();

  // ============ Auth Actions ============

  Future<AppUser> signInWithGoogle();

  Future<AppUser> signInAnonymously();

  Future<void> signOut();

  Future<AppUser> linkAnonymousToGoogle();

  // ============ Profile ============

  Future<void> updateUsername(String username);

  Future<void> updateSettings(UserSettings settings);

  // ============ Onboarding ============

  Future<bool> hasCompletedOnboarding();

  Future<void> completeOnboarding({
    required int defaultPairsPlanning,
    required AlgorithmSet favoritedAlgSet,
  });

  Future<void> resetOnboarding();

  // ============ Timer Stats ============

  Future<TimerStats> getTimerStats();

  Future<void> updateTimerStats(TimerStats stats);

  // ============ Stats Snapshots ============

  Future<void> saveStatsSnapshot(StatsSnapshot snapshot);

  Future<List<StatsSnapshot>> getStatsSnapshots({int limit = 30});

  Future<StatsSnapshot?> getLatestSnapshot();
}
