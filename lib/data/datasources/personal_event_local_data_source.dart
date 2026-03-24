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
  });

  final DateTime date;
  final String title;
  final String? startTime; // "HH:mm"
  final String? endTime;   // "HH:mm"
  final String? description;
  final String? color;     // hex color
  final DateTime? createdAt;

  Map<String, dynamic> toJson() => {
        'date': _dateStr(date),
        'title': title,
        'startTime': startTime,
        'endTime': endTime,
        'description': description,
        'color': color,
        'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
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
    final key = '$_keyPrefix:${_dateKey(event.date)}';
    final existing = _prefs.getStringList(key) ?? [];
    existing.add(jsonEncode(event.toJson()));
    await _prefs.setStringList(key, existing);
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

  Future<void> updateEvent(DateTime date, int index, PersonalEvent event) async {
    final key = '$_keyPrefix:${_dateKey(date)}';
    final existing = _prefs.getStringList(key) ?? [];
    if (index >= 0 && index < existing.length) {
      existing[index] = jsonEncode(event.toJson());
      await _prefs.setStringList(key, existing);
    }
  }
}
