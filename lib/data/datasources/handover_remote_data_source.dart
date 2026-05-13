import 'package:moniq/data/models/handover_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HandoverRemoteDataSource {
  HandoverRemoteDataSource({required SupabaseClient client}) : _client = client;

  final SupabaseClient _client;

  String? get _userId => _client.auth.currentUser?.id;

  String _dateStr(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  /// 특정 팀의 특정 날짜 인계 메모 (작성자·시프트 메타 포함, 시간 오름차순)
  Future<List<HandoverWithMeta>> getTeamDayHandovers({
    required String teamId,
    required DateTime date,
  }) async {
    if (_userId == null) return [];
    final rows = await _client
        .from('shift_handovers')
        .select(
          'id, team_id, shift_type_id, shift_date, body, created_by, '
          'created_at, updated_at, is_deleted, '
          'users:created_by(display_name, avatar_url), '
          'shift_type:shift_type_id(name, color)',
        )
        .eq('team_id', teamId)
        .eq('shift_date', _dateStr(date))
        .order('created_at', ascending: true);

    return (rows as List).map((r) {
      final json = r as Map<String, dynamic>;
      final user = json['users'] as Map<String, dynamic>?;
      final shiftType = json['shift_type'] as Map<String, dynamic>?;
      return HandoverWithMeta(
        handover: HandoverModel.fromJson(json),
        authorName: user?['display_name'] as String? ?? '알 수 없음',
        authorAvatarUrl: user?['avatar_url'] as String?,
        shiftName: shiftType?['name'] as String? ?? '-',
        shiftColor: shiftType?['color'] as String?,
      );
    }).toList();
  }

  /// 인계 개수만 (홈 카드 카운트 용)
  Future<int> countTeamDayHandovers({
    required String teamId,
    required DateTime date,
  }) async {
    if (_userId == null) return 0;
    final rows = await _client
        .from('shift_handovers')
        .select('id')
        .eq('team_id', teamId)
        .eq('shift_date', _dateStr(date));
    return (rows as List).length;
  }

  Future<HandoverModel> create({
    required String teamId,
    required String shiftTypeId,
    required DateTime date,
    required String body,
  }) async {
    final row = await _client
        .from('shift_handovers')
        .insert({
          'team_id': teamId,
          'shift_type_id': shiftTypeId,
          'shift_date': _dateStr(date),
          'body': body,
          'created_by': _userId,
        })
        .select()
        .single();
    return HandoverModel.fromJson(row);
  }

  /// soft delete (DELETE 정책 없음 — UPDATE로 is_deleted=true)
  Future<void> softDelete(String id) async {
    await _client
        .from('shift_handovers')
        .update({'is_deleted': true})
        .eq('id', id);
  }
}
