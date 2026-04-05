import 'package:supabase_flutter/supabase_flutter.dart';

class FeedbackRemoteDataSource {
  FeedbackRemoteDataSource({required SupabaseClient client})
      : _client = client;

  final SupabaseClient _client;

  Future<Map<String, dynamic>?> getFeedback(String scheduleId) async {
    final rows = await _client
        .from('schedule_feedback')
        .select()
        .eq('schedule_id', scheduleId)
        .limit(1);
    final list = rows as List;
    return list.isNotEmpty ? list.first as Map<String, dynamic> : null;
  }

  Future<void> saveFeedback({
    required String scheduleId,
    required String teamId,
    required int overallRating,
    required Map<String, int> ruleRatings,
    String? notes,
  }) async {
    await _client.from('schedule_feedback').upsert({
      'schedule_id': scheduleId,
      'team_id': teamId,
      'overall_rating': overallRating,
      'rule_ratings': ruleRatings,
      'notes': notes,
    }, onConflict: 'schedule_id');
  }
}
