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
        _initKey = 'personal_shift_types_initialized:$userId';

  final SharedPreferences _prefs;
  final String _key;
  final String _initKey;

  List<PersonalShiftType> getAll() {
    // 사용자가 한 번이라도 초기화를 끝냈으면 빈 리스트도 그대로 존중
    // (전체 삭제 후 기본값 자동 복구 방지)
    final initialized = _prefs.getBool(_initKey) ?? false;
    final raw = _prefs.getStringList(_key);
    if (!initialized && (raw == null || raw.isEmpty)) {
      return _defaults();
    }
    if (raw == null) return const [];
    return raw
        .map((s) =>
            PersonalShiftType.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
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

  /// 기본 근무 유형 목록 (저장하지 않음). OFF는 캘린더가 자동 처리하므로 제외.
  /// 빠른 근무 추가에서 개인 근무 유형이 비어 있을 때의 폴백으로도 사용된다.
  static List<PersonalShiftType> get defaultTypes => [
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
      ];

  /// 기본 근무 유형 — 최초 1회만 생성 후 저장.
  List<PersonalShiftType> _defaults() {
    final defaults = defaultTypes;
    save(defaults);
    return defaults;
  }
}
