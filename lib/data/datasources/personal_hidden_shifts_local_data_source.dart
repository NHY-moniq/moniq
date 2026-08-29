import 'package:shared_preferences/shared_preferences.dart';

/// 개인 캘린더에서 "근무 삭제"로 숨긴 날짜 집합 (로컬 전용, 사용자별).
///
/// 팀의 근무 데이터(shifts)는 그대로 보존하고, **개인 캘린더 화면에서만**
/// 해당 날짜의 팀 근무(및 OFF 채움)를 제거한다. 전역 "팀 근무 숨기기" 토글과는
/// 별개의 영구 숨김 목록이다.
class PersonalHiddenShiftsLocalDataSource {
  PersonalHiddenShiftsLocalDataSource({
    required SharedPreferences prefs,
    required String userId,
  })  : _prefs = prefs,
        _userId = userId;

  final SharedPreferences _prefs;
  final String _userId;

  String get _key => 'personal_hidden_shift_dates:$_userId';

  /// **팀 근무만 가릴** 날짜 집합.
  ///
  /// [_key](삭제로 숨긴 날)는 그 날의 개인 근무 일정까지 함께 치우지만,
  /// 이 목록은 팀 근무만 가리고 개인 근무·OFF 표시는 남긴다. 두 곳에서 쓴다.
  /// - 오프로 바꾼 날: 개인 근무가 없으니 OFF 표시가 남는다
  /// - 팀에 없는 개인 유형으로 바꾼 날: 그 개인 근무가 대신 보인다
  ///
  /// (오프는 팀 근무 유형으로 존재하지 않아 오버라이드로 표현할 수 없다)
  String get _offKey => 'personal_off_dates:$_userId';

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  DateTime? _parse(String s) {
    final p = s.split('-');
    if (p.length != 3) return null;
    final y = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    final d = int.tryParse(p[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  Set<DateTime> getHiddenDates() {
    final raw = _prefs.getStringList(_key) ?? const [];
    final out = <DateTime>{};
    for (final s in raw) {
      final d = _parse(s);
      if (d != null) out.add(d);
    }
    return out;
  }

  bool isHidden(DateTime date) =>
      getHiddenDates().contains(DateTime(date.year, date.month, date.day));

  /// 오프로 바꾼 날짜들 — 팀 근무는 가리되 OFF 표시는 유지한다.
  Set<DateTime> getOffDates() {
    final raw = _prefs.getStringList(_offKey) ?? const [];
    final out = <DateTime>{};
    for (final s in raw) {
      final d = _parse(s);
      if (d != null) out.add(d);
    }
    return out;
  }

  /// 주어진 날짜를 "오프"로 표시. 삭제 숨김과는 배타적이라 그쪽에서 제거한다.
  Future<void> markOffDates(Iterable<DateTime> dates) async {
    final cur = (_prefs.getStringList(_offKey) ?? const []).toSet();
    for (final d in dates) {
      cur.add(_fmt(DateTime(d.year, d.month, d.day)));
    }
    await _prefs.setStringList(_offKey, cur.toList());
    await unhideDates(dates);
  }

  /// 오프 표시 해제 (근무를 다시 넣거나 삭제할 때).
  Future<void> clearOffDates(Iterable<DateTime> dates) async {
    final cur = (_prefs.getStringList(_offKey) ?? const []).toSet();
    if (cur.isEmpty) return;
    var changed = false;
    for (final d in dates) {
      if (cur.remove(_fmt(DateTime(d.year, d.month, d.day)))) changed = true;
    }
    if (!changed) return;
    await _prefs.setStringList(_offKey, cur.toList());
  }

  /// 주어진 날짜들을 숨김 목록에 추가. 반환값: 새로 추가된 개수.
  Future<int> hideDates(Iterable<DateTime> dates) async {
    final cur = (_prefs.getStringList(_key) ?? const []).toSet();
    final before = cur.length;
    for (final d in dates) {
      cur.add(_fmt(DateTime(d.year, d.month, d.day)));
    }
    await _prefs.setStringList(_key, cur.toList());
    // 삭제(빈 칸)와 오프 표시는 배타적 — 삭제한 날의 오프 표시는 지운다.
    await clearOffDates(dates);
    return cur.length - before;
  }

  /// 특정 연/월 전체를 숨김 (그 달의 모든 날짜).
  /// 반환값: 새로 숨김 처리된 날짜 수.
  Future<int> hideMonth(int year, int month) async {
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final dates = [
      for (var d = 1; d <= daysInMonth; d++) DateTime(year, month, d),
    ];
    return hideDates(dates);
  }

  /// 주어진 날짜들의 숨김을 해제.
  ///
  /// "근무 삭제"는 그 달 전체를 숨김 목록에 넣으므로, 이후 같은 달에 근무를
  /// 새로 추가하면 넣자마자 다시 가려진다. 근무를 쓸 때 그 날을 풀어줘야 한다.
  Future<void> unhideDates(Iterable<DateTime> dates) async {
    final cur = (_prefs.getStringList(_key) ?? const []).toSet();
    if (cur.isEmpty) return;
    var changed = false;
    for (final d in dates) {
      if (cur.remove(_fmt(DateTime(d.year, d.month, d.day)))) changed = true;
    }
    if (!changed) return;
    await _prefs.setStringList(_key, cur.toList());
  }

  /// 모든 숨김 해제 (예: 팀 근무를 다시 가져오기 할 때).
  Future<void> clearAll() async {
    await _prefs.remove(_key);
  }

  /// 특정 연/월의 숨김을 해제.
  Future<void> unhideMonth(int year, int month) async {
    final cur = _prefs.getStringList(_key) ?? const [];
    final kept = cur.where((s) {
      final d = _parse(s);
      return !(d != null && d.year == year && d.month == month);
    }).toList();
    await _prefs.setStringList(_key, kept);
  }
}
