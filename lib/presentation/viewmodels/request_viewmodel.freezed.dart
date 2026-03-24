// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'request_viewmodel.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$RequestListState {
  String get teamId => throw _privateConstructorUsedError;
  List<RequestModel> get requests => throw _privateConstructorUsedError;
  String get filter =>
      throw _privateConstructorUsedError; // all, pending, approved, rejected
  bool get isAdmin => throw _privateConstructorUsedError;

  /// Create a copy of RequestListState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RequestListStateCopyWith<RequestListState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RequestListStateCopyWith<$Res> {
  factory $RequestListStateCopyWith(
    RequestListState value,
    $Res Function(RequestListState) then,
  ) = _$RequestListStateCopyWithImpl<$Res, RequestListState>;
  @useResult
  $Res call({
    String teamId,
    List<RequestModel> requests,
    String filter,
    bool isAdmin,
  });
}

/// @nodoc
class _$RequestListStateCopyWithImpl<$Res, $Val extends RequestListState>
    implements $RequestListStateCopyWith<$Res> {
  _$RequestListStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RequestListState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? teamId = null,
    Object? requests = null,
    Object? filter = null,
    Object? isAdmin = null,
  }) {
    return _then(
      _value.copyWith(
            teamId: null == teamId
                ? _value.teamId
                : teamId // ignore: cast_nullable_to_non_nullable
                      as String,
            requests: null == requests
                ? _value.requests
                : requests // ignore: cast_nullable_to_non_nullable
                      as List<RequestModel>,
            filter: null == filter
                ? _value.filter
                : filter // ignore: cast_nullable_to_non_nullable
                      as String,
            isAdmin: null == isAdmin
                ? _value.isAdmin
                : isAdmin // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$RequestListStateImplCopyWith<$Res>
    implements $RequestListStateCopyWith<$Res> {
  factory _$$RequestListStateImplCopyWith(
    _$RequestListStateImpl value,
    $Res Function(_$RequestListStateImpl) then,
  ) = __$$RequestListStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String teamId,
    List<RequestModel> requests,
    String filter,
    bool isAdmin,
  });
}

/// @nodoc
class __$$RequestListStateImplCopyWithImpl<$Res>
    extends _$RequestListStateCopyWithImpl<$Res, _$RequestListStateImpl>
    implements _$$RequestListStateImplCopyWith<$Res> {
  __$$RequestListStateImplCopyWithImpl(
    _$RequestListStateImpl _value,
    $Res Function(_$RequestListStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of RequestListState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? teamId = null,
    Object? requests = null,
    Object? filter = null,
    Object? isAdmin = null,
  }) {
    return _then(
      _$RequestListStateImpl(
        teamId: null == teamId
            ? _value.teamId
            : teamId // ignore: cast_nullable_to_non_nullable
                  as String,
        requests: null == requests
            ? _value._requests
            : requests // ignore: cast_nullable_to_non_nullable
                  as List<RequestModel>,
        filter: null == filter
            ? _value.filter
            : filter // ignore: cast_nullable_to_non_nullable
                  as String,
        isAdmin: null == isAdmin
            ? _value.isAdmin
            : isAdmin // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc

class _$RequestListStateImpl implements _RequestListState {
  const _$RequestListStateImpl({
    required this.teamId,
    required final List<RequestModel> requests,
    this.filter = 'all',
    this.isAdmin = false,
  }) : _requests = requests;

  @override
  final String teamId;
  final List<RequestModel> _requests;
  @override
  List<RequestModel> get requests {
    if (_requests is EqualUnmodifiableListView) return _requests;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_requests);
  }

  @override
  @JsonKey()
  final String filter;
  // all, pending, approved, rejected
  @override
  @JsonKey()
  final bool isAdmin;

  @override
  String toString() {
    return 'RequestListState(teamId: $teamId, requests: $requests, filter: $filter, isAdmin: $isAdmin)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RequestListStateImpl &&
            (identical(other.teamId, teamId) || other.teamId == teamId) &&
            const DeepCollectionEquality().equals(other._requests, _requests) &&
            (identical(other.filter, filter) || other.filter == filter) &&
            (identical(other.isAdmin, isAdmin) || other.isAdmin == isAdmin));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    teamId,
    const DeepCollectionEquality().hash(_requests),
    filter,
    isAdmin,
  );

  /// Create a copy of RequestListState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RequestListStateImplCopyWith<_$RequestListStateImpl> get copyWith =>
      __$$RequestListStateImplCopyWithImpl<_$RequestListStateImpl>(
        this,
        _$identity,
      );
}

abstract class _RequestListState implements RequestListState {
  const factory _RequestListState({
    required final String teamId,
    required final List<RequestModel> requests,
    final String filter,
    final bool isAdmin,
  }) = _$RequestListStateImpl;

  @override
  String get teamId;
  @override
  List<RequestModel> get requests;
  @override
  String get filter; // all, pending, approved, rejected
  @override
  bool get isAdmin;

  /// Create a copy of RequestListState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RequestListStateImplCopyWith<_$RequestListStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
