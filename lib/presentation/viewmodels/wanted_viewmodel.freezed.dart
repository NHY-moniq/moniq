// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'wanted_viewmodel.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$WantedAdminState {
  String get teamId => throw _privateConstructorUsedError;
  WantedRequestModel? get activeRequest => throw _privateConstructorUsedError;
  List<WantedEntryWithUser> get allEntries =>
      throw _privateConstructorUsedError;
  bool get isCreating => throw _privateConstructorUsedError;
  bool get isLoading => throw _privateConstructorUsedError;
  String? get error => throw _privateConstructorUsedError;

  /// Create a copy of WantedAdminState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $WantedAdminStateCopyWith<WantedAdminState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WantedAdminStateCopyWith<$Res> {
  factory $WantedAdminStateCopyWith(
    WantedAdminState value,
    $Res Function(WantedAdminState) then,
  ) = _$WantedAdminStateCopyWithImpl<$Res, WantedAdminState>;
  @useResult
  $Res call({
    String teamId,
    WantedRequestModel? activeRequest,
    List<WantedEntryWithUser> allEntries,
    bool isCreating,
    bool isLoading,
    String? error,
  });

  $WantedRequestModelCopyWith<$Res>? get activeRequest;
}

/// @nodoc
class _$WantedAdminStateCopyWithImpl<$Res, $Val extends WantedAdminState>
    implements $WantedAdminStateCopyWith<$Res> {
  _$WantedAdminStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of WantedAdminState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? teamId = null,
    Object? activeRequest = freezed,
    Object? allEntries = null,
    Object? isCreating = null,
    Object? isLoading = null,
    Object? error = freezed,
  }) {
    return _then(
      _value.copyWith(
            teamId: null == teamId
                ? _value.teamId
                : teamId // ignore: cast_nullable_to_non_nullable
                      as String,
            activeRequest: freezed == activeRequest
                ? _value.activeRequest
                : activeRequest // ignore: cast_nullable_to_non_nullable
                      as WantedRequestModel?,
            allEntries: null == allEntries
                ? _value.allEntries
                : allEntries // ignore: cast_nullable_to_non_nullable
                      as List<WantedEntryWithUser>,
            isCreating: null == isCreating
                ? _value.isCreating
                : isCreating // ignore: cast_nullable_to_non_nullable
                      as bool,
            isLoading: null == isLoading
                ? _value.isLoading
                : isLoading // ignore: cast_nullable_to_non_nullable
                      as bool,
            error: freezed == error
                ? _value.error
                : error // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }

  /// Create a copy of WantedAdminState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $WantedRequestModelCopyWith<$Res>? get activeRequest {
    if (_value.activeRequest == null) {
      return null;
    }

    return $WantedRequestModelCopyWith<$Res>(_value.activeRequest!, (value) {
      return _then(_value.copyWith(activeRequest: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$WantedAdminStateImplCopyWith<$Res>
    implements $WantedAdminStateCopyWith<$Res> {
  factory _$$WantedAdminStateImplCopyWith(
    _$WantedAdminStateImpl value,
    $Res Function(_$WantedAdminStateImpl) then,
  ) = __$$WantedAdminStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String teamId,
    WantedRequestModel? activeRequest,
    List<WantedEntryWithUser> allEntries,
    bool isCreating,
    bool isLoading,
    String? error,
  });

  @override
  $WantedRequestModelCopyWith<$Res>? get activeRequest;
}

/// @nodoc
class __$$WantedAdminStateImplCopyWithImpl<$Res>
    extends _$WantedAdminStateCopyWithImpl<$Res, _$WantedAdminStateImpl>
    implements _$$WantedAdminStateImplCopyWith<$Res> {
  __$$WantedAdminStateImplCopyWithImpl(
    _$WantedAdminStateImpl _value,
    $Res Function(_$WantedAdminStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of WantedAdminState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? teamId = null,
    Object? activeRequest = freezed,
    Object? allEntries = null,
    Object? isCreating = null,
    Object? isLoading = null,
    Object? error = freezed,
  }) {
    return _then(
      _$WantedAdminStateImpl(
        teamId: null == teamId
            ? _value.teamId
            : teamId // ignore: cast_nullable_to_non_nullable
                  as String,
        activeRequest: freezed == activeRequest
            ? _value.activeRequest
            : activeRequest // ignore: cast_nullable_to_non_nullable
                  as WantedRequestModel?,
        allEntries: null == allEntries
            ? _value._allEntries
            : allEntries // ignore: cast_nullable_to_non_nullable
                  as List<WantedEntryWithUser>,
        isCreating: null == isCreating
            ? _value.isCreating
            : isCreating // ignore: cast_nullable_to_non_nullable
                  as bool,
        isLoading: null == isLoading
            ? _value.isLoading
            : isLoading // ignore: cast_nullable_to_non_nullable
                  as bool,
        error: freezed == error
            ? _value.error
            : error // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc

class _$WantedAdminStateImpl implements _WantedAdminState {
  const _$WantedAdminStateImpl({
    required this.teamId,
    this.activeRequest,
    final List<WantedEntryWithUser> allEntries = const [],
    this.isCreating = false,
    this.isLoading = false,
    this.error,
  }) : _allEntries = allEntries;

  @override
  final String teamId;
  @override
  final WantedRequestModel? activeRequest;
  final List<WantedEntryWithUser> _allEntries;
  @override
  @JsonKey()
  List<WantedEntryWithUser> get allEntries {
    if (_allEntries is EqualUnmodifiableListView) return _allEntries;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_allEntries);
  }

  @override
  @JsonKey()
  final bool isCreating;
  @override
  @JsonKey()
  final bool isLoading;
  @override
  final String? error;

  @override
  String toString() {
    return 'WantedAdminState(teamId: $teamId, activeRequest: $activeRequest, allEntries: $allEntries, isCreating: $isCreating, isLoading: $isLoading, error: $error)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WantedAdminStateImpl &&
            (identical(other.teamId, teamId) || other.teamId == teamId) &&
            (identical(other.activeRequest, activeRequest) ||
                other.activeRequest == activeRequest) &&
            const DeepCollectionEquality().equals(
              other._allEntries,
              _allEntries,
            ) &&
            (identical(other.isCreating, isCreating) ||
                other.isCreating == isCreating) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.error, error) || other.error == error));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    teamId,
    activeRequest,
    const DeepCollectionEquality().hash(_allEntries),
    isCreating,
    isLoading,
    error,
  );

  /// Create a copy of WantedAdminState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$WantedAdminStateImplCopyWith<_$WantedAdminStateImpl> get copyWith =>
      __$$WantedAdminStateImplCopyWithImpl<_$WantedAdminStateImpl>(
        this,
        _$identity,
      );
}

abstract class _WantedAdminState implements WantedAdminState {
  const factory _WantedAdminState({
    required final String teamId,
    final WantedRequestModel? activeRequest,
    final List<WantedEntryWithUser> allEntries,
    final bool isCreating,
    final bool isLoading,
    final String? error,
  }) = _$WantedAdminStateImpl;

  @override
  String get teamId;
  @override
  WantedRequestModel? get activeRequest;
  @override
  List<WantedEntryWithUser> get allEntries;
  @override
  bool get isCreating;
  @override
  bool get isLoading;
  @override
  String? get error;

  /// Create a copy of WantedAdminState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$WantedAdminStateImplCopyWith<_$WantedAdminStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$WantedMemberState {
  String get teamId => throw _privateConstructorUsedError;
  WantedRequestModel? get activeRequest => throw _privateConstructorUsedError;
  List<WantedEntryModel> get myEntries => throw _privateConstructorUsedError;
  bool get isSubmitting => throw _privateConstructorUsedError;
  String? get error => throw _privateConstructorUsedError;

  /// Create a copy of WantedMemberState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $WantedMemberStateCopyWith<WantedMemberState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WantedMemberStateCopyWith<$Res> {
  factory $WantedMemberStateCopyWith(
    WantedMemberState value,
    $Res Function(WantedMemberState) then,
  ) = _$WantedMemberStateCopyWithImpl<$Res, WantedMemberState>;
  @useResult
  $Res call({
    String teamId,
    WantedRequestModel? activeRequest,
    List<WantedEntryModel> myEntries,
    bool isSubmitting,
    String? error,
  });

  $WantedRequestModelCopyWith<$Res>? get activeRequest;
}

/// @nodoc
class _$WantedMemberStateCopyWithImpl<$Res, $Val extends WantedMemberState>
    implements $WantedMemberStateCopyWith<$Res> {
  _$WantedMemberStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of WantedMemberState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? teamId = null,
    Object? activeRequest = freezed,
    Object? myEntries = null,
    Object? isSubmitting = null,
    Object? error = freezed,
  }) {
    return _then(
      _value.copyWith(
            teamId: null == teamId
                ? _value.teamId
                : teamId // ignore: cast_nullable_to_non_nullable
                      as String,
            activeRequest: freezed == activeRequest
                ? _value.activeRequest
                : activeRequest // ignore: cast_nullable_to_non_nullable
                      as WantedRequestModel?,
            myEntries: null == myEntries
                ? _value.myEntries
                : myEntries // ignore: cast_nullable_to_non_nullable
                      as List<WantedEntryModel>,
            isSubmitting: null == isSubmitting
                ? _value.isSubmitting
                : isSubmitting // ignore: cast_nullable_to_non_nullable
                      as bool,
            error: freezed == error
                ? _value.error
                : error // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }

  /// Create a copy of WantedMemberState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $WantedRequestModelCopyWith<$Res>? get activeRequest {
    if (_value.activeRequest == null) {
      return null;
    }

    return $WantedRequestModelCopyWith<$Res>(_value.activeRequest!, (value) {
      return _then(_value.copyWith(activeRequest: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$WantedMemberStateImplCopyWith<$Res>
    implements $WantedMemberStateCopyWith<$Res> {
  factory _$$WantedMemberStateImplCopyWith(
    _$WantedMemberStateImpl value,
    $Res Function(_$WantedMemberStateImpl) then,
  ) = __$$WantedMemberStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String teamId,
    WantedRequestModel? activeRequest,
    List<WantedEntryModel> myEntries,
    bool isSubmitting,
    String? error,
  });

  @override
  $WantedRequestModelCopyWith<$Res>? get activeRequest;
}

/// @nodoc
class __$$WantedMemberStateImplCopyWithImpl<$Res>
    extends _$WantedMemberStateCopyWithImpl<$Res, _$WantedMemberStateImpl>
    implements _$$WantedMemberStateImplCopyWith<$Res> {
  __$$WantedMemberStateImplCopyWithImpl(
    _$WantedMemberStateImpl _value,
    $Res Function(_$WantedMemberStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of WantedMemberState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? teamId = null,
    Object? activeRequest = freezed,
    Object? myEntries = null,
    Object? isSubmitting = null,
    Object? error = freezed,
  }) {
    return _then(
      _$WantedMemberStateImpl(
        teamId: null == teamId
            ? _value.teamId
            : teamId // ignore: cast_nullable_to_non_nullable
                  as String,
        activeRequest: freezed == activeRequest
            ? _value.activeRequest
            : activeRequest // ignore: cast_nullable_to_non_nullable
                  as WantedRequestModel?,
        myEntries: null == myEntries
            ? _value._myEntries
            : myEntries // ignore: cast_nullable_to_non_nullable
                  as List<WantedEntryModel>,
        isSubmitting: null == isSubmitting
            ? _value.isSubmitting
            : isSubmitting // ignore: cast_nullable_to_non_nullable
                  as bool,
        error: freezed == error
            ? _value.error
            : error // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc

class _$WantedMemberStateImpl implements _WantedMemberState {
  const _$WantedMemberStateImpl({
    required this.teamId,
    this.activeRequest,
    final List<WantedEntryModel> myEntries = const [],
    this.isSubmitting = false,
    this.error,
  }) : _myEntries = myEntries;

  @override
  final String teamId;
  @override
  final WantedRequestModel? activeRequest;
  final List<WantedEntryModel> _myEntries;
  @override
  @JsonKey()
  List<WantedEntryModel> get myEntries {
    if (_myEntries is EqualUnmodifiableListView) return _myEntries;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_myEntries);
  }

  @override
  @JsonKey()
  final bool isSubmitting;
  @override
  final String? error;

  @override
  String toString() {
    return 'WantedMemberState(teamId: $teamId, activeRequest: $activeRequest, myEntries: $myEntries, isSubmitting: $isSubmitting, error: $error)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WantedMemberStateImpl &&
            (identical(other.teamId, teamId) || other.teamId == teamId) &&
            (identical(other.activeRequest, activeRequest) ||
                other.activeRequest == activeRequest) &&
            const DeepCollectionEquality().equals(
              other._myEntries,
              _myEntries,
            ) &&
            (identical(other.isSubmitting, isSubmitting) ||
                other.isSubmitting == isSubmitting) &&
            (identical(other.error, error) || other.error == error));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    teamId,
    activeRequest,
    const DeepCollectionEquality().hash(_myEntries),
    isSubmitting,
    error,
  );

  /// Create a copy of WantedMemberState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$WantedMemberStateImplCopyWith<_$WantedMemberStateImpl> get copyWith =>
      __$$WantedMemberStateImplCopyWithImpl<_$WantedMemberStateImpl>(
        this,
        _$identity,
      );
}

abstract class _WantedMemberState implements WantedMemberState {
  const factory _WantedMemberState({
    required final String teamId,
    final WantedRequestModel? activeRequest,
    final List<WantedEntryModel> myEntries,
    final bool isSubmitting,
    final String? error,
  }) = _$WantedMemberStateImpl;

  @override
  String get teamId;
  @override
  WantedRequestModel? get activeRequest;
  @override
  List<WantedEntryModel> get myEntries;
  @override
  bool get isSubmitting;
  @override
  String? get error;

  /// Create a copy of WantedMemberState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$WantedMemberStateImplCopyWith<_$WantedMemberStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
