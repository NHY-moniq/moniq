import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:moniq/data/models/team_member_with_user.dart';
import 'package:moniq/data/models/team_model.dart';
import 'package:moniq/data/models/team_member_model.dart';
import 'package:moniq/data/models/user_model.dart';

class TeamRemoteDataSource {
  TeamRemoteDataSource({required SupabaseClient client}) : _client = client;

  final SupabaseClient _client;

  Future<List<TeamModel>> getMyTeams() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    final memberRows = await _client
        .from('team_members')
        .select('team_id')
        .eq('user_id', userId)
        .eq('is_deleted', false);

    final teamIds = (memberRows as List)
        .map((r) => r['team_id'] as String)
        .toList();

    if (teamIds.isEmpty) return [];

    final teamRows = await _client
        .from('teams')
        .select()
        .inFilter('id', teamIds)
        .eq('is_deleted', false)
        .order('created_at');

    return (teamRows as List)
        .map((r) => TeamModel.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<TeamModel> createTeam({
    required String name,
    String? icon,
    String? description,
    String? teamType,
  }) async {
    final response = await _client.rpc(
      'create_team',
      params: {
        'p_name': name,
        'p_icon': icon,
        'p_description': description,
        'p_team_type': teamType ?? 'organizational',
      },
    );

    final data = response as Map<String, dynamic>;
    final teamId = data['team_id'] as String;

    final teamRow = await _client
        .from('teams')
        .select()
        .eq('id', teamId)
        .single();

    return TeamModel.fromJson(teamRow);
  }

  Future<Map<String, dynamic>> joinTeamByInvite(String inviteCode) async {
    final response = await _client.rpc(
      'join_team_by_invite',
      params: {'p_invite_code': inviteCode},
    );

    return response as Map<String, dynamic>;
  }

  Future<List<TeamMemberModel>> getTeamMembers(String teamId) async {
    final rows = await _client
        .from('team_members')
        .select()
        .eq('team_id', teamId)
        .eq('is_deleted', false);

    return (rows as List)
        .map((r) => TeamMemberModel.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<TeamModel?> getFavoriteTeam() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    final memberRow = await _client
        .from('team_members')
        .select('team_id')
        .eq('user_id', userId)
        .eq('is_favorite', true)
        .eq('is_deleted', false)
        .maybeSingle();

    if (memberRow == null) return null;

    final teamRow = await _client
        .from('teams')
        .select()
        .eq('id', memberRow['team_id'] as String)
        .eq('is_deleted', false)
        .maybeSingle();

    if (teamRow == null) return null;

    return TeamModel.fromJson(teamRow);
  }

  Future<void> setFavoriteTeam(String teamId) async {
    await _client.rpc('set_favorite_team', params: {'p_team_id': teamId});
  }

  Future<void> clearFavoriteTeam() async {
    await _client.rpc('clear_favorite_team');
  }

  /// 팀 정보 수정
  Future<void> updateTeam(
    String teamId, {
    String? name,
    String? icon,
    String? description,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (icon != null) updates['icon'] = icon;
    if (description != null) updates['description'] = description;
    if (updates.isEmpty) return;

    await _client.from('teams').update(updates).eq('id', teamId);
  }

  /// 멤버 + 유저 정보 조인
  Future<List<TeamMemberWithUser>> getTeamMembersWithUsers(
    String teamId,
  ) async {
    final members = await _client
        .from('team_members')
        .select()
        .eq('team_id', teamId)
        .eq('is_deleted', false)
        .order('joined_at');

    final memberModels = (members as List)
        .map((r) => TeamMemberModel.fromJson(r as Map<String, dynamic>))
        .toList();

    if (memberModels.isEmpty) return [];

    final userIds = memberModels.map((m) => m.userId).toList();
    final userRows = await _client
        .from('users')
        .select()
        .inFilter('id', userIds)
        .eq('is_deleted', false);

    final userMap = <String, UserModel>{};
    for (final r in (userRows as List)) {
      final user = UserModel.fromJson(r as Map<String, dynamic>);
      userMap[user.id] = user;
    }

    return memberModels.map((m) {
      final user = userMap[m.userId] ?? _buildMissingUser(m.userId);
      return TeamMemberWithUser(member: m, user: user);
    }).toList();
  }

  /// 멤버 역할 변경
  Future<void> updateMemberRole(
    String teamId,
    String userId,
    String role,
  ) async {
    await _client
        .from('team_members')
        .update({'role': role})
        .eq('team_id', teamId)
        .eq('user_id', userId);
  }

  /// 멤버 제거 (soft delete)
  Future<void> removeMember(String teamId, String userId) async {
    await _client
        .from('team_members')
        .update({'is_deleted': true})
        .eq('team_id', teamId)
        .eq('user_id', userId);
  }

  /// 팀 삭제 (soft delete) — 관리자 전용, DB에서 admin 권한 검증
  Future<void> deleteTeam(String teamId) async {
    await _client.rpc('delete_team', params: {'p_team_id': teamId});
  }

  UserModel _buildMissingUser(String userId) {
    final shortId = userId.length >= 8 ? userId.substring(0, 8) : userId;
    return UserModel(
      id: userId,
      email: 'missing-user-$shortId',
      displayName: '사용자($shortId)',
    );
  }
}
