// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'wanted_request_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

WantedRequestModel _$WantedRequestModelFromJson(Map<String, dynamic> json) {
  return _WantedRequestModel.fromJson(json);
}

/// @nodoc
mixin _$WantedRequestModel {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'team_id')
  String get teamId => throw _privateConstructorUsedError;
  @JsonKey(name: 'period_start')
  DateTime get periodStart => throw _privateConstructorUsedError;
  @JsonKey(name: 'period_end')
  DateTime get periodEnd => throw _privateConstructorUsedError;
  DateTime? get deadline => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError; // collecting, closed
  @JsonKey(name: 'created_by')
  String get createdBy => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime? get createdAt => throw _privateConstructorUsedError;

  /// Serializes this WantedRequestModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of WantedRequestModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $WantedRequestModelCopyWith<WantedRequestModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WantedRequestModelCopyWith<$Res> {
  factory $WantedRequestModelCopyWith(
    WantedRequestModel value,
    $Res Function(WantedRequestModel) then,
  ) = _$WantedRequestModelCopyWithImpl<$Res, WantedRequestModel>;
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'team_id') String teamId,
    @JsonKey(name: 'period_start') DateTime periodStart,
    @JsonKey(name: 'period_end') DateTime periodEnd,
    DateTime? deadline,
    String status,
    @JsonKey(name: 'created_by') String createdBy,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  });
}

/// @nodoc
class _$WantedRequestModelCopyWithImpl<$Res, $Val extends WantedRequestModel>
    implements $WantedRequestModelCopyWith<$Res> {
  _$WantedRequestModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of WantedRequestModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? teamId = null,
    Object? periodStart = null,
    Object? periodEnd = null,
    Object? deadline = freezed,
    Object? status = null,
    Object? createdBy = null,
    Object? createdAt = freezed,
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
            periodStart: null == periodStart
                ? _value.periodStart
                : periodStart // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            periodEnd: null == periodEnd
                ? _value.periodEnd
                : periodEnd // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            deadline: freezed == deadline
                ? _value.deadline
                : deadline // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as String,
            createdBy: null == createdBy
                ? _value.createdBy
                : createdBy // ignore: cast_nullable_to_non_nullable
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
abstract class _$$WantedRequestModelImplCopyWith<$Res>
    implements $WantedRequestModelCopyWith<$Res> {
  factory _$$WantedRequestModelImplCopyWith(
    _$WantedRequestModelImpl value,
    $Res Function(_$WantedRequestModelImpl) then,
  ) = __$$WantedRequestModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'team_id') String teamId,
    @JsonKey(name: 'period_start') DateTime periodStart,
    @JsonKey(name: 'period_end') DateTime periodEnd,
    DateTime? deadline,
    String status,
    @JsonKey(name: 'created_by') String createdBy,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  });
}

/// @nodoc
class __$$WantedRequestModelImplCopyWithImpl<$Res>
    extends _$WantedRequestModelCopyWithImpl<$Res, _$WantedRequestModelImpl>
    implements _$$WantedRequestModelImplCopyWith<$Res> {
  __$$WantedRequestModelImplCopyWithImpl(
    _$WantedRequestModelImpl _value,
    $Res Function(_$WantedRequestModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of WantedRequestModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? teamId = null,
    Object? periodStart = null,
    Object? periodEnd = null,
    Object? deadline = freezed,
    Object? status = null,
    Object? createdBy = null,
    Object? createdAt = freezed,
  }) {
    return _then(
      _$WantedRequestModelImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        teamId: null == teamId
            ? _value.teamId
            : teamId // ignore: cast_nullable_to_non_nullable
                  as String,
        periodStart: null == periodStart
            ? _value.periodStart
            : periodStart // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        periodEnd: null == periodEnd
            ? _value.periodEnd
            : periodEnd // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        deadline: freezed == deadline
            ? _value.deadline
            : deadline // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as String,
        createdBy: null == createdBy
            ? _value.createdBy
            : createdBy // ignore: cast_nullable_to_non_nullable
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
class _$WantedRequestModelImpl implements _WantedRequestModel {
  const _$WantedRequestModelImpl({
    required this.id,
    @JsonKey(name: 'team_id') required this.teamId,
    @JsonKey(name: 'period_start') required this.periodStart,
    @JsonKey(name: 'period_end') required this.periodEnd,
    this.deadline,
    this.status = 'collecting',
    @JsonKey(name: 'created_by') required this.createdBy,
    @JsonKey(name: 'created_at') this.createdAt,
  });

  factory _$WantedRequestModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$WantedRequestModelImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'team_id')
  final String teamId;
  @override
  @JsonKey(name: 'period_start')
  final DateTime periodStart;
  @override
  @JsonKey(name: 'period_end')
  final DateTime periodEnd;
  @override
  final DateTime? deadline;
  @override
  @JsonKey()
  final String status;
  // collecting, closed
  @override
  @JsonKey(name: 'created_by')
  final String createdBy;
  @override
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;

  @override
  String toString() {
    return 'WantedRequestModel(id: $id, teamId: $teamId, periodStart: $periodStart, periodEnd: $periodEnd, deadline: $deadline, status: $status, createdBy: $createdBy, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WantedRequestModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.teamId, teamId) || other.teamId == teamId) &&
            (identical(other.periodStart, periodStart) ||
                other.periodStart == periodStart) &&
            (identical(other.periodEnd, periodEnd) ||
                other.periodEnd == periodEnd) &&
            (identical(other.deadline, deadline) ||
                other.deadline == deadline) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.createdBy, createdBy) ||
                other.createdBy == createdBy) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    teamId,
    periodStart,
    periodEnd,
    deadline,
    status,
    createdBy,
    createdAt,
  );

  /// Create a copy of WantedRequestModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$WantedRequestModelImplCopyWith<_$WantedRequestModelImpl> get copyWith =>
      __$$WantedRequestModelImplCopyWithImpl<_$WantedRequestModelImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$WantedRequestModelImplToJson(this);
  }
}

abstract class _WantedRequestModel implements WantedRequestModel {
  const factory _WantedRequestModel({
    required final String id,
    @JsonKey(name: 'team_id') required final String teamId,
    @JsonKey(name: 'period_start') required final DateTime periodStart,
    @JsonKey(name: 'period_end') required final DateTime periodEnd,
    final DateTime? deadline,
    final String status,
    @JsonKey(name: 'created_by') required final String createdBy,
    @JsonKey(name: 'created_at') final DateTime? createdAt,
  }) = _$WantedRequestModelImpl;

  factory _WantedRequestModel.fromJson(Map<String, dynamic> json) =
      _$WantedRequestModelImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'team_id')
  String get teamId;
  @override
  @JsonKey(name: 'period_start')
  DateTime get periodStart;
  @override
  @JsonKey(name: 'period_end')
  DateTime get periodEnd;
  @override
  DateTime? get deadline;
  @override
  String get status; // collecting, closed
  @override
  @JsonKey(name: 'created_by')
  String get createdBy;
  @override
  @JsonKey(name: 'created_at')
  DateTime? get createdAt;

  /// Create a copy of WantedRequestModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$WantedRequestModelImplCopyWith<_$WantedRequestModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

WantedEntryModel _$WantedEntryModelFromJson(Map<String, dynamic> json) {
  return _WantedEntryModel.fromJson(json);
}

/// @nodoc
mixin _$WantedEntryModel {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'wanted_request_id')
  String get wantedRequestId => throw _privateConstructorUsedError;
  @JsonKey(name: 'team_id')
  String get teamId => throw _privateConstructorUsedError;
  @JsonKey(name: 'user_id')
  String get userId => throw _privateConstructorUsedError;
  @JsonKey(name: 'wanted_date')
  DateTime get wantedDate => throw _privateConstructorUsedError;
  String? get reason => throw _privateConstructorUsedError;
  int get priority => throw _privateConstructorUsedError; // 1=최우선, 2=차선, 3=가능하면
  @JsonKey(name: 'created_at')
  DateTime? get createdAt => throw _privateConstructorUsedError;

  /// Serializes this WantedEntryModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of WantedEntryModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $WantedEntryModelCopyWith<WantedEntryModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WantedEntryModelCopyWith<$Res> {
  factory $WantedEntryModelCopyWith(
    WantedEntryModel value,
    $Res Function(WantedEntryModel) then,
  ) = _$WantedEntryModelCopyWithImpl<$Res, WantedEntryModel>;
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'wanted_request_id') String wantedRequestId,
    @JsonKey(name: 'team_id') String teamId,
    @JsonKey(name: 'user_id') String userId,
    @JsonKey(name: 'wanted_date') DateTime wantedDate,
    String? reason,
    int priority,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  });
}

/// @nodoc
class _$WantedEntryModelCopyWithImpl<$Res, $Val extends WantedEntryModel>
    implements $WantedEntryModelCopyWith<$Res> {
  _$WantedEntryModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of WantedEntryModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? wantedRequestId = null,
    Object? teamId = null,
    Object? userId = null,
    Object? wantedDate = null,
    Object? reason = freezed,
    Object? priority = null,
    Object? createdAt = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            wantedRequestId: null == wantedRequestId
                ? _value.wantedRequestId
                : wantedRequestId // ignore: cast_nullable_to_non_nullable
                      as String,
            teamId: null == teamId
                ? _value.teamId
                : teamId // ignore: cast_nullable_to_non_nullable
                      as String,
            userId: null == userId
                ? _value.userId
                : userId // ignore: cast_nullable_to_non_nullable
                      as String,
            wantedDate: null == wantedDate
                ? _value.wantedDate
                : wantedDate // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            reason: freezed == reason
                ? _value.reason
                : reason // ignore: cast_nullable_to_non_nullable
                      as String?,
            priority: null == priority
                ? _value.priority
                : priority // ignore: cast_nullable_to_non_nullable
                      as int,
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
abstract class _$$WantedEntryModelImplCopyWith<$Res>
    implements $WantedEntryModelCopyWith<$Res> {
  factory _$$WantedEntryModelImplCopyWith(
    _$WantedEntryModelImpl value,
    $Res Function(_$WantedEntryModelImpl) then,
  ) = __$$WantedEntryModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'wanted_request_id') String wantedRequestId,
    @JsonKey(name: 'team_id') String teamId,
    @JsonKey(name: 'user_id') String userId,
    @JsonKey(name: 'wanted_date') DateTime wantedDate,
    String? reason,
    int priority,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  });
}

/// @nodoc
class __$$WantedEntryModelImplCopyWithImpl<$Res>
    extends _$WantedEntryModelCopyWithImpl<$Res, _$WantedEntryModelImpl>
    implements _$$WantedEntryModelImplCopyWith<$Res> {
  __$$WantedEntryModelImplCopyWithImpl(
    _$WantedEntryModelImpl _value,
    $Res Function(_$WantedEntryModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of WantedEntryModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? wantedRequestId = null,
    Object? teamId = null,
    Object? userId = null,
    Object? wantedDate = null,
    Object? reason = freezed,
    Object? priority = null,
    Object? createdAt = freezed,
  }) {
    return _then(
      _$WantedEntryModelImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        wantedRequestId: null == wantedRequestId
            ? _value.wantedRequestId
            : wantedRequestId // ignore: cast_nullable_to_non_nullable
                  as String,
        teamId: null == teamId
            ? _value.teamId
            : teamId // ignore: cast_nullable_to_non_nullable
                  as String,
        userId: null == userId
            ? _value.userId
            : userId // ignore: cast_nullable_to_non_nullable
                  as String,
        wantedDate: null == wantedDate
            ? _value.wantedDate
            : wantedDate // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        reason: freezed == reason
            ? _value.reason
            : reason // ignore: cast_nullable_to_non_nullable
                  as String?,
        priority: null == priority
            ? _value.priority
            : priority // ignore: cast_nullable_to_non_nullable
                  as int,
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
class _$WantedEntryModelImpl implements _WantedEntryModel {
  const _$WantedEntryModelImpl({
    required this.id,
    @JsonKey(name: 'wanted_request_id') required this.wantedRequestId,
    @JsonKey(name: 'team_id') required this.teamId,
    @JsonKey(name: 'user_id') required this.userId,
    @JsonKey(name: 'wanted_date') required this.wantedDate,
    this.reason,
    this.priority = 1,
    @JsonKey(name: 'created_at') this.createdAt,
  });

  factory _$WantedEntryModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$WantedEntryModelImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'wanted_request_id')
  final String wantedRequestId;
  @override
  @JsonKey(name: 'team_id')
  final String teamId;
  @override
  @JsonKey(name: 'user_id')
  final String userId;
  @override
  @JsonKey(name: 'wanted_date')
  final DateTime wantedDate;
  @override
  final String? reason;
  @override
  @JsonKey()
  final int priority;
  // 1=최우선, 2=차선, 3=가능하면
  @override
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;

  @override
  String toString() {
    return 'WantedEntryModel(id: $id, wantedRequestId: $wantedRequestId, teamId: $teamId, userId: $userId, wantedDate: $wantedDate, reason: $reason, priority: $priority, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WantedEntryModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.wantedRequestId, wantedRequestId) ||
                other.wantedRequestId == wantedRequestId) &&
            (identical(other.teamId, teamId) || other.teamId == teamId) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.wantedDate, wantedDate) ||
                other.wantedDate == wantedDate) &&
            (identical(other.reason, reason) || other.reason == reason) &&
            (identical(other.priority, priority) ||
                other.priority == priority) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    wantedRequestId,
    teamId,
    userId,
    wantedDate,
    reason,
    priority,
    createdAt,
  );

  /// Create a copy of WantedEntryModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$WantedEntryModelImplCopyWith<_$WantedEntryModelImpl> get copyWith =>
      __$$WantedEntryModelImplCopyWithImpl<_$WantedEntryModelImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$WantedEntryModelImplToJson(this);
  }
}

abstract class _WantedEntryModel implements WantedEntryModel {
  const factory _WantedEntryModel({
    required final String id,
    @JsonKey(name: 'wanted_request_id') required final String wantedRequestId,
    @JsonKey(name: 'team_id') required final String teamId,
    @JsonKey(name: 'user_id') required final String userId,
    @JsonKey(name: 'wanted_date') required final DateTime wantedDate,
    final String? reason,
    final int priority,
    @JsonKey(name: 'created_at') final DateTime? createdAt,
  }) = _$WantedEntryModelImpl;

  factory _WantedEntryModel.fromJson(Map<String, dynamic> json) =
      _$WantedEntryModelImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'wanted_request_id')
  String get wantedRequestId;
  @override
  @JsonKey(name: 'team_id')
  String get teamId;
  @override
  @JsonKey(name: 'user_id')
  String get userId;
  @override
  @JsonKey(name: 'wanted_date')
  DateTime get wantedDate;
  @override
  String? get reason;
  @override
  int get priority; // 1=최우선, 2=차선, 3=가능하면
  @override
  @JsonKey(name: 'created_at')
  DateTime? get createdAt;

  /// Create a copy of WantedEntryModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$WantedEntryModelImplCopyWith<_$WantedEntryModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
