import 'package:freezed_annotation/freezed_annotation.dart';

part 'custom_rule_model.freezed.dart';
part 'custom_rule_model.g.dart';

@freezed
class CustomRuleModel with _$CustomRuleModel {
  const factory CustomRuleModel({
    required String id,
    @JsonKey(name: 'team_id') required String teamId,
    @JsonKey(name: 'rule_type') required String ruleType,
    @JsonKey(name: 'rule_value') required Map<String, dynamic> ruleValue,
    @JsonKey(name: 'original_text') required String originalText,
    @JsonKey(name: 'parsed_dsl') Map<String, dynamic>? parsedDsl,
    @Default('soft') String priority,
    @JsonKey(name: 'is_active') @Default(true) bool isActive,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  }) = _CustomRuleModel;

  factory CustomRuleModel.fromJson(Map<String, dynamic> json) =>
      _$CustomRuleModelFromJson(json);
}
