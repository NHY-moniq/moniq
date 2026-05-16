import 'package:moniq/data/models/schedule_model.dart';
import 'package:moniq/data/models/shift_model.dart';
import 'package:moniq/data/models/shift_rule_model.dart';
import 'package:moniq/data/models/shift_type_model.dart';
import 'package:moniq/data/models/user_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ShiftRemoteDataSource {
  ShiftRemoteDataSource({required SupabaseClient client}) : _client = client;

  final SupabaseClient _client;
  static const Set<String> _protectedDefaultCodes = {'D', 'E', 'N', 'ED'};

  String? get _userId => _client.auth.currentUser?.id;

  Future<List<ShiftTypeModel>> getShiftTypes(String teamId) async {
    final rows = await _client
        .from('shift_types')
        .select()
        .eq('team_id', teamId)
        .eq('is_active', true)
        .order('display_order');

    return (rows as List)
        .map((r) => ShiftTypeModel.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// 내 모든 근무 (전체 팀, 기간 필터) — 홈 캘린더용
  Future<List<ShiftModel>> getMyShifts({
    required DateTime start,
    required DateTime end,
  }) async {
    if (_userId == null) throw Exception('Not authenticated');

    final startStr = _dateStr(start);
    final endStr = _dateStr(end);

    final rows = await _client
        .from('shifts')
        .select()
        .eq('user_id', _userId!)
        .gte('shift_date', startStr)
        .lte('shift_date', endStr)
        .order('shift_date');

    final shifts = (rows as List)
        .map((r) => ShiftModel.fromJson(r as Map<String, dynamic>))
        .toList();

    if (shifts.isEmpty) return const [];

    final scheduleIds = shifts.map((s) => s.scheduleId).toSet().toList();
    final activeScheduleIds = await _getLatestPublishedScheduleIds(
      scheduleIds: scheduleIds,
    );

    return shifts
        .where((s) => activeScheduleIds.contains(s.scheduleId))
        .toList();
  }

  /// 팀 전체 근무 — 팀 캘린더용.
  ///
  /// 발행 정책: 한 날짜 D는 D를 기간에 포함하는 published schedule 중
  /// version_no가 가장 큰 schedule이 "소유"한다. 해당 schedule의 shifts만
  /// 표시하고, 더 낮은 버전 schedule의 shifts는 그 날짜에 대해 무시한다.
  /// 이렇게 해야 새 버전이 일부 사용자를 OFF로 바꾼 경우, 이전 버전의
  /// 시프트가 누락된 슬롯을 채우며 잘못된 데이터가 노출되는 문제를 막을
  /// 수 있다.
  Future<List<ShiftModel>> getTeamShifts({
    required String teamId,
    required DateTime start,
    required DateTime end,
  }) async {
    final startStr = _dateStr(start);
    final endStr = _dateStr(end);

    // shifts와 published schedules 메타를 병렬 조회
    final shiftsFuture = _client
        .from('shifts')
        .select()
        .eq('team_id', teamId)
        .gte('shift_date', startStr)
        .lte('shift_date', endStr)
        .order('shift_date');

    // 해당 기간과 겹치는 모든 published schedule 조회
    final schedulesFuture = _client
        .from('schedules')
        .select('id, period_start, period_end, version_no')
        .eq('team_id', teamId)
        .eq('status', 'published')
        .lte('period_start', endStr)
        .gte('period_end', startStr);

    final results = await Future.wait([shiftsFuture, schedulesFuture]);
    final shifts = (results[0] as List)
        .map((r) => ShiftModel.fromJson(r as Map<String, dynamic>))
        .toList();
    if (shifts.isEmpty) return const [];

    final schedules = results[1] as List;
    if (schedules.isEmpty) return const [];

    // 날짜별 owner schedule id 계산: 해당 날짜를 포함하는 published schedule 중
    // 최대 version_no를 가진 schedule.
    final dateOwnerScheduleId = <String, String>{};
    for (final s in shifts) {
      final dateStr = _dateStr(s.shiftDate);
      if (dateOwnerScheduleId.containsKey(dateStr)) continue;
      String? winnerId;
      int winnerVersion = -1;
      for (final raw in schedules) {
        final row = raw as Map<String, dynamic>;
        final pStart = row['period_start']?.toString() ?? '';
        final pEnd = row['period_end']?.toString() ?? '';
        if (dateStr.compareTo(pStart) < 0 || dateStr.compareTo(pEnd) > 0) {
          continue;
        }
        final version = (row['version_no'] as num?)?.toInt() ?? 0;
        if (version > winnerVersion) {
          winnerVersion = version;
          winnerId = row['id'] as String;
        }
      }
      if (winnerId != null) {
        dateOwnerScheduleId[dateStr] = winnerId;
      }
    }

    // owner schedule의 shifts만 노출
    return shifts.where((s) {
      final owner = dateOwnerScheduleId[_dateStr(s.shiftDate)];
      return owner != null && owner == s.scheduleId;
    }).toList();
  }

  /// 특정 날짜 + 팀 + shift_type 에 배정된 팀원(본인 제외) 목록
  Future<List<UserModel>> getCoworkers({
    required String teamId,
    required DateTime date,
    required String shiftTypeId,
  }) async {
    if (_userId == null) return [];
    final dateStr = _dateStr(date);

    final shiftRows = await _client
        .from('shifts')
        .select('user_id')
        .eq('team_id', teamId)
        .eq('shift_date', dateStr)
        .eq('shift_type_id', shiftTypeId)
        .neq('user_id', _userId!);

    final userIds = (shiftRows as List)
        .map((r) => r['user_id'] as String)
        .toSet()
        .toList();

    if (userIds.isEmpty) return [];

    final userRows = await _client
        .from('users')
        .select()
        .inFilter('id', userIds)
        .eq('is_deleted', false);

    return (userRows as List)
        .map((r) => UserModel.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// 팀 멤버 + 유저 정보 — 로스터용
  Future<List<UserModel>> getTeamUsers(String teamId) async {
    final memberRows = await _client
        .from('team_members')
        .select('user_id')
        .eq('team_id', teamId)
        .eq('is_deleted', false);

    final userIds = (memberRows as List)
        .map((r) => r['user_id'] as String)
        .toList();

    if (userIds.isEmpty) return [];

    final userRows = await _client
        .from('users')
        .select()
        .inFilter('id', userIds)
        .eq('is_deleted', false);

    return (userRows as List)
        .map((r) => UserModel.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// 팀의 게시된 스케줄 목록
  Future<List<ScheduleModel>> getPublishedSchedules({
    required String teamId,
    required DateTime start,
    required DateTime end,
  }) async {
    final startStr = _dateStr(start);
    final endStr = _dateStr(end);

    final rows = await _client
        .from('schedules')
        .select()
        .eq('team_id', teamId)
        .eq('status', 'published')
        .lte('period_start', endStr)
        .gte('period_end', startStr)
        .order('version_no', ascending: false);

    return (rows as List)
        .map((r) => ScheduleModel.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// 주어진 schedule id들 중, published 상태이면서
  /// (team_id, period_start, period_end) 기준 최신 version만 반환.
  Future<Set<String>> _getLatestPublishedScheduleIds({
    required List<String> scheduleIds,
    String? teamId,
  }) async {
    if (scheduleIds.isEmpty) return const <String>{};

    var query = _client
        .from('schedules')
        .select('id, team_id, period_start, period_end, version_no')
        .inFilter('id', scheduleIds)
        .eq('status', 'published');

    if (teamId != null) {
      query = query.eq('team_id', teamId);
    }

    final rows = await query.order('version_no', ascending: false);

    final latestByPeriod = <String, String>{};
    for (final row in (rows as List)) {
      final map = row as Map<String, dynamic>;
      final id = map['id'] as String;
      final tId = map['team_id'] as String? ?? '';
      final pStart = map['period_start']?.toString() ?? '';
      final pEnd = map['period_end']?.toString() ?? '';
      final key = '$tId|$pStart|$pEnd';
      latestByPeriod.putIfAbsent(key, () => id);
    }

    return latestByPeriod.values.toSet();
  }

  // ── 근무 유형 CRUD ──

  /// 모든 근무 유형 (비활성 포함) — 관리 화면용
  Future<List<ShiftTypeModel>> getAllShiftTypes(String teamId) async {
    final rows = await _client
        .from('shift_types')
        .select()
        .eq('team_id', teamId)
        .order('display_order');

    return (rows as List)
        .map((r) => ShiftTypeModel.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<ShiftTypeModel> createShiftType(
    String teamId, {
    required String name,
    required String code,
    String? startTime,
    String? endTime,
    required String color,
    required int displayOrder,
  }) async {
    final row = await _client
        .from('shift_types')
        .insert({
          'team_id': teamId,
          'name': name,
          'code': code,
          'start_time': startTime,
          'end_time': endTime,
          'color': color,
          'display_order': displayOrder,
        })
        .select()
        .single();

    return ShiftTypeModel.fromJson(row);
  }

  Future<void> updateShiftType(
    String id, {
    String? name,
    String? code,
    String? startTime,
    String? endTime,
    String? color,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (code != null) updates['code'] = code;
    if (startTime != null) updates['start_time'] = startTime;
    if (endTime != null) updates['end_time'] = endTime;
    if (color != null) updates['color'] = color;
    if (updates.isEmpty) return;

    await _client.from('shift_types').update(updates).eq('id', id);
  }

  Future<void> toggleShiftTypeActive(String id, bool isActive) async {
    await _client
        .from('shift_types')
        .update({'is_active': isActive})
        .eq('id', id);
  }

  /// 개별 근무(shift) 수정 — 관리자 전용 (RLS에서 차단됨)
  Future<void> updateShift(
    String shiftId, {
    String? shiftTypeId,
    String? userId,
    String? note,
  }) async {
    final updates = <String, dynamic>{};
    if (shiftTypeId != null) updates['shift_type_id'] = shiftTypeId;
    if (userId != null) updates['user_id'] = userId;
    if (note != null) updates['note'] = note;
    if (updates.isEmpty) return;

    await _client.from('shifts').update(updates).eq('id', shiftId);
  }

  /// 개별 근무(shift) 삭제 — 관리자 전용
  Future<void> deleteShift(String shiftId) async {
    await _client.from('shifts').delete().eq('id', shiftId);
  }

  /// shifts 일괄 삽입 (단건도 가능). RLS에서 본인 user_id만 INSERT 허용.
  Future<void> insertShifts(List<Map<String, dynamic>> shifts) async {
    if (shifts.isEmpty) return;
    await _client.from('shifts').insert(shifts);
  }

  /// 근무 유형 삭제. 해당 유형으로 배정된 근무가 있으면 삭제 불가 예외.
  Future<void> deleteShiftType(String id) async {
    final shiftType = await _client
        .from('shift_types')
        .select('code')
        .eq('id', id)
        .maybeSingle();

    final code = (shiftType?['code'] as String?)?.trim().toUpperCase();
    if (code != null && _protectedDefaultCodes.contains(code)) {
      throw Exception('데이/이브닝/나이트/교육 기본 근무 유형은 삭제할 수 없습니다.');
    }

    final referenced = await _client
        .from('shifts')
        .select('id')
        .eq('shift_type_id', id)
        .limit(1);
    if ((referenced as List).isNotEmpty) {
      throw Exception('이 근무 유형으로 배정된 근무가 있어 삭제할 수 없습니다. 비활성화만 가능합니다.');
    }
    await _client.from('shift_types').delete().eq('id', id);
  }

  Future<void> reorderShiftTypes(String teamId, List<String> orderedIds) async {
    for (var i = 0; i < orderedIds.length; i++) {
      await _client
          .from('shift_types')
          .update({'display_order': i})
          .eq('id', orderedIds[i]);
    }
  }

  // ── 규칙 CRUD ──

  Future<List<ShiftRuleModel>> getShiftRules(String teamId) async {
    final rows = await _client
        .from('shift_rules')
        .select()
        .eq('team_id', teamId)
        .order('rule_type');

    return (rows as List)
        .map((r) => ShiftRuleModel.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> upsertShiftRule(
    String teamId, {
    required String ruleType,
    required Map<String, dynamic> ruleValue,
  }) async {
    await _client.from('shift_rules').upsert({
      'team_id': teamId,
      'rule_type': ruleType,
      'rule_value': ruleValue,
    }, onConflict: 'team_id,rule_type');
  }

  String _dateStr(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}
