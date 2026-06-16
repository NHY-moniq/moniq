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

  /// 주어진 날짜들을 숨김 목록에 추가. 반환값: 새로 추가된 개수.
  Future<int> hideDates(Iterable<DateTime> dates) async {
    final cur = (_prefs.getStringList(_key) ?? const []).toSet();
    final before = cur.length;
    for (final d in dates) {
      cur.add(_fmt(DateTime(d.year, d.month, d.day)));
    }
    await _prefs.setStringList(_key, cur.toList());
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
