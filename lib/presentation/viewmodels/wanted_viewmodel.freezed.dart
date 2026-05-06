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
  List<WantedRequestModel> get activeRequests =>
      throw _privateConstructorUsedError;
  List<WantedEntryWithUser> get allEntries =>
      throw _privateConstructorUsedError; // 마감된 최근 수집 (활성 없을 때 표시)
  List<WantedRequestModel> get lastClosedRequests =>
      throw _privateConstructorUsedError;
  WantedRequestModel? get lastClosedRequest =>
      throw _privateConstructorUsedError;
  List<WantedEntryWithUser> get lastClosedEntries =>
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
    List<WantedRequestModel> activeRequests,
    List<WantedEntryWithUser> allEntries,
    List<WantedRequestModel> lastClosedRequests,
    WantedRequestModel? lastClosedRequest,
    List<WantedEntryWithUser> lastClosedEntries,
    bool isCreating,
    bool isLoading,
    String? error,
  });

  $WantedRequestModelCopyWith<$Res>? get activeRequest;
  $WantedRequestModelCopyWith<$Res>? get lastClosedRequest;
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
    Object? activeRequests = null,
    Object? allEntries = null,
    Object? lastClosedRequests = null,
    Object? lastClosedRequest = freezed,
    Object? lastClosedEntries = null,
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
            activeRequests: null == activeRequests
                ? _value.activeRequests
                : activeRequests // ignore: cast_nullable_to_non_nullable
                      as List<WantedRequestModel>,
            allEntries: null == allEntries
                ? _value.allEntries
                : allEntries // ignore: cast_nullable_to_non_nullable
                      as List<WantedEntryWithUser>,
            lastClosedRequests: null == lastClosedRequests
                ? _value.lastClosedRequests
                : lastClosedRequests // ignore: cast_nullable_to_non_nullable
                      as List<WantedRequestModel>,
            lastClosedRequest: freezed == lastClosedRequest
                ? _value.lastClosedRequest
                : lastClosedRequest // ignore: cast_nullable_to_non_nullable
                      as WantedRequestModel?,
            lastClosedEntries: null == lastClosedEntries
                ? _value.lastClosedEntries
                : lastClosedEntries // ignore: cast_nullable_to_non_nullable
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

  /// Create a copy of WantedAdminState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $WantedRequestModelCopyWith<$Res>? get lastClosedRequest {
    if (_value.lastClosedRequest == null) {
      return null;
    }

    return $WantedRequestModelCopyWith<$Res>(_value.lastClosedRequest!, (
      value,
    ) {
      return _then(_value.copyWith(lastClosedRequest: value) as $Val);
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
    List<WantedRequestModel> activeRequests,
    List<WantedEntryWithUser> allEntries,
    List<WantedRequestModel> lastClosedRequests,
    WantedRequestModel? lastClosedRequest,
    List<WantedEntryWithUser> lastClosedEntries,
    bool isCreating,
    bool isLoading,
    String? error,
  });

  @override
  $WantedRequestModelCopyWith<$Res>? get activeRequest;
  @override
  $WantedRequestModelCopyWith<$Res>? get lastClosedRequest;
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
    Object? activeRequests = null,
    Object? allEntries = null,
    Object? lastClosedRequests = null,
    Object? lastClosedRequest = freezed,
    Object? lastClosedEntries = null,
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
        activeRequests: null == activeRequests
            ? _value._activeRequests
            : activeRequests // ignore: cast_nullable_to_non_nullable
                  as List<WantedRequestModel>,
        allEntries: null == allEntries
            ? _value._allEntries
            : allEntries // ignore: cast_nullable_to_non_nullable
                  as List<WantedEntryWithUser>,
        lastClosedRequests: null == lastClosedRequests
            ? _value._lastClosedRequests
            : lastClosedRequests // ignore: cast_nullable_to_non_nullable
                  as List<WantedRequestModel>,
        lastClosedRequest: freezed == lastClosedRequest
            ? _value.lastClosedRequest
            : lastClosedRequest // ignore: cast_nullable_to_non_nullable
                  as WantedRequestModel?,
        lastClosedEntries: null == lastClosedEntries
            ? _value._lastClosedEntries
            : lastClosedEntries // ignore: cast_nullable_to_non_nullable
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
    final List<WantedRequestModel> activeRequests = const [],
    final List<WantedEntryWithUser> allEntries = const [],
    final List<WantedRequestModel> lastClosedRequests = const [],
    this.lastClosedRequest,
    final List<WantedEntryWithUser> lastClosedEntries = const [],
    this.isCreating = false,
    this.isLoading = false,
    this.error,
  }) : _activeRequests = activeRequests,
       _allEntries = allEntries,
       _lastClosedRequests = lastClosedRequests,
       _lastClosedEntries = lastClosedEntries;

  @override
  final String teamId;
  @override
  final WantedRequestModel? activeRequest;
  final List<WantedRequestModel> _activeRequests;
  @override
  @JsonKey()
  List<WantedRequestModel> get activeRequests {
    if (_activeRequests is EqualUnmodifiableListView) return _activeRequests;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_activeRequests);
  }

  final List<WantedEntryWithUser> _allEntries;
  @override
  @JsonKey()
  List<WantedEntryWithUser> get allEntries {
    if (_allEntries is EqualUnmodifiableListView) return _allEntries;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_allEntries);
  }

  // 마감된 최근 수집 (활성 없을 때 표시)
  final List<WantedRequestModel> _lastClosedRequests;
  // 마감된 최근 수집 (활성 없을 때 표시)
  @override
  @JsonKey()
  List<WantedRequestModel> get lastClosedRequests {
    if (_lastClosedRequests is EqualUnmodifiableListView)
      return _lastClosedRequests;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_lastClosedRequests);
  }

  @override
  final WantedRequestModel? lastClosedRequest;
  final List<WantedEntryWithUser> _lastClosedEntries;
  @override
  @JsonKey()
  List<WantedEntryWithUser> get lastClosedEntries {
    if (_lastClosedEntries is EqualUnmodifiableListView)
      return _lastClosedEntries;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_lastClosedEntries);
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
    return 'WantedAdminState(teamId: $teamId, activeRequest: $activeRequest, activeRequests: $activeRequests, allEntries: $allEntries, lastClosedRequests: $lastClosedRequests, lastClosedRequest: $lastClosedRequest, lastClosedEntries: $lastClosedEntries, isCreating: $isCreating, isLoading: $isLoading, error: $error)';
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
              other._activeRequests,
              _activeRequests,
            ) &&
            const DeepCollectionEquality().equals(
              other._allEntries,
              _allEntries,
            ) &&
            const DeepCollectionEquality().equals(
              other._lastClosedRequests,
              _lastClosedRequests,
            ) &&
            (identical(other.lastClosedRequest, lastClosedRequest) ||
                other.lastClosedRequest == lastClosedRequest) &&
            const DeepCollectionEquality().equals(
              other._lastClosedEntries,
              _lastClosedEntries,
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
    const DeepCollectionEquality().hash(_activeRequests),
    const DeepCollectionEquality().hash(_allEntries),
    const DeepCollectionEquality().hash(_lastClosedRequests),
    lastClosedRequest,
    const DeepCollectionEquality().hash(_lastClosedEntries),
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
    final List<WantedRequestModel> activeRequests,
    final List<WantedEntryWithUser> allEntries,
    final List<WantedRequestModel> lastClosedRequests,
    final WantedRequestModel? lastClosedRequest,
    final List<WantedEntryWithUser> lastClosedEntries,
    final bool isCreating,
    final bool isLoading,
    final String? error,
  }) = _$WantedAdminStateImpl;

  @override
  String get teamId;
  @override
  WantedRequestModel? get activeRequest;
  @override
  List<WantedRequestModel> get activeRequests;
  @override
  List<WantedEntryWithUser> get allEntries; // 마감된 최근 수집 (활성 없을 때 표시)
  @override
  List<WantedRequestModel> get lastClosedRequests;
  @override
  WantedRequestModel? get lastClosedRequest;
  @override
  List<WantedEntryWithUser> get lastClosedEntries;
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
  List<WantedRequestModel> get activeRequests =>
      throw _privateConstructorUsedError;
  List<WantedEntryModel> get myEntries => throw _privateConstructorUsedError;
  TeamMemberModel? get myMember => throw _privateConstructorUsedError;
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
    List<WantedRequestModel> activeRequests,
    List<WantedEntryModel> myEntries,
    TeamMemberModel? myMember,
    bool isSubmitting,
    String? error,
  });

  $WantedRequestModelCopyWith<$Res>? get activeRequest;
  $TeamMemberModelCopyWith<$Res>? get myMember;
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
    Object? activeRequests = null,
    Object? myEntries = null,
    Object? myMember = freezed,
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
            activeRequests: null == activeRequests
                ? _value.activeRequests
                : activeRequests // ignore: cast_nullable_to_non_nullable
                      as List<WantedRequestModel>,
            myEntries: null == myEntries
                ? _value.myEntries
                : myEntries // ignore: cast_nullable_to_non_nullable
                      as List<WantedEntryModel>,
            myMember: freezed == myMember
                ? _value.myMember
                : myMember // ignore: cast_nullable_to_non_nullable
                      as TeamMemberModel?,
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

  /// Create a copy of WantedMemberState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $TeamMemberModelCopyWith<$Res>? get myMember {
    if (_value.myMember == null) {
      return null;
    }

    return $TeamMemberModelCopyWith<$Res>(_value.myMember!, (value) {
      return _then(_value.copyWith(myMember: value) as $Val);
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
    List<WantedRequestModel> activeRequests,
    List<WantedEntryModel> myEntries,
    TeamMemberModel? myMember,
    bool isSubmitting,
    String? error,
  });

  @override
  $WantedRequestModelCopyWith<$Res>? get activeRequest;
  @override
  $TeamMemberModelCopyWith<$Res>? get myMember;
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
    Object? activeRequests = null,
    Object? myEntries = null,
    Object? myMember = freezed,
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
        activeRequests: null == activeRequests
            ? _value._activeRequests
            : activeRequests // ignore: cast_nullable_to_non_nullable
                  as List<WantedRequestModel>,
        myEntries: null == myEntries
            ? _value._myEntries
            : myEntries // ignore: cast_nullable_to_non_nullable
                  as List<WantedEntryModel>,
        myMember: freezed == myMember
            ? _value.myMember
            : myMember // ignore: cast_nullable_to_non_nullable
                  as TeamMemberModel?,
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
    final List<WantedRequestModel> activeRequests = const [],
    final List<WantedEntryModel> myEntries = const [],
    this.myMember,
    this.isSubmitting = false,
    this.error,
  }) : _activeRequests = activeRequests,
       _myEntries = myEntries;

  @override
  final String teamId;
  @override
  final WantedRequestModel? activeRequest;
  final List<WantedRequestModel> _activeRequests;
  @override
  @JsonKey()
  List<WantedRequestModel> get activeRequests {
    if (_activeRequests is EqualUnmodifiableListView) return _activeRequests;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_activeRequests);
  }

  final List<WantedEntryModel> _myEntries;
  @override
  @JsonKey()
  List<WantedEntryModel> get myEntries {
    if (_myEntries is EqualUnmodifiableListView) return _myEntries;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_myEntries);
  }

  @override
  final TeamMemberModel? myMember;
  @override
  @JsonKey()
  final bool isSubmitting;
  @override
  final String? error;

  @override
  String toString() {
    return 'WantedMemberState(teamId: $teamId, activeRequest: $activeRequest, activeRequests: $activeRequests, myEntries: $myEntries, myMember: $myMember, isSubmitting: $isSubmitting, error: $error)';
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
              other._activeRequests,
              _activeRequests,
            ) &&
            const DeepCollectionEquality().equals(
              other._myEntries,
              _myEntries,
            ) &&
            (identical(other.myMember, myMember) ||
                other.myMember == myMember) &&
            (identical(other.isSubmitting, isSubmitting) ||
                other.isSubmitting == isSubmitting) &&
            (identical(other.error, error) || other.error == error));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    teamId,
    activeRequest,
    const DeepCollectionEquality().hash(_activeRequests),
    const DeepCollectionEquality().hash(_myEntries),
    myMember,
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
    final List<WantedRequestModel> activeRequests,
    final List<WantedEntryModel> myEntries,
    final TeamMemberModel? myMember,
    final bool isSubmitting,
    final String? error,
  }) = _$WantedMemberStateImpl;

  @override
  String get teamId;
  @override
  WantedRequestModel? get activeRequest;
  @override
  List<WantedRequestModel> get activeRequests;
  @override
  List<WantedEntryModel> get myEntries;
  @override
  TeamMemberModel? get myMember;
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
