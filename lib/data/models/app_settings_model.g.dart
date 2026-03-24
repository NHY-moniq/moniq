// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_settings_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AppSettingsModelImpl _$$AppSettingsModelImplFromJson(
  Map<String, dynamic> json,
) => _$AppSettingsModelImpl(
  userId: json['user_id'] as String,
  themeMode: json['theme_mode'] as String? ?? 'system',
  fontScale: (json['font_scale'] as num?)?.toDouble() ?? 1.0,
  calendarStartDay: json['calendar_start_day'] as String? ?? 'monday',
  notificationsEnabled: json['notifications_enabled'] as bool? ?? true,
);

Map<String, dynamic> _$$AppSettingsModelImplToJson(
  _$AppSettingsModelImpl instance,
) => <String, dynamic>{
  'user_id': instance.userId,
  'theme_mode': instance.themeMode,
  'font_scale': instance.fontScale,
  'calendar_start_day': instance.calendarStartDay,
  'notifications_enabled': instance.notificationsEnabled,
};
