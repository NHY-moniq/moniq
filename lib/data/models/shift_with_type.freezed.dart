// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'shift_with_type.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$ShiftWithType {
  ShiftModel get shift => throw _privateConstructorUsedError;
  ShiftTypeModel get shiftType => throw _privateConstructorUsedError;
  String? get teamName => throw _privateConstructorUsedError;

  /// Create a copy of ShiftWithType
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ShiftWithTypeCopyWith<ShiftWithType> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ShiftWithTypeCopyWith<$Res> {
  factory $ShiftWithTypeCopyWith(
    ShiftWithType value,
    $Res Function(ShiftWithType) then,
  ) = _$ShiftWithTypeCopyWithImpl<$Res, ShiftWithType>;
  @useResult
  $Res call({ShiftModel shift, ShiftTypeModel shiftType, String? teamName});

  $ShiftModelCopyWith<$Res> get shift;
  $ShiftTypeModelCopyWith<$Res> get shiftType;
}

/// @nodoc
class _$ShiftWithTypeCopyWithImpl<$Res, $Val extends ShiftWithType>
    implements $ShiftWithTypeCopyWith<$Res> {
  _$ShiftWithTypeCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ShiftWithType
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? shift = null,
    Object? shiftType = null,
    Object? teamName = freezed,
  }) {
    return _then(
      _value.copyWith(
            shift: null == shift
                ? _value.shift
                : shift // ignore: cast_nullable_to_non_nullable
                      as ShiftModel,
            shiftType: null == shiftType
                ? _value.shiftType
                : shiftType // ignore: cast_nullable_to_non_nullable
                      as ShiftTypeModel,
            teamName: freezed == teamName
                ? _value.teamName
                : teamName // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }

  /// Create a copy of ShiftWithType
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ShiftModelCopyWith<$Res> get shift {
    return $ShiftModelCopyWith<$Res>(_value.shift, (value) {
      return _then(_value.copyWith(shift: value) as $Val);
    });
  }

  /// Create a copy of ShiftWithType
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
abstract class _$$ShiftWithTypeImplCopyWith<$Res>
    implements $ShiftWithTypeCopyWith<$Res> {
  factory _$$ShiftWithTypeImplCopyWith(
    _$ShiftWithTypeImpl value,
    $Res Function(_$ShiftWithTypeImpl) then,
  ) = __$$ShiftWithTypeImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({ShiftModel shift, ShiftTypeModel shiftType, String? teamName});

  @override
  $ShiftModelCopyWith<$Res> get shift;
  @override
  $ShiftTypeModelCopyWith<$Res> get shiftType;
}

/// @nodoc
class __$$ShiftWithTypeImplCopyWithImpl<$Res>
    extends _$ShiftWithTypeCopyWithImpl<$Res, _$ShiftWithTypeImpl>
    implements _$$ShiftWithTypeImplCopyWith<$Res> {
  __$$ShiftWithTypeImplCopyWithImpl(
    _$ShiftWithTypeImpl _value,
    $Res Function(_$ShiftWithTypeImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ShiftWithType
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? shift = null,
    Object? shiftType = null,
    Object? teamName = freezed,
  }) {
    return _then(
      _$ShiftWithTypeImpl(
        shift: null == shift
            ? _value.shift
            : shift // ignore: cast_nullable_to_non_nullable
                  as ShiftModel,
        shiftType: null == shiftType
            ? _value.shiftType
            : shiftType // ignore: cast_nullable_to_non_nullable
                  as ShiftTypeModel,
        teamName: freezed == teamName
            ? _value.teamName
            : teamName // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc

class _$ShiftWithTypeImpl implements _ShiftWithType {
  const _$ShiftWithTypeImpl({
    required this.shift,
    required this.shiftType,
    this.teamName,
  });

  @override
  final ShiftModel shift;
  @override
  final ShiftTypeModel shiftType;
  @override
  final String? teamName;

  @override
  String toString() {
    return 'ShiftWithType(shift: $shift, shiftType: $shiftType, teamName: $teamName)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ShiftWithTypeImpl &&
            (identical(other.shift, shift) || other.shift == shift) &&
            (identical(other.shiftType, shiftType) ||
                other.shiftType == shiftType) &&
            (identical(other.teamName, teamName) ||
                other.teamName == teamName));
  }

  @override
  int get hashCode => Object.hash(runtimeType, shift, shiftType, teamName);

  /// Create a copy of ShiftWithType
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ShiftWithTypeImplCopyWith<_$ShiftWithTypeImpl> get copyWith =>
      __$$ShiftWithTypeImplCopyWithImpl<_$ShiftWithTypeImpl>(this, _$identity);
}

abstract class _ShiftWithType implements ShiftWithType {
  const factory _ShiftWithType({
    required final ShiftModel shift,
    required final ShiftTypeModel shiftType,
    final String? teamName,
  }) = _$ShiftWithTypeImpl;

  @override
  ShiftModel get shift;
  @override
  ShiftTypeModel get shiftType;
  @override
  String? get teamName;

  /// Create a copy of ShiftWithType
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ShiftWithTypeImplCopyWith<_$ShiftWithTypeImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
