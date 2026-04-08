import 'package:moniq/data/models/wanted_request_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WantedRemoteDataSource {
  WantedRemoteDataSource({required SupabaseClient client}) : _client = client;

  final SupabaseClient _client;

  String? get _userId => _client.auth.currentUser?.id;

  /// 희망 휴무 수집 요청 생성 (관리자)
  Future<WantedRequestModel> createWantedRequest({
    required String teamId,
    required DateTime periodStart,
    required DateTime periodEnd,
    DateTime? deadline,
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

  /// 활성 수집 요청 (collecting 상태)
  Future<WantedRequestModel?> getActiveWantedRequest(String teamId) async {
    final rows = await _client
        .from('wanted_requests')
        .select()
        .eq('team_id', teamId)
        .eq('status', 'collecting')
        .order('created_at', ascending: false)
        .limit(1);

    if ((rows as List).isEmpty) return null;
    return WantedRequestModel.fromJson(rows.first);
  }

  /// 수집 요청 마감
  Future<void> closeWantedRequest(String requestId) async {
    await _client
        .from('wanted_requests')
        .update({'status': 'closed'})
        .eq('id', requestId);
  }

  /// 수집 요청이 아직 입력 가능한 상태인지 확인. 마감 또는 상태가 collecting이 아니면 예외.
  Future<void> _ensureCollecting(String wantedRequestId) async {
    final req = await _client
        .from('wanted_requests')
        .select('status, deadline')
        .eq('id', wantedRequestId)
        .single();

    final status = req['status'] as String?;
    if (status != 'collecting') {
      throw Exception('희망 휴무 수집이 마감되었습니다');
    }
    final deadlineStr = req['deadline'] as String?;
    if (deadlineStr != null) {
      final deadline = DateTime.parse(deadlineStr);
      if (DateTime.now().isAfter(deadline)) {
        throw Exception('희망 휴무 수집 마감일이 지났습니다');
      }
    }
  }

  /// 희망 휴무일 입력 (팀원)
  Future<WantedEntryModel> addWantedEntry({
    required String wantedRequestId,
    required String teamId,
    required DateTime wantedDate,
    String? reason,
    int priority = 1,
  }) async {
    if (_userId == null) throw Exception('Not authenticated');
    await _ensureCollecting(wantedRequestId);

    final row = await _client
        .from('wanted_entries')
        .insert({
          'wanted_request_id': wantedRequestId,
          'team_id': teamId,
          'user_id': _userId,
          'wanted_date': _dateStr(wantedDate),
          'reason': reason,
          'priority': priority,
        })
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
  Future<List<WantedEntryWithUser>> getAllEntries(String wantedRequestId) async {
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

  /// 희망 휴무일 삭제 (수집 진행 중일 때만)
  Future<void> deleteWantedEntry(String entryId) async {
    final entry = await _client
        .from('wanted_entries')
        .select('wanted_request_id')
        .eq('id', entryId)
        .single();
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
  Future<List<Map<String, dynamic>>> getTeamMemberTokens(
      String teamId) async {
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
