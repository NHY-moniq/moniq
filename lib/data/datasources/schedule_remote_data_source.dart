import 'package:moniq/data/models/schedule_model.dart';
import 'package:moniq/data/models/shift_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ScheduleRemoteDataSource {
  ScheduleRemoteDataSource({required SupabaseClient client}) : _client = client;

  final SupabaseClient _client;

  String? get _userId => _client.auth.currentUser?.id;

  /// 스케줄 생성 (draft)
  Future<ScheduleModel> createSchedule({
    required String teamId,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async {
    if (_userId == null) throw Exception('Not authenticated');

    // 기존 최신 버전 확인
    final existing = await _client
        .from('schedules')
        .select('version_no, id')
        .eq('team_id', teamId)
        .order('version_no', ascending: false)
        .limit(1);

    final latestVersion =
        (existing as List).isNotEmpty ? existing.first['version_no'] as int : 0;
    final previousId =
        (existing).isNotEmpty ? existing.first['id'] as String : null;

    final row = await _client
        .from('schedules')
        .insert({
          'team_id': teamId,
          'period_start': _dateStr(periodStart),
          'period_end': _dateStr(periodEnd),
          'version_no': latestVersion + 1,
          'previous_version_id': previousId,
          'status': 'draft',
          'created_by': _userId,
        })
        .select()
        .single();

    return ScheduleModel.fromJson(row);
  }

  /// 시프트 일괄 삽입
  Future<void> insertShifts(List<Map<String, dynamic>> shifts) async {
    if (shifts.isEmpty) return;
    await _client.from('shifts').insert(shifts);
  }

  /// 스케줄 발행
  Future<void> publishSchedule(String scheduleId) async {
    await _client
        .from('schedules')
        .update({'status': 'published'})
        .eq('id', scheduleId);
  }

  /// 스케줄 삭제 (draft만)
  Future<void> deleteSchedule(String scheduleId) async {
    await _client.from('shifts').delete().eq('schedule_id', scheduleId);
    await _client.from('schedules').delete().eq('id', scheduleId);
  }

  /// 특정 스케줄의 시프트 조회
  Future<List<ShiftModel>> getShiftsBySchedule(String scheduleId) async {
    final rows = await _client
        .from('shifts')
        .select()
        .eq('schedule_id', scheduleId)
        .order('shift_date')
        .order('user_id');

    return (rows as List)
        .map((r) => ShiftModel.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// 팀의 특정 날짜 범위(양 끝 포함) 시프트 조회 — 이전 달 마지막 주 시드 등에 사용.
  Future<List<ShiftModel>> getTeamShiftsInRange({
    required String teamId,
    required DateTime start,
    required DateTime end,
  }) async {
    String fmt(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final rows = await _client
        .from('shifts')
        .select()
        .eq('team_id', teamId)
        .gte('shift_date', fmt(start))
        .lte('shift_date', fmt(end))
        .order('shift_date');

    return (rows as List)
        .map((r) => ShiftModel.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// 팀의 스케줄 목록
  Future<List<ScheduleModel>> getSchedules(String teamId) async {
    final rows = await _client
        .from('schedules')
        .select()
        .eq('team_id', teamId)
        .order('version_no', ascending: false);

    return (rows as List)
        .map((r) => ScheduleModel.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// 특정 팀의 연월 기간에 해당하는 스케줄 + shifts 전체 삭제
  Future<int> deleteSchedulesByMonth({
    required String teamId,
    required int year,
    required int month,
  }) async {
    final monthStart = '$year-${month.toString().padLeft(2, '0')}-01';
    final nextMonth = month == 12 ? 1 : month + 1;
    final nextYear = month == 12 ? year + 1 : year;
    final monthEnd = '$nextYear-${nextMonth.toString().padLeft(2, '0')}-01';

    // 해당 기간의 shifts 먼저 삭제
    await _client
        .from('shifts')
        .delete()
        .eq('team_id', teamId)
        .gte('shift_date', monthStart)
        .lt('shift_date', monthEnd);

    // 해당 기간의 schedules 조회
    final schedules = await _client
        .from('schedules')
        .select('id')
        .eq('team_id', teamId)
        .gte('period_start', monthStart)
        .lt('period_start', monthEnd);

    int count = (schedules as List).length;
    final scheduleIds = (schedules).map((s) => s['id'] as String).toList();

    if (scheduleIds.isNotEmpty) {
      // 다른 스케줄의 previous_version_id 참조 해제
      await _client
          .from('schedules')
          .update({'previous_version_id': null})
          .inFilter('previous_version_id', scheduleIds);

      // 스케줄 삭제
      for (final id in scheduleIds) {
        await _client.from('schedules').delete().eq('id', id);
      }
    }

    return count;
  }

  String _dateStr(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}
