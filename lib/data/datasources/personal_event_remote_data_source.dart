import 'package:supabase_flutter/supabase_flutter.dart';

import 'personal_event_local_data_source.dart';

/// Supabase personal_events 테이블 CRUD.
/// 로컬 캐시(PersonalEventLocalDataSource)와 함께 사용된다.
class PersonalEventRemoteDataSource {
  PersonalEventRemoteDataSource({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String? get _userId => _client.auth.currentUser?.id;

  String _dateStr(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  /// 현재 사용자의 모든 이벤트를 불러온다.
  Future<List<PersonalEvent>> fetchAll() async {
    if (_userId == null) return [];
    final rows = await _client
        .from('personal_events')
        .select()
        .eq('user_id', _userId!)
        .order('event_date');
    return (rows as List).map((r) => _fromRow(r as Map<String, dynamic>)).toList();
  }

  /// insert 후 발급된 id를 포함한 이벤트 반환.
  Future<PersonalEvent> insert(PersonalEvent event) async {
    if (_userId == null) throw Exception('Not authenticated');
    final row = await _client
        .from('personal_events')
        .insert({
          'user_id': _userId,
          'event_date': _dateStr(event.date),
          'title': event.title,
          'start_time': event.startTime,
          'end_time': event.endTime,
          'description': event.description,
          'color': event.color,
          'recurrence': event.recurrence,
        })
        .select()
        .single();
    return _fromRow(row);
  }

  Future<void> update(PersonalEvent event) async {
    if (event.id == null) return;
    await _client.from('personal_events').update({
      'event_date': _dateStr(event.date),
      'title': event.title,
      'start_time': event.startTime,
      'end_time': event.endTime,
      'description': event.description,
      'color': event.color,
      'recurrence': event.recurrence,
    }).eq('id', event.id!);
  }

  Future<void> delete(String id) async {
    await _client.from('personal_events').delete().eq('id', id);
  }

  PersonalEvent _fromRow(Map<String, dynamic> row) {
    return PersonalEvent(
      id: row['id'] as String?,
      date: DateTime.parse(row['event_date'] as String),
      title: row['title'] as String,
      startTime: row['start_time'] as String?,
      endTime: row['end_time'] as String?,
      description: row['description'] as String?,
      color: row['color'] as String?,
      recurrence: row['recurrence'] as String?,
      createdAt: row['created_at'] != null
          ? DateTime.parse(row['created_at'] as String)
          : null,
    );
  }
}
