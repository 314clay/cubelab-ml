import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cubelab/data/models/cube_scan_encounter.dart';
import 'package:cubelab/data/repositories/cube_scan_repository.dart';

/// Supabase implementation of CubeScanRepository.
/// Persists scan encounters to the cube_scan_encounters table.
class SupabaseCubeScanRepository implements CubeScanRepository {
  final SupabaseClient _client;

  SupabaseCubeScanRepository(this._client);

  @override
  Future<void> saveEncounter(CubeScanEncounter encounter) async {
    await _client.from('cube_scan_encounters').insert(encounter.toSupabase());
  }

  @override
  Future<List<CubeScanEncounter>> getRecentEncounters(
    String userId, {
    int limit = 50,
  }) async {
    final data = await _client
        .from('cube_scan_encounters')
        .select()
        .eq('user_id', userId)
        .order('scanned_at', ascending: false)
        .limit(limit);

    return data
        .map((json) => CubeScanEncounter.fromSupabase(json))
        .toList();
  }
}
