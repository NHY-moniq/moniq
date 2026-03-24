import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );
    _initialized = true;
  }

  Future<bool> requestPermission() async {
    if (Platform.isIOS) {
      final result = await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return result ?? false;
    }
    return true;
  }

  /// 특정 시각에 알림 예약
  Future<void> scheduleAt({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    final tzDate = tz.TZDateTime.from(scheduledDate, tz.local);

    // 과거 시간이면 스킵
    if (tzDate.isBefore(tz.TZDateTime.now(tz.local))) return;

    const androidDetails = AndroidNotificationDetails(
      'moniq_schedule',
      'Moniq 일정 알림',
      channelDescription: '일정 시작 전 알림',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzDate,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// 일정 시작 10분 전 알림 예약
  Future<void> scheduleEventReminder({
    required int id,
    required String title,
    required DateTime eventDate,
    required String startTime, // "HH:mm"
  }) async {
    final parts = startTime.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

    final eventDateTime = DateTime(
      eventDate.year, eventDate.month, eventDate.day, hour, minute,
    );
    // 10분 전
    final reminderTime = eventDateTime.subtract(const Duration(minutes: 10));

    await scheduleAt(
      id: id,
      title: 'Moniq 일정 알림',
      body: '10분 후 "$title" 일정이 시작됩니다',
      scheduledDate: reminderTime,
    );
  }

  /// 종일 일정 → 해당 일 오전 10시 알림
  Future<void> scheduleAllDayReminder({
    required int id,
    required String title,
    required DateTime eventDate,
  }) async {
    final reminderTime = DateTime(
      eventDate.year, eventDate.month, eventDate.day, 10, 0,
    );

    await scheduleAt(
      id: id,
      title: 'Moniq 오늘의 일정',
      body: '오늘 "$title" 일정이 있습니다',
      scheduledDate: reminderTime,
    );
  }

  /// 스케줄 변경 요청 즉시 알림
  Future<void> showScheduleChangeNotification({
    required String teamName,
    required String message,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'moniq_request',
      'Moniq 요청 알림',
      channelDescription: '스케줄 변경 요청 알림',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      '[$teamName] 스케줄 변경 요청',
      message,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  Future<void> cancel(int id) async {
    await _plugin.cancel(id);
  }
}
