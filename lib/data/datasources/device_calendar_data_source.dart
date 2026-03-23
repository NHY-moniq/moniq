import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/foundation.dart';
import 'dart:developer' as dev;

class DeviceCalendarEvent {
  const DeviceCalendarEvent({
    required this.id,
    required this.title,
    required this.date,
    this.startTime,
    this.endTime,
    this.isAllDay = false,
    this.calendarName,
    this.color,
  });

  final String id;
  final String title;
  final DateTime date;
  final String? startTime;
  final String? endTime;
  final bool isAllDay;
  final String? calendarName;
  final String? color;

  String get timeRange {
    if (isAllDay || startTime == null) return '종일';
    if (endTime == null) return startTime!;
    return '$startTime ~ $endTime';
  }
}

class DeviceCalendarDataSource {
  DeviceCalendarDataSource();

  final DeviceCalendarPlugin _plugin = DeviceCalendarPlugin();
  bool _hasPermission = false;

  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    final result = await _plugin.requestPermissions();
    _hasPermission = result.isSuccess && (result.data ?? false);
    dev.log('[DeviceCalendar] requestPermission: $_hasPermission (isSuccess=${result.isSuccess}, data=${result.data})');
    return _hasPermission;
  }

  Future<bool> hasPermission() async {
    if (kIsWeb) return false;
    final result = await _plugin.hasPermissions();
    _hasPermission = result.isSuccess && (result.data ?? false);
    return _hasPermission;
  }

  Future<List<Calendar>> getCalendars() async {
    if (kIsWeb || !_hasPermission) {
      dev.log('[DeviceCalendar] getCalendars: skipped (web=$kIsWeb, perm=$_hasPermission)');
      return [];
    }
    final result = await _plugin.retrieveCalendars();
    dev.log('[DeviceCalendar] getCalendars: isSuccess=${result.isSuccess}, count=${result.data?.length ?? 0}');
    if (result.data != null) {
      for (final c in result.data!) {
        dev.log('[DeviceCalendar]   calendar: id=${c.id}, name=${c.name}, isDefault=${c.isDefault}, isReadOnly=${c.isReadOnly}');
      }
    }
    if (!result.isSuccess || result.data == null) return [];
    return result.data!;
  }

  /// 기본 캘린더를 찾아 반환 (isDefault가 true이거나, 없으면 첫 번째 캘린더)
  Future<Calendar?> getDefaultCalendar() async {
    final calendars = await getCalendars();
    if (calendars.isEmpty) return null;
    final cal = calendars.firstWhere(
      (c) => c.isDefault == true,
      orElse: () => calendars.first,
    );
    dev.log('[DeviceCalendar] defaultCalendar: id=${cal.id}, name=${cal.name}');
    return cal;
  }

  /// 기본 캘린더 + 공휴일 캘린더 반환
  Future<List<Calendar>> getImportCalendars() async {
    final calendars = await getCalendars();
    if (calendars.isEmpty) return [];

    final result = <Calendar>[];

    // 기본 캘린더
    final defaultCal = calendars.firstWhere(
      (c) => c.isDefault == true,
      orElse: () => calendars.first,
    );
    result.add(defaultCal);

    // 공휴일 캘린더 (대한민국 공휴일, Holidays 등)
    for (final c in calendars) {
      if (c.id == defaultCal.id) continue;
      final name = (c.name ?? '').toLowerCase();
      if (name.contains('holiday') ||
          name.contains('공휴일') ||
          name.contains('holidays') ||
          name.contains('대한민국')) {
        result.add(c);
      }
    }

    dev.log('[DeviceCalendar] importCalendars: ${result.map((c) => c.name).toList()}');
    return result;
  }

  Future<List<DeviceCalendarEvent>> getEventsForMonth(DateTime month) async {
    if (kIsWeb || !_hasPermission) return [];

    final calendars = await getImportCalendars();
    if (calendars.isEmpty) return [];

    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
    final events = <DeviceCalendarEvent>[];
    final offset = DateTime.now().timeZoneOffset;

    for (final calendar in calendars) {
      if (calendar.id == null) continue;

      dev.log('[DeviceCalendar] getEventsForMonth: ${month.year}-${month.month}, calendar=${calendar.name}');

      final result = await _plugin.retrieveEvents(
        calendar.id!,
        RetrieveEventsParams(startDate: start, endDate: end),
      );

      dev.log('[DeviceCalendar] retrieveEvents: isSuccess=${result.isSuccess}, count=${result.data?.length ?? 0}');
      if (!result.isSuccess || result.data == null) continue;

      String? colorHex;
      if (calendar.color != null) {
        colorHex = '#${calendar.color!.toRadixString(16).padLeft(8, '0').substring(2, 8)}';
      }

      for (final event in result.data!) {
        if (event.title == null || event.title!.isEmpty) continue;

        final rawStart = event.start;
        if (rawStart == null) continue;

        // TZDateTime → 로컬 DateTime 변환 (타임존 오프셋 수동 적용)
        final localStart = rawStart.toUtc().add(offset);

        final date = DateTime(
          localStart.year,
          localStart.month,
          localStart.day,
        );

        String? startTime;
        String? endTime;
        if (event.allDay != true) {
          startTime = _formatTime(localStart);
          final rawEnd = event.end;
          if (rawEnd != null) {
            final localEnd = rawEnd.toUtc().add(offset);
            endTime = _formatTime(localEnd);
          }
        }

        events.add(DeviceCalendarEvent(
          id: event.eventId ?? '',
          title: event.title!,
          date: date,
          startTime: startTime,
          endTime: endTime,
          isAllDay: event.allDay ?? false,
          calendarName: calendar.name,
          color: colorHex,
        ));
      }
    }

    return events;
  }

  Future<Map<DateTime, List<DeviceCalendarEvent>>> getMonthlyEventsMap(
    DateTime month,
  ) async {
    final events = await getEventsForMonth(month);
    final map = <DateTime, List<DeviceCalendarEvent>>{};
    for (final event in events) {
      map.putIfAbsent(event.date, () => []).add(event);
    }
    return map;
  }

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}
