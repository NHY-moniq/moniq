import 'package:supabase_flutter/supabase_flutter.dart';

import 'personal_event_local_data_source.dart';

/// 팀 캘린더에서 import한 개인 이벤트를 구분하기 위한 description prefix.
/// 사용자가 직접 추가한 이벤트와 구분하여, 재import 시 안전하게 일괄 삭제할 수
/// 있도록 마커 역할만 한다 (사용자에 의해 직접 입력되는 prefix가 아님).
const kPersonalTeamImportMarker = '__moniq_team_import__';

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

  /// insert payload. `end_date`는 값이 있을 때만 포함한다 —
  /// end_date 마이그레이션 전 DB에서도 당일 일정은 정상 저장되도록 하기 위함.
  /// (PostgREST 다건 insert는 모든 row의 key가 같아야 하므로 [withEndDate]로 통일)
  Map<String, dynamic> _insertPayload(
    PersonalEvent event, {
    required bool withEndDate,
  }) => {
        'user_id': _userId,
        'event_date': _dateStr(event.date),
        if (withEndDate)
          'end_date': event.endDate != null ? _dateStr(event.endDate!) : null,
        'title': event.title,
        'start_time': event.startTime,
        'end_time': event.endTime,
        'description': event.description,
        'color': event.color,
        'recurrence': event.recurrence,
      };

  /// insert 후 발급된 id를 포함한 이벤트 반환.
  Future<PersonalEvent> insert(PersonalEvent event) async {
    if (_userId == null) throw Exception('Not authenticated');
    final row = await _client
        .from('personal_events')
        .insert(_insertPayload(event, withEndDate: event.endDate != null))
        .select()
        .single();
    return _fromRow(row);
  }

  Future<void> update(PersonalEvent event) async {
    if (event.id == null) return;
    await _client.from('personal_events').update({
      'event_date': _dateStr(event.date),
      'end_date': event.endDate != null ? _dateStr(event.endDate!) : null,
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
    // 기간이 있는 일정이 하나라도 있으면 전체 row에 end_date를 포함(key 통일).
    final withEndDate = events.any((e) => e.endDate != null);
    final payload = events
        .map((e) => _insertPayload(e, withEndDate: withEndDate))
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
      endDate: row['end_date'] != null
          ? DateTime.parse(row['end_date'] as String)
          : null,
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
