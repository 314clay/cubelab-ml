import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cubelab/data/models/user.dart';
import 'package:cubelab/shared/providers/repository_providers.dart';

/// Current authenticated user
final currentUserProvider = FutureProvider<AppUser?>((ref) async {
  final repository = ref.watch(userRepositoryProvider);
  return repository.getCurrentUser();
});

/// Whether the user is signed in (not anonymous)
final isSignedInProvider = FutureProvider<bool>((ref) async {
  final repository = ref.watch(userRepositoryProvider);
  return repository.isSignedIn();
});

/// Aggregated profile stats from multiple repositories
final profileStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repository = ref.watch(profileRepositoryProvider);
  return repository.getProfileStats();
});

/// User settings derived from current user, mutable for local edits
final userSettingsProvider = StateProvider<UserSettings?>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  return userAsync.valueOrNull?.settings;
});
