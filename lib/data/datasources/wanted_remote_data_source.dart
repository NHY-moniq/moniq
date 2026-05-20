import 'package:moniq/data/models/wanted_request_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WantedRemoteDataSource {
  WantedRemoteDataSource({required SupabaseClient client}) : _client = client;

  final SupabaseClient _client;

  String? get _userId => _client.auth.currentUser?.id;

  /// 수집 요청 생성 (관리자)
  Future<WantedRequestModel> createWantedRequest({
    required String teamId,
    required DateTime periodStart,
    required DateTime periodEnd,
    DateTime? deadline,
    String wantedType = 'day_off',
  }) async {
    if (_userId == null) throw Exception('Not authenticated');

    final row = await _client
        .from('wanted_requests')
        .insert({
          'team_id': teamId,
          'period_start': _dateStr(periodStart),
          'period_end': _dateStr(periodEnd),
          'deadline': deadline?.toIso8601String(),
          'status': 'collecting',
          'wanted_type': wantedType,
          'created_by': _userId,
        })
        .select()
        .single();

    return WantedRequestModel.fromJson(row);
  }

  /// 팀의 수집 요청 목록
  Future<List<WantedRequestModel>> getWantedRequests(String teamId) async {
    final rows = await _client
        .from('wanted_requests')
        .select()
        .eq('team_id', teamId)
        .order('created_at', ascending: false);

    return (rows as List)
        .map((r) => WantedRequestModel.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// 활성 수집 요청 (collecting 상태). wantedType을 지정하면 해당 타입만 조회.
  Future<WantedRequestModel?> getActiveWantedRequest(
    String teamId, {
    String? wantedType,
  }) async {
    var query = _client
        .from('wanted_requests')
        .select()
        .eq('team_id', teamId)
        .eq('status', 'collecting');

    if (wantedType != null) {
      query = query.eq('wanted_type', wantedType);
    }

    final rows = await query.order('created_at', ascending: false).limit(1);

    if ((rows as List).isEmpty) return null;
    return WantedRequestModel.fromJson(rows.first);
  }

  /// 팀의 모든 활성 수집 요청 목록 (타입별)
  Future<List<WantedRequestModel>> getActiveWantedRequests(
    String teamId,
  ) async {
    final rows = await _client
        .from('wanted_requests')
        .select()
        .eq('team_id', teamId)
        .eq('status', 'collecting')
        .order('created_at', ascending: false);

    return (rows as List)
        .map((r) => WantedRequestModel.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// 수집 요청 마감 — update가 실제로 적용됐는지 검증.
  Future<void> closeWantedRequest(String requestId) async {
    final result = await _client
        .from('wanted_requests')
        .update({'status': 'closed'})
        .eq('id', requestId)
        .select();
    if ((result as List).isEmpty) {
      throw Exception('수집 마감 실패: 권한이 없거나 요청을 찾을 수 없습니다');
    }
  }

  /// 여러 수집 요청 일괄 마감.
  Future<void> closeWantedRequests(List<String> requestIds) async {
    if (requestIds.isEmpty) return;
    final result = await _client
        .from('wanted_requests')
        .update({'status': 'closed'})
        .inFilter('id', requestIds)
        .select('id');
    if ((result as List).isEmpty) {
      throw Exception('수집 마감 실패: 권한이 없거나 요청을 찾을 수 없습니다');
    }
  }

  /// 마감된 수집 요청 재개 — status를 'collecting'으로 되돌리고 deadline을 갱신.
  Future<void> reopenWantedRequest(
    String requestId, {
    required DateTime deadline,
  }) async {
    final deadlineEnd = DateTime(
      deadline.year,
      deadline.month,
      deadline.day,
      23,
      59,
      59,
    );
    final result = await _client
        .from('wanted_requests')
        .update({
          'status': 'collecting',
          'deadline': deadlineEnd.toIso8601String(),
        })
        .eq('id', requestId)
        .select();
    if ((result as List).isEmpty) {
      throw Exception('수집 재개 실패: 권한이 없거나 요청을 찾을 수 없습니다');
    }
  }

  /// 여러 마감 수집 요청 일괄 재개.
  Future<void> reopenWantedRequests(
    List<String> requestIds, {
    required DateTime deadline,
  }) async {
    if (requestIds.isEmpty) return;
    final deadlineEnd = DateTime(
      deadline.year,
      deadline.month,
      deadline.day,
      23,
      59,
      59,
    );
    final result = await _client
        .from('wanted_requests')
        .update({
          'status': 'collecting',
          'deadline': deadlineEnd.toIso8601String(),
        })
        .inFilter('id', requestIds)
        .select('id');
    if ((result as List).isEmpty) {
      throw Exception('수집 재개 실패: 권한이 없거나 요청을 찾을 수 없습니다');
    }
  }

  /// 수집 요청이 아직 입력 가능한 상태인지 확인. 마감 또는 상태가 collecting이 아니면 예외.
  Future<void> _ensureCollecting(String wantedRequestId) async {
    final req = await _client
        .from('wanted_requests')
        .select('status, deadline')
        .eq('id', wantedRequestId)
        .maybeSingle();
    if (req == null) throw Exception('수집 요청을 찾을 수 없습니다');

    final status = req['status'] as String?;
    if (status != 'collecting') {
      throw Exception('이미 수집이 완료되어 입력할 수 없습니다');
    }
    final deadlineStr = req['deadline'] as String?;
    if (deadlineStr != null) {
      final deadline = DateTime.parse(deadlineStr);
      if (DateTime.now().isAfter(deadline)) {
        throw Exception('수집 마감일이 지나 입력할 수 없습니다');
      }
    }
  }

  /// 엔트리 입력 (팀원)
  Future<WantedEntryModel> addWantedEntry({
    required String wantedRequestId,
    required String teamId,
    required DateTime wantedDate,
    String? reason,
    int priority = 1,
    String? shiftTypeId,
  }) async {
    if (_userId == null) throw Exception('Not authenticated');
    await _ensureCollecting(wantedRequestId);

    final data = {
      'wanted_request_id': wantedRequestId,
      'team_id': teamId,
      'user_id': _userId,
      'wanted_date': _dateStr(wantedDate),
      'reason': reason,
      'priority': priority,
    };
    if (shiftTypeId != null) data['shift_type_id'] = shiftTypeId;

    final row = await _client
        .from('wanted_entries')
        .insert(data)
        .select()
        .single();

    return WantedEntryModel.fromJson(row);
  }

  /// 내 희망 휴무일 목록
  Future<List<WantedEntryModel>> getMyEntries(String wantedRequestId) async {
    if (_userId == null) throw Exception('Not authenticated');

    final rows = await _client
        .from('wanted_entries')
        .select()
        .eq('wanted_request_id', wantedRequestId)
        .eq('user_id', _userId!)
        .order('wanted_date');

    return (rows as List)
        .map((r) => WantedEntryModel.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// 수집 요청의 모든 엔트리 (관리자 조회, 사용자 이름 포함)
  Future<List<WantedEntryWithUser>> getAllEntries(
    String wantedRequestId,
  ) async {
    final rows = await _client
        .from('wanted_entries')
        .select('*, users!inner(display_name)')
        .eq('wanted_request_id', wantedRequestId)
        .order('wanted_date');

    return (rows as List).map((r) {
      final map = r as Map<String, dynamic>;
      final displayName =
          (map['users'] as Map<String, dynamic>?)?['display_name'] as String? ??
          '알 수 없음';
      return WantedEntryWithUser(
        entry: WantedEntryModel.fromJson(map),
        displayName: displayName,
      );
    }).toList();
  }

  /// 여러 수집 요청의 엔트리 일괄 조회 (스케줄 생성용)
  Future<List<WantedEntryModel>> getEntriesByRequestIds(
    List<String> requestIds,
  ) async {
    if (requestIds.isEmpty) return const [];

    final rows = await _client
        .from('wanted_entries')
        .select()
        .inFilter('wanted_request_id', requestIds)
        .order('wanted_date');

    return (rows as List)
        .map((r) => WantedEntryModel.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// 희망 휴무일 삭제 (수집 진행 중일 때만)
  Future<void> deleteWantedEntry(String entryId) async {
    final entry = await _client
        .from('wanted_entries')
        .select('wanted_request_id')
        .eq('id', entryId)
        .maybeSingle();
    if (entry == null) return; // 이미 삭제됨 — 무시
    final requestId = entry['wanted_request_id'] as String?;
    if (requestId == null) {
      throw Exception('엔트리 데이터가 올바르지 않습니다');
    }
    await _ensureCollecting(requestId);
    await _client.from('wanted_entries').delete().eq('id', entryId);
  }

  /// 특정 기간의 모든 희망 휴무 엔트리 (스케줄 생성 시 사용)
  Future<List<WantedEntryModel>> getEntriesForPeriod({
    required String teamId,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async {
    final rows = await _client
        .from('wanted_entries')
        .select('*, wanted_requests!inner(team_id, period_start, period_end)')
        .eq('team_id', teamId)
        .gte('wanted_date', _dateStr(periodStart))
        .lte('wanted_date', _dateStr(periodEnd));

    return (rows as List)
        .map((r) => WantedEntryModel.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// 팀 멤버의 FCM 토큰 목록 조회 (푸시 알림용)
  Future<List<Map<String, dynamic>>> getTeamMemberTokens(String teamId) async {
    final rows = await _client
        .from('team_members')
        .select('user_id, users!inner(fcm_token)')
        .eq('team_id', teamId)
        .eq('is_deleted', false);

    return (rows as List).cast<Map<String, dynamic>>();
  }

  String _dateStr(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}
