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

  String _dateStr(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}
