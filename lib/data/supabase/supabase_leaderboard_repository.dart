import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cubelab/data/models/algorithm.dart';
import 'package:cubelab/data/models/leaderboard.dart';
import 'package:cubelab/data/repositories/leaderboard_repository.dart';

/// Supabase implementation of LeaderboardRepository
///
/// Fetches leaderboard data from denormalized leaderboard tables.
/// Users can only update their own entries; everyone can view leaderboards.
class SupabaseLeaderboardRepository implements LeaderboardRepository {
  final SupabaseClient _client;

  /// Minimum solves required for algorithm leaderboard eligibility
  static const int _minSolvesForEligibility = 50;

  SupabaseLeaderboardRepository(this._client);

  String? get _userId => _client.auth.currentUser?.id;

  // ============ Cross Leaderboard ============

  @override
  Future<CrossLeaderboard> getCrossLeaderboard({
    required int level,
    int limit = 50,
  }) async {
    final response = await _client
        .from('cross_leaderboards')
        .select()
        .eq('level', level)
        .order('avg_time_ms', ascending: true)
        .limit(limit);

    final entries = (response as List).asMap().entries.map((entry) {
      final json = entry.value as Map<String, dynamic>;
      final rank = entry.key + 1;
      return _leaderboardEntryFromSupabase(json, rank);
    }).toList();

    return CrossLeaderboard(
      level: level,
      lastUpdated: DateTime.now(),
      entries: entries,
    );
  }

  @override
  Future<int?> getUserCrossRank(int level) async {
    final userId = _userId;
    if (userId == null) return null;

    // Get user's entry
    final userResponse = await _client
        .from('cross_leaderboards')
        .select('avg_time_ms')
        .eq('user_id', userId)
        .eq('level', level)
        .maybeSingle();

    if (userResponse == null) return null;

    final userTime = userResponse['avg_time_ms'] as int;

    // Count how many entries have better (lower) times
    final countResponse = await _client
        .from('cross_leaderboards')
        .select()
        .eq('level', level)
        .lt('avg_time_ms', userTime);

    final betterCount = (countResponse as List).length;
    return betterCount + 1;
  }

  // ============ Algorithm Leaderboards ============

  @override
  Future<AlgorithmLeaderboard> getAlgorithmTimeLeaderboard({
    required AlgorithmSet set,
    int limit = 50,
  }) async {
    final response = await _client
        .from('algorithm_leaderboards')
        .select()
        .eq('set_type', set.name)
        .eq('board_type', 'avg_time')
        .order('value', ascending: true)
        .limit(limit);

    final entries = (response as List).asMap().entries.map((entry) {
      final json = entry.value as Map<String, dynamic>;
      final rank = entry.key + 1;
      return _leaderboardEntryFromSupabase(json, rank, valueKey: 'value');
    }).toList();

    return AlgorithmLeaderboard(
      set: set,
      type: 'time',
      lastUpdated: DateTime.now(),
      entries: entries,
    );
  }

  @override
  Future<AlgorithmLeaderboard> getAlgorithmCountLeaderboard({
    int limit = 50,
  }) async {
    // For count leaderboard, we aggregate across all sets
    final response = await _client
        .from('algorithm_leaderboards')
        .select()
        .eq('board_type', 'learned_count')
        .order('value', ascending: false) // Higher count = better
        .limit(limit);

    final entries = (response as List).asMap().entries.map((entry) {
      final json = entry.value as Map<String, dynamic>;
      final rank = entry.key + 1;
      return _leaderboardEntryFromSupabase(json, rank, valueKey: 'value');
    }).toList();

    return AlgorithmLeaderboard(
      set: null,
      type: 'count',
      lastUpdated: DateTime.now(),
      entries: entries,
    );
  }

  @override
  Future<int?> getUserAlgorithmTimeRank(AlgorithmSet set) async {
    final userId = _userId;
    if (userId == null) return null;

    // Get user's entry
    final userResponse = await _client
        .from('algorithm_leaderboards')
        .select('value')
        .eq('user_id', userId)
        .eq('set_type', set.name)
        .eq('board_type', 'avg_time')
        .maybeSingle();

    if (userResponse == null) return null;

    final userValue = userResponse['value'] as int;

    // Count how many entries have better (lower) values
    final countResponse = await _client
        .from('algorithm_leaderboards')
        .select()
        .eq('set_type', set.name)
        .eq('board_type', 'avg_time')
        .lt('value', userValue);

    final betterCount = (countResponse as List).length;
    return betterCount + 1;
  }

  @override
  Future<int?> getUserAlgorithmCountRank() async {
    final userId = _userId;
    if (userId == null) return null;

    // Get user's entry
    final userResponse = await _client
        .from('algorithm_leaderboards')
        .select('value')
        .eq('user_id', userId)
        .eq('board_type', 'learned_count')
        .maybeSingle();

    if (userResponse == null) return null;

    final userValue = userResponse['value'] as int;

    // Count how many entries have better (higher) values
    final countResponse = await _client
        .from('algorithm_leaderboards')
        .select()
        .eq('board_type', 'learned_count')
        .gt('value', userValue);

    final betterCount = (countResponse as List).length;
    return betterCount + 1;
  }

  // ============ Eligibility ============

  @override
  Future<bool> isEligibleForAlgorithmLeaderboard(AlgorithmSet set) async {
    final userId = _userId;
    if (userId == null) return false;

    // Check if user has enough solves for this set
    final response = await _client
        .from('algorithm_solves')
        .select()
        .eq('user_id', userId);

    // Filter solves by set (we'd need to join with algorithm catalog)
    // For now, check total solves as a simple heuristic
    final solveCount = (response as List).length;
    return solveCount >= _minSolvesForEligibility;
  }

  @override
  Future<Map<AlgorithmSet, bool>> getAllEligibility() async {
    final result = <AlgorithmSet, bool>{};

    for (final set in AlgorithmSet.values) {
      result[set] = await isEligibleForAlgorithmLeaderboard(set);
    }

    return result;
  }

  // ============ Helpers ============

  LeaderboardEntry _leaderboardEntryFromSupabase(
    Map<String, dynamic> json,
    int rank, {
    String valueKey = 'avg_time_ms',
  }) {
    final userId = _userId;
    final entryUserId = json['user_id'] as String;

    return LeaderboardEntry(
      rank: rank,
      userId: entryUserId,
      username: json['username'] as String? ?? 'Anonymous',
      value: json[valueKey] as int,
      secondaryValue: json['success_rate'] != null
          ? (json['success_rate'] as num).toDouble()
          : null,
      isCurrentUser: userId != null && entryUserId == userId,
    );
  }

  // ============ Leaderboard Updates ============

  /// Updates the user's cross leaderboard entry
  /// Called after cross training sessions
  Future<void> updateCrossLeaderboardEntry({
    required int level,
    required int avgTimeMs,
    required int totalSolves,
    required double successRate,
    required String username,
  }) async {
    final userId = _userId;
    if (userId == null) return;

    await _client.from('cross_leaderboards').upsert({
      'user_id': userId,
      'username': username,
      'level': level,
      'avg_time_ms': avgTimeMs,
      'total_solves': totalSolves,
      'success_rate': successRate,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id,level');
  }

  /// Updates the user's algorithm leaderboard entry
  /// Called after algorithm training
  Future<void> updateAlgorithmLeaderboardEntry({
    required AlgorithmSet set,
    required String boardType,
    required int value,
    required int totalSolves,
    required String username,
  }) async {
    final userId = _userId;
    if (userId == null) return;

    await _client.from('algorithm_leaderboards').upsert({
      'user_id': userId,
      'username': username,
      'set_type': set.name,
      'board_type': boardType,
      'value': value,
      'total_solves': totalSolves,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id,set_type,board_type');
  }
}
