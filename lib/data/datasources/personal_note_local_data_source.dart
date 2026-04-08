import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class PersonalNote {
  PersonalNote({
    required this.date,
    required this.content,
    this.createdAt,
  });

  final DateTime date;
  final String content;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() => {
        'date': '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        'content': content,
        'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
      };

  factory PersonalNote.fromJson(Map<String, dynamic> json) {
    final parts = (json['date'] as String).split('-');
    return PersonalNote(
      date: DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2])),
      content: json['content'] as String,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
    );
  }
}

class PersonalNoteLocalDataSource {
  PersonalNoteLocalDataSource({
    required SharedPreferences prefs,
    required String userId,
  })  : _prefs = prefs,
        _userId = userId;

  final SharedPreferences _prefs;
  final String _userId;

  static const _keyPrefix = 'personal_notes';

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  /// 특정 날짜의 메모 목록
  List<PersonalNote> getNotes(DateTime date) {
    final key = '$_keyPrefix:$_userId:${_dateKey(date)}';
    final raw = _prefs.getStringList(key);
    if (raw == null || raw.isEmpty) return [];
    return raw
        .map((s) => PersonalNote.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
  }

  /// 월간 메모가 있는 날짜 목록
  Map<DateTime, List<PersonalNote>> getMonthlyNotes(DateTime month) {
    final result = <DateTime, List<PersonalNote>>{};
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;

    for (int d = 1; d <= daysInMonth; d++) {
      final date = DateTime(month.year, month.month, d);
      final notes = getNotes(date);
      if (notes.isNotEmpty) {
        result[date] = notes;
      }
    }
    return result;
  }

  /// 메모 추가
  Future<void> addNote(DateTime date, String content) async {
    final key = '$_keyPrefix:$_userId:${_dateKey(date)}';
    final existing = _prefs.getStringList(key) ?? [];
    final note = PersonalNote(
      date: DateTime(date.year, date.month, date.day),
      content: content,
      createdAt: DateTime.now(),
    );
    existing.add(jsonEncode(note.toJson()));
    await _prefs.setStringList(key, existing);
  }

  /// 메모 삭제 (인덱스)
  Future<void> removeNote(DateTime date, int index) async {
    final key = '$_keyPrefix:$_userId:${_dateKey(date)}';
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

  /// 메모 수정
  Future<void> updateNote(DateTime date, int index, String content) async {
    final key = '$_keyPrefix:$_userId:${_dateKey(date)}';
    final existing = _prefs.getStringList(key) ?? [];
    if (index >= 0 && index < existing.length) {
      final note = PersonalNote(
        date: DateTime(date.year, date.month, date.day),
        content: content,
        createdAt: DateTime.now(),
      );
      existing[index] = jsonEncode(note.toJson());
      await _prefs.setStringList(key, existing);
    }
  }
}
