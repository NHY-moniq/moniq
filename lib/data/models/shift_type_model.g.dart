// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shift_type_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ShiftTypeModelImpl _$$ShiftTypeModelImplFromJson(Map<String, dynamic> json) =>
    _$ShiftTypeModelImpl(
      id: json['id'] as String,
      teamId: json['team_id'] as String,
      name: json['name'] as String,
      code: json['code'] as String,
      startTime: json['start_time'] as String?,
      endTime: json['end_time'] as String?,
      color: json['color'] as String? ?? '#A0AEC0',
      displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$$ShiftTypeModelImplToJson(
  _$ShiftTypeModelImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'team_id': instance.teamId,
  'name': instance.name,
  'code': instance.code,
  'start_time': instance.startTime,
  'end_time': instance.endTime,
  'color': instance.color,
  'display_order': instance.displayOrder,
  'is_active': instance.isActive,
  'created_at': instance.createdAt?.toIso8601String(),
  'updated_at': instance.updatedAt?.toIso8601String(),
};
