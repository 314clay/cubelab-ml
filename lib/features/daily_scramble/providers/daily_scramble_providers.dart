import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cubelab/data/models/daily_challenge.dart';
import 'package:cubelab/data/repositories/daily_challenge_repository.dart';
import 'package:cubelab/features/daily_scramble/models/daily_scramble_state.dart';
import 'package:cubelab/shared/providers/repository_providers.dart';

/// State notifier for daily scramble solve flow
class DailyScrambleNotifier extends StateNotifier<DailyScrambleState> {
  final DailyChallengeRepository? _repository;
  Stopwatch? _stopwatch;
  Timer? _updateTimer;

  DailyScrambleNotifier(DailyChallengeRepository repository)
      : _repository = repository,
        super(DailyScrambleState.initial()) {
    _initialize();
  }

  /// Creates a notifier in an error state when the repository can't be created
  DailyScrambleNotifier.errored(String error)
      : _repository = null,
        super(DailyScrambleState(
          phase: DailySolvePhase.notStarted,
          error: error,
        ));

  /// Load today's challenge and check completion status
  Future<void> _initialize() async {
    if (_repository == null) return;
    state = state.copyWith(phase: DailySolvePhase.loading);

    try {
      final challenge = await _repository!.getTodaysChallenge();
      final today = DateTime.now();
      final hasCompleted = await _repository!.hasCompletedDailyScramble(today);

      if (hasCompleted) {
        final userSolve = await _repository!.getDailyScrambleSolve(today);
        state = state.copyWith(
          phase: DailySolvePhase.alreadyCompleted,
          challenge: challenge,
          userSolve: userSolve,
        );
      } else {
        state = state.copyWith(
          phase: DailySolvePhase.notStarted,
          challenge: challenge,
        );
      }
    } catch (e) {
      state = state.copyWith(
        phase: DailySolvePhase.notStarted,
        error: e.toString(),
      );
    }
  }

  /// Start holding (visual feedback)
  void startHolding() {
    if (state.phase == DailySolvePhase.notStarted) {
      state = state.copyWith(phase: DailySolvePhase.holding);
    }
  }

  /// Cancel hold
  void cancelHold() {
    if (state.phase == DailySolvePhase.holding) {
      state = state.copyWith(phase: DailySolvePhase.notStarted);
    }
  }

  /// Start timer (on release)
  void startTimer() {
    if (state.phase == DailySolvePhase.holding) {
      _stopwatch = Stopwatch()..start();
      state = state.copyWith(phase: DailySolvePhase.solving, elapsedMs: 0);

      // Update every 10ms
      _updateTimer = Timer.periodic(const Duration(milliseconds: 10), (_) {
        if (_stopwatch?.isRunning ?? false) {
          state = state.copyWith(elapsedMs: _stopwatch!.elapsedMilliseconds);
        }
      });
    }
  }

  /// Stop timer
  void stopTimer() {
    if (state.phase == DailySolvePhase.solving) {
      _stopwatch?.stop();
      _updateTimer?.cancel();
      state = state.copyWith(
        phase: DailySolvePhase.stopped,
        elapsedMs: _stopwatch?.elapsedMilliseconds ?? 0,
      );
    }
  }

  /// Reset for new attempt (if user cancels submission)
  void reset() {
    _stopwatch = null;
    _updateTimer?.cancel();
    state = state.copyWith(
      phase: DailySolvePhase.notStarted,
      elapsedMs: 0,
    );
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }
}

/// Provider for daily scramble state
final dailyScrambleProvider =
    StateNotifierProvider<DailyScrambleNotifier, DailyScrambleState>((ref) {
  try {
    final repository = ref.watch(dailyChallengeRepositoryProvider);
    return DailyScrambleNotifier(repository);
  } catch (e) {
    return DailyScrambleNotifier.errored(e.toString());
  }
});

/// Provider for today's challenge (convenience)
final todaysScrambleProvider = FutureProvider<DailyChallenge>((ref) async {
  final repository = ref.watch(dailyChallengeRepositoryProvider);
  return repository.getTodaysChallenge();
});

/// Provider for completion status
final hasCompletedTodayProvider = FutureProvider<bool>((ref) async {
  final repository = ref.watch(dailyChallengeRepositoryProvider);
  final today = DateTime.now();
  return repository.hasCompletedDailyScramble(today);
});

/// Provider for community solve count
final communitySolveCountProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(dailyChallengeRepositoryProvider);
  final today = DateTime.now();
  return repository.getCommunityCount(today);
});
