import 'package:moniq/data/datasources/custom_rule_remote_data_source.dart';
import 'package:moniq/data/models/custom_rule_model.dart';

class CustomRuleRepository {
  CustomRuleRepository({required CustomRuleRemoteDataSource dataSource})
      : _ds = dataSource;

  final CustomRuleRemoteDataSource _ds;

  Future<List<CustomRuleModel>> fetchRules(String teamId) =>
      _ds.fetchRules(teamId);

  Future<CustomRuleModel> addRule({
    required String teamId,
    required String ruleType,
    required Map<String, dynamic> ruleValue,
    required String originalText,
    Map<String, dynamic>? parsedDsl,
    String priority = 'soft',
  }) =>
      _ds.addRule(
        teamId: teamId,
        ruleType: ruleType,
        ruleValue: ruleValue,
        originalText: originalText,
        parsedDsl: parsedDsl,
        priority: priority,
      );

  Future<void> toggleActive(String ruleId, {required bool isActive}) =>
      _ds.toggleActive(ruleId, isActive: isActive);

  Future<void> deleteRule(String ruleId) => _ds.deleteRule(ruleId);
}
