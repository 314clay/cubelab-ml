import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cubelab/data/models/algorithm.dart';
import 'package:cubelab/data/models/algorithm_case.dart';
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
import 'package:cubelab/data/repositories/algorithm_repository.dart';
import 'package:cubelab/data/stubs/json_loader.dart';

/// Supabase implementation of AlgorithmRepository
///
/// Algorithm catalog (static data) comes from JSON assets.
/// User-specific data (progress, solves, reviews) is persisted to Supabase.
class SupabaseAlgorithmRepository implements AlgorithmRepository {
  final SupabaseClient _client;
  final _random = Random();

  // Cached algorithm catalog from JSON
  List<Algorithm>? _algorithms;
  ZBLLStructure? _zbllStructure;

  // In-memory training session
  TrainingSession? _currentSession;

  SupabaseAlgorithmRepository(this._client);

  String? get _userId => _client.auth.currentUser?.id;

  // ============ Load Static Data from JSON ============

  Future<List<Algorithm>> _loadAlgorithms() async {
    if (_algorithms != null) return _algorithms!;

    final pllJson = await JsonLoader.loadJsonList('algorithms/pll.json');
    final ollJson = await JsonLoader.loadJsonList('algorithms/oll.json');
    final zbllJson = await JsonLoader.loadJsonList('algorithms/zbll.json');

    _algorithms = [
      ...pllJson.map((json) => Algorithm.fromJson(json as Map<String, dynamic>)),
      ...ollJson.map((json) => Algorithm.fromJson(json as Map<String, dynamic>)),
      ...zbllJson.map((json) => Algorithm.fromJson(json as Map<String, dynamic>)),
    ];
    return _algorithms!;
  }

  Future<ZBLLStructure> _loadZBLLStructure() async {
    if (_zbllStructure != null) return _zbllStructure!;

    final json = await JsonLoader.loadJson('algorithms/zbll_structure.json');
    _zbllStructure = ZBLLStructure.fromJson(json);
    return _zbllStructure!;
  }

  // ============ Algorithm Catalog (from JSON) ============

  @override
  Future<List<Algorithm>> getAllAlgorithms() async {
    return await _loadAlgorithms();
  }

  @override
  Future<List<Algorithm>> getAlgorithmsBySet(AlgorithmSet set) async {
    final all = await _loadAlgorithms();
    return all.where((a) => a.set == set).toList();
  }

  @override
  Future<List<Algorithm>> getAlgorithmsBySubset(
    AlgorithmSet set,
    String subset,
  ) async {
    final all = await _loadAlgorithms();
    return all.where((a) => a.set == set && a.subset == subset).toList();
  }

  @override
  Future<Algorithm?> getAlgorithm(String id) async {
    final all = await _loadAlgorithms();
    try {
      return all.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<String>> getZBLLSubsets() async {
    final structure = await _loadZBLLStructure();
    return structure.subsets.map((s) => s.name).toList();
  }

  @override
  Future<ZBLLStructure> getZBLLStructure() async {
    return await _loadZBLLStructure();
  }

  // ============ User Algorithms (from Supabase) ============

  @override
  Future<List<UserAlgorithm>> getUserAlgorithms() async {
    final userId = _userId;
    if (userId == null) return [];

    final response = await _client
        .from('user_algorithms')
        .select()
        .eq('user_id', userId);

    return (response as List)
        .map((json) => _userAlgorithmFromSupabase(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<UserAlgorithm?> getUserAlgorithm(String algorithmId) async {
    final userId = _userId;
    if (userId == null) return null;

    final response = await _client
        .from('user_algorithms')
        .select()
        .eq('user_id', userId)
        .eq('algorithm_id', algorithmId)
        .maybeSingle();

    if (response == null) return null;
    return _userAlgorithmFromSupabase(response);
  }

  @override
  Future<void> setAlgorithmEnabled(String algorithmId, bool enabled) async {
    final userId = _userId;
    if (userId == null) return;

    await _client.from('user_algorithms').upsert({
      'user_id': userId,
      'algorithm_id': algorithmId,
      'enabled': enabled,
    }, onConflict: 'user_id,algorithm_id');
  }

  @override
  Future<void> setCustomAlgorithm(String algorithmId, String? customAlg) async {
    final userId = _userId;
    if (userId == null) return;

    await _client.from('user_algorithms').upsert({
      'user_id': userId,
      'algorithm_id': algorithmId,
      'custom_alg': customAlg,
    }, onConflict: 'user_id,algorithm_id');
  }

  @override
  Future<void> enableAllInSet(AlgorithmSet set) async {
    final userId = _userId;
    if (userId == null) return;

    final algorithms = await getAlgorithmsBySet(set);
    final batch = algorithms.map((a) => {
      'user_id': userId,
      'algorithm_id': a.id,
      'enabled': true,
    }).toList();

    // Upsert all at once
    await _client.from('user_algorithms').upsert(batch, onConflict: 'user_id,algorithm_id');
  }

  @override
  Future<void> disableAllInSet(AlgorithmSet set) async {
    final userId = _userId;
    if (userId == null) return;

    final algorithms = await getAlgorithmsBySet(set);
    final algorithmIds = algorithms.map((a) => a.id).toList();

    await _client
        .from('user_algorithms')
        .update({'enabled': false})
        .eq('user_id', userId)
        .inFilter('algorithm_id', algorithmIds);
  }

  @override
  Future<void> enableAllInSubset(AlgorithmSet set, String subset) async {
    final userId = _userId;
    if (userId == null) return;

    final algorithms = await getAlgorithmsBySubset(set, subset);
    final batch = algorithms.map((a) => {
      'user_id': userId,
      'algorithm_id': a.id,
      'enabled': true,
    }).toList();

    await _client.from('user_algorithms').upsert(batch, onConflict: 'user_id,algorithm_id');
  }

  @override
  Future<void> disableAllInSubset(AlgorithmSet set, String subset) async {
    final userId = _userId;
    if (userId == null) return;

    final algorithms = await getAlgorithmsBySubset(set, subset);
    final algorithmIds = algorithms.map((a) => a.id).toList();

    await _client
        .from('user_algorithms')
        .update({'enabled': false})
        .eq('user_id', userId)
        .inFilter('algorithm_id', algorithmIds);
  }

  UserAlgorithm _userAlgorithmFromSupabase(Map<String, dynamic> json) {
    return UserAlgorithm(
      userId: json['user_id'] as String,
      algorithmId: json['algorithm_id'] as String,
      enabled: json['enabled'] as bool? ?? false,
      customAlg: json['custom_alg'] as String?,
      isLearned: json['is_learned'] as bool? ?? false,
      srsState: SRSState(
        easeFactor: (json['ease_factor'] as num?)?.toDouble() ?? 2.5,
        interval: json['interval_days'] as int? ?? 0,
        repetitions: json['repetitions'] as int? ?? 0,
        nextReviewDate: json['next_review_date'] != null
            ? DateTime.parse(json['next_review_date'] as String)
            : null,
        stability: (json['stability'] as num?)?.toDouble() ?? 0,
        difficulty: (json['srs_difficulty'] as num?)?.toDouble() ?? 5.0,
        desiredRetention: (json['desired_retention'] as num?)?.toDouble() ?? 0.9,
        cardState: json['card_state'] != null
            ? SRSCardStateExtension.fromString(json['card_state'] as String)
            : SRSCardState.newCard,
        remainingSteps: json['remaining_steps'] as int?,
        learningDueAt: json['learning_due_at'] != null
            ? DateTime.parse(json['learning_due_at'] as String)
            : null,
        lapses: json['lapses'] as int? ?? 0,
        lastReviewedAt: json['last_reviewed_at'] != null
            ? DateTime.parse(json['last_reviewed_at'] as String)
            : null,
      ),
      lastReviewedAt: json['last_reviewed_at'] != null
          ? DateTime.parse(json['last_reviewed_at'] as String)
          : null,
      totalReviews: json['total_reviews'] as int? ?? 0,
    );
  }

  // ============ Solves ============

  @override
  Future<void> saveSolve(AlgorithmSolve solve) async {
    final userId = _userId;
    if (userId == null) return;

    await _client.from('algorithm_solves').insert({
      'id': solve.id,
      'user_id': userId,
      'algorithm_id': solve.algorithmId,
      'time_ms': solve.timeMs,
      'success': solve.success,
      'scramble': solve.scramble,
      'notes': solve.notes,
      'session_id': solve.sessionId,
      'created_at': solve.createdAt.toIso8601String(),
    });
  }

  @override
  Future<List<AlgorithmSolve>> getRecentSolves({int limit = 20}) async {
    final userId = _userId;
    if (userId == null) return [];

    final response = await _client
        .from('algorithm_solves')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);

    return (response as List)
        .map((json) => _algorithmSolveFromSupabase(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<AlgorithmSolve>> getSolvesForAlgorithm(
    String algorithmId, {
    int limit = 20,
  }) async {
    final userId = _userId;
    if (userId == null) return [];

    final response = await _client
        .from('algorithm_solves')
        .select()
        .eq('user_id', userId)
        .eq('algorithm_id', algorithmId)
        .order('created_at', ascending: false)
        .limit(limit);

    return (response as List)
        .map((json) => _algorithmSolveFromSupabase(json as Map<String, dynamic>))
        .toList();
  }

  AlgorithmSolve _algorithmSolveFromSupabase(Map<String, dynamic> json) {
    return AlgorithmSolve(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      algorithmId: json['algorithm_id'] as String,
      timeMs: json['time_ms'] as int,
      success: json['success'] as bool? ?? true,
      scramble: json['scramble'] as String?,
      notes: json['notes'] as String?,
      sessionId: json['session_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  // ============ Stats ============

  @override
  Future<AlgorithmStats> getStats({DateRange? range}) async {
    final userId = _userId;
    if (userId == null) return AlgorithmStats.empty();

    // Get user algorithms
    final userAlgorithms = await getUserAlgorithms();
    final algorithms = await _loadAlgorithms();

    // Calculate stats
    int totalLearned = userAlgorithms.where((ua) => ua.isLearned).length;
    int totalDrills = 0;
    int dueToday = 0;

    // Get solve count
    final solvesResponse = await _client
        .from('algorithm_solves')
        .select('id')
        .eq('user_id', userId);
    totalDrills = (solvesResponse as List).length;

    // Get due count
    final now = DateTime.now();
    dueToday = userAlgorithms
        .where((ua) =>
            ua.enabled &&
            ua.srsState?.nextReviewDate != null &&
            ua.srsState!.nextReviewDate!.isBefore(now))
        .length;

    // Calculate average time
    int avgTimeMs = 0;
    if (totalDrills > 0) {
      final recentSolves = await getRecentSolves(limit: 100);
      if (recentSolves.isNotEmpty) {
        avgTimeMs = recentSolves.fold<int>(0, (sum, s) => sum + s.timeMs) ~/
            recentSolves.length;
      }
    }

    // Stats by set
    final Map<AlgorithmSet, AlgorithmSetStats> bySet = {};
    for (final set in AlgorithmSet.values) {
      final setAlgorithms = algorithms.where((a) => a.set == set).toList();
      final setIds = setAlgorithms.map((a) => a.id).toSet();
      final setUserAlgs =
          userAlgorithms.where((ua) => setIds.contains(ua.algorithmId)).toList();

      final learned = setUserAlgs.where((ua) => ua.isLearned).length;
      final total = setAlgorithms.length;

      // Get average time for this set
      final setSolves = await _client
          .from('algorithm_solves')
          .select()
          .eq('user_id', userId)
          .inFilter('algorithm_id', setIds.toList())
          .limit(50);

      int setAvgTime = 0;
      if ((setSolves as List).isNotEmpty) {
        setAvgTime = setSolves
            .map((s) => s['time_ms'] as int)
            .reduce((a, b) => a + b) ~/
            setSolves.length;
      }

      bySet[set] = AlgorithmSetStats(
        set: set,
        learned: learned,
        total: total,
        avgTimeMs: setAvgTime,
      );
    }

    return AlgorithmStats(
      totalLearned: totalLearned,
      totalDrills: totalDrills,
      avgTimeMs: avgTimeMs,
      dueToday: dueToday,
      bySet: bySet,
      weakestCases: [], // TODO: Calculate weak cases
    );
  }

  @override
  Future<int> getLearnedCount(AlgorithmSet set) async {
    final userAlgorithms = await getUserAlgorithms();
    final algorithms = await getAlgorithmsBySet(set);
    final setIds = algorithms.map((a) => a.id).toSet();
    return userAlgorithms
        .where((ua) => setIds.contains(ua.algorithmId) && ua.isLearned)
        .length;
  }

  @override
  Future<int> getEnabledCount(AlgorithmSet set) async {
    final userAlgorithms = await getUserAlgorithms();
    final algorithms = await getAlgorithmsBySet(set);
    final setIds = algorithms.map((a) => a.id).toSet();
    return userAlgorithms
        .where((ua) => setIds.contains(ua.algorithmId) && ua.enabled)
        .length;
  }

  @override
  Future<int> getDueCount() async {
    final userAlgorithms = await getUserAlgorithms();
    final now = DateTime.now();
    return userAlgorithms
        .where((ua) =>
            ua.enabled &&
            ua.srsState?.nextReviewDate != null &&
            ua.srsState!.nextReviewDate!.isBefore(now))
        .length;
  }

  @override
  Future<List<DrillSession>> getDrillHistory({int limit = 10}) async {
    // TODO: Implement drill session history from training_sessions table
    return [];
  }

  @override
  Future<List<TrendDataPoint>> getPerformanceTrend({int limit = 30}) async {
    final userId = _userId;
    if (userId == null) return [];

    // Get solves grouped by day
    final response = await _client
        .from('algorithm_solves')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit * 10); // Get more to ensure we have enough days

    final solves = (response as List)
        .map((json) => _algorithmSolveFromSupabase(json as Map<String, dynamic>))
        .toList();

    // Group by day
    final Map<String, List<AlgorithmSolve>> byDay = {};
    for (final solve in solves) {
      final day = solve.createdAt.toIso8601String().split('T')[0];
      byDay.putIfAbsent(day, () => []).add(solve);
    }

    // Calculate average per day
    final trend = byDay.entries.take(limit).map((entry) {
      final avgMs = entry.value.fold<int>(0, (sum, s) => sum + s.timeMs) ~/
          entry.value.length;
      return TrendDataPoint(
        date: DateTime.parse(entry.key),
        avgTimeSeconds: avgMs / 1000.0,
      );
    }).toList();

    return trend;
  }

  // ============ SRS ============

  @override
  Future<List<UserAlgorithm>> getDueAlgorithms() async {
    final userAlgorithms = await getUserAlgorithms();
    final now = DateTime.now();
    return userAlgorithms
        .where((ua) =>
            ua.enabled &&
            ua.srsState?.nextReviewDate != null &&
            ua.srsState!.nextReviewDate!.isBefore(now))
        .toList();
  }

  @override
  Future<UserAlgorithm?> getNextDueAlgorithm() async {
    final due = await getDueAlgorithms();
    if (due.isEmpty) return null;
    due.sort((a, b) =>
        a.srsState!.nextReviewDate!.compareTo(b.srsState!.nextReviewDate!));
    return due.first;
  }

  @override
  Future<void> recordReview(AlgorithmReview review) async {
    final userId = _userId;
    if (userId == null) return;

    // Insert review record
    await _client.from('algorithm_reviews').insert({
      'id': review.id,
      'user_id': userId,
      'algorithm_id': review.userAlgorithmId,
      'rating': review.rating.name,
      'interval_days': review.stateAfter.interval,
      'ease_factor': review.stateAfter.easeFactor,
      'repetitions': review.stateAfter.repetitions,
      'created_at': review.createdAt.toIso8601String(),
    });

    // Update user algorithm with new SRS state
    await _client.from('user_algorithms').upsert({
      'user_id': userId,
      'algorithm_id': review.userAlgorithmId,
      'ease_factor': review.stateAfter.easeFactor,
      'interval_days': review.stateAfter.interval,
      'repetitions': review.stateAfter.repetitions,
      'next_review_date': review.stateAfter.nextReviewDate?.toIso8601String(),
      'stability': review.stateAfter.stability,
      'srs_difficulty': review.stateAfter.difficulty,
      'desired_retention': review.stateAfter.desiredRetention,
      'card_state': review.stateAfter.cardState.jsonValue,
      'remaining_steps': review.stateAfter.remainingSteps,
      'learning_due_at': review.stateAfter.learningDueAt?.toIso8601String(),
      'lapses': review.stateAfter.lapses,
      'last_reviewed_at': review.createdAt.toIso8601String(),
    }, onConflict: 'user_id,algorithm_id');
  }

  @override
  Future<List<AlgorithmReview>> getReviewHistory(
    String algorithmId, {
    int limit = 20,
  }) async {
    final userId = _userId;
    if (userId == null) return [];

    final response = await _client
        .from('algorithm_reviews')
        .select()
        .eq('user_id', userId)
        .eq('algorithm_id', algorithmId)
        .order('created_at', ascending: false)
        .limit(limit);

    // Note: We don't store full state before/after in DB for simplicity
    // Returns simplified reviews
    return (response as List).map((json) {
      return AlgorithmReview(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        userAlgorithmId: json['algorithm_id'] as String,
        rating: ReviewRatingExtension.fromString(json['rating'] as String),
        timeMs: 0, // Not stored in simplified schema
        stateBefore: SRSState.initial(),
        stateAfter: SRSState(
          easeFactor: (json['ease_factor'] as num).toDouble(),
          interval: json['interval_days'] as int,
          repetitions: json['repetitions'] as int,
        ),
        createdAt: DateTime.parse(json['created_at'] as String),
      );
    }).toList();
  }

  // ============ Training Sessions ============

  @override
  Future<TrainingStats> getTrainingStats() async {
    final dueCount = await getDueCount();
    final recentSolves = await getRecentSolves(limit: 50);

    double avgRecognitionTime = 0;
    if (recentSolves.isNotEmpty) {
      avgRecognitionTime = recentSolves.fold<int>(0, (sum, s) => sum + s.timeMs) /
          recentSolves.length /
          1000.0;
    }

    final successCount = recentSolves.where((s) => s.success).length;
    final successRate = recentSolves.isEmpty
        ? 0.0
        : successCount / recentSolves.length;

    return TrainingStats(
      casesDue: dueCount,
      avgRecognitionTime: avgRecognitionTime,
      successRate: successRate,
      recentSessions: [], // TODO: Fetch from training_sessions
    );
  }

  @override
  Future<List<TrainingSession>> getRecentSessions({int limit = 5}) async {
    final userId = _userId;
    if (userId == null) return [];

    final response = await _client
        .from('training_sessions')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);

    // TODO: Also fetch training_solves for each session
    return (response as List).map((json) {
      return TrainingSession(
        id: json['id'] as String,
        startTime: DateTime.parse(json['started_at'] as String),
        endTime: json['ended_at'] != null
            ? DateTime.parse(json['ended_at'] as String)
            : null,
        solves: [],
        mode: SessionMode.srs,
      );
    }).toList();
  }

  @override
  Future<TrainingSession?> getCurrentSession() async {
    return _currentSession;
  }

  @override
  Future<void> saveSession(TrainingSession session) async {
    final userId = _userId;
    if (userId == null) return;

    await _client.from('training_sessions').upsert({
      'id': session.id,
      'user_id': userId,
      'session_type': session.mode.name,
      'started_at': session.startTime.toIso8601String(),
      'ended_at': session.endTime?.toIso8601String(),
      'total_cases': session.totalCases,
      'correct_count': session.solves.where((s) => s.recognitionCorrect).length,
      'accuracy_percent': session.recognitionAccuracy * 100,
      'avg_time_ms': session.avgTime > 0 ? (session.avgTime * 1000).round() : null,
    }, onConflict: 'id');

    _currentSession = session;
  }

  @override
  Future<void> saveTrainingSolve(TrainingSolve solve, String sessionId) async {
    final userId = _userId;
    if (userId == null) return;

    await _client.from('training_solves').insert({
      'id': solve.id,
      'session_id': sessionId,
      'user_id': userId,
      'algorithm_id': solve.algorithmId,
      'recognition_time_ms': solve.recognitionTimeMs,
      'execution_time_ms': solve.executionTimeMs,
      'is_correct': solve.recognitionCorrect,
      'created_at': solve.timestamp.toIso8601String(),
    });

    // Update current session
    if (_currentSession != null && _currentSession!.id == sessionId) {
      _currentSession = _currentSession!.copyWith(
        solves: [..._currentSession!.solves, solve],
      );
    }
  }

  // ============ Training Queue ============

  @override
  Future<List<Algorithm>> getDueTrainingCases() async {
    final dueUserAlgs = await getDueAlgorithms();
    final algorithms = await _loadAlgorithms();

    return dueUserAlgs
        .map((ua) {
          try {
            return algorithms.firstWhere((a) => a.id == ua.algorithmId);
          } catch (_) {
            return null;
          }
        })
        .whereType<Algorithm>()
        .toList();
  }

  @override
  Future<List<Algorithm>> getRandomTrainingCases({int count = 20}) async {
    final userAlgorithms = await getUserAlgorithms();
    final enabledUserAlgs = userAlgorithms.where((ua) => ua.enabled).toList();

    if (enabledUserAlgs.isEmpty) return [];

    final algorithms = await _loadAlgorithms();

    final randomCases = <Algorithm>[];
    final shuffled = List<UserAlgorithm>.from(enabledUserAlgs)..shuffle(_random);

    for (final ua in shuffled.take(count)) {
      try {
        final alg = algorithms.firstWhere((a) => a.id == ua.algorithmId);
        randomCases.add(alg);
      } catch (_) {
        // Skip if algorithm not found
      }
    }

    return randomCases;
  }

  @override
  Future<List<String>> getMultipleChoiceOptions(String algorithmId) async {
    final algorithm = await getAlgorithm(algorithmId);
    if (algorithm == null) return [];

    final subset =
        await getAlgorithmsBySubset(algorithm.set, algorithm.subset ?? '');
    final options = subset.where((a) => a.id != algorithmId).toList();
    options.shuffle(_random);

    // Return 3 distractors + correct answer, shuffled
    final distractors = options.take(3).map((a) => a.id).toList();
    final allOptions = [...distractors, algorithmId];
    allOptions.shuffle(_random);

    return allOptions;
  }

  @override
  Future<SRSRating> autoRatePerformance(String algorithmId, int totalTimeMs) async {
    final solves = await getSolvesForAlgorithm(algorithmId, limit: 10);

    if (solves.isEmpty) {
      // First attempt - use default thresholds (3 seconds baseline)
      const baselineMs = 3000;
      final ratio = totalTimeMs / baselineMs;

      if (ratio < 0.8) return SRSRating.easy;
      if (ratio < 1.1) return SRSRating.good;
      if (ratio < 1.5) return SRSRating.hard;
      return SRSRating.again;
    }

    // Calculate user's average
    final avgMs = solves.fold<int>(0, (sum, s) => sum + s.timeMs) / solves.length;
    final ratio = totalTimeMs / avgMs;

    if (ratio < 0.8) return SRSRating.easy;
    if (ratio < 1.1) return SRSRating.good;
    if (ratio < 1.5) return SRSRating.hard;
    return SRSRating.again;
  }

  // ============ Daily Challenges ============

  @override
  Future<DailyAlgorithmChallenge> getDailyAlgorithmChallenge(DateTime date) async {
    final dateStr = date.toUtc().toIso8601String().split('T')[0];
    final algorithms = await _loadAlgorithms();

    // Deterministic algorithm selection based on date
    final seed = date.millisecondsSinceEpoch ~/ 86400000;
    final algorithmIndex = seed % algorithms.length;
    final algorithm = algorithms[algorithmIndex];

    // Check if user has completed this challenge
    final userId = _userId;
    DailyChallengeAttempt? userAttempt;
    bool isCompleted = false;

    if (userId != null) {
      final response = await _client
          .from('daily_algorithm_solves')
          .select()
          .eq('user_id', userId)
          .eq('challenge_date', dateStr)
          .maybeSingle();

      if (response != null) {
        isCompleted = true;
        userAttempt = DailyChallengeAttempt(
          id: response['id'] as String,
          dailyChallengeId: 'daily_$dateStr',
          userId: userId,
          recognized: true,
          timeMs: response['time_ms'] as int,
          addedToTraining: false,
          timestamp: DateTime.parse(response['completed_at'] as String),
        );
      }
    }

    return DailyAlgorithmChallenge(
      id: 'daily_$dateStr',
      date: date,
      algorithmId: algorithm.id,
      algorithmCase: AlgorithmCase(
        id: algorithm.id,
        set: algorithm.set.name,
        subset: algorithm.subset,
        subSubset: algorithm.subSubset,
        name: algorithm.name,
        defaultAlgs: algorithm.defaultAlgs,
        scrambleSetup: algorithm.scrambleSetup,
        imageUrl: algorithm.imageUrl,
      ),
      userAttempt: userAttempt,
      isCompleted: isCompleted,
    );
  }

  @override
  Future<void> saveDailyChallengeAttempt(DailyChallengeAttempt attempt) async {
    final userId = _userId;
    if (userId == null) return;

    // Extract date from challenge ID
    final dateStr = attempt.dailyChallengeId.replaceFirst('daily_', '');

    await _client.from('daily_algorithm_solves').upsert({
      'id': attempt.id,
      'user_id': userId,
      'challenge_date': dateStr,
      'algorithm_id': '', // TODO: Need to pass algorithm ID
      'time_ms': attempt.timeMs,
      'success': attempt.recognized,
      'completed_at': attempt.timestamp.toIso8601String(),
    }, onConflict: 'user_id,challenge_date');
  }

  @override
  Future<List<DailyAlgorithmChallenge>> getRecentDailyChallenges({
    int limit = 7,
  }) async {
    final challenges = <DailyAlgorithmChallenge>[];
    final now = DateTime.now();

    for (int i = 0; i < limit; i++) {
      final date = now.subtract(Duration(days: i));
      final challenge = await getDailyAlgorithmChallenge(date);
      challenges.add(challenge);
    }

    return challenges;
  }
}
