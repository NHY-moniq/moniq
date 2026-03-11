// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shift_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ShiftModelImpl _$$ShiftModelImplFromJson(Map<String, dynamic> json) =>
    _$ShiftModelImpl(
      id: json['id'] as String,
      scheduleId: json['schedule_id'] as String,
      teamId: json['team_id'] as String,
      userId: json['user_id'] as String,
      shiftDate: DateTime.parse(json['shift_date'] as String),
      shiftTypeId: json['shift_type_id'] as String,
      note: json['note'] as String?,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$$ShiftModelImplToJson(_$ShiftModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'schedule_id': instance.scheduleId,
      'team_id': instance.teamId,
      'user_id': instance.userId,
      'shift_date': instance.shiftDate.toIso8601String(),
      'shift_type_id': instance.shiftTypeId,
      'note': instance.note,
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
    };
