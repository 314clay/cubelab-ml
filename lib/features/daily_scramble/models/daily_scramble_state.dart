import 'package:cubelab/data/models/daily_challenge.dart';

/// Phase of the daily scramble solve flow
enum DailySolvePhase {
  /// Fetching today's challenge from repository
  loading,

  /// Ready to start (show scramble, timer at 0)
  notStarted,

  /// User is holding screen (visual feedback state)
  holding,

  /// Timer running - solve in progress
  solving,

  /// Timer stopped - ready to submit
  stopped,

  /// User already completed today's challenge
  alreadyCompleted,
}

/// State for the daily scramble solve flow
class DailyScrambleState {
  /// Current phase of the solve flow
  final DailySolvePhase phase;

  /// Today's challenge data
  final DailyChallenge? challenge;

  /// Elapsed time in milliseconds
  final int elapsedMs;

  /// User's solve if already completed today
  final DailyScrambleSolve? userSolve;

  /// Error message if something went wrong
  final String? error;

  const DailyScrambleState({
    required this.phase,
    this.challenge,
    this.elapsedMs = 0,
    this.userSolve,
    this.error,
  });

  /// Initial state - loading
  factory DailyScrambleState.initial() {
    return const DailyScrambleState(
      phase: DailySolvePhase.loading,
    );
  }

  /// Create a copy with updated fields
  DailyScrambleState copyWith({
    DailySolvePhase? phase,
    DailyChallenge? challenge,
    int? elapsedMs,
    DailyScrambleSolve? userSolve,
    String? error,
  }) {
    return DailyScrambleState(
      phase: phase ?? this.phase,
      challenge: challenge ?? this.challenge,
      elapsedMs: elapsedMs ?? this.elapsedMs,
      userSolve: userSolve ?? this.userSolve,
      error: error ?? this.error,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyScrambleState &&
          runtimeType == other.runtimeType &&
          phase == other.phase &&
          challenge == other.challenge &&
          elapsedMs == other.elapsedMs &&
          userSolve == other.userSolve &&
          error == other.error;

  @override
  int get hashCode =>
      phase.hashCode ^
      challenge.hashCode ^
      elapsedMs.hashCode ^
      userSolve.hashCode ^
      error.hashCode;

  @override
  String toString() {
    return 'DailyScrambleState(phase: $phase, elapsedMs: $elapsedMs, '
        'hasChallenge: ${challenge != null}, hasUserSolve: ${userSolve != null}, '
        'error: $error)';
  }
}
