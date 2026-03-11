import 'package:freezed_annotation/freezed_annotation.dart';

part 'shift_rule_model.freezed.dart';
part 'shift_rule_model.g.dart';

@freezed
class ShiftRuleModel with _$ShiftRuleModel {
  const factory ShiftRuleModel({
    required String id,
    @JsonKey(name: 'team_id') required String teamId,
    @JsonKey(name: 'rule_type') required String ruleType,
    @JsonKey(name: 'rule_value') required Map<String, dynamic> ruleValue,
    @JsonKey(name: 'is_active') @Default(true) bool isActive,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _ShiftRuleModel;

  factory ShiftRuleModel.fromJson(Map<String, dynamic> json) =>
      _$ShiftRuleModelFromJson(json);
}
