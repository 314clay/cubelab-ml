import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:cubelab/data/models/cross_session.dart';
import 'package:cubelab/data/models/cross_solve.dart';
import 'package:cubelab/data/models/cross_srs_item.dart';
import 'package:cubelab/data/models/srs_state.dart';
import 'package:cubelab/data/models/stats.dart';
import 'package:cubelab/data/repositories/cross_trainer_repository.dart';

/// Supabase implementation of CrossTrainerRepository
///
/// Manages cross training sessions, solves, stats, and SRS items.
/// All data is scoped to the current user via RLS policies.
class SupabaseCrossTrainerRepository implements CrossTrainerRepository {
  final SupabaseClient _client;
  final _random = Random();
  final _uuid = const Uuid();

  SupabaseCrossTrainerRepository(this._client);

  String? get _userId => _client.auth.currentUser?.id;

  // ============ Session Management ============

  @override
  Future<CrossSession?> getActiveSession() async {
    final userId = _userId;
    if (userId == null) return null;

    final response = await _client
        .from('cross_sessions')
        .select()
        .eq('user_id', userId)
        .isFilter('ended_at', null)
        .order('started_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (response == null) return null;

    return _crossSessionFromSupabase(response);
  }

  @override
  Future<CrossSession> startSession() async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('User not signed in');
    }

    // End any existing active sessions
    final activeSession = await getActiveSession();
    if (activeSession != null) {
      await endSession(activeSession.id);
    }

    final sessionId = _uuid.v4();
    final now = DateTime.now();

    await _client.from('cross_sessions').insert({
      'id': sessionId,
      'user_id': userId,
      'started_at': now.toIso8601String(),
    });

    return CrossSession(
      id: sessionId,
      userId: userId,
      startedAt: now,
    );
  }

  @override
  Future<void> endSession(String sessionId) async {
    final userId = _userId;
    if (userId == null) return;

    // Calculate session stats
    final solves = await getSolvesBySession(sessionId);

    int solveCount = solves.length;
    int successCount = solves.where((s) => s.crossSuccess).length;

    int? avgInspectionTimeMs;
    int? avgExecutionTimeMs;

    if (solves.isNotEmpty) {
      avgInspectionTimeMs =
          solves.map((s) => s.inspectionTimeMs).reduce((a, b) => a + b) ~/ solves.length;
      avgExecutionTimeMs =
          solves.map((s) => s.executionTimeMs).reduce((a, b) => a + b) ~/ solves.length;
    }

    await _client.from('cross_sessions').update({
      'ended_at': DateTime.now().toIso8601String(),
      'solve_count': solveCount,
      'success_count': successCount,
      'avg_inspection_time_ms': avgInspectionTimeMs,
      'avg_execution_time_ms': avgExecutionTimeMs,
    }).eq('id', sessionId).eq('user_id', userId);
  }

  CrossSession _crossSessionFromSupabase(Map<String, dynamic> json) {
    return CrossSession(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      solveCount: json['solve_count'] as int? ?? 0,
      successCount: json['success_count'] as int? ?? 0,
      avgInspectionTimeMs: json['avg_inspection_time_ms'] as int?,
      avgExecutionTimeMs: json['avg_execution_time_ms'] as int?,
      startedAt: DateTime.parse(json['started_at'] as String),
      endedAt: json['ended_at'] != null
          ? DateTime.parse(json['ended_at'] as String)
          : null,
    );
  }

  // ============ Solves ============

  @override
  Future<void> saveSolve(CrossSolve solve) async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('User not signed in');
    }

    await _client.from('cross_solves').insert({
      'id': solve.id,
      'user_id': userId,
      'session_id': solve.sessionId,
      'scramble': solve.scramble,
      'difficulty': solve.difficulty,
      'cross_color': solve.crossColor,
      'pairs_attempting': solve.pairsAttempting,
      'pairs_planned': solve.pairsPlanned,
      'cross_success': solve.crossSuccess,
      'blindfolded': solve.blindfolded,
      'inspection_time_ms': solve.inspectionTimeMs,
      'execution_time_ms': solve.executionTimeMs,
      'used_unlimited_time': solve.usedUnlimitedTime,
      'notes': solve.notes,
      'created_at': solve.createdAt.toIso8601String(),
    });
  }

  @override
  Future<List<CrossSolve>> getRecentSolves({int limit = 10}) async {
    final userId = _userId;
    if (userId == null) return [];

    final response = await _client
        .from('cross_solves')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);

    return (response as List)
        .map((json) => _crossSolveFromSupabase(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<CrossSolve>> getSolvesBySession(String sessionId) async {
    final userId = _userId;
    if (userId == null) return [];

    final response = await _client
        .from('cross_solves')
        .select()
        .eq('user_id', userId)
        .eq('session_id', sessionId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => _crossSolveFromSupabase(json as Map<String, dynamic>))
        .toList();
  }

  CrossSolve _crossSolveFromSupabase(Map<String, dynamic> json) {
    return CrossSolve(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      scramble: json['scramble'] as String,
      difficulty: json['difficulty'] as int,
      crossColor: json['cross_color'] as String? ?? 'white',
      pairsAttempting: json['pairs_attempting'] as int,
      pairsPlanned: json['pairs_planned'] as int,
      crossSuccess: json['cross_success'] as bool? ?? true,
      blindfolded: json['blindfolded'] as bool? ?? false,
      inspectionTimeMs: json['inspection_time_ms'] as int,
      executionTimeMs: json['execution_time_ms'] as int,
      usedUnlimitedTime: json['used_unlimited_time'] as bool? ?? false,
      notes: json['notes'] as String?,
      sessionId: json['session_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  // ============ Stats ============

  @override
  Future<CrossStats> getStats({DateRange? range}) async {
    final userId = _userId;
    if (userId == null) return CrossStats.empty();

    // Build query
    var query = _client.from('cross_solves').select().eq('user_id', userId);

    if (range != null) {
      query = query
          .gte('created_at', range.start.toIso8601String())
          .lte('created_at', range.end.toIso8601String());
    }

    final response = await query;
    final solves = (response as List)
        .map((json) => _crossSolveFromSupabase(json as Map<String, dynamic>))
        .toList();

    if (solves.isEmpty) return CrossStats.empty();

    // Calculate overall stats
    final totalSolves = solves.length;
    final successCount = solves.where((s) => s.crossSuccess).length;
    final successRate = totalSolves > 0 ? successCount / totalSolves : 0.0;

    final avgInspectionTimeMs =
        solves.map((s) => s.inspectionTimeMs).reduce((a, b) => a + b) ~/ totalSolves;
    final avgExecutionTimeMs =
        solves.map((s) => s.executionTimeMs).reduce((a, b) => a + b) ~/ totalSolves;

    // Get session count
    final sessionResponse = await _client
        .from('cross_sessions')
        .select('id')
        .eq('user_id', userId);
    final sessionCount = (sessionResponse as List).length;

    // Calculate stats by level (pairs attempting)
    final Map<int, LevelStats> byLevel = {};
    final solvesByLevel = <int, List<CrossSolve>>{};

    for (final solve in solves) {
      solvesByLevel.putIfAbsent(solve.pairsAttempting, () => []).add(solve);
    }

    for (final entry in solvesByLevel.entries) {
      final level = entry.key;
      final levelSolves = entry.value;
      final levelTotal = levelSolves.length;
      final levelSuccess = levelSolves.where((s) => s.crossSuccess).length;

      byLevel[level] = LevelStats(
        solveCount: levelTotal,
        avgInspectionTimeMs:
            levelSolves.map((s) => s.inspectionTimeMs).reduce((a, b) => a + b) ~/ levelTotal,
        avgExecutionTimeMs:
            levelSolves.map((s) => s.executionTimeMs).reduce((a, b) => a + b) ~/ levelTotal,
        successRate: levelTotal > 0 ? levelSuccess / levelTotal : 0.0,
      );
    }

    return CrossStats(
      totalSolves: totalSolves,
      successRate: successRate,
      avgInspectionTimeMs: avgInspectionTimeMs,
      avgExecutionTimeMs: avgExecutionTimeMs,
      sessionCount: sessionCount,
      byLevel: byLevel,
    );
  }

  @override
  Future<List<CrossSession>> getSessionHistory({int limit = 20}) async {
    final userId = _userId;
    if (userId == null) return [];

    final response = await _client
        .from('cross_sessions')
        .select()
        .eq('user_id', userId)
        .order('started_at', ascending: false)
        .limit(limit);

    return (response as List)
        .map((json) => _crossSessionFromSupabase(json as Map<String, dynamic>))
        .toList();
  }

  // ============ Scrambles ============

  @override
  Future<String> generateScramble({required int moves}) async {
    // Generate scramble client-side for speed
    final moveSet = ['R', 'L', 'U', 'D', 'F', 'B'];
    final modifiers = ['', '\'', '2'];

    final buffer = StringBuffer();
    String lastMove = '';
    String lastAxis = '';

    for (int i = 0; i < moves; i++) {
      String move;
      String axis;

      do {
        move = moveSet[_random.nextInt(6)];
        axis = _getAxis(move);
      } while (move == lastMove || (axis == lastAxis && _random.nextDouble() < 0.5));

      final modifier = modifiers[_random.nextInt(3)];
      buffer.write('$move$modifier ');

      lastMove = move;
      lastAxis = axis;
    }

    return buffer.toString().trim();
  }

  String _getAxis(String move) {
    switch (move) {
      case 'R':
      case 'L':
        return 'x';
      case 'U':
      case 'D':
        return 'y';
      case 'F':
      case 'B':
        return 'z';
      default:
        return '';
    }
  }

  @override
  Future<List<String>> getScramblePool() async {
    // Generate a pool of scrambles
    final scrambles = <String>[];
    for (int i = 0; i < 10; i++) {
      scrambles.add(await generateScramble(moves: 20));
    }
    return scrambles;
  }

  // ============ SRS Items ============

  @override
  Future<void> addSRSItem(CrossSRSItem item) async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('User not signed in');
    }

    await _client.from('cross_srs_items').insert({
      'id': item.id,
      'user_id': userId,
      'scramble': item.scramble,
      'difficulty': item.difficulty,
      'cross_color': item.crossColor,
      'pairs_attempting': item.pairsAttempting,
      // SRS State fields
      'ease_factor': item.srsState.easeFactor,
      'interval_days': item.srsState.interval,
      'repetitions': item.srsState.repetitions,
      'next_review_date': item.srsState.nextReviewDate?.toIso8601String(),
      'stability': item.srsState.stability,
      'srs_difficulty': item.srsState.difficulty,
      'desired_retention': item.srsState.desiredRetention,
      'card_state': item.srsState.cardState.jsonValue,
      'remaining_steps': item.srsState.remainingSteps,
      'learning_due_at': item.srsState.learningDueAt?.toIso8601String(),
      'lapses': item.srsState.lapses,
      'last_reviewed_at': item.lastReviewedAt?.toIso8601String(),
      'total_reviews': item.totalReviews,
      'created_at': item.createdAt.toIso8601String(),
    });
  }

  @override
  Future<List<CrossSRSItem>> getActiveSRSItems() async {
    final userId = _userId;
    if (userId == null) return [];

    final response = await _client
        .from('cross_srs_items')
        .select()
        .eq('user_id', userId)
        .order('next_review_date', ascending: true);

    return (response as List)
        .map((json) => _crossSRSItemFromSupabase(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<CrossSRSItem?> getNextDueSRSItem() async {
    final userId = _userId;
    if (userId == null) return null;

    final response = await _client
        .from('cross_srs_items')
        .select()
        .eq('user_id', userId)
        .lte('next_review_date', DateTime.now().toIso8601String())
        .order('next_review_date', ascending: true)
        .limit(1)
        .maybeSingle();

    if (response == null) return null;

    return _crossSRSItemFromSupabase(response);
  }

  @override
  Future<void> updateSRSItem(CrossSRSItem item) async {
    final userId = _userId;
    if (userId == null) return;

    await _client.from('cross_srs_items').update({
      'ease_factor': item.srsState.easeFactor,
      'interval_days': item.srsState.interval,
      'repetitions': item.srsState.repetitions,
      'next_review_date': item.srsState.nextReviewDate?.toIso8601String(),
      'stability': item.srsState.stability,
      'srs_difficulty': item.srsState.difficulty,
      'desired_retention': item.srsState.desiredRetention,
      'card_state': item.srsState.cardState.jsonValue,
      'remaining_steps': item.srsState.remainingSteps,
      'learning_due_at': item.srsState.learningDueAt?.toIso8601String(),
      'lapses': item.srsState.lapses,
      'last_reviewed_at': item.lastReviewedAt?.toIso8601String(),
      'total_reviews': item.totalReviews,
    }).eq('id', item.id).eq('user_id', userId);
  }

  @override
  Future<void> deleteSRSItem(String id) async {
    final userId = _userId;
    if (userId == null) return;

    await _client.from('cross_srs_items').delete().eq('id', id).eq('user_id', userId);
  }

  CrossSRSItem _crossSRSItemFromSupabase(Map<String, dynamic> json) {
    return CrossSRSItem(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      scramble: json['scramble'] as String,
      difficulty: json['difficulty'] as int,
      crossColor: json['cross_color'] as String? ?? 'white',
      pairsAttempting: json['pairs_attempting'] as int,
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
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
