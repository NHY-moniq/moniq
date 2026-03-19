// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'request_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

RequestModel _$RequestModelFromJson(Map<String, dynamic> json) {
  return _RequestModel.fromJson(json);
}

/// @nodoc
mixin _$RequestModel {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'team_id')
  String get teamId => throw _privateConstructorUsedError;
  @JsonKey(name: 'requester_user_id')
  String get requesterUserId => throw _privateConstructorUsedError;
  @JsonKey(name: 'source_shift_id')
  String? get sourceShiftId => throw _privateConstructorUsedError;
  @JsonKey(name: 'change_type')
  String get changeType => throw _privateConstructorUsedError;
  @JsonKey(name: 'requested_date')
  DateTime? get requestedDate => throw _privateConstructorUsedError;
  @JsonKey(name: 'requested_shift_type_id')
  String? get requestedShiftTypeId => throw _privateConstructorUsedError;
  String? get reason => throw _privateConstructorUsedError;
  String? get note => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  @JsonKey(name: 'reviewed_by')
  String? get reviewedBy => throw _privateConstructorUsedError;
  @JsonKey(name: 'reviewed_at')
  DateTime? get reviewedAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime? get createdAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'updated_at')
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this RequestModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of RequestModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RequestModelCopyWith<RequestModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RequestModelCopyWith<$Res> {
  factory $RequestModelCopyWith(
    RequestModel value,
    $Res Function(RequestModel) then,
  ) = _$RequestModelCopyWithImpl<$Res, RequestModel>;
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'team_id') String teamId,
    @JsonKey(name: 'requester_user_id') String requesterUserId,
    @JsonKey(name: 'source_shift_id') String? sourceShiftId,
    @JsonKey(name: 'change_type') String changeType,
    @JsonKey(name: 'requested_date') DateTime? requestedDate,
    @JsonKey(name: 'requested_shift_type_id') String? requestedShiftTypeId,
    String? reason,
    String? note,
    String status,
    @JsonKey(name: 'reviewed_by') String? reviewedBy,
    @JsonKey(name: 'reviewed_at') DateTime? reviewedAt,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  });
}

/// @nodoc
class _$RequestModelCopyWithImpl<$Res, $Val extends RequestModel>
    implements $RequestModelCopyWith<$Res> {
  _$RequestModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RequestModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? teamId = null,
    Object? requesterUserId = null,
    Object? sourceShiftId = freezed,
    Object? changeType = null,
    Object? requestedDate = freezed,
    Object? requestedShiftTypeId = freezed,
    Object? reason = freezed,
    Object? note = freezed,
    Object? status = null,
    Object? reviewedBy = freezed,
    Object? reviewedAt = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
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
            requesterUserId: null == requesterUserId
                ? _value.requesterUserId
                : requesterUserId // ignore: cast_nullable_to_non_nullable
                      as String,
            sourceShiftId: freezed == sourceShiftId
                ? _value.sourceShiftId
                : sourceShiftId // ignore: cast_nullable_to_non_nullable
                      as String?,
            changeType: null == changeType
                ? _value.changeType
                : changeType // ignore: cast_nullable_to_non_nullable
                      as String,
            requestedDate: freezed == requestedDate
                ? _value.requestedDate
                : requestedDate // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            requestedShiftTypeId: freezed == requestedShiftTypeId
                ? _value.requestedShiftTypeId
                : requestedShiftTypeId // ignore: cast_nullable_to_non_nullable
                      as String?,
            reason: freezed == reason
                ? _value.reason
                : reason // ignore: cast_nullable_to_non_nullable
                      as String?,
            note: freezed == note
                ? _value.note
                : note // ignore: cast_nullable_to_non_nullable
                      as String?,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as String,
            reviewedBy: freezed == reviewedBy
                ? _value.reviewedBy
                : reviewedBy // ignore: cast_nullable_to_non_nullable
                      as String?,
            reviewedAt: freezed == reviewedAt
                ? _value.reviewedAt
                : reviewedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            createdAt: freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            updatedAt: freezed == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$RequestModelImplCopyWith<$Res>
    implements $RequestModelCopyWith<$Res> {
  factory _$$RequestModelImplCopyWith(
    _$RequestModelImpl value,
    $Res Function(_$RequestModelImpl) then,
  ) = __$$RequestModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'team_id') String teamId,
    @JsonKey(name: 'requester_user_id') String requesterUserId,
    @JsonKey(name: 'source_shift_id') String? sourceShiftId,
    @JsonKey(name: 'change_type') String changeType,
    @JsonKey(name: 'requested_date') DateTime? requestedDate,
    @JsonKey(name: 'requested_shift_type_id') String? requestedShiftTypeId,
    String? reason,
    String? note,
    String status,
    @JsonKey(name: 'reviewed_by') String? reviewedBy,
    @JsonKey(name: 'reviewed_at') DateTime? reviewedAt,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  });
}

/// @nodoc
class __$$RequestModelImplCopyWithImpl<$Res>
    extends _$RequestModelCopyWithImpl<$Res, _$RequestModelImpl>
    implements _$$RequestModelImplCopyWith<$Res> {
  __$$RequestModelImplCopyWithImpl(
    _$RequestModelImpl _value,
    $Res Function(_$RequestModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of RequestModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? teamId = null,
    Object? requesterUserId = null,
    Object? sourceShiftId = freezed,
    Object? changeType = null,
    Object? requestedDate = freezed,
    Object? requestedShiftTypeId = freezed,
    Object? reason = freezed,
    Object? note = freezed,
    Object? status = null,
    Object? reviewedBy = freezed,
    Object? reviewedAt = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(
      _$RequestModelImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        teamId: null == teamId
            ? _value.teamId
            : teamId // ignore: cast_nullable_to_non_nullable
                  as String,
        requesterUserId: null == requesterUserId
            ? _value.requesterUserId
            : requesterUserId // ignore: cast_nullable_to_non_nullable
                  as String,
        sourceShiftId: freezed == sourceShiftId
            ? _value.sourceShiftId
            : sourceShiftId // ignore: cast_nullable_to_non_nullable
                  as String?,
        changeType: null == changeType
            ? _value.changeType
            : changeType // ignore: cast_nullable_to_non_nullable
                  as String,
        requestedDate: freezed == requestedDate
            ? _value.requestedDate
            : requestedDate // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        requestedShiftTypeId: freezed == requestedShiftTypeId
            ? _value.requestedShiftTypeId
            : requestedShiftTypeId // ignore: cast_nullable_to_non_nullable
                  as String?,
        reason: freezed == reason
            ? _value.reason
            : reason // ignore: cast_nullable_to_non_nullable
                  as String?,
        note: freezed == note
            ? _value.note
            : note // ignore: cast_nullable_to_non_nullable
                  as String?,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as String,
        reviewedBy: freezed == reviewedBy
            ? _value.reviewedBy
            : reviewedBy // ignore: cast_nullable_to_non_nullable
                  as String?,
        reviewedAt: freezed == reviewedAt
            ? _value.reviewedAt
            : reviewedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        createdAt: freezed == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        updatedAt: freezed == updatedAt
            ? _value.updatedAt
            : updatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$RequestModelImpl implements _RequestModel {
  const _$RequestModelImpl({
    required this.id,
    @JsonKey(name: 'team_id') required this.teamId,
    @JsonKey(name: 'requester_user_id') required this.requesterUserId,
    @JsonKey(name: 'source_shift_id') this.sourceShiftId,
    @JsonKey(name: 'change_type') required this.changeType,
    @JsonKey(name: 'requested_date') this.requestedDate,
    @JsonKey(name: 'requested_shift_type_id') this.requestedShiftTypeId,
    this.reason,
    this.note,
    this.status = 'pending',
    @JsonKey(name: 'reviewed_by') this.reviewedBy,
    @JsonKey(name: 'reviewed_at') this.reviewedAt,
    @JsonKey(name: 'created_at') this.createdAt,
    @JsonKey(name: 'updated_at') this.updatedAt,
  });

  factory _$RequestModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$RequestModelImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'team_id')
  final String teamId;
  @override
  @JsonKey(name: 'requester_user_id')
  final String requesterUserId;
  @override
  @JsonKey(name: 'source_shift_id')
  final String? sourceShiftId;
  @override
  @JsonKey(name: 'change_type')
  final String changeType;
  @override
  @JsonKey(name: 'requested_date')
  final DateTime? requestedDate;
  @override
  @JsonKey(name: 'requested_shift_type_id')
  final String? requestedShiftTypeId;
  @override
  final String? reason;
  @override
  final String? note;
  @override
  @JsonKey()
  final String status;
  @override
  @JsonKey(name: 'reviewed_by')
  final String? reviewedBy;
  @override
  @JsonKey(name: 'reviewed_at')
  final DateTime? reviewedAt;
  @override
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  @override
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  @override
  String toString() {
    return 'RequestModel(id: $id, teamId: $teamId, requesterUserId: $requesterUserId, sourceShiftId: $sourceShiftId, changeType: $changeType, requestedDate: $requestedDate, requestedShiftTypeId: $requestedShiftTypeId, reason: $reason, note: $note, status: $status, reviewedBy: $reviewedBy, reviewedAt: $reviewedAt, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RequestModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.teamId, teamId) || other.teamId == teamId) &&
            (identical(other.requesterUserId, requesterUserId) ||
                other.requesterUserId == requesterUserId) &&
            (identical(other.sourceShiftId, sourceShiftId) ||
                other.sourceShiftId == sourceShiftId) &&
            (identical(other.changeType, changeType) ||
                other.changeType == changeType) &&
            (identical(other.requestedDate, requestedDate) ||
                other.requestedDate == requestedDate) &&
            (identical(other.requestedShiftTypeId, requestedShiftTypeId) ||
                other.requestedShiftTypeId == requestedShiftTypeId) &&
            (identical(other.reason, reason) || other.reason == reason) &&
            (identical(other.note, note) || other.note == note) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.reviewedBy, reviewedBy) ||
                other.reviewedBy == reviewedBy) &&
            (identical(other.reviewedAt, reviewedAt) ||
                other.reviewedAt == reviewedAt) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    teamId,
    requesterUserId,
    sourceShiftId,
    changeType,
    requestedDate,
    requestedShiftTypeId,
    reason,
    note,
    status,
    reviewedBy,
    reviewedAt,
    createdAt,
    updatedAt,
  );

  /// Create a copy of RequestModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RequestModelImplCopyWith<_$RequestModelImpl> get copyWith =>
      __$$RequestModelImplCopyWithImpl<_$RequestModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$RequestModelImplToJson(this);
  }
}

abstract class _RequestModel implements RequestModel {
  const factory _RequestModel({
    required final String id,
    @JsonKey(name: 'team_id') required final String teamId,
    @JsonKey(name: 'requester_user_id') required final String requesterUserId,
    @JsonKey(name: 'source_shift_id') final String? sourceShiftId,
    @JsonKey(name: 'change_type') required final String changeType,
    @JsonKey(name: 'requested_date') final DateTime? requestedDate,
    @JsonKey(name: 'requested_shift_type_id')
    final String? requestedShiftTypeId,
    final String? reason,
    final String? note,
    final String status,
    @JsonKey(name: 'reviewed_by') final String? reviewedBy,
    @JsonKey(name: 'reviewed_at') final DateTime? reviewedAt,
    @JsonKey(name: 'created_at') final DateTime? createdAt,
    @JsonKey(name: 'updated_at') final DateTime? updatedAt,
  }) = _$RequestModelImpl;

  factory _RequestModel.fromJson(Map<String, dynamic> json) =
      _$RequestModelImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'team_id')
  String get teamId;
  @override
  @JsonKey(name: 'requester_user_id')
  String get requesterUserId;
  @override
  @JsonKey(name: 'source_shift_id')
  String? get sourceShiftId;
  @override
  @JsonKey(name: 'change_type')
  String get changeType;
  @override
  @JsonKey(name: 'requested_date')
  DateTime? get requestedDate;
  @override
  @JsonKey(name: 'requested_shift_type_id')
  String? get requestedShiftTypeId;
  @override
  String? get reason;
  @override
  String? get note;
  @override
  String get status;
  @override
  @JsonKey(name: 'reviewed_by')
  String? get reviewedBy;
  @override
  @JsonKey(name: 'reviewed_at')
  DateTime? get reviewedAt;
  @override
  @JsonKey(name: 'created_at')
  DateTime? get createdAt;
  @override
  @JsonKey(name: 'updated_at')
  DateTime? get updatedAt;

  /// Create a copy of RequestModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RequestModelImplCopyWith<_$RequestModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
