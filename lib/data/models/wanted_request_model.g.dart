// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wanted_request_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$WantedRequestModelImpl _$$WantedRequestModelImplFromJson(
  Map<String, dynamic> json,
) => _$WantedRequestModelImpl(
  id: json['id'] as String,
  teamId: json['team_id'] as String,
  periodStart: DateTime.parse(json['period_start'] as String),
  periodEnd: DateTime.parse(json['period_end'] as String),
  deadline: json['deadline'] == null
      ? null
      : DateTime.parse(json['deadline'] as String),
  status: json['status'] as String? ?? 'collecting',
  createdBy: json['created_by'] as String,
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$$WantedRequestModelImplToJson(
  _$WantedRequestModelImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'team_id': instance.teamId,
  'period_start': instance.periodStart.toIso8601String(),
  'period_end': instance.periodEnd.toIso8601String(),
  'deadline': instance.deadline?.toIso8601String(),
  'status': instance.status,
  'created_by': instance.createdBy,
  'created_at': instance.createdAt?.toIso8601String(),
};

_$WantedEntryModelImpl _$$WantedEntryModelImplFromJson(
  Map<String, dynamic> json,
) => _$WantedEntryModelImpl(
  id: json['id'] as String,
  wantedRequestId: json['wanted_request_id'] as String,
  teamId: json['team_id'] as String,
  userId: json['user_id'] as String,
  wantedDate: DateTime.parse(json['wanted_date'] as String),
  reason: json['reason'] as String?,
  priority: (json['priority'] as num?)?.toInt() ?? 1,
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$$WantedEntryModelImplToJson(
  _$WantedEntryModelImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'wanted_request_id': instance.wantedRequestId,
  'team_id': instance.teamId,
  'user_id': instance.userId,
  'wanted_date': instance.wantedDate.toIso8601String(),
  'reason': instance.reason,
  'priority': instance.priority,
  'created_at': instance.createdAt?.toIso8601String(),
};
