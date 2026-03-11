// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'shift_rule_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

ShiftRuleModel _$ShiftRuleModelFromJson(Map<String, dynamic> json) {
  return _ShiftRuleModel.fromJson(json);
}

/// @nodoc
mixin _$ShiftRuleModel {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'team_id')
  String get teamId => throw _privateConstructorUsedError;
  @JsonKey(name: 'rule_type')
  String get ruleType => throw _privateConstructorUsedError;
  @JsonKey(name: 'rule_value')
  Map<String, dynamic> get ruleValue => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_active')
  bool get isActive => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime? get createdAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'updated_at')
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this ShiftRuleModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ShiftRuleModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ShiftRuleModelCopyWith<ShiftRuleModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ShiftRuleModelCopyWith<$Res> {
  factory $ShiftRuleModelCopyWith(
    ShiftRuleModel value,
    $Res Function(ShiftRuleModel) then,
  ) = _$ShiftRuleModelCopyWithImpl<$Res, ShiftRuleModel>;
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'team_id') String teamId,
    @JsonKey(name: 'rule_type') String ruleType,
    @JsonKey(name: 'rule_value') Map<String, dynamic> ruleValue,
    @JsonKey(name: 'is_active') bool isActive,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  });
}

/// @nodoc
class _$ShiftRuleModelCopyWithImpl<$Res, $Val extends ShiftRuleModel>
    implements $ShiftRuleModelCopyWith<$Res> {
  _$ShiftRuleModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ShiftRuleModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? teamId = null,
    Object? ruleType = null,
    Object? ruleValue = null,
    Object? isActive = null,
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
            ruleType: null == ruleType
                ? _value.ruleType
                : ruleType // ignore: cast_nullable_to_non_nullable
                      as String,
            ruleValue: null == ruleValue
                ? _value.ruleValue
                : ruleValue // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>,
            isActive: null == isActive
                ? _value.isActive
                : isActive // ignore: cast_nullable_to_non_nullable
                      as bool,
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
abstract class _$$ShiftRuleModelImplCopyWith<$Res>
    implements $ShiftRuleModelCopyWith<$Res> {
  factory _$$ShiftRuleModelImplCopyWith(
    _$ShiftRuleModelImpl value,
    $Res Function(_$ShiftRuleModelImpl) then,
  ) = __$$ShiftRuleModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'team_id') String teamId,
    @JsonKey(name: 'rule_type') String ruleType,
    @JsonKey(name: 'rule_value') Map<String, dynamic> ruleValue,
    @JsonKey(name: 'is_active') bool isActive,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  });
}

/// @nodoc
class __$$ShiftRuleModelImplCopyWithImpl<$Res>
    extends _$ShiftRuleModelCopyWithImpl<$Res, _$ShiftRuleModelImpl>
    implements _$$ShiftRuleModelImplCopyWith<$Res> {
  __$$ShiftRuleModelImplCopyWithImpl(
    _$ShiftRuleModelImpl _value,
    $Res Function(_$ShiftRuleModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ShiftRuleModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? teamId = null,
    Object? ruleType = null,
    Object? ruleValue = null,
    Object? isActive = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(
      _$ShiftRuleModelImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        teamId: null == teamId
            ? _value.teamId
            : teamId // ignore: cast_nullable_to_non_nullable
                  as String,
        ruleType: null == ruleType
            ? _value.ruleType
            : ruleType // ignore: cast_nullable_to_non_nullable
                  as String,
        ruleValue: null == ruleValue
            ? _value._ruleValue
            : ruleValue // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>,
        isActive: null == isActive
            ? _value.isActive
            : isActive // ignore: cast_nullable_to_non_nullable
                  as bool,
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
class _$ShiftRuleModelImpl implements _ShiftRuleModel {
  const _$ShiftRuleModelImpl({
    required this.id,
    @JsonKey(name: 'team_id') required this.teamId,
    @JsonKey(name: 'rule_type') required this.ruleType,
    @JsonKey(name: 'rule_value') required final Map<String, dynamic> ruleValue,
    @JsonKey(name: 'is_active') this.isActive = true,
    @JsonKey(name: 'created_at') this.createdAt,
    @JsonKey(name: 'updated_at') this.updatedAt,
  }) : _ruleValue = ruleValue;

  factory _$ShiftRuleModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$ShiftRuleModelImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'team_id')
  final String teamId;
  @override
  @JsonKey(name: 'rule_type')
  final String ruleType;
  final Map<String, dynamic> _ruleValue;
  @override
  @JsonKey(name: 'rule_value')
  Map<String, dynamic> get ruleValue {
    if (_ruleValue is EqualUnmodifiableMapView) return _ruleValue;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_ruleValue);
  }

  @override
  @JsonKey(name: 'is_active')
  final bool isActive;
  @override
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  @override
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  @override
  String toString() {
    return 'ShiftRuleModel(id: $id, teamId: $teamId, ruleType: $ruleType, ruleValue: $ruleValue, isActive: $isActive, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ShiftRuleModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.teamId, teamId) || other.teamId == teamId) &&
            (identical(other.ruleType, ruleType) ||
                other.ruleType == ruleType) &&
            const DeepCollectionEquality().equals(
              other._ruleValue,
              _ruleValue,
            ) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive) &&
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
    ruleType,
    const DeepCollectionEquality().hash(_ruleValue),
    isActive,
    createdAt,
    updatedAt,
  );

  /// Create a copy of ShiftRuleModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ShiftRuleModelImplCopyWith<_$ShiftRuleModelImpl> get copyWith =>
      __$$ShiftRuleModelImplCopyWithImpl<_$ShiftRuleModelImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$ShiftRuleModelImplToJson(this);
  }
}

abstract class _ShiftRuleModel implements ShiftRuleModel {
  const factory _ShiftRuleModel({
    required final String id,
    @JsonKey(name: 'team_id') required final String teamId,
    @JsonKey(name: 'rule_type') required final String ruleType,
    @JsonKey(name: 'rule_value') required final Map<String, dynamic> ruleValue,
    @JsonKey(name: 'is_active') final bool isActive,
    @JsonKey(name: 'created_at') final DateTime? createdAt,
    @JsonKey(name: 'updated_at') final DateTime? updatedAt,
  }) = _$ShiftRuleModelImpl;

  factory _ShiftRuleModel.fromJson(Map<String, dynamic> json) =
      _$ShiftRuleModelImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'team_id')
  String get teamId;
  @override
  @JsonKey(name: 'rule_type')
  String get ruleType;
  @override
  @JsonKey(name: 'rule_value')
  Map<String, dynamic> get ruleValue;
  @override
  @JsonKey(name: 'is_active')
  bool get isActive;
  @override
  @JsonKey(name: 'created_at')
  DateTime? get createdAt;
  @override
  @JsonKey(name: 'updated_at')
  DateTime? get updatedAt;

  /// Create a copy of ShiftRuleModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ShiftRuleModelImplCopyWith<_$ShiftRuleModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
