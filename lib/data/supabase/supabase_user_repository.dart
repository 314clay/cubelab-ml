import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cubelab/data/models/algorithm.dart';
import 'package:cubelab/data/models/user.dart';
import 'package:cubelab/data/repositories/user_repository.dart';

/// Supabase implementation of UserRepository
///
/// ## Google OAuth Setup Requirements
///
/// ### Google Cloud Console (console.cloud.google.com)
/// 1. Create OAuth 2.0 Client ID with type **"Web application"** (NOT Desktop/iOS/Android)
/// 2. Add Authorized redirect URIs:
///    - `https://<project-ref>.supabase.co/auth/v1/callback` (required)
///    - `http://localhost:3000` (for web dev - Supabase default)
///    - `http://localhost:5050` (optional alternate port)
///
/// ### Supabase Dashboard (Authentication > Providers > Google)
/// 1. Enable "Sign in with Google"
/// 2. Client ID: from Google Cloud (Web application type)
/// 3. Client Secret: from Google Cloud (generate fresh if "invalid_client" errors)
///
/// ### Supabase Dashboard (Authentication > URL Configuration)
/// 1. Site URL: `http://localhost:3000` (for dev)
/// 2. Redirect URLs must include:
///    - `io.supabase.cubelab://login-callback/` (for iOS/Android)
///    - `http://localhost:3000` (for web dev)
///
/// ### Common Errors & Fixes
/// - "invalid_client": Wrong client type (use Web, not Desktop) or bad secret
/// - "redirect_uri_mismatch": URL not in Google's Authorized redirect URIs
/// - Redirect to wrong port: Check Supabase Site URL setting
class SupabaseUserRepository implements UserRepository {
  final SupabaseClient _client;

  // In-memory cache for settings and onboarding state
  // These will be persisted to a user_settings table in a future phase
  UserSettings _cachedSettings = const UserSettings();
  bool _hasOnboarded = false;
  int _defaultPairsPlanning = 2;
  AlgorithmSet? _favoritedAlgSet;

  SupabaseUserRepository(this._client);

  /// Map Supabase User to AppUser
  AppUser? _mapSupabaseUser(User? supabaseUser) {
    if (supabaseUser == null) return null;

    return AppUser(
      id: supabaseUser.id,
      email: supabaseUser.email,
      username: supabaseUser.userMetadata?['name'] as String? ??
               supabaseUser.userMetadata?['full_name'] as String? ??
               'Cuber',
      isAnonymous: supabaseUser.isAnonymous,
      defaultPairsPlanning: _defaultPairsPlanning,
      favoritedAlgSet: _favoritedAlgSet,
      settings: _cachedSettings,
      createdAt: DateTime.parse(supabaseUser.createdAt),
    );
  }

  // ============ Auth State ============

  @override
  Future<AppUser?> getCurrentUser() async {
    final supabaseUser = _client.auth.currentUser;
    return _mapSupabaseUser(supabaseUser);
  }

  @override
  Future<bool> isSignedIn() async {
    return _client.auth.currentUser != null;
  }

  @override
  Stream<AppUser?> watchCurrentUser() {
    return _client.auth.onAuthStateChange.map((event) {
      return _mapSupabaseUser(event.session?.user);
    });
  }

  // ============ Auth Actions ============

  @override
  Future<AppUser> signInWithGoogle() async {
    // On web, don't specify redirectTo - Supabase uses current URL
    // On mobile, use deep link scheme
    final response = await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? null : 'io.supabase.cubelab://login-callback/',
    );

    if (!response) {
      throw Exception('Google sign-in failed');
    }

    // Wait for auth state to update
    await Future.delayed(const Duration(milliseconds: 500));

    final user = await getCurrentUser();
    if (user == null) {
      throw Exception('Failed to get user after Google sign-in');
    }
    return user;
  }

  @override
  Future<AppUser> signInAnonymously() async {
    final response = await _client.auth.signInAnonymously();

    if (response.user == null) {
      throw Exception('Anonymous sign-in failed');
    }

    return _mapSupabaseUser(response.user)!;
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
    // Clear cached data
    _cachedSettings = const UserSettings();
    _hasOnboarded = false;
    _defaultPairsPlanning = 2;
    _favoritedAlgSet = null;
  }

  @override
  Future<AppUser> linkAnonymousToGoogle() async {
    // Link anonymous account to Google identity
    final response = await _client.auth.linkIdentity(OAuthProvider.google);

    if (!response) {
      throw Exception('Failed to link Google account');
    }

    // Wait for auth state to update
    await Future.delayed(const Duration(milliseconds: 500));

    final user = await getCurrentUser();
    if (user == null) {
      throw Exception('Failed to get user after linking');
    }
    return user;
  }

  // ============ Profile ============

  @override
  Future<void> updateUsername(String username) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not signed in');

    await _client.from('users').update({
      'username': username,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', userId);
  }

  @override
  Future<void> updateSettings(UserSettings settings) async {
    // For now, just cache locally
    // In a future phase, this will persist to a user_settings table
    _cachedSettings = settings;
  }

  // ============ Onboarding ============

  @override
  Future<bool> hasCompletedOnboarding() async {
    // For now, return cached value
    // In a future phase, this will check the database
    return _hasOnboarded;
  }

  @override
  Future<void> completeOnboarding({
    required int defaultPairsPlanning,
    required AlgorithmSet favoritedAlgSet,
  }) async {
    _hasOnboarded = true;
    _defaultPairsPlanning = defaultPairsPlanning;
    _favoritedAlgSet = favoritedAlgSet;

    // In a future phase, persist to database
  }

  @override
  Future<void> resetOnboarding() async {
    _hasOnboarded = false;
    _defaultPairsPlanning = 2;
    _favoritedAlgSet = null;
  }

  // ============ Timer Stats ============
  // Note: Timer stats are managed by TimerRepository, not UserRepository
  // These methods exist for interface compliance but will be removed
  // when we refactor the repository interfaces

  @override
  Future<TimerStats> getTimerStats() async {
    // Timer stats are now managed by TimerRepository
    // Return empty stats - actual stats come from timerRepositoryProvider
    return const TimerStats();
  }

  @override
  Future<void> updateTimerStats(TimerStats stats) async {
    // Timer stats are now managed by TimerRepository
    // This is a no-op - actual updates go through timerRepositoryProvider
  }

  // ============ Stats Snapshots ============

  @override
  Future<void> saveStatsSnapshot(StatsSnapshot snapshot) async {
    // TODO: Persist to Supabase stats_snapshots table in Phase 6.2
  }

  @override
  Future<List<StatsSnapshot>> getStatsSnapshots({int limit = 30}) async {
    // TODO: Fetch from Supabase in Phase 6.2
    return [];
  }

  @override
  Future<StatsSnapshot?> getLatestSnapshot() async {
    // TODO: Fetch from Supabase in Phase 6.2
    return null;
  }
}
