/// 개인 일정 반복 규칙 인코딩/디코딩 + 날짜 전개.
///
/// 저장 포맷 (하위 호환):
/// - 레거시: `none` / `daily` / `weekly` / `biweekly` / `monthly` / `yearly`
///   → 기존 값 그대로 저장·전개한다 (동작 불변).
/// - 커스텀: `custom:` 접두 뒤에 `;`로 구분한 `key=value` 목록.
///   예) `custom:freq=weekly;interval=2;days=1,3;end=count:10`
///       `custom:freq=monthly;byLastWeekday=6;end=until:2027-03-01`
///       `custom:freq=daily;interval=3`
///
/// 키 목록:
/// - `freq`          : daily | weekly | monthly | yearly (필수)
/// - `interval`      : 반복 간격 N (기본 1, 1~99)
/// - `days`          : 매주일 때 요일 집합, `DateTime.weekday` 값(1=월…7=일)
///                     을 `,`로 나열
/// - `byMonthDay`    : 매달 N일 (매달일 때)
/// - `byLastWeekday` : 매달 마지막 X요일, `DateTime.weekday` 값 (매달일 때.
///                     `byMonthDay`보다 우선)
/// - `end`           : `count:N` (총 N회, 시작일 포함) | `until:YYYY-MM-DD`
///                     (그 날짜까지 포함). 없으면 기본 전개 범위(1년)를 따른다.
library;

/// 커스텀 반복 문자열 접두어.
const String kCustomRecurrencePrefix = 'custom:';

/// 반복 단위.
enum RecurrenceFreq { daily, weekly, monthly, yearly }

/// 파싱된 반복 규칙. 레거시 값과 커스텀 값 모두 이 형태로 정규화된다.
class RecurrenceRule {
  const RecurrenceRule({
    required this.freq,
    this.interval = 1,
    this.weekdays = const <int>{},
    this.byMonthDay,
    this.byLastWeekday,
    this.count,
    this.until,
  });

  final RecurrenceFreq freq;

  /// 반복 간격 (예: 2주마다 = weekly + interval 2). 1~99.
  final int interval;

  /// 매주일 때 요일 집합 — `DateTime.weekday` 값 (1=월 … 7=일).
  /// 비어 있으면 시작일의 요일 하나로 취급한다.
  final Set<int> weekdays;

  /// 매달 N일. null이면 시작일의 일(day)을 쓴다.
  final int? byMonthDay;

  /// 매달 마지막 X요일 (`DateTime.weekday`). 지정 시 [byMonthDay]보다 우선.
  final int? byLastWeekday;

  /// 총 발생 횟수 (시작일 포함). [until]과 동시 지정하지 않는다.
  final int? count;

  /// 이 날짜까지(포함) 반복.
  final DateTime? until;

  bool get hasEnd => count != null || until != null;

  /// 레거시 토큰 → 규칙. 커스텀/none/알 수 없는 값은 null.
  static RecurrenceRule? _fromLegacy(String raw) {
    switch (raw) {
      case 'daily':
        return const RecurrenceRule(freq: RecurrenceFreq.daily);
      case 'weekly':
        return const RecurrenceRule(freq: RecurrenceFreq.weekly);
      case 'biweekly':
        return const RecurrenceRule(freq: RecurrenceFreq.weekly, interval: 2);
      case 'monthly':
        return const RecurrenceRule(freq: RecurrenceFreq.monthly);
      case 'yearly':
        return const RecurrenceRule(freq: RecurrenceFreq.yearly);
      default:
        return null;
    }
  }

  /// 저장 문자열 → 규칙. `none`/null/파싱 불가면 null (반복 없음).
  static RecurrenceRule? parse(String? raw) {
    if (raw == null || raw.isEmpty || raw == 'none') return null;
    if (!raw.startsWith(kCustomRecurrencePrefix)) return _fromLegacy(raw);

    final body = raw.substring(kCustomRecurrencePrefix.length);
    RecurrenceFreq? freq;
    var interval = 1;
    var weekdays = <int>{};
    int? byMonthDay;
    int? byLastWeekday;
    int? count;
    DateTime? until;

    for (final part in body.split(';')) {
      final eq = part.indexOf('=');
      if (eq <= 0) continue;
      final key = part.substring(0, eq);
      final value = part.substring(eq + 1);
      switch (key) {
        case 'freq':
          for (final f in RecurrenceFreq.values) {
            if (f.name == value) freq = f;
          }
        case 'interval':
          interval = int.tryParse(value)?.clamp(1, 99) ?? 1;
        case 'days':
          weekdays = value
              .split(',')
              .map(int.tryParse)
              .whereType<int>()
              .where((d) => d >= 1 && d <= 7)
              .toSet();
        case 'byMonthDay':
          final d = int.tryParse(value);
          if (d != null && d >= 1 && d <= 31) byMonthDay = d;
        case 'byLastWeekday':
          final d = int.tryParse(value);
          if (d != null && d >= 1 && d <= 7) byLastWeekday = d;
        case 'end':
          final colon = value.indexOf(':');
          if (colon <= 0) break;
          final kind = value.substring(0, colon);
          final arg = value.substring(colon + 1);
          if (kind == 'count') {
            final n = int.tryParse(arg);
            if (n != null && n >= 1) count = n;
          } else if (kind == 'until') {
            until = _parseDate(arg);
          }
      }
    }
    if (freq == null) return null;
    return RecurrenceRule(
      freq: freq,
      interval: interval,
      weekdays: weekdays,
      byMonthDay: byMonthDay,
      byLastWeekday: byLastWeekday,
      count: count,
      until: until,
    );
  }

  /// 규칙 → 저장 문자열. 레거시 값으로 표현 가능하면(간격 1~2, 부가 조건
  /// 없음) 레거시 토큰을 반환해 기존 데이터와 호환을 유지한다.
  String encode() {
    final isPlain =
        weekdays.isEmpty && byMonthDay == null && byLastWeekday == null &&
        !hasEnd;
    if (isPlain && interval == 1) {
      switch (freq) {
        case RecurrenceFreq.daily:
          return 'daily';
        case RecurrenceFreq.weekly:
          return 'weekly';
        case RecurrenceFreq.monthly:
          return 'monthly';
        case RecurrenceFreq.yearly:
          return 'yearly';
      }
    }
    if (isPlain && interval == 2 && freq == RecurrenceFreq.weekly) {
      return 'biweekly';
    }

    final parts = <String>['freq=${freq.name}'];
    if (interval != 1) parts.add('interval=$interval');
    if (freq == RecurrenceFreq.weekly && weekdays.isNotEmpty) {
      final sorted = weekdays.toList()..sort();
      parts.add('days=${sorted.join(',')}');
    }
    if (freq == RecurrenceFreq.monthly) {
      if (byLastWeekday != null) {
        parts.add('byLastWeekday=$byLastWeekday');
      } else if (byMonthDay != null) {
        parts.add('byMonthDay=$byMonthDay');
      }
    }
    if (count != null) {
      parts.add('end=count:$count');
    } else if (until != null) {
      parts.add('end=until:${_dateStr(until!)}');
    }
    return '$kCustomRecurrencePrefix${parts.join(';')}';
  }
}

/// 요일 짧은 한글 라벨 (`DateTime.weekday` → 월…일).
String weekdayShortKo(int weekday) =>
    const ['월', '화', '수', '목', '금', '토', '일'][(weekday - 1) % 7];

/// 저장된 반복 값의 사용자용 요약 라벨.
/// 예: `매주` / `2주마다 · 월·수 · 10회 후 종료` / `매달 · 마지막 토요일`.
/// `none`/null이면 '반복 안 함'.
String recurrenceSummaryLabel(String? recurrence) {
  if (recurrence == null || recurrence.isEmpty || recurrence == 'none') {
    return '반복 안 함';
  }
  switch (recurrence) {
    case 'daily':
      return '매일';
    case 'weekly':
      return '매주';
    case 'biweekly':
      return '2주마다';
    case 'monthly':
      return '매달';
    case 'yearly':
      return '매년';
  }
  final rule = RecurrenceRule.parse(recurrence);
  if (rule == null) return recurrence;

  final unit = switch (rule.freq) {
    RecurrenceFreq.daily => '일',
    RecurrenceFreq.weekly => '주',
    RecurrenceFreq.monthly => '달',
    RecurrenceFreq.yearly => '년',
  };
  final head = rule.interval == 1
      ? switch (rule.freq) {
          RecurrenceFreq.daily => '매일',
          RecurrenceFreq.weekly => '매주',
          RecurrenceFreq.monthly => '매달',
          RecurrenceFreq.yearly => '매년',
        }
      : '${rule.interval}$unit마다';

  final parts = <String>[head];
  if (rule.freq == RecurrenceFreq.weekly && rule.weekdays.isNotEmpty) {
    final sorted = rule.weekdays.toList()..sort();
    parts.add(sorted.map(weekdayShortKo).join('·'));
  }
  if (rule.freq == RecurrenceFreq.monthly) {
    if (rule.byLastWeekday != null) {
      parts.add('마지막 ${weekdayShortKo(rule.byLastWeekday!)}요일');
    } else if (rule.byMonthDay != null) {
      parts.add('${rule.byMonthDay}일');
    }
  }
  if (rule.count != null) {
    parts.add('${rule.count}회 후 종료');
  } else if (rule.until != null) {
    final u = rule.until!;
    parts.add('${u.year}.${u.month}.${u.day}까지');
  }
  return parts.join(' · ');
}

/// 반복 값이 커스텀 포맷인지.
bool isCustomRecurrence(String? recurrence) =>
    recurrence != null && recurrence.startsWith(kCustomRecurrencePrefix);

/// 기본 전개 범위 — 종료 조건이 없으면 시작일로부터 1년까지 전개한다.
/// (레거시 전개와 동일한 관행)
const int kRecurrenceDefaultSpanDays = 365;

/// 반복 값에 따라 발생 날짜 목록을 만든다 (시작일 포함, 날짜만).
///
/// - 레거시 값은 기존 `_generateRecurrenceDates` 로직과 동일하게 전개한다.
/// - 커스텀 값은 interval/요일 집합/매달 N일·마지막 요일/count·until을
///   반영한다. 종료가 없으면 1년 범위로 전개한다.
List<DateTime> expandRecurrenceDates(DateTime start, String? recurrence) {
  final startDate = DateTime(start.year, start.month, start.day);
  if (recurrence == null || recurrence.isEmpty || recurrence == 'none') {
    return [startDate];
  }
  if (isCustomRecurrence(recurrence)) {
    final rule = RecurrenceRule.parse(recurrence);
    if (rule == null) return [startDate];
    return _expandRule(startDate, rule);
  }
  return _expandLegacy(startDate, recurrence);
}

/// 레거시 토큰 전개 — 기존 동작을 그대로 보존한다
/// (monthly의 말일 overflow 롤오버 포함).
List<DateTime> _expandLegacy(DateTime start, String recurrence) {
  final dates = <DateTime>[start];
  final maxDate = start.add(const Duration(days: kRecurrenceDefaultSpanDays));

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

List<DateTime> _expandRule(DateTime start, RecurrenceRule rule) {
  // until이 있으면 그 날짜까지(포함), 없으면 기본 1년 범위.
  // until이 1년보다 멀어도 기존 관행대로 1년에서 자른다.
  final hardMax =
      start.add(const Duration(days: kRecurrenceDefaultSpanDays));
  var maxDate = hardMax;
  if (rule.until != null) {
    final u = DateTime(rule.until!.year, rule.until!.month, rule.until!.day);
    if (u.isBefore(hardMax)) maxDate = u;
  }
  final maxCount = rule.count;

  // 시작일은 사용자가 일정을 만든 날이므로 항상 첫 발생으로 포함한다.
  final dates = <DateTime>[start];
  bool full() => maxCount != null && dates.length >= maxCount;
  void addIfNew(DateTime d) {
    if (d.isAfter(start) && !d.isAfter(maxDate) && !full()) dates.add(d);
  }

  if (full()) return dates;

  switch (rule.freq) {
    case RecurrenceFreq.daily:
      var k = 1;
      while (true) {
        final d = _addDays(start, k * rule.interval);
        if (d.isAfter(maxDate) || full()) break;
        addIfNew(d);
        k++;
      }
    case RecurrenceFreq.weekly:
      final days = rule.weekdays.isEmpty ? {start.weekday} : rule.weekdays;
      // 시작일이 속한 주(월요일 시작)를 0주차로 두고, interval 주기가
      // 맞는 주의 지정 요일만 채운다.
      final anchorMonday = _addDays(start, -(start.weekday - 1));
      var d = _addDays(start, 1);
      while (!d.isAfter(maxDate) && !full()) {
        final weekIndex = d.difference(anchorMonday).inDays ~/ 7;
        if (weekIndex % rule.interval == 0 && days.contains(d.weekday)) {
          addIfNew(d);
        }
        d = _addDays(d, 1);
      }
    case RecurrenceFreq.monthly:
      // k=0(시작 달)부터 훑는다 — 시작일 뒤에 오는 "마지막 X요일"처럼
      // 시작 달 안의 발생도 포함하기 위함. 상한은 방어적 가드.
      for (var k = 0; k <= 500; k++) {
        final m = start.month + k * rule.interval;
        if (DateTime(start.year, m, 1).isAfter(maxDate)) break;
        final DateTime? d;
        if (rule.byLastWeekday != null) {
          d = _lastWeekdayOfMonth(start.year, m, rule.byLastWeekday!);
        } else {
          final day = rule.byMonthDay ?? start.day;
          final daysInMonth = DateTime(start.year, m + 1, 0).day;
          // 그 달에 없는 날(예: 31일)은 건너뛴다.
          d = day <= daysInMonth ? DateTime(start.year, m, day) : null;
        }
        if (d != null) addIfNew(d);
        if (full()) break;
      }
    case RecurrenceFreq.yearly:
      for (var k = 1; k <= 500; k++) {
        final y = start.year + k * rule.interval;
        if (DateTime(y, start.month, 1).isAfter(maxDate)) break;
        // 2/29처럼 그 해에 없는 날짜는 건너뛴다.
        final candidate = DateTime(y, start.month, start.day);
        if (candidate.month == start.month) addIfNew(candidate);
        if (full()) break;
      }
  }
  return dates;
}

/// [year]/[month]의 마지막 [weekday](1=월…7=일) 날짜.
DateTime _lastWeekdayOfMonth(int year, int month, int weekday) {
  final lastDay = DateTime(year, month + 1, 0);
  final diff = (lastDay.weekday - weekday) % 7;
  return _addDays(lastDay, -diff);
}

DateTime _addDays(DateTime d, int days) =>
    DateTime(d.year, d.month, d.day + days);

DateTime? _parseDate(String raw) {
  final parts = raw.split('-');
  if (parts.length < 3) return null;
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}

String _dateStr(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}'
    '-${d.day.toString().padLeft(2, '0')}';
