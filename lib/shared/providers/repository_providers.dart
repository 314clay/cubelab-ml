import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cubelab/data/repositories/algorithm_repository.dart';
import 'package:cubelab/data/repositories/cross_trainer_repository.dart';
import 'package:cubelab/data/repositories/daily_challenge_repository.dart';
import 'package:cubelab/data/repositories/leaderboard_repository.dart';
import 'package:cubelab/data/repositories/profile_repository.dart';
import 'package:cubelab/data/repositories/timer_repository.dart';
import 'package:cubelab/data/repositories/user_repository.dart';

import 'package:cubelab/data/stubs/stub_profile_repository.dart';
import 'package:cubelab/data/supabase/supabase_algorithm_repository.dart';
import 'package:cubelab/data/supabase/supabase_cross_trainer_repository.dart';
import 'package:cubelab/data/supabase/supabase_daily_challenge_repository.dart';
import 'package:cubelab/data/supabase/supabase_leaderboard_repository.dart';
import 'package:cubelab/data/supabase/supabase_timer_repository.dart';
import 'package:cubelab/data/supabase/supabase_user_repository.dart';
import 'package:cubelab/shared/providers/supabase_providers.dart';

/// Cross trainer repository provider
/// Uses Supabase for cloud persistence
final crossTrainerRepositoryProvider = Provider<CrossTrainerRepository>((ref) {
  return SupabaseCrossTrainerRepository(ref.watch(supabaseClientProvider));
});

/// Algorithm repository provider
/// Uses Supabase for user data, JSON assets for algorithm catalog
final algorithmRepositoryProvider = Provider<AlgorithmRepository>((ref) {
  return SupabaseAlgorithmRepository(ref.watch(supabaseClientProvider));
});

/// Daily challenge repository provider
/// Uses Supabase for cloud persistence and community features
final dailyChallengeRepositoryProvider =
    Provider<DailyChallengeRepository>((ref) {
  return SupabaseDailyChallengeRepository(ref.watch(supabaseClientProvider));
});

/// Leaderboard repository provider
/// Uses Supabase for global leaderboards
final leaderboardRepositoryProvider = Provider<LeaderboardRepository>((ref) {
  return SupabaseLeaderboardRepository(ref.watch(supabaseClientProvider));
});

/// User repository provider
final userRepositoryProvider = Provider<UserRepository>((ref) {
  return SupabaseUserRepository(ref.watch(supabaseClientProvider));
});

/// Timer repository provider
/// Uses Supabase for cloud persistence with real-time sync
final timerRepositoryProvider = Provider<TimerRepository>((ref) {
  return SupabaseTimerRepository(ref.watch(supabaseClientProvider));
});

/// Profile repository provider
/// Aggregates data from multiple repositories for profile stats and achievements
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return StubProfileRepository(
    userRepository: ref.watch(userRepositoryProvider),
    timerRepository: ref.watch(timerRepositoryProvider),
    algorithmRepository: ref.watch(algorithmRepositoryProvider),
    crossTrainerRepository: ref.watch(crossTrainerRepositoryProvider),
  );
  // TODO: return CompositeProfileRepository(...) when backends are ready
});
