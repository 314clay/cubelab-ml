import 'package:cubelab/features/daily_scramble/providers/daily_scramble_providers.dart';

/// Re-exports daily scramble providers with home-specific names.
/// Used by DailyScrambleCard on the home page.
final todaysChallengeProvider = todaysScrambleProvider;
final dailyScrambleCompletedProvider = hasCompletedTodayProvider;
