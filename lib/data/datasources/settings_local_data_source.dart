import 'package:shared_preferences/shared_preferences.dart';

class SettingsLocalDataSource {
  SettingsLocalDataSource({required SharedPreferences prefs}) : _prefs = prefs;

  final SharedPreferences _prefs;

  static const _keyThemeMode = 'settings_theme_mode';
  static const _keyFontScale = 'settings_font_scale';
  static const _keyCalendarStartDay = 'settings_calendar_start_day';
  static const _keyNotificationsEnabled = 'settings_notifications_enabled';
  static const _keyCalendarSyncEnabled = 'settings_calendar_sync_enabled';

  String getThemeMode() => _prefs.getString(_keyThemeMode) ?? 'light';
  Future<void> setThemeMode(String mode) => _prefs.setString(_keyThemeMode, mode);

  double getFontScale() => _prefs.getDouble(_keyFontScale) ?? 1.0;
  Future<void> setFontScale(double scale) => _prefs.setDouble(_keyFontScale, scale);

  String getCalendarStartDay() =>
      _prefs.getString(_keyCalendarStartDay) ?? 'monday';
  Future<void> setCalendarStartDay(String day) =>
      _prefs.setString(_keyCalendarStartDay, day);

  bool getNotificationsEnabled() =>
      _prefs.getBool(_keyNotificationsEnabled) ?? true;
  Future<void> setNotificationsEnabled(bool enabled) =>
      _prefs.setBool(_keyNotificationsEnabled, enabled);

  bool getCalendarSyncEnabled() =>
      _prefs.getBool(_keyCalendarSyncEnabled) ?? false;
  Future<void> setCalendarSyncEnabled(bool enabled) =>
      _prefs.setBool(_keyCalendarSyncEnabled, enabled);
}
