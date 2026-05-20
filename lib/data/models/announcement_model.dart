import 'package:freezed_annotation/freezed_annotation.dart';

part 'announcement_model.freezed.dart';
part 'announcement_model.g.dart';

@freezed
class AnnouncementModel with _$AnnouncementModel {
  const factory AnnouncementModel({
    required String id,
    @JsonKey(name: 'team_id') required String teamId,
    required String title,
    String? content,
    @JsonKey(name: 'created_by') required String createdBy,
    @JsonKey(name: 'is_pinned') @Default(false) bool isPinned,
    @JsonKey(name: 'attachment_urls') @Default([]) List<String> attachmentUrls,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,

    /// 작성자 표시 이름 — `users` 조인으로 채워진다.
    /// 작성자가 탈퇴/삭제된 경우 null.
    @JsonKey(name: 'author_name') String? authorName,

    /// 작성자 프로필 이미지 URL — `users` 조인으로 채워진다.
    @JsonKey(name: 'author_avatar_url') String? authorAvatarUrl,

    /// 공지에 달린 댓글 수 — `announcement_comments(count)` 집계로 채워진다.
    @JsonKey(name: 'comment_count') @Default(0) int commentCount,
  }) = _AnnouncementModel;

  factory AnnouncementModel.fromJson(Map<String, dynamic> json) =>
      _$AnnouncementModelFromJson(json);
}

@freezed
class AnnouncementCommentModel with _$AnnouncementCommentModel {
  const factory AnnouncementCommentModel({
    required String id,
    @JsonKey(name: 'announcement_id') required String announcementId,
    @JsonKey(name: 'team_id') required String teamId,
    @JsonKey(name: 'user_id') required String userId,
    required String content,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  }) = _AnnouncementCommentModel;

  factory AnnouncementCommentModel.fromJson(Map<String, dynamic> json) =>
      _$AnnouncementCommentModelFromJson(json);
}

class AnnouncementCommentWithUser {
  AnnouncementCommentWithUser({
    required this.comment,
    required this.displayName,
  });
  final AnnouncementCommentModel comment;
  final String displayName;
}

class AnnouncementWithTeam {
  AnnouncementWithTeam({required this.announcement, required this.teamName});

  final AnnouncementModel announcement;
  final String teamName;
}
