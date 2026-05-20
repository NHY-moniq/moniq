import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/datasources/device_calendar_data_source.dart';
import 'package:moniq/data/datasources/notification_service.dart';
import 'package:moniq/data/datasources/personal_event_local_data_source.dart';
import 'package:moniq/data/datasources/settings_local_data_source.dart';
import 'package:moniq/data/providers/auth_providers.dart';
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
      'system' => ThemeMode.system,
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

/// 푸시 알림 on/off 상태 관리
final notificationEnabledProvider =
    NotifierProvider<NotificationEnabledNotifier, bool>(
        NotificationEnabledNotifier.new);

class NotificationEnabledNotifier extends Notifier<bool> {
  @override
  bool build() {
    final repo = ref.watch(settingsRepositoryProvider);
    return repo.getNotificationsEnabled();
  }

  Future<bool> enable() async {
    try {
      final granted = await NotificationService.instance.requestPermission();
      if (!granted) return false;
    } catch (_) {
      // 시뮬레이터 등 권한 요청 실패 시에도 설정은 저장
    }

    final repo = ref.read(settingsRepositoryProvider);
    await repo.setNotificationsEnabled(true);

    try {
      await _scheduleEventNotifications();
    } catch (_) {
      // 알림 예약 실패해도 설정은 유지
    }

    state = true;
    return true;
  }

  Future<void> disable() async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.setNotificationsEnabled(false);
    await NotificationService.instance.cancelAll();
    state = false;
  }

  /// 개인 일정에 대해 알림 예약
  Future<void> _scheduleEventNotifications() async {
    final ns = NotificationService.instance;
    await ns.cancelAll();

    final prefs = ref.read(sharedPreferencesProvider);
    final userId = ref.read(currentUserProvider)?.id ?? 'anonymous';
    final eventDs = PersonalEventLocalDataSource(prefs: prefs, userId: userId);

    final now = DateTime.now();
    int notifId = 100;

    for (int m = 0; m < 2; m++) {
      final month = DateTime(now.year, now.month + m, 1);
      final events = eventDs.getMonthlyEvents(month);

      for (final entry in events.entries) {
        for (final event in entry.value) {
          if (event.startTime != null && event.startTime!.isNotEmpty) {
            // 시간 있는 일정 → 10분 전 알림
            await ns.scheduleEventReminder(
              id: notifId++,
              title: event.title,
              eventDate: event.date,
              startTime: event.startTime!,
            );
          } else {
            // 종일 일정 → 해당 일 오전 10시 알림
            await ns.scheduleAllDayReminder(
              id: notifId++,
              title: event.title,
              eventDate: event.date,
            );
          }
        }
      }
    }
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

/// 개인 캘린더에서 팀 로스터의 근무(dot/preview)를 숨길지 여부
final hideTeamShiftsInPersonalProvider =
    NotifierProvider<HideTeamShiftsNotifier, bool>(
        HideTeamShiftsNotifier.new);

class HideTeamShiftsNotifier extends Notifier<bool> {
  @override
  bool build() {
    final repo = ref.watch(settingsRepositoryProvider);
    return repo.getHideTeamShiftsInPersonal();
  }

  Future<void> setHide(bool hide) async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.setHideTeamShiftsInPersonal(hide);
    state = hide;
  }
}
