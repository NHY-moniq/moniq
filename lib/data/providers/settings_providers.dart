import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/datasources/device_calendar_data_source.dart';
import 'package:moniq/data/datasources/settings_local_data_source.dart';
import 'package:moniq/data/repositories/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Must be overridden in ProviderScope');
});

final settingsLocalDataSourceProvider = Provider<SettingsLocalDataSource>(
  (ref) => SettingsLocalDataSource(
    prefs: ref.watch(sharedPreferencesProvider),
  ),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(
    dataSource: ref.watch(settingsLocalDataSourceProvider),
  ),
);

/// 테마 모드 상태 관리
final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final repo = ref.watch(settingsRepositoryProvider);
    return _parseThemeMode(repo.getThemeMode());
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final repo = ref.read(settingsRepositoryProvider);
    final modeStr = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await repo.setThemeMode(modeStr);
    state = mode;
  }

  ThemeMode _parseThemeMode(String mode) {
    return switch (mode) {
      'dark' => ThemeMode.dark,
      _ => ThemeMode.light,
    };
  }
}

/// 폰트 스케일 상태 관리
final fontScaleProvider =
    NotifierProvider<FontScaleNotifier, double>(FontScaleNotifier.new);

class FontScaleNotifier extends Notifier<double> {
  @override
  double build() {
    final repo = ref.watch(settingsRepositoryProvider);
    return repo.getFontScale();
  }

  Future<void> setFontScale(double scale) async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.setFontScale(scale);
    state = scale;
  }
}

/// 기기 캘린더 데이터소스
final deviceCalendarDataSourceProvider = Provider<DeviceCalendarDataSource>(
  (ref) => DeviceCalendarDataSource(),
);

/// 캘린더 시작 요일 상태 관리
final calendarStartDayProvider =
    NotifierProvider<CalendarStartDayNotifier, String>(
        CalendarStartDayNotifier.new);

class CalendarStartDayNotifier extends Notifier<String> {
  @override
  String build() {
    final repo = ref.watch(settingsRepositoryProvider);
    return repo.getCalendarStartDay();
  }

  Future<void> setStartDay(String day) async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.setCalendarStartDay(day);
    state = day;
  }
}
