// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'request_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$RequestModelImpl _$$RequestModelImplFromJson(Map<String, dynamic> json) =>
    _$RequestModelImpl(
      id: json['id'] as String,
      teamId: json['team_id'] as String,
      requesterUserId: json['requester_user_id'] as String,
      sourceShiftId: json['source_shift_id'] as String?,
      changeType: json['change_type'] as String,
      requestedDate: json['requested_date'] == null
          ? null
          : DateTime.parse(json['requested_date'] as String),
      requestedShiftTypeId: json['requested_shift_type_id'] as String?,
      targetUserId: json['target_user_id'] as String?,
      reason: json['reason'] as String?,
      note: json['note'] as String?,
      status: json['status'] as String? ?? 'pending',
      reviewedBy: json['reviewed_by'] as String?,
      reviewedAt: json['reviewed_at'] == null
          ? null
          : DateTime.parse(json['reviewed_at'] as String),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$$RequestModelImplToJson(_$RequestModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'team_id': instance.teamId,
      'requester_user_id': instance.requesterUserId,
      'source_shift_id': instance.sourceShiftId,
      'change_type': instance.changeType,
      'requested_date': instance.requestedDate?.toIso8601String(),
      'requested_shift_type_id': instance.requestedShiftTypeId,
      'target_user_id': instance.targetUserId,
      'reason': instance.reason,
      'note': instance.note,
      'status': instance.status,
      'reviewed_by': instance.reviewedBy,
      'reviewed_at': instance.reviewedAt?.toIso8601String(),
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
    };
