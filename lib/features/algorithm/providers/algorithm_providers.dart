import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cubelab/data/models/algorithm.dart';
import 'package:cubelab/data/models/stats.dart';
import 'package:cubelab/data/models/training_stats.dart';
import 'package:cubelab/data/models/user_algorithm.dart';
import 'package:cubelab/data/models/srs_state.dart';
import 'package:cubelab/data/models/algorithm_review.dart';
import 'package:cubelab/data/repositories/algorithm_repository.dart';
import 'package:cubelab/shared/providers/repository_providers.dart';

// ============ Filter State ============

/// Currently selected algorithm set filter for the catalog
final selectedAlgorithmSetProvider = StateProvider<AlgorithmSet?>((ref) => null);

// ============ Catalog Providers ============

/// All algorithms, optionally filtered by the selected set
final algorithmCatalogProvider = FutureProvider<List<Algorithm>>((ref) async {
  final repository = ref.watch(algorithmRepositoryProvider);
  final selectedSet = ref.watch(selectedAlgorithmSetProvider);

  if (selectedSet != null) {
    return repository.getAlgorithmsBySet(selectedSet);
  }
  return repository.getAllAlgorithms();
});

/// User algorithm states (enabled, learned, SRS data)
final userAlgorithmsProvider = FutureProvider<List<UserAlgorithm>>((ref) async {
  final repository = ref.watch(algorithmRepositoryProvider);
  return repository.getUserAlgorithms();
});

// ============ Stats Providers ============

/// Aggregate algorithm statistics
final algorithmStatsProvider = FutureProvider<AlgorithmStats>((ref) async {
  final repository = ref.watch(algorithmRepositoryProvider);
  return repository.getStats();
});

/// Training stats overview
final trainingStatsProvider = FutureProvider<TrainingStats>((ref) async {
  final repository = ref.watch(algorithmRepositoryProvider);
  return repository.getTrainingStats();
});

// ============ SRS Providers ============

/// Algorithms due for SRS review
final dueAlgorithmsProvider = FutureProvider<List<UserAlgorithm>>((ref) async {
  final repository = ref.watch(algorithmRepositoryProvider);
  return repository.getDueAlgorithms();
});

// ============ Training State ============

enum TrainingPhase { idle, showing, timing, reviewing }

class TrainingState {
  final Algorithm? currentAlgorithm;
  final TrainingPhase phase;
  final int timeMs;
  final String? sessionId;
  final int casesCompleted;
  final int casesCorrect;
  final String? error;

  const TrainingState({
    this.currentAlgorithm,
    this.phase = TrainingPhase.idle,
    this.timeMs = 0,
    this.sessionId,
    this.casesCompleted = 0,
    this.casesCorrect = 0,
    this.error,
  });

  TrainingState copyWith({
    Algorithm? currentAlgorithm,
    TrainingPhase? phase,
    int? timeMs,
    String? sessionId,
    int? casesCompleted,
    int? casesCorrect,
    String? error,
  }) {
    return TrainingState(
      currentAlgorithm: currentAlgorithm ?? this.currentAlgorithm,
      phase: phase ?? this.phase,
      timeMs: timeMs ?? this.timeMs,
      sessionId: sessionId ?? this.sessionId,
      casesCompleted: casesCompleted ?? this.casesCompleted,
      casesCorrect: casesCorrect ?? this.casesCorrect,
      error: error ?? this.error,
    );
  }
}

// ============ Training Notifier ============

class TrainingNotifier extends StateNotifier<TrainingState> {
  final AlgorithmRepository? _repository;
  Stopwatch? _stopwatch;
  Timer? _updateTimer;
  List<Algorithm> _queue = [];

  TrainingNotifier(AlgorithmRepository repository)
      : _repository = repository,
        super(const TrainingState());

  TrainingNotifier.errored(String error)
      : _repository = null,
        super(TrainingState(error: error));

  /// Start a new training session: fetch cases and show the first one
  Future<void> startTraining() async {
    if (_repository == null) return;
    _queue = await _repository!.getRandomTrainingCases(count: 20);
    if (_queue.isEmpty) return;

    final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    state = TrainingState(
      currentAlgorithm: _queue.removeAt(0),
      phase: TrainingPhase.showing,
      sessionId: sessionId,
    );
  }

  /// User recognizes the case -- show it and let them prepare
  void showCase() {
    state = state.copyWith(phase: TrainingPhase.showing);
  }

  /// Start the execution timer
  void startTimer() {
    _stopwatch = Stopwatch()..start();
    state = state.copyWith(phase: TrainingPhase.timing, timeMs: 0);

    _updateTimer = Timer.periodic(const Duration(milliseconds: 10), (_) {
      if (_stopwatch?.isRunning ?? false) {
        state = state.copyWith(timeMs: _stopwatch!.elapsedMilliseconds);
      }
    });
  }

  /// Stop the timer and move to review phase
  void stopTimer() {
    _stopwatch?.stop();
    _updateTimer?.cancel();
    state = state.copyWith(
      phase: TrainingPhase.reviewing,
      timeMs: _stopwatch?.elapsedMilliseconds ?? 0,
    );
  }

  /// Rate performance and advance to next case
  Future<void> ratePerformance(SRSRating rating) async {
    final alg = state.currentAlgorithm;
    if (alg == null) return;

    final isCorrect = rating == SRSRating.good || rating == SRSRating.easy;
    final completed = state.casesCompleted + 1;
    final correct = state.casesCorrect + (isCorrect ? 1 : 0);

    // Record the review
    final review = AlgorithmReview(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: '',
      userAlgorithmId: alg.id,
      rating: rating,
      timeMs: state.timeMs,
      stateBefore: SRSState.initial(),
      stateAfter: SRSState.initial(),
      createdAt: DateTime.now(),
    );

    try {
      await _repository!.recordReview(review);
    } catch (_) {
      // Continue even if recording fails
    }

    // Advance to next case or finish
    if (_queue.isNotEmpty) {
      state = state.copyWith(
        currentAlgorithm: _queue.removeAt(0),
        phase: TrainingPhase.showing,
        timeMs: 0,
        casesCompleted: completed,
        casesCorrect: correct,
      );
    } else {
      state = TrainingState(
        phase: TrainingPhase.idle,
        casesCompleted: completed,
        casesCorrect: correct,
        sessionId: state.sessionId,
      );
    }
  }

  /// Reset training session
  void reset() {
    _stopwatch = null;
    _updateTimer?.cancel();
    _queue = [];
    state = const TrainingState();
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }
}

/// Provider for training state
final trainingProvider =
    StateNotifierProvider<TrainingNotifier, TrainingState>((ref) {
  try {
    final repository = ref.watch(algorithmRepositoryProvider);
    return TrainingNotifier(repository);
  } catch (e) {
    return TrainingNotifier.errored(e.toString());
  }
});
