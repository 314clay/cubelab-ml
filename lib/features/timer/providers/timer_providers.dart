import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cubelab/data/models/timer_session.dart';
import 'package:cubelab/data/models/timer_solve.dart';
import 'package:cubelab/data/models/user.dart';
import 'package:cubelab/data/repositories/timer_repository.dart';
import 'package:cubelab/shared/providers/repository_providers.dart';

enum TimerPhase { idle, scrambling, holding, solving, stopped }

class TimerState {
  final TimerPhase phase;
  final String currentScramble;
  final int elapsedMs;
  final TimerSession? session;
  final TimerStats? allTimeStats;
  final String? error;

  const TimerState({
    this.phase = TimerPhase.idle,
    this.currentScramble = '',
    this.elapsedMs = 0,
    this.session,
    this.allTimeStats,
    this.error,
  });

  TimerState copyWith({
    TimerPhase? phase,
    String? currentScramble,
    int? elapsedMs,
    TimerSession? session,
    TimerStats? allTimeStats,
    String? error,
  }) {
    return TimerState(
      phase: phase ?? this.phase,
      currentScramble: currentScramble ?? this.currentScramble,
      elapsedMs: elapsedMs ?? this.elapsedMs,
      session: session ?? this.session,
      allTimeStats: allTimeStats ?? this.allTimeStats,
      error: error ?? this.error,
    );
  }
}

class TimerNotifier extends StateNotifier<TimerState> {
  final TimerRepository? _repository;
  Stopwatch? _stopwatch;
  Timer? _updateTimer;
  final _random = Random();

  static const _faces = ['U', 'D', 'L', 'R', 'F', 'B'];
  static const _suffixes = ['', "'", '2'];

  TimerNotifier(TimerRepository repository)
      : _repository = repository,
        super(const TimerState()) {
    _initialize();
  }

  /// Creates a notifier in an error state when the repository can't be created
  TimerNotifier.errored(String error)
      : _repository = null,
        super(TimerState(
          error: error,
          currentScramble: '',
        ));

  Future<void> _initialize() async {
    if (_repository == null) return;
    try {
      final session = await _repository!.getTodaySession();
      final stats = await _repository!.getAllTimeStats();
      state = state.copyWith(
        phase: TimerPhase.idle,
        session: session,
        allTimeStats: stats,
        currentScramble: _generateScramble(),
      );
    } catch (_) {
      state = state.copyWith(
        phase: TimerPhase.idle,
        currentScramble: _generateScramble(),
      );
    }
  }

  String _generateScramble() {
    final moves = <String>[];
    String? lastFace;

    for (var i = 0; i < 20; i++) {
      String face;
      do {
        face = _faces[_random.nextInt(_faces.length)];
      } while (face == lastFace);

      final suffix = _suffixes[_random.nextInt(_suffixes.length)];
      moves.add('$face$suffix');
      lastFace = face;
    }

    return moves.join(' ');
  }

  void generateScramble() {
    state = state.copyWith(currentScramble: _generateScramble());
  }

  void startHolding() {
    if (state.phase == TimerPhase.idle) {
      state = state.copyWith(phase: TimerPhase.holding);
    }
  }

  void cancelHold() {
    if (state.phase == TimerPhase.holding) {
      state = state.copyWith(phase: TimerPhase.idle);
    }
  }

  void startTimer() {
    if (state.phase == TimerPhase.holding) {
      _stopwatch = Stopwatch()..start();
      state = state.copyWith(phase: TimerPhase.solving, elapsedMs: 0);

      _updateTimer = Timer.periodic(const Duration(milliseconds: 10), (_) {
        if (_stopwatch?.isRunning ?? false) {
          state = state.copyWith(elapsedMs: _stopwatch!.elapsedMilliseconds);
        }
      });
    }
  }

  Future<void> stopTimer() async {
    if (state.phase == TimerPhase.solving) {
      _stopwatch?.stop();
      _updateTimer?.cancel();
      final elapsed = _stopwatch?.elapsedMilliseconds ?? 0;

      state = state.copyWith(
        phase: TimerPhase.stopped,
        elapsedMs: elapsed,
      );

      // Save solve
      final sessionId = state.session?.id ?? 'session_${_dateKey(DateTime.now())}';
      final solve = TimerSolve(
        id: 'solve_${DateTime.now().millisecondsSinceEpoch}',
        sessionId: sessionId,
        timestamp: DateTime.now(),
        timeMs: elapsed,
        scramble: state.currentScramble,
      );

      try {
        await _repository!.saveSolve(solve);
        final session = await _repository!.getTodaySession();
        final stats = await _repository!.getAllTimeStats();
        state = state.copyWith(
          phase: TimerPhase.idle,
          session: session,
          allTimeStats: stats,
          currentScramble: _generateScramble(),
        );
      } catch (_) {
        // Still transition to idle even if save fails
        state = state.copyWith(
          phase: TimerPhase.idle,
          currentScramble: _generateScramble(),
        );
      }
    }
  }

  Future<void> deleteSolve(String id) async {
    if (_repository == null) return;
    try {
      await _repository!.deleteSolve(id);
      final session = await _repository!.getTodaySession();
      final stats = await _repository!.getAllTimeStats();
      state = state.copyWith(session: session, allTimeStats: stats);
    } catch (_) {
      // Silently fail
    }
  }

  Future<void> togglePenalty(String id, int? currentPenalty) async {
    final solve = state.session?.solves.firstWhere((s) => s.id == id);
    if (solve == null) return;

    int? newPenalty;
    if (currentPenalty == null) {
      newPenalty = 2; // none -> +2
    } else if (currentPenalty == 2) {
      newPenalty = -1; // +2 -> DNF
    } else {
      newPenalty = null; // DNF -> none
    }

    if (_repository == null) return;
    try {
      await _repository!.updateSolve(solve.copyWith(penalty: newPenalty));
      final session = await _repository!.getTodaySession();
      final stats = await _repository!.getAllTimeStats();
      state = state.copyWith(session: session, allTimeStats: stats);
    } catch (_) {
      // Silently fail
    }
  }

  String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }
}

final timerProvider =
    StateNotifierProvider<TimerNotifier, TimerState>((ref) {
  try {
    final repository = ref.watch(timerRepositoryProvider);
    return TimerNotifier(repository);
  } catch (e) {
    return TimerNotifier.errored(e.toString());
  }
});

final timerSessionProvider = FutureProvider<TimerSession>((ref) async {
  final repository = ref.watch(timerRepositoryProvider);
  return repository.getTodaySession();
});

final timerStatsProvider = FutureProvider<TimerStats>((ref) async {
  final repository = ref.watch(timerRepositoryProvider);
  return repository.getAllTimeStats();
});
