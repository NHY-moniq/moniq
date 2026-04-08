import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import 'personal_event_remote_data_source.dart';

class PersonalEvent {
  PersonalEvent({
    this.id,
    required this.date,
    required this.title,
    this.startTime,
    this.endTime,
    this.description,
    this.color,
    this.createdAt,
    this.recurrence,
  });

  /// Supabase row id (로컬 전용 이벤트는 null).
  final String? id;
  final DateTime date;
  final String title;
  final String? startTime; // "HH:mm"
  final String? endTime;   // "HH:mm"
  final String? description;
  final String? color;     // hex color
  final DateTime? createdAt;
  final String? recurrence; // none, daily, weekly, biweekly, monthly, yearly

  PersonalEvent copyWith({String? id}) => PersonalEvent(
        id: id ?? this.id,
        date: date,
        title: title,
        startTime: startTime,
        endTime: endTime,
        description: description,
        color: color,
        createdAt: createdAt,
        recurrence: recurrence,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
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
      id: json['id'] as String?,
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
  PersonalEventLocalDataSource({
    required SharedPreferences prefs,
    PersonalEventRemoteDataSource? remote,
  })  : _prefs = prefs,
        _remote = remote ?? PersonalEventRemoteDataSource();

  final SharedPreferences _prefs;
  final PersonalEventRemoteDataSource _remote;

  static const _keyPrefix = 'personal_events';

  /// Supabase에서 사용자 이벤트 전부를 가져와 로컬 캐시를 재구축한다.
  /// 로그인 직후 / 인증 변경 시 호출.
  Future<void> pullFromRemote() async {
    try {
      final remoteEvents = await _remote.fetchAll();
      // 기존 로컬 캐시 비우기 (이 prefix만)
      final keys = _prefs.getKeys().where((k) => k.startsWith('$_keyPrefix:'));
      for (final k in keys) {
        await _prefs.remove(k);
      }
      // 새로 채움
      for (final e in remoteEvents) {
        final key = '$_keyPrefix:${_dateKey(e.date)}';
        final list = _prefs.getStringList(key) ?? [];
        list.add(jsonEncode(e.toJson()));
        await _prefs.setStringList(key, list);
      }
    } catch (_) {
      // 동기화 실패 시 기존 로컬 캐시 유지
    }
  }

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
      var e = PersonalEvent(
        date: date,
        title: event.title,
        startTime: event.startTime,
        endTime: event.endTime,
        description: event.description,
        color: event.color,
        createdAt: event.createdAt,
        recurrence: event.recurrence,
      );
      // Supabase insert (id 발급). 실패 시 로컬에만 저장.
      try {
        final saved = await _remote.insert(e);
        e = saved;
      } catch (_) {}
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
      // Supabase에서도 삭제 (id 있는 경우)
      try {
        final removed = PersonalEvent.fromJson(
            jsonDecode(existing[index]) as Map<String, dynamic>);
        if (removed.id != null) {
          await _remote.delete(removed.id!);
        }
      } catch (_) {}
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
        final kept = <String>[];
        for (final s in existing) {
          final e = PersonalEvent.fromJson(
              jsonDecode(s) as Map<String, dynamic>);
          final isMatch = e.title == title && e.recurrence == recurrence;
          if (isMatch) {
            if (e.id != null) {
              try {
                await _remote.delete(e.id!);
              } catch (_) {}
            }
          } else {
            kept.add(s);
          }
        }
        if (kept.isEmpty) {
          await _prefs.remove(key);
        } else if (kept.length != existing.length) {
          await _prefs.setStringList(key, kept);
        }
      }
      current = current.add(const Duration(days: 1));
    }
  }

  Future<void> updateEvent(DateTime date, int index, PersonalEvent event) async {
    final key = '$_keyPrefix:${_dateKey(date)}';
    final existing = _prefs.getStringList(key) ?? [];
    if (index >= 0 && index < existing.length) {
      // 기존 id 보존 후 remote update
      var merged = event;
      try {
        final old = PersonalEvent.fromJson(
            jsonDecode(existing[index]) as Map<String, dynamic>);
        if (old.id != null) {
          merged = event.copyWith(id: old.id);
          await _remote.update(merged);
        } else {
          // id가 없던 로컬 전용 이벤트면 새로 insert
          final saved = await _remote.insert(merged);
          merged = saved;
        }
      } catch (_) {}
      existing[index] = jsonEncode(merged.toJson());
      await _prefs.setStringList(key, existing);
    }
  }
}
