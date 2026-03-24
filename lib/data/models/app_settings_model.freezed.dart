// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'app_settings_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

AppSettingsModel _$AppSettingsModelFromJson(Map<String, dynamic> json) {
  return _AppSettingsModel.fromJson(json);
}

/// @nodoc
mixin _$AppSettingsModel {
  @JsonKey(name: 'user_id')
  String get userId => throw _privateConstructorUsedError;
  @JsonKey(name: 'theme_mode')
  String get themeMode => throw _privateConstructorUsedError;
  @JsonKey(name: 'font_scale')
  double get fontScale => throw _privateConstructorUsedError;
  @JsonKey(name: 'calendar_start_day')
  String get calendarStartDay => throw _privateConstructorUsedError;
  @JsonKey(name: 'notifications_enabled')
  bool get notificationsEnabled => throw _privateConstructorUsedError;

  /// Serializes this AppSettingsModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AppSettingsModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AppSettingsModelCopyWith<AppSettingsModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AppSettingsModelCopyWith<$Res> {
  factory $AppSettingsModelCopyWith(
    AppSettingsModel value,
    $Res Function(AppSettingsModel) then,
  ) = _$AppSettingsModelCopyWithImpl<$Res, AppSettingsModel>;
  @useResult
  $Res call({
    @JsonKey(name: 'user_id') String userId,
    @JsonKey(name: 'theme_mode') String themeMode,
    @JsonKey(name: 'font_scale') double fontScale,
    @JsonKey(name: 'calendar_start_day') String calendarStartDay,
    @JsonKey(name: 'notifications_enabled') bool notificationsEnabled,
  });
}

/// @nodoc
class _$AppSettingsModelCopyWithImpl<$Res, $Val extends AppSettingsModel>
    implements $AppSettingsModelCopyWith<$Res> {
  _$AppSettingsModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AppSettingsModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? userId = null,
    Object? themeMode = null,
    Object? fontScale = null,
    Object? calendarStartDay = null,
    Object? notificationsEnabled = null,
  }) {
    return _then(
      _value.copyWith(
            userId: null == userId
                ? _value.userId
                : userId // ignore: cast_nullable_to_non_nullable
                      as String,
            themeMode: null == themeMode
                ? _value.themeMode
                : themeMode // ignore: cast_nullable_to_non_nullable
                      as String,
            fontScale: null == fontScale
                ? _value.fontScale
                : fontScale // ignore: cast_nullable_to_non_nullable
                      as double,
            calendarStartDay: null == calendarStartDay
                ? _value.calendarStartDay
                : calendarStartDay // ignore: cast_nullable_to_non_nullable
                      as String,
            notificationsEnabled: null == notificationsEnabled
                ? _value.notificationsEnabled
                : notificationsEnabled // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AppSettingsModelImplCopyWith<$Res>
    implements $AppSettingsModelCopyWith<$Res> {
  factory _$$AppSettingsModelImplCopyWith(
    _$AppSettingsModelImpl value,
    $Res Function(_$AppSettingsModelImpl) then,
  ) = __$$AppSettingsModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(name: 'user_id') String userId,
    @JsonKey(name: 'theme_mode') String themeMode,
    @JsonKey(name: 'font_scale') double fontScale,
    @JsonKey(name: 'calendar_start_day') String calendarStartDay,
    @JsonKey(name: 'notifications_enabled') bool notificationsEnabled,
  });
}

/// @nodoc
class __$$AppSettingsModelImplCopyWithImpl<$Res>
    extends _$AppSettingsModelCopyWithImpl<$Res, _$AppSettingsModelImpl>
    implements _$$AppSettingsModelImplCopyWith<$Res> {
  __$$AppSettingsModelImplCopyWithImpl(
    _$AppSettingsModelImpl _value,
    $Res Function(_$AppSettingsModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AppSettingsModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? userId = null,
    Object? themeMode = null,
    Object? fontScale = null,
    Object? calendarStartDay = null,
    Object? notificationsEnabled = null,
  }) {
    return _then(
      _$AppSettingsModelImpl(
        userId: null == userId
            ? _value.userId
            : userId // ignore: cast_nullable_to_non_nullable
                  as String,
        themeMode: null == themeMode
            ? _value.themeMode
            : themeMode // ignore: cast_nullable_to_non_nullable
                  as String,
        fontScale: null == fontScale
            ? _value.fontScale
            : fontScale // ignore: cast_nullable_to_non_nullable
                  as double,
        calendarStartDay: null == calendarStartDay
            ? _value.calendarStartDay
            : calendarStartDay // ignore: cast_nullable_to_non_nullable
                  as String,
        notificationsEnabled: null == notificationsEnabled
            ? _value.notificationsEnabled
            : notificationsEnabled // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AppSettingsModelImpl implements _AppSettingsModel {
  const _$AppSettingsModelImpl({
    @JsonKey(name: 'user_id') required this.userId,
    @JsonKey(name: 'theme_mode') this.themeMode = 'system',
    @JsonKey(name: 'font_scale') this.fontScale = 1.0,
    @JsonKey(name: 'calendar_start_day') this.calendarStartDay = 'monday',
    @JsonKey(name: 'notifications_enabled') this.notificationsEnabled = true,
  });

  factory _$AppSettingsModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$AppSettingsModelImplFromJson(json);

  @override
  @JsonKey(name: 'user_id')
  final String userId;
  @override
  @JsonKey(name: 'theme_mode')
  final String themeMode;
  @override
  @JsonKey(name: 'font_scale')
  final double fontScale;
  @override
  @JsonKey(name: 'calendar_start_day')
  final String calendarStartDay;
  @override
  @JsonKey(name: 'notifications_enabled')
  final bool notificationsEnabled;

  @override
  String toString() {
    return 'AppSettingsModel(userId: $userId, themeMode: $themeMode, fontScale: $fontScale, calendarStartDay: $calendarStartDay, notificationsEnabled: $notificationsEnabled)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AppSettingsModelImpl &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.themeMode, themeMode) ||
                other.themeMode == themeMode) &&
            (identical(other.fontScale, fontScale) ||
                other.fontScale == fontScale) &&
            (identical(other.calendarStartDay, calendarStartDay) ||
                other.calendarStartDay == calendarStartDay) &&
            (identical(other.notificationsEnabled, notificationsEnabled) ||
                other.notificationsEnabled == notificationsEnabled));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    userId,
    themeMode,
    fontScale,
    calendarStartDay,
    notificationsEnabled,
  );

  /// Create a copy of AppSettingsModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AppSettingsModelImplCopyWith<_$AppSettingsModelImpl> get copyWith =>
      __$$AppSettingsModelImplCopyWithImpl<_$AppSettingsModelImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$AppSettingsModelImplToJson(this);
  }
}

abstract class _AppSettingsModel implements AppSettingsModel {
  const factory _AppSettingsModel({
    @JsonKey(name: 'user_id') required final String userId,
    @JsonKey(name: 'theme_mode') final String themeMode,
    @JsonKey(name: 'font_scale') final double fontScale,
    @JsonKey(name: 'calendar_start_day') final String calendarStartDay,
    @JsonKey(name: 'notifications_enabled') final bool notificationsEnabled,
  }) = _$AppSettingsModelImpl;

  factory _AppSettingsModel.fromJson(Map<String, dynamic> json) =
      _$AppSettingsModelImpl.fromJson;

  @override
  @JsonKey(name: 'user_id')
  String get userId;
  @override
  @JsonKey(name: 'theme_mode')
  String get themeMode;
  @override
  @JsonKey(name: 'font_scale')
  double get fontScale;
  @override
  @JsonKey(name: 'calendar_start_day')
  String get calendarStartDay;
  @override
  @JsonKey(name: 'notifications_enabled')
  bool get notificationsEnabled;

  /// Create a copy of AppSettingsModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AppSettingsModelImplCopyWith<_$AppSettingsModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
