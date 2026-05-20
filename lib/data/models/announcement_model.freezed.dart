// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'announcement_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

AnnouncementModel _$AnnouncementModelFromJson(Map<String, dynamic> json) {
  return _AnnouncementModel.fromJson(json);
}

/// @nodoc
mixin _$AnnouncementModel {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'team_id')
  String get teamId => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String? get content => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_by')
  String get createdBy => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_pinned')
  bool get isPinned => throw _privateConstructorUsedError;
  @JsonKey(name: 'attachment_urls')
  List<String> get attachmentUrls => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime? get createdAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'updated_at')
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  /// 작성자 표시 이름 — `users` 조인으로 채워진다.
  /// 작성자가 탈퇴/삭제된 경우 null.
  @JsonKey(name: 'author_name')
  String? get authorName => throw _privateConstructorUsedError;

  /// 작성자 프로필 이미지 URL — `users` 조인으로 채워진다.
  @JsonKey(name: 'author_avatar_url')
  String? get authorAvatarUrl => throw _privateConstructorUsedError;

  /// 공지에 달린 댓글 수 — `announcement_comments(count)` 집계로 채워진다.
  @JsonKey(name: 'comment_count')
  int get commentCount => throw _privateConstructorUsedError;

  /// Serializes this AnnouncementModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AnnouncementModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AnnouncementModelCopyWith<AnnouncementModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AnnouncementModelCopyWith<$Res> {
  factory $AnnouncementModelCopyWith(
    AnnouncementModel value,
    $Res Function(AnnouncementModel) then,
  ) = _$AnnouncementModelCopyWithImpl<$Res, AnnouncementModel>;
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'team_id') String teamId,
    String title,
    String? content,
    @JsonKey(name: 'created_by') String createdBy,
    @JsonKey(name: 'is_pinned') bool isPinned,
    @JsonKey(name: 'attachment_urls') List<String> attachmentUrls,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
    @JsonKey(name: 'author_name') String? authorName,
    @JsonKey(name: 'author_avatar_url') String? authorAvatarUrl,
    @JsonKey(name: 'comment_count') int commentCount,
  });
}

/// @nodoc
class _$AnnouncementModelCopyWithImpl<$Res, $Val extends AnnouncementModel>
    implements $AnnouncementModelCopyWith<$Res> {
  _$AnnouncementModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AnnouncementModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? teamId = null,
    Object? title = null,
    Object? content = freezed,
    Object? createdBy = null,
    Object? isPinned = null,
    Object? attachmentUrls = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
    Object? authorName = freezed,
    Object? authorAvatarUrl = freezed,
    Object? commentCount = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            teamId: null == teamId
                ? _value.teamId
                : teamId // ignore: cast_nullable_to_non_nullable
                      as String,
            title: null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String,
            content: freezed == content
                ? _value.content
                : content // ignore: cast_nullable_to_non_nullable
                      as String?,
            createdBy: null == createdBy
                ? _value.createdBy
                : createdBy // ignore: cast_nullable_to_non_nullable
                      as String,
            isPinned: null == isPinned
                ? _value.isPinned
                : isPinned // ignore: cast_nullable_to_non_nullable
                      as bool,
            attachmentUrls: null == attachmentUrls
                ? _value.attachmentUrls
                : attachmentUrls // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            createdAt: freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            updatedAt: freezed == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            authorName: freezed == authorName
                ? _value.authorName
                : authorName // ignore: cast_nullable_to_non_nullable
                      as String?,
            authorAvatarUrl: freezed == authorAvatarUrl
                ? _value.authorAvatarUrl
                : authorAvatarUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            commentCount: null == commentCount
                ? _value.commentCount
                : commentCount // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AnnouncementModelImplCopyWith<$Res>
    implements $AnnouncementModelCopyWith<$Res> {
  factory _$$AnnouncementModelImplCopyWith(
    _$AnnouncementModelImpl value,
    $Res Function(_$AnnouncementModelImpl) then,
  ) = __$$AnnouncementModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'team_id') String teamId,
    String title,
    String? content,
    @JsonKey(name: 'created_by') String createdBy,
    @JsonKey(name: 'is_pinned') bool isPinned,
    @JsonKey(name: 'attachment_urls') List<String> attachmentUrls,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
    @JsonKey(name: 'author_name') String? authorName,
    @JsonKey(name: 'author_avatar_url') String? authorAvatarUrl,
    @JsonKey(name: 'comment_count') int commentCount,
  });
}

/// @nodoc
class __$$AnnouncementModelImplCopyWithImpl<$Res>
    extends _$AnnouncementModelCopyWithImpl<$Res, _$AnnouncementModelImpl>
    implements _$$AnnouncementModelImplCopyWith<$Res> {
  __$$AnnouncementModelImplCopyWithImpl(
    _$AnnouncementModelImpl _value,
    $Res Function(_$AnnouncementModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AnnouncementModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? teamId = null,
    Object? title = null,
    Object? content = freezed,
    Object? createdBy = null,
    Object? isPinned = null,
    Object? attachmentUrls = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
    Object? authorName = freezed,
    Object? authorAvatarUrl = freezed,
    Object? commentCount = null,
  }) {
    return _then(
      _$AnnouncementModelImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        teamId: null == teamId
            ? _value.teamId
            : teamId // ignore: cast_nullable_to_non_nullable
                  as String,
        title: null == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        content: freezed == content
            ? _value.content
            : content // ignore: cast_nullable_to_non_nullable
                  as String?,
        createdBy: null == createdBy
            ? _value.createdBy
            : createdBy // ignore: cast_nullable_to_non_nullable
                  as String,
        isPinned: null == isPinned
            ? _value.isPinned
            : isPinned // ignore: cast_nullable_to_non_nullable
                  as bool,
        attachmentUrls: null == attachmentUrls
            ? _value._attachmentUrls
            : attachmentUrls // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        createdAt: freezed == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        updatedAt: freezed == updatedAt
            ? _value.updatedAt
            : updatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        authorName: freezed == authorName
            ? _value.authorName
            : authorName // ignore: cast_nullable_to_non_nullable
                  as String?,
        authorAvatarUrl: freezed == authorAvatarUrl
            ? _value.authorAvatarUrl
            : authorAvatarUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        commentCount: null == commentCount
            ? _value.commentCount
            : commentCount // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AnnouncementModelImpl implements _AnnouncementModel {
  const _$AnnouncementModelImpl({
    required this.id,
    @JsonKey(name: 'team_id') required this.teamId,
    required this.title,
    this.content,
    @JsonKey(name: 'created_by') required this.createdBy,
    @JsonKey(name: 'is_pinned') this.isPinned = false,
    @JsonKey(name: 'attachment_urls')
    final List<String> attachmentUrls = const [],
    @JsonKey(name: 'created_at') this.createdAt,
    @JsonKey(name: 'updated_at') this.updatedAt,
    @JsonKey(name: 'author_name') this.authorName,
    @JsonKey(name: 'author_avatar_url') this.authorAvatarUrl,
    @JsonKey(name: 'comment_count') this.commentCount = 0,
  }) : _attachmentUrls = attachmentUrls;

  factory _$AnnouncementModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$AnnouncementModelImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'team_id')
  final String teamId;
  @override
  final String title;
  @override
  final String? content;
  @override
  @JsonKey(name: 'created_by')
  final String createdBy;
  @override
  @JsonKey(name: 'is_pinned')
  final bool isPinned;
  final List<String> _attachmentUrls;
  @override
  @JsonKey(name: 'attachment_urls')
  List<String> get attachmentUrls {
    if (_attachmentUrls is EqualUnmodifiableListView) return _attachmentUrls;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_attachmentUrls);
  }

  @override
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  @override
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  /// 작성자 표시 이름 — `users` 조인으로 채워진다.
  /// 작성자가 탈퇴/삭제된 경우 null.
  @override
  @JsonKey(name: 'author_name')
  final String? authorName;

  /// 작성자 프로필 이미지 URL — `users` 조인으로 채워진다.
  @override
  @JsonKey(name: 'author_avatar_url')
  final String? authorAvatarUrl;

  /// 공지에 달린 댓글 수 — `announcement_comments(count)` 집계로 채워진다.
  @override
  @JsonKey(name: 'comment_count')
  final int commentCount;

  @override
  String toString() {
    return 'AnnouncementModel(id: $id, teamId: $teamId, title: $title, content: $content, createdBy: $createdBy, isPinned: $isPinned, attachmentUrls: $attachmentUrls, createdAt: $createdAt, updatedAt: $updatedAt, authorName: $authorName, authorAvatarUrl: $authorAvatarUrl, commentCount: $commentCount)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AnnouncementModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.teamId, teamId) || other.teamId == teamId) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.content, content) || other.content == content) &&
            (identical(other.createdBy, createdBy) ||
                other.createdBy == createdBy) &&
            (identical(other.isPinned, isPinned) ||
                other.isPinned == isPinned) &&
            const DeepCollectionEquality().equals(
              other._attachmentUrls,
              _attachmentUrls,
            ) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.authorName, authorName) ||
                other.authorName == authorName) &&
            (identical(other.authorAvatarUrl, authorAvatarUrl) ||
                other.authorAvatarUrl == authorAvatarUrl) &&
            (identical(other.commentCount, commentCount) ||
                other.commentCount == commentCount));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    teamId,
    title,
    content,
    createdBy,
    isPinned,
    const DeepCollectionEquality().hash(_attachmentUrls),
    createdAt,
    updatedAt,
    authorName,
    authorAvatarUrl,
    commentCount,
  );

  /// Create a copy of AnnouncementModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AnnouncementModelImplCopyWith<_$AnnouncementModelImpl> get copyWith =>
      __$$AnnouncementModelImplCopyWithImpl<_$AnnouncementModelImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$AnnouncementModelImplToJson(this);
  }
}

abstract class _AnnouncementModel implements AnnouncementModel {
  const factory _AnnouncementModel({
    required final String id,
    @JsonKey(name: 'team_id') required final String teamId,
    required final String title,
    final String? content,
    @JsonKey(name: 'created_by') required final String createdBy,
    @JsonKey(name: 'is_pinned') final bool isPinned,
    @JsonKey(name: 'attachment_urls') final List<String> attachmentUrls,
    @JsonKey(name: 'created_at') final DateTime? createdAt,
    @JsonKey(name: 'updated_at') final DateTime? updatedAt,
    @JsonKey(name: 'author_name') final String? authorName,
    @JsonKey(name: 'author_avatar_url') final String? authorAvatarUrl,
    @JsonKey(name: 'comment_count') final int commentCount,
  }) = _$AnnouncementModelImpl;

  factory _AnnouncementModel.fromJson(Map<String, dynamic> json) =
      _$AnnouncementModelImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'team_id')
  String get teamId;
  @override
  String get title;
  @override
  String? get content;
  @override
  @JsonKey(name: 'created_by')
  String get createdBy;
  @override
  @JsonKey(name: 'is_pinned')
  bool get isPinned;
  @override
  @JsonKey(name: 'attachment_urls')
  List<String> get attachmentUrls;
  @override
  @JsonKey(name: 'created_at')
  DateTime? get createdAt;
  @override
  @JsonKey(name: 'updated_at')
  DateTime? get updatedAt;

  /// 작성자 표시 이름 — `users` 조인으로 채워진다.
  /// 작성자가 탈퇴/삭제된 경우 null.
  @override
  @JsonKey(name: 'author_name')
  String? get authorName;

  /// 작성자 프로필 이미지 URL — `users` 조인으로 채워진다.
  @override
  @JsonKey(name: 'author_avatar_url')
  String? get authorAvatarUrl;

  /// 공지에 달린 댓글 수 — `announcement_comments(count)` 집계로 채워진다.
  @override
  @JsonKey(name: 'comment_count')
  int get commentCount;

  /// Create a copy of AnnouncementModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AnnouncementModelImplCopyWith<_$AnnouncementModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

AnnouncementCommentModel _$AnnouncementCommentModelFromJson(
  Map<String, dynamic> json,
) {
  return _AnnouncementCommentModel.fromJson(json);
}

/// @nodoc
mixin _$AnnouncementCommentModel {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'announcement_id')
  String get announcementId => throw _privateConstructorUsedError;
  @JsonKey(name: 'team_id')
  String get teamId => throw _privateConstructorUsedError;
  @JsonKey(name: 'user_id')
  String get userId => throw _privateConstructorUsedError;
  String get content => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime? get createdAt => throw _privateConstructorUsedError;

  /// Serializes this AnnouncementCommentModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AnnouncementCommentModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AnnouncementCommentModelCopyWith<AnnouncementCommentModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AnnouncementCommentModelCopyWith<$Res> {
  factory $AnnouncementCommentModelCopyWith(
    AnnouncementCommentModel value,
    $Res Function(AnnouncementCommentModel) then,
  ) = _$AnnouncementCommentModelCopyWithImpl<$Res, AnnouncementCommentModel>;
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'announcement_id') String announcementId,
    @JsonKey(name: 'team_id') String teamId,
    @JsonKey(name: 'user_id') String userId,
    String content,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  });
}

/// @nodoc
class _$AnnouncementCommentModelCopyWithImpl<
  $Res,
  $Val extends AnnouncementCommentModel
>
    implements $AnnouncementCommentModelCopyWith<$Res> {
  _$AnnouncementCommentModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AnnouncementCommentModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? announcementId = null,
    Object? teamId = null,
    Object? userId = null,
    Object? content = null,
    Object? createdAt = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            announcementId: null == announcementId
                ? _value.announcementId
                : announcementId // ignore: cast_nullable_to_non_nullable
                      as String,
            teamId: null == teamId
                ? _value.teamId
                : teamId // ignore: cast_nullable_to_non_nullable
                      as String,
            userId: null == userId
                ? _value.userId
                : userId // ignore: cast_nullable_to_non_nullable
                      as String,
            content: null == content
                ? _value.content
                : content // ignore: cast_nullable_to_non_nullable
                      as String,
            createdAt: freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AnnouncementCommentModelImplCopyWith<$Res>
    implements $AnnouncementCommentModelCopyWith<$Res> {
  factory _$$AnnouncementCommentModelImplCopyWith(
    _$AnnouncementCommentModelImpl value,
    $Res Function(_$AnnouncementCommentModelImpl) then,
  ) = __$$AnnouncementCommentModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'announcement_id') String announcementId,
    @JsonKey(name: 'team_id') String teamId,
    @JsonKey(name: 'user_id') String userId,
    String content,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  });
}

/// @nodoc
class __$$AnnouncementCommentModelImplCopyWithImpl<$Res>
    extends
        _$AnnouncementCommentModelCopyWithImpl<
          $Res,
          _$AnnouncementCommentModelImpl
        >
    implements _$$AnnouncementCommentModelImplCopyWith<$Res> {
  __$$AnnouncementCommentModelImplCopyWithImpl(
    _$AnnouncementCommentModelImpl _value,
    $Res Function(_$AnnouncementCommentModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AnnouncementCommentModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? announcementId = null,
    Object? teamId = null,
    Object? userId = null,
    Object? content = null,
    Object? createdAt = freezed,
  }) {
    return _then(
      _$AnnouncementCommentModelImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        announcementId: null == announcementId
            ? _value.announcementId
            : announcementId // ignore: cast_nullable_to_non_nullable
                  as String,
        teamId: null == teamId
            ? _value.teamId
            : teamId // ignore: cast_nullable_to_non_nullable
                  as String,
        userId: null == userId
            ? _value.userId
            : userId // ignore: cast_nullable_to_non_nullable
                  as String,
        content: null == content
            ? _value.content
            : content // ignore: cast_nullable_to_non_nullable
                  as String,
        createdAt: freezed == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AnnouncementCommentModelImpl implements _AnnouncementCommentModel {
  const _$AnnouncementCommentModelImpl({
    required this.id,
    @JsonKey(name: 'announcement_id') required this.announcementId,
    @JsonKey(name: 'team_id') required this.teamId,
    @JsonKey(name: 'user_id') required this.userId,
    required this.content,
    @JsonKey(name: 'created_at') this.createdAt,
  });

  factory _$AnnouncementCommentModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$AnnouncementCommentModelImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'announcement_id')
  final String announcementId;
  @override
  @JsonKey(name: 'team_id')
  final String teamId;
  @override
  @JsonKey(name: 'user_id')
  final String userId;
  @override
  final String content;
  @override
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;

  @override
  String toString() {
    return 'AnnouncementCommentModel(id: $id, announcementId: $announcementId, teamId: $teamId, userId: $userId, content: $content, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AnnouncementCommentModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.announcementId, announcementId) ||
                other.announcementId == announcementId) &&
            (identical(other.teamId, teamId) || other.teamId == teamId) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.content, content) || other.content == content) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    announcementId,
    teamId,
    userId,
    content,
    createdAt,
  );

  /// Create a copy of AnnouncementCommentModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AnnouncementCommentModelImplCopyWith<_$AnnouncementCommentModelImpl>
  get copyWith =>
      __$$AnnouncementCommentModelImplCopyWithImpl<
        _$AnnouncementCommentModelImpl
      >(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AnnouncementCommentModelImplToJson(this);
  }
}

abstract class _AnnouncementCommentModel implements AnnouncementCommentModel {
  const factory _AnnouncementCommentModel({
    required final String id,
    @JsonKey(name: 'announcement_id') required final String announcementId,
    @JsonKey(name: 'team_id') required final String teamId,
    @JsonKey(name: 'user_id') required final String userId,
    required final String content,
    @JsonKey(name: 'created_at') final DateTime? createdAt,
  }) = _$AnnouncementCommentModelImpl;

  factory _AnnouncementCommentModel.fromJson(Map<String, dynamic> json) =
      _$AnnouncementCommentModelImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'announcement_id')
  String get announcementId;
  @override
  @JsonKey(name: 'team_id')
  String get teamId;
  @override
  @JsonKey(name: 'user_id')
  String get userId;
  @override
  String get content;
  @override
  @JsonKey(name: 'created_at')
  DateTime? get createdAt;

  /// Create a copy of AnnouncementCommentModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AnnouncementCommentModelImplCopyWith<_$AnnouncementCommentModelImpl>
  get copyWith => throw _privateConstructorUsedError;
}
