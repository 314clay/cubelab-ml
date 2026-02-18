import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cubelab/data/models/timer_session.dart';
import 'package:cubelab/data/models/timer_solve.dart';
import 'package:cubelab/data/models/user.dart';
import 'package:cubelab/data/repositories/timer_repository.dart';

/// Supabase implementation of TimerRepository
///
/// Stores timer solves and sessions in Supabase with real-time updates.
/// All operations are scoped to the current user via RLS policies.
class SupabaseTimerRepository implements TimerRepository {
  final SupabaseClient _client;

  // Stream controllers for reactive updates
  final _sessionController = StreamController<TimerSession>.broadcast();
  final _statsController = StreamController<TimerStats>.broadcast();

  // Realtime subscription
  RealtimeChannel? _solveChannel;

  // Cache for current session and stats
  TimerSession? _cachedSession;
  List<TimerSolve> _cachedSolves = [];

  SupabaseTimerRepository(this._client) {
    _setupRealtimeSubscription();
  }

  String? get _userId => _client.auth.currentUser?.id;

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  void _setupRealtimeSubscription() {
    final userId = _userId;
    if (userId == null) return;

    _solveChannel = _client
        .channel('timer_solves_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'timer_solves',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            // Refresh data on any change
            _refreshData();
          },
        )
        .subscribe();
  }

  Future<void> _refreshData() async {
    try {
      // Reload all solves and update caches
      await _loadAllSolves();
      _notifySessionUpdate();
      _notifyStatsUpdate();
    } catch (e) {
      // Log error but don't throw - realtime updates are best-effort
    }
  }

  Future<void> _loadAllSolves() async {
    final userId = _userId;
    if (userId == null) return;

    final response = await _client
        .from('timer_solves')
        .select()
        .eq('user_id', userId)
        .order('timestamp', ascending: false);

    _cachedSolves = (response as List)
        .map((json) => _timerSolveFromSupabase(json as Map<String, dynamic>))
        .toList();

    // Update cached session
    final todayKey = _dateKey(_today);
    final todaySolves = _cachedSolves
        .where((s) => s.sessionId == todayKey)
        .toList();

    _cachedSession = TimerSession(
      id: 'session_$todayKey',
      date: _today,
      solves: todaySolves,
    );
  }

  void _notifySessionUpdate() {
    if (_cachedSession != null) {
      _sessionController.add(_cachedSession!);
    }
  }

  void _notifyStatsUpdate() {
    _statsController.add(_calculateAllTimeStats());
  }

  TimerStats _calculateAllTimeStats() {
    if (_cachedSolves.isEmpty) {
      return const TimerStats();
    }

    // Get all valid (non-DNF) solves
    final validSolves = _cachedSolves.where((s) => !s.isDNF).toList();
    if (validSolves.isEmpty) {
      return TimerStats(totalSolves: _cachedSolves.length);
    }

    // Best single
    final times = validSolves.map((s) => s.displayTimeMs).toList();
    times.sort();
    final pbSingle = times.first;

    // Best Ao5 and Ao12 - check all possible windows
    int? pbAo5;
    int? pbAo12;

    // Sort all solves by timestamp (newest first) for rolling averages
    final sortedSolves = List<TimerSolve>.from(_cachedSolves)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Find best Ao5
    if (sortedSolves.length >= 5) {
      for (int i = 0; i <= sortedSolves.length - 5; i++) {
        final window = sortedSolves.sublist(i, i + 5);
        final ao5 = _calculateTrimmedAverage(window);
        if (ao5 != null && ao5 > 0 && (pbAo5 == null || ao5 < pbAo5)) {
          pbAo5 = ao5;
        }
      }
    }

    // Find best Ao12
    if (sortedSolves.length >= 12) {
      for (int i = 0; i <= sortedSolves.length - 12; i++) {
        final window = sortedSolves.sublist(i, i + 12);
        final ao12 = _calculateTrimmedAverage(window);
        if (ao12 != null && ao12 > 0 && (pbAo12 == null || ao12 < pbAo12)) {
          pbAo12 = ao12;
        }
      }
    }

    return TimerStats(
      pbSingleMs: pbSingle,
      pbAo5Ms: pbAo5,
      pbAo12Ms: pbAo12,
      totalSolves: _cachedSolves.length,
    );
  }

  int? _calculateTrimmedAverage(List<TimerSolve> solves) {
    final dnfCount = solves.where((s) => s.isDNF).length;
    if (dnfCount > 1) return null; // DNF average

    final times = solves
        .map((s) => s.isDNF ? double.maxFinite.toInt() : s.displayTimeMs)
        .toList();
    times.sort();

    // Remove best and worst
    final trimmed = times.sublist(1, times.length - 1);

    // If any remaining is DNF, return null
    if (trimmed.any((t) => t == double.maxFinite.toInt())) return null;

    final sum = trimmed.fold<int>(0, (sum, t) => sum + t);
    return (sum / trimmed.length).round();
  }

  // ============ Supabase Serialization ============

  TimerSolve _timerSolveFromSupabase(Map<String, dynamic> json) {
    return TimerSolve(
      id: json['id'] as String,
      sessionId: json['session_id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      timeMs: json['time_ms'] as int,
      penalty: json['penalty'] as int?,
      scramble: json['scramble'] as String,
    );
  }

  Map<String, dynamic> _timerSolveToSupabase(TimerSolve solve) {
    return {
      'id': solve.id,
      'user_id': _userId,
      'session_id': solve.sessionId,
      'timestamp': solve.timestamp.toIso8601String(),
      'time_ms': solve.timeMs,
      'penalty': solve.penalty,
      'scramble': solve.scramble,
    };
  }

  // ============ Repository Interface Implementation ============

  @override
  Future<TimerSession> getTodaySession() async {
    final userId = _userId;
    if (userId == null) {
      return TimerSession.empty(_today);
    }

    final todayKey = _dateKey(_today);

    final response = await _client
        .from('timer_solves')
        .select()
        .eq('user_id', userId)
        .eq('session_id', todayKey)
        .order('timestamp', ascending: false);

    final solves = (response as List)
        .map((json) => _timerSolveFromSupabase(json as Map<String, dynamic>))
        .toList();

    _cachedSession = TimerSession(
      id: 'session_$todayKey',
      date: _today,
      solves: solves,
    );

    return _cachedSession!;
  }

  @override
  Stream<TimerSession> watchTodaySession() {
    // Load initial data and emit
    Future.microtask(() async {
      await getTodaySession();
      _notifySessionUpdate();
    });

    return _sessionController.stream;
  }

  @override
  Future<void> saveSolve(TimerSolve solve) async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('User not signed in');
    }

    // Insert into Supabase
    await _client.from('timer_solves').insert(_timerSolveToSupabase(solve));

    // Update local cache immediately for responsiveness
    _cachedSolves.insert(0, solve);

    // Update session cache
    final todayKey = _dateKey(_today);
    if (solve.sessionId == todayKey) {
      final currentSolves = _cachedSession?.solves ?? [];
      _cachedSession = TimerSession(
        id: 'session_$todayKey',
        date: _today,
        solves: [solve, ...currentSolves],
      );
    }

    _notifySessionUpdate();
    _notifyStatsUpdate();
  }

  @override
  Future<void> updateSolve(TimerSolve solve) async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('User not signed in');
    }

    // Update in Supabase
    await _client
        .from('timer_solves')
        .update({
          'time_ms': solve.timeMs,
          'penalty': solve.penalty,
          'scramble': solve.scramble,
        })
        .eq('id', solve.id)
        .eq('user_id', userId);

    // Update local cache
    final index = _cachedSolves.indexWhere((s) => s.id == solve.id);
    if (index != -1) {
      _cachedSolves[index] = solve;
    }

    // Update session cache
    if (_cachedSession != null) {
      final sessionIndex = _cachedSession!.solves.indexWhere((s) => s.id == solve.id);
      if (sessionIndex != -1) {
        final updatedSolves = List<TimerSolve>.from(_cachedSession!.solves);
        updatedSolves[sessionIndex] = solve;
        _cachedSession = _cachedSession!.copyWith(solves: updatedSolves);
      }
    }

    _notifySessionUpdate();
    _notifyStatsUpdate();
  }

  @override
  Future<void> deleteSolve(String solveId) async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('User not signed in');
    }

    // Delete from Supabase
    await _client
        .from('timer_solves')
        .delete()
        .eq('id', solveId)
        .eq('user_id', userId);

    // Update local cache
    _cachedSolves.removeWhere((s) => s.id == solveId);

    // Update session cache
    if (_cachedSession != null) {
      final updatedSolves = _cachedSession!.solves.where((s) => s.id != solveId).toList();
      _cachedSession = _cachedSession!.copyWith(solves: updatedSolves);
    }

    _notifySessionUpdate();
    _notifyStatsUpdate();
  }

  @override
  Future<TimerStats> getAllTimeStats() async {
    final userId = _userId;
    if (userId == null) {
      return const TimerStats();
    }

    // Load all solves if cache is empty
    if (_cachedSolves.isEmpty) {
      await _loadAllSolves();
    }

    return _calculateAllTimeStats();
  }

  @override
  Stream<TimerStats> watchAllTimeStats() {
    // Load initial data and emit
    Future.microtask(() async {
      await getAllTimeStats();
      _notifyStatsUpdate();
    });

    return _statsController.stream;
  }

  @override
  Future<List<TimerSession>> getRecentSessions({int limit = 7}) async {
    final userId = _userId;
    if (userId == null) {
      return [];
    }

    // Get distinct session IDs with their solves
    final response = await _client
        .from('timer_solves')
        .select()
        .eq('user_id', userId)
        .order('timestamp', ascending: false);

    final allSolves = (response as List)
        .map((json) => _timerSolveFromSupabase(json as Map<String, dynamic>))
        .toList();

    // Group by session
    final Map<String, List<TimerSolve>> sessionMap = {};
    for (final solve in allSolves) {
      sessionMap.putIfAbsent(solve.sessionId, () => []).add(solve);
    }

    // Convert to TimerSessions
    final sessions = sessionMap.entries.map((entry) {
      // Parse date from session ID (format: YYYY-MM-DD)
      final dateParts = entry.key.split('-');
      final date = DateTime(
        int.parse(dateParts[0]),
        int.parse(dateParts[1]),
        int.parse(dateParts[2]),
      );

      return TimerSession(
        id: 'session_${entry.key}',
        date: date,
        solves: entry.value,
      );
    }).toList();

    // Sort by date descending and limit
    sessions.sort((a, b) => b.date.compareTo(a.date));
    return sessions.take(limit).toList();
  }

  @override
  Future<List<TimerSolve>> getAllSolves() async {
    final userId = _userId;
    if (userId == null) {
      return [];
    }

    if (_cachedSolves.isEmpty) {
      await _loadAllSolves();
    }

    return List.unmodifiable(_cachedSolves);
  }

  /// Dispose resources
  void dispose() {
    _solveChannel?.unsubscribe();
    _sessionController.close();
    _statsController.close();
  }
}
