// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'announcement_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AnnouncementModelImpl _$$AnnouncementModelImplFromJson(
  Map<String, dynamic> json,
) => _$AnnouncementModelImpl(
  id: json['id'] as String,
  teamId: json['team_id'] as String,
  title: json['title'] as String,
  content: json['content'] as String?,
  createdBy: json['created_by'] as String,
  isPinned: json['is_pinned'] as bool? ?? false,
  attachmentUrls:
      (json['attachment_urls'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
  updatedAt: json['updated_at'] == null
      ? null
      : DateTime.parse(json['updated_at'] as String),
);

Map<String, dynamic> _$$AnnouncementModelImplToJson(
  _$AnnouncementModelImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'team_id': instance.teamId,
  'title': instance.title,
  'content': instance.content,
  'created_by': instance.createdBy,
  'is_pinned': instance.isPinned,
  'attachment_urls': instance.attachmentUrls,
  'created_at': instance.createdAt?.toIso8601String(),
  'updated_at': instance.updatedAt?.toIso8601String(),
};

_$AnnouncementCommentModelImpl _$$AnnouncementCommentModelImplFromJson(
  Map<String, dynamic> json,
) => _$AnnouncementCommentModelImpl(
  id: json['id'] as String,
  announcementId: json['announcement_id'] as String,
  teamId: json['team_id'] as String,
  userId: json['user_id'] as String,
  content: json['content'] as String,
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$$AnnouncementCommentModelImplToJson(
  _$AnnouncementCommentModelImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'announcement_id': instance.announcementId,
  'team_id': instance.teamId,
  'user_id': instance.userId,
  'content': instance.content,
  'created_at': instance.createdAt?.toIso8601String(),
};
