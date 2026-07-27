import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import 'personal_event_remote_data_source.dart';

class PersonalEvent {
  PersonalEvent({
    this.id,
    required this.date,
    required this.title,
    this.endDate,
    this.startTime,
    this.endTime,
    this.description,
    this.color,
    this.createdAt,
    this.recurrence,
  });

  /// Supabase row id (로컬 전용 이벤트는 null).
  final String? id;

  /// 시작 일자. 캘린더에서 이 일정이 걸리는 기준 날짜다.
  final DateTime date;
  final String title;

  /// 종료 일자. null 또는 [date]와 같으면 당일 일정.
  final DateTime? endDate;
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
        endDate: endDate,
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
        'endDate': endDate != null ? _dateStr(endDate!) : null,
        'startTime': startTime,
        'endTime': endTime,
        'description': description,
        'color': color,
        'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
        'recurrence': recurrence,
      };

  factory PersonalEvent.fromJson(Map<String, dynamic> json) {
    return PersonalEvent(
      id: json['id'] as String?,
      date: _parseDateStr(json['date'] as String)!,
      title: json['title'] as String,
      endDate: _parseDateStr(json['endDate'] as String?),
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

  /// 시작일과 종료일이 다른(하루를 넘기는) 일정인지.
  bool get spansMultipleDays =>
      endDate != null &&
      DateTime(endDate!.year, endDate!.month, endDate!.day)
          .isAfter(DateTime(date.year, date.month, date.day));

  String get timeRange {
    if (!spansMultipleDays) {
      if (startTime == null) return '종일';
      if (endTime == null) return startTime!;
      return '$startTime ~ $endTime';
    }
    // 여러 날에 걸친 일정은 날짜를 함께 보여준다.
    final from = _monthDayStr(date);
    final to = _monthDayStr(endDate!);
    if (startTime == null) return '$from ~ $to';
    final tail = endTime != null ? '$to $endTime' : to;
    return '$from $startTime ~ $tail';
  }

  static String _dateStr(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  static String _monthDayStr(DateTime dt) => '${dt.month}/${dt.day}';

  static DateTime? _parseDateStr(String? raw) {
    if (raw == null) return null;
    final parts = raw.split('-');
    if (parts.length < 3) return null;
    return DateTime(
        int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  }
}

/// 특정 날짜에 표시되는 일정 1건 + 그 일정의 **저장 위치**.
///
/// 여러 날에 걸친 일정은 시작일이 아닌 날에도 표시되지만, 저장/삭제/수정은
/// 언제나 시작일 키 + 그 날 리스트의 인덱스로 이뤄진다. 표시용 조회 결과에
/// 원본 위치를 함께 실어 보내 continuation 카드에서도 수정/삭제가 정확히
/// 동작하게 한다.
class PersonalEventOccurrence {
  const PersonalEventOccurrence({
    required this.event,
    required this.originDate,
    required this.originIndex,
    required this.isContinuation,
  });

  final PersonalEvent event;

  /// 이 일정이 저장된 날짜 키 (= 시작일).
  final DateTime originDate;

  /// [originDate] 저장 리스트 내 인덱스.
  final int originIndex;

  /// 시작일이 아닌 날에 기간 때문에 표시되는 항목인지.
  final bool isContinuation;
}

class PersonalEventLocalDataSource {
  PersonalEventLocalDataSource({
    required SharedPreferences prefs,
    String userId = 'anonymous',
    PersonalEventRemoteDataSource? remote,
  })  : _prefs = prefs,
        _userId = userId,
        _remote = remote ?? PersonalEventRemoteDataSource();

  final SharedPreferences _prefs;
  final String _userId;
  final PersonalEventRemoteDataSource _remote;

  static const _keyPrefix = 'personal_events';

  /// 다일 일정 역스캔 상한 (일). 이 이상 긴 일정은 시작일 기준으로만 표시된다.
  static const _maxSpanScanLimit = 366;

  /// 사용자별 키 생성 (읽기/쓰기 통일)
  String _userDateKey(DateTime date) =>
      '$_keyPrefix:$_userId:${_dateKey(date)}';

  /// 이 사용자가 저장한 일정 중 가장 긴 기간(일수) 캐시 키.
  String get _maxSpanKey => '$_keyPrefix:$_userId:max_span_days';

  /// 여러 날에 걸친 일정을 시작일이 아닌 날에도 표시하려면 조회일보다 앞선
  /// 날짜의 저장분까지 훑어야 한다. 캐시 전체를 매번 스캔하지 않도록 실제로
  /// 저장된 최대 기간만큼만 거슬러 올라간다 (다일 일정이 없으면 0 → 스캔 없음).
  int get _maxSpanDays {
    final v = _prefs.getInt(_maxSpanKey) ?? 0;
    if (v <= 0) return 0;
    return v > _maxSpanScanLimit ? _maxSpanScanLimit : v;
  }

  Future<void> _rememberSpan(PersonalEvent event) async {
    if (event.endDate == null) return;
    final span = _dateOnly(event.endDate!).difference(_dateOnly(event.date)).inDays;
    if (span <= 0 || span <= _maxSpanDays) return;
    await _prefs.setInt(
      _maxSpanKey,
      span > _maxSpanScanLimit ? _maxSpanScanLimit : span,
    );
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime _addDays(DateTime d, int days) =>
      DateTime(d.year, d.month, d.day + days);

  /// Supabase에서 사용자 이벤트 전부를 가져와 로컬 캐시를 재구축한다.
  /// 로그인 직후 / 인증 변경 시 호출.
  Future<void> pullFromRemote() async {
    try {
      final remoteEvents = await _remote.fetchAll();
      // 기존 로컬 캐시 비우기 (이 사용자 prefix만)
      final userPrefix = '$_keyPrefix:$_userId:';
      final keys = _prefs.getKeys().where((k) => k.startsWith(userPrefix));
      for (final k in keys) {
        await _prefs.remove(k);
      }
      // 레거시 키(userId 없는 형식)도 정리
      final legacyKeys = _prefs.getKeys().where((k) =>
          k.startsWith('$_keyPrefix:') &&
          !k.startsWith(userPrefix) &&
          k.split(':').length == 2);
      for (final k in legacyKeys) {
        await _prefs.remove(k);
      }
      // 새로 채움 (다일 일정 역스캔 범위도 함께 재계산)
      int maxSpan = 0;
      for (final e in remoteEvents) {
        final key = _userDateKey(e.date);
        final list = _prefs.getStringList(key) ?? [];
        list.add(jsonEncode(e.toJson()));
        await _prefs.setStringList(key, list);
        if (e.endDate != null) {
          final span =
              _dateOnly(e.endDate!).difference(_dateOnly(e.date)).inDays;
          if (span > maxSpan) maxSpan = span;
        }
      }
      await _prefs.setInt(
        _maxSpanKey,
        maxSpan > _maxSpanScanLimit ? _maxSpanScanLimit : maxSpan,
      );
    } catch (_) {
      // 동기화 실패 시 기존 로컬 캐시 유지
    }
  }

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  List<PersonalEvent> getEvents(DateTime date) {
    final key = _userDateKey(date);
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

  /// [date]에 표시돼야 하는 일정 전체 — 이 날 시작하는 일정 + 이전에 시작해
  /// 이 날까지 이어지는 다일 일정. 각 항목은 저장 위치를 함께 담고 있어
  /// 수정/삭제에 그대로 쓸 수 있다.
  ///
  /// 앞부분은 [getEvents] 결과와 순서·인덱스가 동일하다.
  List<PersonalEventOccurrence> getOccurrences(DateTime date) {
    final target = _dateOnly(date);
    final out = <PersonalEventOccurrence>[];

    final own = getEvents(target);
    for (int i = 0; i < own.length; i++) {
      out.add(PersonalEventOccurrence(
        event: own[i],
        originDate: target,
        originIndex: i,
        isContinuation: false,
      ));
    }

    // 이전 날짜에서 시작해 이 날까지 걸쳐 있는 일정.
    for (int back = 1; back <= _maxSpanDays; back++) {
      final origin = _addDays(target, -back);
      final events = getEvents(origin);
      for (int i = 0; i < events.length; i++) {
        final e = events[i];
        if (!e.spansMultipleDays) continue;
        if (_dateOnly(e.endDate!).isBefore(target)) continue;
        out.add(PersonalEventOccurrence(
          event: e,
          originDate: origin,
          originIndex: i,
          isContinuation: true,
        ));
      }
    }
    return out;
  }

  /// [getOccurrences]의 이벤트만 뽑은 목록 — 표시/내보내기 전용.
  /// (수정/삭제 인덱스가 필요하면 [getOccurrences]를 쓸 것)
  List<PersonalEvent> getEventsIncludingSpans(DateTime date) =>
      getOccurrences(date).map((o) => o.event).toList();

  /// [getMonthlyEvents]와 같지만 다일 일정을 걸쳐 있는 모든 날짜에 채워 넣는다.
  /// 캘린더 셀 표시용 (수정/삭제 인덱스로는 쓰지 말 것 — [getOccurrences] 사용).
  Map<DateTime, List<PersonalEvent>> getMonthlyEventsIncludingSpans(
      DateTime month) {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month, daysInMonth);
    final result = <DateTime, List<PersonalEvent>>{};

    void spread(PersonalEvent e, DateTime from) {
      final end = _dateOnly(e.endDate!);
      var cursor = from;
      while (!cursor.isAfter(lastDay) && !cursor.isAfter(end)) {
        (result[cursor] ??= <PersonalEvent>[]).add(e);
        cursor = _addDays(cursor, 1);
      }
    }

    // 1) 이 달에 시작하는 일정 (+ 이 달 안에서 이어지는 날들)
    for (int d = 1; d <= daysInMonth; d++) {
      final date = DateTime(month.year, month.month, d);
      for (final e in getEvents(date)) {
        (result[date] ??= <PersonalEvent>[]).add(e);
        if (e.spansMultipleDays) spread(e, _addDays(date, 1));
      }
    }

    // 2) 이전 달에서 시작해 이 달로 넘어온 다일 일정
    for (int back = 1; back <= _maxSpanDays; back++) {
      final origin = _addDays(firstDay, -back);
      for (final e in getEvents(origin)) {
        if (!e.spansMultipleDays) continue;
        if (_dateOnly(e.endDate!).isBefore(firstDay)) continue;
        spread(e, firstDay);
      }
    }
    return result;
  }

  Future<void> addEvent(PersonalEvent event) async {
    final dates = _generateRecurrenceDates(event.date, event.recurrence);
    // 반복 일정도 원본과 동일한 기간(일수)을 유지한다.
    final spanDays = event.endDate != null
        ? _dateOnly(event.endDate!).difference(_dateOnly(event.date)).inDays
        : null;
    await _rememberSpan(event);
    for (final date in dates) {
      var e = PersonalEvent(
        date: date,
        title: event.title,
        endDate: spanDays != null ? date.add(Duration(days: spanDays)) : null,
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
      final key = _userDateKey(date);
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
    final key = _userDateKey(date);
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

  /// 팀 캘린더 import 이벤트를 새 리스트로 교체. 기존 team-import 이벤트는 삭제,
  /// 사용자가 직접 추가한 이벤트는 보존된다. 로컬 캐시도 함께 재구축.
  /// 반환값: 새로 insert된 이벤트 개수.
  Future<int> replaceTeamImports(List<PersonalEvent> events) async {
    int inserted = 0;
    try {
      await _remote.deleteAllTeamImports();
      if (events.isNotEmpty) {
        final result = await _remote.insertMany(events);
        inserted = result.length;
      }
    } catch (_) {
      // 원격 실패 시 로컬 캐시 재구축으로 정합성 회복
    }
    // 로컬 캐시 전체 재구축 (서버 상태와 동기화)
    await pullFromRemote();
    return inserted;
  }

  /// 특정 연/월의 모든 개인 이벤트 일괄 삭제. 로컬 캐시 + Supabase 모두 정리.
  /// 반환값: 삭제된 이벤트 개수.
  ///
  /// 동작:
  /// 1) Supabase에서 해당 월의 personal_events를 범위 쿼리로 일괄 삭제 시도
  /// 2) 그래도 남은 row가 있으면 id별로 개별 삭제 (RLS 회피 등 fallback)
  /// 3) `pullFromRemote()`로 로컬 캐시를 서버 상태에 다시 동기화
  Future<int> deleteEventsByMonth({
    required int year,
    required int month,
  }) async {
    int removed = 0;
    // 1) 범위 쿼리 일괄 삭제
    try {
      removed = await _remote.deleteByMonth(year: year, month: month);
    } catch (_) {}

    // 2) Fallback — fetchAll로 잔존 row 확인 후 id별 개별 삭제
    try {
      final all = await _remote.fetchAll();
      final stale = all.where((e) =>
          e.id != null &&
          e.date.year == year &&
          e.date.month == month).toList();
      for (final e in stale) {
        try {
          await _remote.delete(e.id!);
          removed++;
        } catch (_) {}
      }
    } catch (_) {}

    // 3) 로컬 캐시를 서버 상태로 강제 재구축
    await pullFromRemote();
    return removed;
  }

  /// 특정 연/월의 **근무(team-import) 일정만** 일괄 삭제.
  /// 사용자가 직접 추가한 개인 일정/메모는 보존된다.
  /// 반환값: 삭제된 근무 일정 개수.
  Future<int> deleteTeamImportsByMonth({
    required int year,
    required int month,
  }) async {
    int removed = 0;
    try {
      final all = await _remote.fetchAll();
      final targets = all.where((e) =>
          e.id != null &&
          e.date.year == year &&
          e.date.month == month &&
          (e.description?.startsWith(kPersonalTeamImportMarker) ?? false));
      for (final e in targets) {
        try {
          await _remote.delete(e.id!);
          removed++;
        } catch (_) {}
      }
    } catch (_) {}
    // 로컬 캐시를 서버 상태로 재구축
    await pullFromRemote();
    return removed;
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
      final key = _userDateKey(current);
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
    await _rememberSpan(event);
    final key = _userDateKey(date);
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
