// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'team_member_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TeamMemberModelImpl _$$TeamMemberModelImplFromJson(
  Map<String, dynamic> json,
) => _$TeamMemberModelImpl(
  id: json['id'] as String,
  teamId: json['team_id'] as String,
  userId: json['user_id'] as String,
  role: json['role'] as String? ?? 'member',
  skillLevel: json['skill_level'] as String?,
  nightExempt: json['night_exempt'] as bool? ?? false,
  dayOnly: json['day_only'] as bool? ?? false,
  nightDedicated: json['night_dedicated'] as bool? ?? false,
  isFavorite: json['is_favorite'] as bool? ?? false,
  joinedAt: json['joined_at'] == null
      ? null
      : DateTime.parse(json['joined_at'] as String),
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
  updatedAt: json['updated_at'] == null
      ? null
      : DateTime.parse(json['updated_at'] as String),
  isDeleted: json['is_deleted'] as bool? ?? false,
);

Map<String, dynamic> _$$TeamMemberModelImplToJson(
  _$TeamMemberModelImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'team_id': instance.teamId,
  'user_id': instance.userId,
  'role': instance.role,
  'skill_level': instance.skillLevel,
  'night_exempt': instance.nightExempt,
  'day_only': instance.dayOnly,
  'night_dedicated': instance.nightDedicated,
  'is_favorite': instance.isFavorite,
  'joined_at': instance.joinedAt?.toIso8601String(),
  'created_at': instance.createdAt?.toIso8601String(),
  'updated_at': instance.updatedAt?.toIso8601String(),
  'is_deleted': instance.isDeleted,
};
