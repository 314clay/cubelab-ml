import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cubelab/data/models/algorithm.dart';
import 'package:cubelab/data/models/algorithm_solve.dart';
import 'package:cubelab/data/models/daily_challenge.dart';
import 'package:cubelab/data/models/pro_solve.dart';
import 'package:cubelab/data/models/solve_comment.dart';
import 'package:cubelab/data/repositories/daily_challenge_repository.dart';
import 'package:cubelab/data/stubs/json_loader.dart';

/// Supabase implementation of DailyChallengeRepository
///
/// Manages daily scramble and algorithm challenges with community features.
/// Daily challenges are global; user submissions are per-user.
class SupabaseDailyChallengeRepository implements DailyChallengeRepository {
  final SupabaseClient _client;

  // Cache for pro solves loaded from assets
  List<ProSolve>? _proSolves;

  SupabaseDailyChallengeRepository(this._client);

  /// Load pro solves from JSON assets (until external API is integrated)
  Future<List<ProSolve>> _loadProSolves() async {
    if (_proSolves != null) return _proSolves!;

    final json = await JsonLoader.loadJsonList('pro_solves.json');
    _proSolves = json.map((j) => ProSolve.fromJson(j as Map<String, dynamic>)).toList();
    return _proSolves!;
  }

  String? get _userId => _client.auth.currentUser?.id;
  String? get _username => _client.auth.currentUser?.userMetadata?['name'] as String? ??
      _client.auth.currentUser?.userMetadata?['full_name'] as String?;

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  // ============ Daily Challenge ============

  @override
  Future<DailyChallenge> getTodaysChallenge() async {
    final challenge = await getChallengeForDate(_today);
    if (challenge != null) return challenge;

    // Generate challenge if it doesn't exist
    return _getOrCreateChallenge(_today);
  }

  @override
  Future<DailyChallenge?> getChallengeForDate(DateTime date) async {
    final dateKey = _dateKey(date);

    final response = await _client
        .from('daily_challenges')
        .select()
        .eq('id', dateKey)
        .maybeSingle();

    if (response == null) return null;

    return _dailyChallengeFromSupabase(response, date);
  }

  Future<DailyChallenge> _getOrCreateChallenge(DateTime date) async {
    final dateKey = _dateKey(date);

    // Try to get existing challenge
    final existing = await getChallengeForDate(date);
    if (existing != null) return existing;

    // Generate a deterministic scramble based on date
    final scramble = _generateDailyScramble(date);

    // Insert new challenge
    await _client.from('daily_challenges').insert({
      'id': dateKey,
      'scramble': scramble,
      'released_at': date.toIso8601String(),
    });

    return DailyChallenge(
      id: dateKey,
      date: date,
      scramble: scramble,
    );
  }

  String _generateDailyScramble(DateTime date) {
    // Generate a deterministic scramble based on date
    final moves = ['R', 'L', 'U', 'D', 'F', 'B'];
    final modifiers = ['', '\'', '2'];
    final seed = date.millisecondsSinceEpoch ~/ 86400000; // Days since epoch

    final buffer = StringBuffer();
    String lastMove = '';

    for (int i = 0; i < 20; i++) {
      String move;
      int attemptSeed = seed + i * 7;

      do {
        move = moves[attemptSeed % 6];
        attemptSeed++;
      } while (move == lastMove);

      final modifier = modifiers[(seed + i * 3) % 3];
      buffer.write('$move$modifier ');
      lastMove = move;
    }

    return buffer.toString().trim();
  }

  DailyChallenge _dailyChallengeFromSupabase(Map<String, dynamic> json, DateTime date) {
    return DailyChallenge(
      id: json['id'] as String,
      date: date,
      scramble: json['scramble'] as String,
      algorithmId: json['algorithm_id'] as String?,
      algorithmSet: json['algorithm_set'] != null
          ? AlgorithmSetExtension.fromString(json['algorithm_set'] as String)
          : null,
    );
  }

  // ============ Daily Scramble ============

  @override
  Future<bool> hasCompletedDailyScramble(DateTime date) async {
    final userId = _userId;
    if (userId == null) return false;

    final dateOnly = DateTime(date.year, date.month, date.day);

    final response = await _client
        .from('daily_scramble_solves')
        .select('id')
        .eq('user_id', userId)
        .eq('challenge_date', dateOnly.toIso8601String().split('T')[0])
        .maybeSingle();

    return response != null;
  }

  @override
  Future<void> saveDailyScrambleSolve(DailyScrambleSolve solve) async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('User not signed in');
    }

    final dateOnly = DateTime(solve.date.year, solve.date.month, solve.date.day);

    await _client.from('daily_scramble_solves').upsert({
      'id': solve.id,
      'user_id': userId,
      'username': solve.username ?? _username,
      'challenge_date': dateOnly.toIso8601String().split('T')[0],
      'time_ms': solve.timeMs,
      'scramble': solve.scramble,
      'notes': solve.notes,
      'pairs_planned': solve.pairsPlanned,
      'was_xcross': solve.wasXcross,
      'was_zbll': solve.wasZbll,
      'alg_used': solve.algUsed,
      'completed_at': solve.createdAt.toIso8601String(),
    }, onConflict: 'user_id,challenge_date');
  }

  @override
  Future<DailyScrambleSolve?> getDailyScrambleSolve(DateTime date) async {
    final userId = _userId;
    if (userId == null) return null;

    final dateOnly = DateTime(date.year, date.month, date.day);

    final response = await _client
        .from('daily_scramble_solves')
        .select()
        .eq('user_id', userId)
        .eq('challenge_date', dateOnly.toIso8601String().split('T')[0])
        .maybeSingle();

    if (response == null) return null;

    return _dailyScrambleSolveFromSupabase(response);
  }

  DailyScrambleSolve _dailyScrambleSolveFromSupabase(Map<String, dynamic> json) {
    return DailyScrambleSolve(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      username: json['username'] as String?,
      date: DateTime.parse(json['challenge_date'] as String),
      scramble: json['scramble'] as String,
      timeMs: json['time_ms'] as int,
      notes: json['notes'] as String?,
      pairsPlanned: json['pairs_planned'] as int?,
      wasXcross: json['was_xcross'] as bool?,
      wasZbll: json['was_zbll'] as bool?,
      algUsed: json['alg_used'] as String?,
      createdAt: DateTime.parse(json['completed_at'] as String),
    );
  }

  // ============ Daily Algorithm ============

  @override
  Future<bool> hasCompletedDailyAlgorithm(DateTime date) async {
    final userId = _userId;
    if (userId == null) return false;

    final dateOnly = DateTime(date.year, date.month, date.day);

    final response = await _client
        .from('daily_algorithm_solves')
        .select('id')
        .eq('user_id', userId)
        .eq('challenge_date', dateOnly.toIso8601String().split('T')[0])
        .maybeSingle();

    return response != null;
  }

  @override
  Future<void> saveDailyAlgorithmSolve(AlgorithmSolve solve) async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('User not signed in');
    }

    final dateOnly = DateTime(solve.createdAt.year, solve.createdAt.month, solve.createdAt.day);

    await _client.from('daily_algorithm_solves').upsert({
      'id': solve.id,
      'user_id': userId,
      'challenge_date': dateOnly.toIso8601String().split('T')[0],
      'algorithm_id': solve.algorithmId,
      'time_ms': solve.timeMs,
      'success': solve.success,
      'completed_at': solve.createdAt.toIso8601String(),
    }, onConflict: 'user_id,challenge_date');
  }

  @override
  Future<AlgorithmSolve?> getDailyAlgorithmSolve(DateTime date) async {
    final userId = _userId;
    if (userId == null) return null;

    final dateOnly = DateTime(date.year, date.month, date.day);

    final response = await _client
        .from('daily_algorithm_solves')
        .select()
        .eq('user_id', userId)
        .eq('challenge_date', dateOnly.toIso8601String().split('T')[0])
        .maybeSingle();

    if (response == null) return null;

    return AlgorithmSolve(
      id: response['id'] as String,
      userId: response['user_id'] as String,
      algorithmId: response['algorithm_id'] as String,
      timeMs: response['time_ms'] as int,
      success: response['success'] as bool? ?? true,
      createdAt: DateTime.parse(response['completed_at'] as String),
    );
  }

  // ============ Pro Solves ============

  @override
  Future<ProSolve?> getProSolveForScramble(String scramble) async {
    final proSolves = await _loadProSolves();
    try {
      return proSolves.firstWhere((p) => p.scramble == scramble);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<ProSolve>> getAllProSolvesForScramble(String scramble) async {
    final proSolves = await _loadProSolves();
    return proSolves.where((p) => p.scramble == scramble).toList();
  }

  // ============ Community Solves ============

  @override
  Future<List<DailyScrambleSolve>> getCommunitySolves(
    DateTime date, {
    int limit = 20,
  }) async {
    final dateOnly = DateTime(date.year, date.month, date.day);

    final response = await _client
        .from('daily_scramble_solves')
        .select()
        .eq('challenge_date', dateOnly.toIso8601String().split('T')[0])
        .order('time_ms', ascending: true)
        .limit(limit);

    return (response as List)
        .map((json) => _dailyScrambleSolveFromSupabase(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<int> getCommunityCount(DateTime date) async {
    final dateOnly = DateTime(date.year, date.month, date.day);

    final response = await _client
        .from('daily_scramble_solves')
        .select()
        .eq('challenge_date', dateOnly.toIso8601String().split('T')[0]);

    return (response as List).length;
  }

  // ============ Comments ============

  @override
  Future<List<SolveComment>> getCommentsForSolve(String solveId) async {
    final response = await _client
        .from('solve_comments')
        .select()
        .eq('solve_id', solveId)
        .order('created_at', ascending: true);

    return (response as List)
        .map((json) => _solveCommentFromSupabase(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<int> getCommentCount(String solveId) async {
    final response = await _client
        .from('solve_comments')
        .select()
        .eq('solve_id', solveId);

    return (response as List).length;
  }

  @override
  Future<void> addComment(SolveComment comment) async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('User not signed in');
    }

    await _client.from('solve_comments').insert({
      'id': comment.id,
      'solve_id': comment.solveId,
      'user_id': userId,
      'username': comment.username,
      'content': comment.content,
      'created_at': comment.createdAt.toIso8601String(),
    });
  }

  SolveComment _solveCommentFromSupabase(Map<String, dynamic> json) {
    return SolveComment(
      id: json['id'] as String,
      solveId: json['solve_id'] as String,
      userId: json['user_id'] as String,
      username: json['username'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
