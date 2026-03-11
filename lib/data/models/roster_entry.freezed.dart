// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'roster_entry.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$RosterEntry {
  ShiftTypeModel get shiftType => throw _privateConstructorUsedError;
  List<RosterWorker> get workers => throw _privateConstructorUsedError;

  /// Create a copy of RosterEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RosterEntryCopyWith<RosterEntry> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RosterEntryCopyWith<$Res> {
  factory $RosterEntryCopyWith(
    RosterEntry value,
    $Res Function(RosterEntry) then,
  ) = _$RosterEntryCopyWithImpl<$Res, RosterEntry>;
  @useResult
  $Res call({ShiftTypeModel shiftType, List<RosterWorker> workers});

  $ShiftTypeModelCopyWith<$Res> get shiftType;
}

/// @nodoc
class _$RosterEntryCopyWithImpl<$Res, $Val extends RosterEntry>
    implements $RosterEntryCopyWith<$Res> {
  _$RosterEntryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RosterEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? shiftType = null, Object? workers = null}) {
    return _then(
      _value.copyWith(
            shiftType: null == shiftType
                ? _value.shiftType
                : shiftType // ignore: cast_nullable_to_non_nullable
                      as ShiftTypeModel,
            workers: null == workers
                ? _value.workers
                : workers // ignore: cast_nullable_to_non_nullable
                      as List<RosterWorker>,
          )
          as $Val,
    );
  }

  /// Create a copy of RosterEntry
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ShiftTypeModelCopyWith<$Res> get shiftType {
    return $ShiftTypeModelCopyWith<$Res>(_value.shiftType, (value) {
      return _then(_value.copyWith(shiftType: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$RosterEntryImplCopyWith<$Res>
    implements $RosterEntryCopyWith<$Res> {
  factory _$$RosterEntryImplCopyWith(
    _$RosterEntryImpl value,
    $Res Function(_$RosterEntryImpl) then,
  ) = __$$RosterEntryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({ShiftTypeModel shiftType, List<RosterWorker> workers});

  @override
  $ShiftTypeModelCopyWith<$Res> get shiftType;
}

/// @nodoc
class __$$RosterEntryImplCopyWithImpl<$Res>
    extends _$RosterEntryCopyWithImpl<$Res, _$RosterEntryImpl>
    implements _$$RosterEntryImplCopyWith<$Res> {
  __$$RosterEntryImplCopyWithImpl(
    _$RosterEntryImpl _value,
    $Res Function(_$RosterEntryImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of RosterEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? shiftType = null, Object? workers = null}) {
    return _then(
      _$RosterEntryImpl(
        shiftType: null == shiftType
            ? _value.shiftType
            : shiftType // ignore: cast_nullable_to_non_nullable
                  as ShiftTypeModel,
        workers: null == workers
            ? _value._workers
            : workers // ignore: cast_nullable_to_non_nullable
                  as List<RosterWorker>,
      ),
    );
  }
}

/// @nodoc

class _$RosterEntryImpl implements _RosterEntry {
  const _$RosterEntryImpl({
    required this.shiftType,
    required final List<RosterWorker> workers,
  }) : _workers = workers;

  @override
  final ShiftTypeModel shiftType;
  final List<RosterWorker> _workers;
  @override
  List<RosterWorker> get workers {
    if (_workers is EqualUnmodifiableListView) return _workers;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_workers);
  }

  @override
  String toString() {
    return 'RosterEntry(shiftType: $shiftType, workers: $workers)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RosterEntryImpl &&
            (identical(other.shiftType, shiftType) ||
                other.shiftType == shiftType) &&
            const DeepCollectionEquality().equals(other._workers, _workers));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    shiftType,
    const DeepCollectionEquality().hash(_workers),
  );

  /// Create a copy of RosterEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RosterEntryImplCopyWith<_$RosterEntryImpl> get copyWith =>
      __$$RosterEntryImplCopyWithImpl<_$RosterEntryImpl>(this, _$identity);
}

abstract class _RosterEntry implements RosterEntry {
  const factory _RosterEntry({
    required final ShiftTypeModel shiftType,
    required final List<RosterWorker> workers,
  }) = _$RosterEntryImpl;

  @override
  ShiftTypeModel get shiftType;
  @override
  List<RosterWorker> get workers;

  /// Create a copy of RosterEntry
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RosterEntryImplCopyWith<_$RosterEntryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$RosterWorker {
  UserModel get user => throw _privateConstructorUsedError;
  String? get note => throw _privateConstructorUsedError;

  /// Create a copy of RosterWorker
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RosterWorkerCopyWith<RosterWorker> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RosterWorkerCopyWith<$Res> {
  factory $RosterWorkerCopyWith(
    RosterWorker value,
    $Res Function(RosterWorker) then,
  ) = _$RosterWorkerCopyWithImpl<$Res, RosterWorker>;
  @useResult
  $Res call({UserModel user, String? note});

  $UserModelCopyWith<$Res> get user;
}

/// @nodoc
class _$RosterWorkerCopyWithImpl<$Res, $Val extends RosterWorker>
    implements $RosterWorkerCopyWith<$Res> {
  _$RosterWorkerCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RosterWorker
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? user = null, Object? note = freezed}) {
    return _then(
      _value.copyWith(
            user: null == user
                ? _value.user
                : user // ignore: cast_nullable_to_non_nullable
                      as UserModel,
            note: freezed == note
                ? _value.note
                : note // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }

  /// Create a copy of RosterWorker
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $UserModelCopyWith<$Res> get user {
    return $UserModelCopyWith<$Res>(_value.user, (value) {
      return _then(_value.copyWith(user: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$RosterWorkerImplCopyWith<$Res>
    implements $RosterWorkerCopyWith<$Res> {
  factory _$$RosterWorkerImplCopyWith(
    _$RosterWorkerImpl value,
    $Res Function(_$RosterWorkerImpl) then,
  ) = __$$RosterWorkerImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({UserModel user, String? note});

  @override
  $UserModelCopyWith<$Res> get user;
}

/// @nodoc
class __$$RosterWorkerImplCopyWithImpl<$Res>
    extends _$RosterWorkerCopyWithImpl<$Res, _$RosterWorkerImpl>
    implements _$$RosterWorkerImplCopyWith<$Res> {
  __$$RosterWorkerImplCopyWithImpl(
    _$RosterWorkerImpl _value,
    $Res Function(_$RosterWorkerImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of RosterWorker
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? user = null, Object? note = freezed}) {
    return _then(
      _$RosterWorkerImpl(
        user: null == user
            ? _value.user
            : user // ignore: cast_nullable_to_non_nullable
                  as UserModel,
        note: freezed == note
            ? _value.note
            : note // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc

class _$RosterWorkerImpl implements _RosterWorker {
  const _$RosterWorkerImpl({required this.user, this.note});

  @override
  final UserModel user;
  @override
  final String? note;

  @override
  String toString() {
    return 'RosterWorker(user: $user, note: $note)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RosterWorkerImpl &&
            (identical(other.user, user) || other.user == user) &&
            (identical(other.note, note) || other.note == note));
  }

  @override
  int get hashCode => Object.hash(runtimeType, user, note);

  /// Create a copy of RosterWorker
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RosterWorkerImplCopyWith<_$RosterWorkerImpl> get copyWith =>
      __$$RosterWorkerImplCopyWithImpl<_$RosterWorkerImpl>(this, _$identity);
}

abstract class _RosterWorker implements RosterWorker {
  const factory _RosterWorker({
    required final UserModel user,
    final String? note,
  }) = _$RosterWorkerImpl;

  @override
  UserModel get user;
  @override
  String? get note;

  /// Create a copy of RosterWorker
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RosterWorkerImplCopyWith<_$RosterWorkerImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
