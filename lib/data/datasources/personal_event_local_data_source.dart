import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class PersonalEvent {
  PersonalEvent({
    required this.date,
    required this.title,
    this.startTime,
    this.endTime,
    this.description,
    this.color,
    this.createdAt,
    this.recurrence,
  });

  final DateTime date;
  final String title;
  final String? startTime; // "HH:mm"
  final String? endTime;   // "HH:mm"
  final String? description;
  final String? color;     // hex color
  final DateTime? createdAt;
  final String? recurrence; // none, daily, weekly, biweekly, monthly, yearly

  Map<String, dynamic> toJson() => {
        'date': _dateStr(date),
        'title': title,
        'startTime': startTime,
        'endTime': endTime,
        'description': description,
        'color': color,
        'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
        'recurrence': recurrence,
      };

  factory PersonalEvent.fromJson(Map<String, dynamic> json) {
    final parts = (json['date'] as String).split('-');
    return PersonalEvent(
      date: DateTime(
          int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2])),
      title: json['title'] as String,
      startTime: json['startTime'] as String?,
      endTime: json['endTime'] as String?,
      description: json['description'] as String?,
      color: json['color'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      recurrence: json['recurrence'] as String?,
    );
  }

  String get timeRange {
    if (startTime == null) return '종일';
    if (endTime == null) return startTime!;
    return '$startTime ~ $endTime';
  }

  static String _dateStr(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}

class PersonalEventLocalDataSource {
  PersonalEventLocalDataSource({required SharedPreferences prefs})
      : _prefs = prefs;

  final SharedPreferences _prefs;

  static const _keyPrefix = 'personal_events';

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  List<PersonalEvent> getEvents(DateTime date) {
    final key = '$_keyPrefix:${_dateKey(date)}';
    final raw = _prefs.getStringList(key);
    if (raw == null || raw.isEmpty) return [];
    return raw
        .map((s) =>
            PersonalEvent.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
  }

  Map<DateTime, List<PersonalEvent>> getMonthlyEvents(DateTime month) {
    final result = <DateTime, List<PersonalEvent>>{};
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;

    for (int d = 1; d <= daysInMonth; d++) {
      final date = DateTime(month.year, month.month, d);
      final events = getEvents(date);
      if (events.isNotEmpty) {
        result[date] = events;
      }
    }
    return result;
  }

  Future<void> addEvent(PersonalEvent event) async {
    final dates = _generateRecurrenceDates(event.date, event.recurrence);
    for (final date in dates) {
      final e = PersonalEvent(
        date: date,
        title: event.title,
        startTime: event.startTime,
        endTime: event.endTime,
        description: event.description,
        color: event.color,
        createdAt: event.createdAt,
        recurrence: event.recurrence,
      );
      final key = '$_keyPrefix:${_dateKey(date)}';
      final existing = _prefs.getStringList(key) ?? [];
      existing.add(jsonEncode(e.toJson()));
      await _prefs.setStringList(key, existing);
    }
  }

  /// 반복 단위에 따라 날짜 목록 생성 (최대 1년)
  List<DateTime> _generateRecurrenceDates(DateTime start, String? recurrence) {
    if (recurrence == null || recurrence == 'none') {
      return [start];
    }

    final dates = <DateTime>[start];
    final maxDate = start.add(const Duration(days: 365));

    DateTime next = start;
    while (true) {
      switch (recurrence) {
        case 'daily':
          next = next.add(const Duration(days: 1));
        case 'weekly':
          next = next.add(const Duration(days: 7));
        case 'biweekly':
          next = next.add(const Duration(days: 14));
        case 'monthly':
          next = DateTime(next.year, next.month + 1, start.day);
        case 'yearly':
          next = DateTime(next.year + 1, start.month, start.day);
        default:
          return dates;
      }
      if (next.isAfter(maxDate)) break;
      dates.add(next);
    }
    return dates;
  }

  Future<void> removeEvent(DateTime date, int index) async {
    final key = '$_keyPrefix:${_dateKey(date)}';
    final existing = _prefs.getStringList(key) ?? [];
    if (index >= 0 && index < existing.length) {
      existing.removeAt(index);
      if (existing.isEmpty) {
        await _prefs.remove(key);
      } else {
        await _prefs.setStringList(key, existing);
      }
    }
  }

  /// 특정 날짜 이후의 동일 반복 일정 전체 삭제
  Future<void> removeRecurringEventsFrom({
    required DateTime date,
    required String title,
    required String recurrence,
  }) async {
    // 해당 날짜부터 1년치 탐색
    final maxDate = date.add(const Duration(days: 366));
    DateTime current = date;

    while (!current.isAfter(maxDate)) {
      final key = '$_keyPrefix:${_dateKey(current)}';
      final existing = _prefs.getStringList(key);
      if (existing != null && existing.isNotEmpty) {
        final filtered = existing.where((s) {
          final e = PersonalEvent.fromJson(
              jsonDecode(s) as Map<String, dynamic>);
          return !(e.title == title && e.recurrence == recurrence);
        }).toList();

        if (filtered.isEmpty) {
          await _prefs.remove(key);
        } else if (filtered.length != existing.length) {
          await _prefs.setStringList(key, filtered);
        }
      }
      current = current.add(const Duration(days: 1));
    }
  }

  Future<void> updateEvent(DateTime date, int index, PersonalEvent event) async {
    final key = '$_keyPrefix:${_dateKey(date)}';
    final existing = _prefs.getStringList(key) ?? [];
    if (index >= 0 && index < existing.length) {
      existing[index] = jsonEncode(event.toJson());
      await _prefs.setStringList(key, existing);
    }
  }
}
