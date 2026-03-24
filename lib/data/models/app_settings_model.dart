import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_settings_model.freezed.dart';
part 'app_settings_model.g.dart';

@freezed
class AppSettingsModel with _$AppSettingsModel {
  const factory AppSettingsModel({
    @JsonKey(name: 'user_id') required String userId,
    @JsonKey(name: 'theme_mode') @Default('system') String themeMode,
    @JsonKey(name: 'font_scale') @Default(1.0) double fontScale,
    @JsonKey(name: 'calendar_start_day') @Default('monday') String calendarStartDay,
    @JsonKey(name: 'notifications_enabled') @Default(true) bool notificationsEnabled,
  }) = _AppSettingsModel;

  factory AppSettingsModel.fromJson(Map<String, dynamic> json) =>
      _$AppSettingsModelFromJson(json);
}
