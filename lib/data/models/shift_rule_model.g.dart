// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shift_rule_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ShiftRuleModelImpl _$$ShiftRuleModelImplFromJson(Map<String, dynamic> json) =>
    _$ShiftRuleModelImpl(
      id: json['id'] as String,
      teamId: json['team_id'] as String,
      ruleType: json['rule_type'] as String,
      ruleValue: json['rule_value'] as Map<String, dynamic>,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$$ShiftRuleModelImplToJson(
  _$ShiftRuleModelImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'team_id': instance.teamId,
  'rule_type': instance.ruleType,
  'rule_value': instance.ruleValue,
  'is_active': instance.isActive,
  'created_at': instance.createdAt?.toIso8601String(),
  'updated_at': instance.updatedAt?.toIso8601String(),
};
