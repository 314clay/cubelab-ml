import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cubelab/data/models/cross_session.dart';
import 'package:cubelab/data/models/cross_solve.dart';
import 'package:cubelab/data/models/cross_srs_item.dart';
import 'package:cubelab/data/models/stats.dart';
import 'package:cubelab/data/repositories/cross_trainer_repository.dart';
import 'package:cubelab/shared/providers/repository_providers.dart';

/// Phase of the cross practice flow
enum CrossPracticePhase {
  idle,
  inspecting,
  executing,
  reviewing,
}

/// State for cross practice
class CrossPracticeState {
  final String? currentScramble;
  final String crossColor;
  final int pairsAttempting;
  final CrossPracticePhase phase;
  final int inspectionTimeMs;
  final int executionTimeMs;
  final CrossSession? session;
  final String? error;

  const CrossPracticeState({
    this.currentScramble,
    this.crossColor = 'white',
    this.pairsAttempting = 1,
    this.phase = CrossPracticePhase.idle,
    this.inspectionTimeMs = 0,
    this.executionTimeMs = 0,
    this.session,
    this.error,
  });

  CrossPracticeState copyWith({
    String? currentScramble,
    String? crossColor,
    int? pairsAttempting,
    CrossPracticePhase? phase,
    int? inspectionTimeMs,
    int? executionTimeMs,
    CrossSession? session,
    String? error,
  }) {
    return CrossPracticeState(
      currentScramble: currentScramble ?? this.currentScramble,
      crossColor: crossColor ?? this.crossColor,
      pairsAttempting: pairsAttempting ?? this.pairsAttempting,
      phase: phase ?? this.phase,
      inspectionTimeMs: inspectionTimeMs ?? this.inspectionTimeMs,
      executionTimeMs: executionTimeMs ?? this.executionTimeMs,
      session: session ?? this.session,
      error: error ?? this.error,
    );
  }
}

/// State notifier for cross practice flow
class CrossPracticeNotifier extends StateNotifier<CrossPracticeState> {
  final CrossTrainerRepository? _repository;
  Stopwatch? _stopwatch;
  Timer? _updateTimer;

  CrossPracticeNotifier(CrossTrainerRepository repository)
      : _repository = repository,
        super(const CrossPracticeState()) {
    generateNewScramble();
  }

  /// Creates a notifier in an error state when the repository can't be created
  CrossPracticeNotifier.errored(String error)
      : _repository = null,
        super(CrossPracticeState(error: error));

  /// Generate a new scramble from the repository
  Future<void> generateNewScramble() async {
    if (_repository == null) return;
    try {
      final scramble = await _repository!.generateScramble(moves: 25);
      state = CrossPracticeState(
        currentScramble: scramble,
        crossColor: state.crossColor,
        pairsAttempting: state.pairsAttempting,
        session: state.session,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Set difficulty level (1-4 pairs)
  void setPairsAttempting(int pairs) {
    if (pairs >= 1 && pairs <= 4) {
      state = state.copyWith(pairsAttempting: pairs);
    }
  }

  /// Start inspection phase — user studies the scramble
  void startInspection() {
    if (state.phase != CrossPracticePhase.idle) return;
    _stopwatch = Stopwatch()..start();
    state = state.copyWith(
      phase: CrossPracticePhase.inspecting,
      inspectionTimeMs: 0,
    );
    _updateTimer = Timer.periodic(const Duration(milliseconds: 10), (_) {
      if (_stopwatch?.isRunning ?? false) {
        state = state.copyWith(inspectionTimeMs: _stopwatch!.elapsedMilliseconds);
      }
    });
  }

  /// Transition from inspection to execution phase
  void startExecution() {
    if (state.phase != CrossPracticePhase.inspecting) return;
    _stopwatch?.stop();
    _updateTimer?.cancel();
    final inspectionMs = _stopwatch?.elapsedMilliseconds ?? 0;

    _stopwatch = Stopwatch()..start();
    state = state.copyWith(
      phase: CrossPracticePhase.executing,
      inspectionTimeMs: inspectionMs,
      executionTimeMs: 0,
    );
    _updateTimer = Timer.periodic(const Duration(milliseconds: 10), (_) {
      if (_stopwatch?.isRunning ?? false) {
        state = state.copyWith(executionTimeMs: _stopwatch!.elapsedMilliseconds);
      }
    });
  }

  /// Stop execution and enter review phase
  void stopExecution() {
    if (state.phase != CrossPracticePhase.executing) return;
    _stopwatch?.stop();
    _updateTimer?.cancel();
    state = state.copyWith(
      phase: CrossPracticePhase.reviewing,
      executionTimeMs: _stopwatch?.elapsedMilliseconds ?? 0,
    );
  }

  /// Record a successful solve and save it
  Future<void> recordSuccess() async {
    if (state.phase != CrossPracticePhase.reviewing) return;
    await _saveSolve(success: true);
    await generateNewScramble();
  }

  /// Record a failed solve and save it
  Future<void> recordFail() async {
    if (state.phase != CrossPracticePhase.reviewing) return;
    await _saveSolve(success: false);
    await generateNewScramble();
  }

  Future<void> _saveSolve({required bool success}) async {
    if (state.currentScramble == null || _repository == null) return;
    try {
      final solve = CrossSolve(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: '',
        scramble: state.currentScramble!,
        difficulty: state.pairsAttempting,
        crossColor: state.crossColor,
        pairsAttempting: state.pairsAttempting,
        pairsPlanned: state.pairsAttempting,
        crossSuccess: success,
        inspectionTimeMs: state.inspectionTimeMs,
        executionTimeMs: state.executionTimeMs,
        sessionId: state.session?.id,
        createdAt: DateTime.now(),
      );
      await _repository!.saveSolve(solve);
    } catch (_) {
      // Best-effort save; don't block the UI
    }
  }

  /// Start a new training session
  Future<void> startSession() async {
    if (_repository == null) return;
    try {
      final session = await _repository!.startSession();
      state = state.copyWith(session: session);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// End the current training session
  Future<void> endSession() async {
    if (state.session == null || _repository == null) return;
    try {
      await _repository!.endSession(state.session!.id);
      state = CrossPracticeState(
        currentScramble: state.currentScramble,
        crossColor: state.crossColor,
        pairsAttempting: state.pairsAttempting,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }
}

/// Provider for cross practice state
final crossPracticeProvider =
    StateNotifierProvider<CrossPracticeNotifier, CrossPracticeState>((ref) {
  try {
    final repository = ref.watch(crossTrainerRepositoryProvider);
    return CrossPracticeNotifier(repository);
  } catch (e) {
    return CrossPracticeNotifier.errored(e.toString());
  }
});

/// Provider for cross training stats
final crossStatsProvider = FutureProvider<CrossStats>((ref) async {
  final repository = ref.watch(crossTrainerRepositoryProvider);
  return repository.getStats();
});

/// Provider for active SRS items
final crossSRSProvider = FutureProvider<List<CrossSRSItem>>((ref) async {
  final repository = ref.watch(crossTrainerRepositoryProvider);
  return repository.getActiveSRSItems();
});

/// Provider for the next due SRS item
final nextSRSItemProvider = FutureProvider<CrossSRSItem?>((ref) async {
  final repository = ref.watch(crossTrainerRepositoryProvider);
  return repository.getNextDueSRSItem();
});
