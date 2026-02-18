abstract class ProfileRepository {
  Future<Map<String, dynamic>> getProfileStats();

  Future<List<Map<String, dynamic>>> getAchievements();

  Future<Map<String, dynamic>> getActivitySummary();
}
