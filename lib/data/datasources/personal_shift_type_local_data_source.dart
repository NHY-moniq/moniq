import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class PersonalShiftType {
  PersonalShiftType({
    required this.id,
    required this.name,
    required this.code,
    this.startTime,
    this.endTime,
    required this.color,
  });

  final String id;
  final String name;
  final String code;
  final String? startTime;
  final String? endTime;
  final String color; // hex

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'code': code,
        'startTime': startTime,
        'endTime': endTime,
        'color': color,
      };

  factory PersonalShiftType.fromJson(Map<String, dynamic> json) =>
      PersonalShiftType(
        id: json['id'] as String,
        name: json['name'] as String,
        code: json['code'] as String,
        startTime: json['startTime'] as String?,
        endTime: json['endTime'] as String?,
        color: json['color'] as String,
      );
}

/// 근무 유형 이름에서 1글자 표준 라벨을 추출.
/// 데이→D, 이브닝→E, 나이트→N, 오프→O, 그 외 → 이름 첫 글자(대문자).
String _baseLetter(String name) {
  if (name.contains('데이') || name.toLowerCase().contains('day')) return 'D';
  if (name.contains('이브닝')) return 'E';
  if (name.contains('나이트')) return 'N';
  if (name.contains('오프')) return 'O';
  if (name.isEmpty) return '?';
  return name[0].toUpperCase();
}

bool _isKoreanStandardName(String name) =>
    name.contains('데이') ||
    name.contains('이브닝') ||
    name.contains('나이트') ||
    name.contains('오프');

/// 근무 유형이 "오프"인지 — 이름/코드 어느 쪽으로도 판별한다.
/// (기본 오프 유형의 코드는 'O'지만, 팀에서 가져온 유형은 'OFF'를 쓴다)
bool isOffShiftName(String name, String code) {
  final c = code.trim().toUpperCase();
  return c == 'O' ||
      c == 'OFF' ||
      name.contains('오프') ||
      name.toLowerCase().contains('off');
}

/// 빠른 추가 시트의 표시 순서 — 오프 → 데이 → 이브닝 → 나이트 → 교육 → 그 외.
int _displayOrderOf(String name, String code) {
  final c = code.trim().toUpperCase();
  final lower = name.toLowerCase();
  if (isOffShiftName(name, code)) return 0;
  if (c == 'D' || name.contains('데이') || lower.contains('day')) return 1;
  if (c == 'E' || name.contains('이브닝')) return 2;
  if (c == 'N' || name.contains('나이트') || lower.contains('night')) return 3;
  if (c == 'ED' || c == 'EDU' || name.contains('교육')) return 4;
  return 5;
}

/// 근무 유형을 [오프, 데이, 이브닝, 나이트, 교육, 그 외] 순으로 정렬.
///
/// 같은 그룹 안에서는 원래 순서를 유지한다 (Dart의 `List.sort`는 unstable이라
/// 원본 인덱스를 tie-breaker로 함께 비교한다).
List<PersonalShiftType> sortShiftTypesForDisplay(
  List<PersonalShiftType> types,
) {
  final indexed = [for (var i = 0; i < types.length; i++) (i, types[i])];
  indexed.sort((a, b) {
    final cmp = _displayOrderOf(
      a.$2.name,
      a.$2.code,
    ).compareTo(_displayOrderOf(b.$2.name, b.$2.code));
    return cmp != 0 ? cmp : a.$1.compareTo(b.$1);
  });
  return [for (final e in indexed) e.$2];
}

/// 다른 shift type과 같은 1글자 라벨이 충돌하면 이름 앞 2글자를 반환.
/// 표준 한국어 이름(데이/이브닝/나이트/오프)은 충돌해도 1글자 우선권 유지.
///
/// 예: 이브닝(E) + Education(E) → 이브닝='E', Education='ED'
String displayShiftLabel(
  PersonalShiftType target,
  List<PersonalShiftType> all,
) {
  final myLabel = _baseLetter(target.name);
  final hasConflict = all.any(
    (st) => st.id != target.id && _baseLetter(st.name) == myLabel,
  );
  if (!hasConflict) return myLabel;
  if (_isKoreanStandardName(target.name)) return myLabel;
  final n = target.name;
  if (n.length >= 2) return n.substring(0, 2).toUpperCase();
  return n.toUpperCase();
}

class PersonalShiftTypeLocalDataSource {
  PersonalShiftTypeLocalDataSource({
    required SharedPreferences prefs,
    required String userId,
  })  : _prefs = prefs,
        _key = 'personal_shift_types:$userId',
        _initKey = 'personal_shift_types_initialized:$userId',
        _eduMigrationKey = 'personal_shift_types_edu_added:$userId',
        _offMigrationKey = 'personal_shift_types_off_added:$userId';

  final SharedPreferences _prefs;
  final String _key;
  final String _initKey;
  final String _eduMigrationKey;
  final String _offMigrationKey;

  List<PersonalShiftType> getAll() {
    // 사용자가 한 번이라도 초기화를 끝냈으면 빈 리스트도 그대로 존중
    // (전체 삭제 후 기본값 자동 복구 방지)
    final initialized = _prefs.getBool(_initKey) ?? false;
    final raw = _prefs.getStringList(_key);
    if (!initialized && (raw == null || raw.isEmpty)) {
      return _defaults();
    }
    if (raw == null) return const [];
    final list = raw
        .map((s) =>
            PersonalShiftType.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();

    // 1회성 마이그레이션: 기존 사용자에게도 기본 유형을 채워준다.
    // 유형별 플래그로 한 번만 실행 → 사용자가 추가/삭제한 경우 다시 건드리지 않는다.
    var migrated = false;

    // '교육(ED)'
    if (!(_prefs.getBool(_eduMigrationKey) ?? false)) {
      _prefs.setBool(_eduMigrationKey, true);
      final hasEducation = list.any(
        (t) => t.code.trim().toUpperCase() == 'ED' || t.name.contains('교육'),
      );
      if (!hasEducation) {
        list.add(defaultTypes.firstWhere((t) => t.id == 'education'));
        migrated = true;
      }
    }

    // '오프(O)' — 근무 유형 목록의 맨 앞에 오도록 insert.
    if (!(_prefs.getBool(_offMigrationKey) ?? false)) {
      _prefs.setBool(_offMigrationKey, true);
      final hasOff = list.any((t) => isOffShiftName(t.name, t.code));
      if (!hasOff) {
        list.insert(0, defaultTypes.firstWhere((t) => t.id == 'off'));
        migrated = true;
      }
    }

    // 자동 생성한 오프 유형의 색을 현재 기본값으로 맞춘다.
    // (앱이 정한 오프 색이 바뀌어도 기존 기기에 옛 색이 남지 않도록.
    //  사용자가 직접 만든 유형이나 이름을 바꾼 유형은 건드리지 않는다)
    final offDefault = defaultTypes.firstWhere((t) => t.id == 'off');
    final autoOffIdx = list.indexWhere(
      (t) => t.id == 'off' && t.name == offDefault.name,
    );
    if (autoOffIdx >= 0 && list[autoOffIdx].color != offDefault.color) {
      final cur = list[autoOffIdx];
      list[autoOffIdx] = PersonalShiftType(
        id: cur.id,
        name: cur.name,
        code: cur.code,
        startTime: cur.startTime,
        endTime: cur.endTime,
        color: offDefault.color,
      );
      migrated = true;
    }

    if (migrated) {
      _prefs.setStringList(
        _key,
        list.map((t) => jsonEncode(t.toJson())).toList(),
      );
    }
    return list;
  }

  Future<void> save(List<PersonalShiftType> types) async {
    final raw = types.map((t) => jsonEncode(t.toJson())).toList();
    await _prefs.setStringList(_key, raw);
    await _prefs.setBool(_initKey, true);
  }

  Future<void> add(PersonalShiftType type) async {
    final list = getAll();
    list.add(type);
    await save(list);
  }

  Future<void> update(String id, PersonalShiftType updated) async {
    final list = getAll();
    final idx = list.indexWhere((t) => t.id == id);
    if (idx >= 0) {
      list[idx] = updated;
      await save(list);
    }
  }

  Future<void> remove(String id) async {
    final list = getAll();
    list.removeWhere((t) => t.id == id);
    await save(list);
  }

  /// 기본 근무 유형 목록 (저장하지 않음). 빠른 근무 추가 순서와 동일하게
  /// 오프 → 데이 → 이브닝 → 나이트 → 교육 순으로 둔다.
  /// 빠른 근무 추가에서 개인 근무 유형이 비어 있을 때의 폴백으로도 사용된다.
  ///
  /// 오프의 코드는 'O' — 캘린더 셀/근무 카드가 오프를 'O'로 표시하므로
  /// 사용자가 설정 화면에서 보는 뱃지와 캘린더 표시를 일치시킨다.
  static List<PersonalShiftType> get defaultTypes => [
        PersonalShiftType(
          id: 'off', name: '오프', code: 'O',
          startTime: null, endTime: null, color: '#D5EBFF',
        ),
        PersonalShiftType(
          id: 'day', name: '데이', code: 'D',
          startTime: '07:00', endTime: '15:00', color: '#FFD700',
        ),
        PersonalShiftType(
          id: 'evening', name: '이브닝', code: 'E',
          startTime: '15:00', endTime: '23:00', color: '#FF8C00',
        ),
        PersonalShiftType(
          id: 'night', name: '나이트', code: 'N',
          startTime: '23:00', endTime: '07:00', color: '#0061A4',
        ),
        PersonalShiftType(
          id: 'education', name: '교육', code: 'ED',
          startTime: '09:00', endTime: '18:00', color: '#9F7AEA',
        ),
      ];

  /// 기본 근무 유형 — 최초 1회만 생성 후 저장.
  List<PersonalShiftType> _defaults() {
    final defaults = defaultTypes;
    save(defaults);
    return defaults;
  }
}
