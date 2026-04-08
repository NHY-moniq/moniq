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

class PersonalShiftTypeLocalDataSource {
  PersonalShiftTypeLocalDataSource({
    required SharedPreferences prefs,
    required String userId,
  })  : _prefs = prefs,
        _key = 'personal_shift_types:$userId';

  final SharedPreferences _prefs;
  final String _key;

  List<PersonalShiftType> getAll() {
    final raw = _prefs.getStringList(_key);
    if (raw == null || raw.isEmpty) return _defaults();
    return raw
        .map((s) =>
            PersonalShiftType.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
  }

  Future<void> save(List<PersonalShiftType> types) async {
    final raw = types.map((t) => jsonEncode(t.toJson())).toList();
    await _prefs.setStringList(_key, raw);
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

  /// 기본 근무 유형
  List<PersonalShiftType> _defaults() {
    final defaults = [
      PersonalShiftType(
        id: 'day', name: '데이', code: 'D',
        startTime: '07:00', endTime: '15:00', color: '#F0C040',
      ),
      PersonalShiftType(
        id: 'evening', name: '이브닝', code: 'E',
        startTime: '15:00', endTime: '23:00', color: '#E8923A',
      ),
      PersonalShiftType(
        id: 'night', name: '나이트', code: 'N',
        startTime: '23:00', endTime: '07:00', color: '#5A8BB5',
      ),
      PersonalShiftType(
        id: 'off', name: '오프', code: 'OFF',
        color: '#A0AEC0',
      ),
    ];
    // 저장해둠
    save(defaults);
    return defaults;
  }
}
