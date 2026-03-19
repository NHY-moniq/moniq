import 'package:moniq/data/datasources/settings_local_data_source.dart';

class SettingsRepository {
  SettingsRepository({required SettingsLocalDataSource dataSource})
      : _dataSource = dataSource;

  final SettingsLocalDataSource _dataSource;

  String getThemeMode() => _dataSource.getThemeMode();
  Future<void> setThemeMode(String mode) => _dataSource.setThemeMode(mode);

  double getFontScale() => _dataSource.getFontScale();
  Future<void> setFontScale(double scale) => _dataSource.setFontScale(scale);

  String getCalendarStartDay() => _dataSource.getCalendarStartDay();
  Future<void> setCalendarStartDay(String day) =>
      _dataSource.setCalendarStartDay(day);

  bool getNotificationsEnabled() => _dataSource.getNotificationsEnabled();
  Future<void> setNotificationsEnabled(bool enabled) =>
      _dataSource.setNotificationsEnabled(enabled);
}
