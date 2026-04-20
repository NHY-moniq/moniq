import 'package:moniq/data/models/request_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RequestRemoteDataSource {
  RequestRemoteDataSource({required SupabaseClient client}) : _client = client;

  final SupabaseClient _client;

  String? get _userId => _client.auth.currentUser?.id;

  /// 변경 요청 생성
  Future<RequestModel> createRequest({
    required String teamId,
    required String changeType,
    String? sourceShiftId,
    DateTime? requestedDate,
    String? requestedShiftTypeId,
    String? targetUserId,
    String? reason,
    String? note,
  }) async {
    if (_userId == null) throw Exception('Not authenticated');

    final row = await _client
        .from('requests')
        .insert({
          'team_id': teamId,
          'requester_user_id': _userId,
          'change_type': changeType,
          'source_shift_id': sourceShiftId,
          'requested_date': requestedDate != null ? _dateStr(requestedDate) : null,
          'requested_shift_type_id': requestedShiftTypeId,
          'target_user_id': targetUserId,
          'reason': reason,
          'note': note,
          'status': 'pending',
        })
        .select()
        .single();

    return RequestModel.fromJson(row);
  }

  /// 승인된 요청을 shifts에 적용 (apply_request RPC).
  /// 호출 전에 status가 'approved'여야 함.
  Future<void> applyRequest(String requestId) async {
    await _client.rpc('apply_request', params: {'p_request_id': requestId});
  }

  /// 팀의 요청 목록
  Future<List<RequestModel>> getTeamRequests(String teamId) async {
    final rows = await _client
        .from('requests')
        .select()
        .eq('team_id', teamId)
        .order('created_at', ascending: false);

    return (rows as List)
        .map((r) => RequestModel.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// 내가 신청자이거나 target_user로 포함된 요청 목록.
  /// (본인이 관여된 모든 요청 — 내가 교환 대상자로 지정된 1:1/1:N swap 포함)
  Future<List<RequestModel>> getMyRequests(String teamId) async {
    if (_userId == null) throw Exception('Not authenticated');

    final rows = await _client
        .from('requests')
        .select()
        .eq('team_id', teamId)
        .or('requester_user_id.eq.$_userId,target_user_id.eq.$_userId')
        .order('created_at', ascending: false);

    return (rows as List)
        .map((r) => RequestModel.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// 요청 상태 변경 (승인/거절)
  Future<void> updateRequestStatus(String requestId, String status) async {
    if (_userId == null) throw Exception('Not authenticated');

    await _client.from('requests').update({
      'status': status,
      'reviewed_by': _userId,
      'reviewed_at': DateTime.now().toIso8601String(),
    }).eq('id', requestId);
  }

  /// 요청 취소
  Future<void> cancelRequest(String requestId) async {
    await _client
        .from('requests')
        .update({'status': 'cancelled'})
        .eq('id', requestId);
  }

  /// 요청 삭제 (보통 취소된 건)
  Future<void> deleteRequest(String requestId) async {
    await _client.from('requests').delete().eq('id', requestId);
  }

  /// 여러 요청 일괄 삭제
  Future<void> deleteRequests(List<String> requestIds) async {
    if (requestIds.isEmpty) return;
    await _client.from('requests').delete().inFilter('id', requestIds);
  }

  String _dateStr(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}
