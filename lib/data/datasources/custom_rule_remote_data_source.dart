import 'package:moniq/data/models/custom_rule_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CustomRuleRemoteDataSource {
  CustomRuleRemoteDataSource({required SupabaseClient client})
      : _client = client;

  final SupabaseClient _client;

  Future<List<CustomRuleModel>> fetchRules(String teamId) async {
    final rows = await _client
        .from('custom_rules')
        .select()
        .eq('team_id', teamId)
        .order('created_at');

    return (rows as List)
        .map((r) => CustomRuleModel.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<CustomRuleModel> addRule({
    required String teamId,
    required String ruleType,
    required Map<String, dynamic> ruleValue,
    required String originalText,
    Map<String, dynamic>? parsedDsl,
    String priority = 'soft',
  }) async {
    final row = await _client
        .from('custom_rules')
        .insert({
          'team_id': teamId,
          'rule_type': ruleType,
          'rule_value': ruleValue,
          'original_text': originalText,
          'parsed_dsl': parsedDsl,
          'priority': priority,
          'is_active': true,
        })
        .select()
        .single();

    return CustomRuleModel.fromJson(row);
  }

  Future<void> toggleActive(String ruleId, {required bool isActive}) async {
    await _client
        .from('custom_rules')
        .update({'is_active': isActive})
        .eq('id', ruleId);
  }

  Future<void> updatePriority(String ruleId, {required String priority}) async {
    await _client
        .from('custom_rules')
        .update({'priority': priority})
        .eq('id', ruleId);
  }

  Future<void> deleteRule(String ruleId) async {
    await _client.from('custom_rules').delete().eq('id', ruleId);
  }

  /// 팀의 누적 "생성 시도" 횟수 조회 (없으면 0).
  Future<int> getParseAttempts(String teamId) async {
    final row = await _client
        .from('custom_rule_usage')
        .select('attempt_count')
        .eq('team_id', teamId)
        .maybeSingle();
    return (row?['attempt_count'] as int?) ?? 0;
  }
}
