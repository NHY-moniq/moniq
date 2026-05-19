import 'package:supabase_flutter/supabase_flutter.dart';

import 'personal_event_local_data_source.dart';

/// 팀 캘린더에서 import한 개인 이벤트를 구분하기 위한 description prefix.
/// 사용자가 직접 추가한 이벤트와 구분하여, 재import 시 안전하게 일괄 삭제할 수
/// 있도록 마커 역할만 한다 (사용자에 의해 직접 입력되는 prefix가 아님).
const kPersonalTeamImportMarker = '__moniq_team_import__';

/// 프라이빗(개인) 팀의 일정/메모 마커.
/// description이 `${kPrivateTeamEventMarker}<teamId>` 로 시작하면 해당 팀에만
/// 노출되고 개인 캘린더에서는 숨겨진다. "개인 캘린더로 내보내기" 동작은
/// 마커를 제거한 사본을 새로 추가한다.
const kPrivateTeamEventMarker = '__moniq_private_team_event:';
const kPrivateTeamNoteMarker = '__moniq_private_team_note:';

/// description에서 해당 [marker] 뒤에 붙은 teamId를 추출. null 이면 마커 없음.
String? teamIdFromMarker(String? description, String marker) {
  if (description == null || !description.startsWith(marker)) return null;
  final rest = description.substring(marker.length);
  // teamId는 마커 직후부터 다음 줄/구분자 전까지.
  final newlineIdx = rest.indexOf('\n');
  return newlineIdx >= 0 ? rest.substring(0, newlineIdx) : rest;
}

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

  /// 다건 insert. 팀 import 등 일괄 등록 용도.
  /// description에 [kPersonalTeamImportMarker] prefix를 포함해 두면 재import 시
  /// [deleteAllTeamImports]로 안전하게 일괄 삭제할 수 있다.
  Future<List<PersonalEvent>> insertMany(List<PersonalEvent> events) async {
    if (_userId == null) throw Exception('Not authenticated');
    if (events.isEmpty) return const [];
    final payload = events
        .map((e) => {
              'user_id': _userId,
              'event_date': _dateStr(e.date),
              'title': e.title,
              'start_time': e.startTime,
              'end_time': e.endTime,
              'description': e.description,
              'color': e.color,
              'recurrence': e.recurrence,
            })
        .toList();
    final rows = await _client
        .from('personal_events')
        .insert(payload)
        .select();
    return (rows as List)
        .map((r) => _fromRow(r as Map<String, dynamic>))
        .toList();
  }

  /// 현재 사용자의 팀 캘린더 import 이벤트만 일괄 삭제.
  /// description이 [kPersonalTeamImportMarker]로 시작하는 row를 대상으로 함.
  /// 반환값: 삭제된 row 개수.
  Future<int> deleteAllTeamImports() async {
    if (_userId == null) return 0;
    final rows = await _client
        .from('personal_events')
        .delete()
        .eq('user_id', _userId!)
        .like('description', '$kPersonalTeamImportMarker%')
        .select();
    return (rows as List).length;
  }

  /// 현재 사용자의 특정 연/월에 해당하는 personal_events를 일괄 삭제.
  /// 반환값: 삭제된 row 개수(추정용 — DB 응답 형태에 의존).
  Future<int> deleteByMonth({
    required int year,
    required int month,
  }) async {
    if (_userId == null) return 0;
    final start = '$year-${month.toString().padLeft(2, '0')}-01';
    final nextYear = month == 12 ? year + 1 : year;
    final nextMonth = month == 12 ? 1 : month + 1;
    final end =
        '$nextYear-${nextMonth.toString().padLeft(2, '0')}-01';
    final rows = await _client
        .from('personal_events')
        .delete()
        .eq('user_id', _userId!)
        .gte('event_date', start)
        .lt('event_date', end)
        .select();
    return (rows as List).length;
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
