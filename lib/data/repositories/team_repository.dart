import 'package:moniq/data/datasources/team_remote_data_source.dart';
import 'package:moniq/data/models/team_member_model.dart';
import 'package:moniq/data/models/team_member_with_user.dart';
import 'package:moniq/data/models/team_model.dart';

class TeamRepository {
  TeamRepository({required TeamRemoteDataSource dataSource})
      : _dataSource = dataSource;

  final TeamRemoteDataSource _dataSource;

  Future<List<TeamModel>> getMyTeams() {
    return _dataSource.getMyTeams();
  }

  Future<TeamModel> getTeamById(String teamId) {
    return _dataSource.getTeamById(teamId);
  }

  Future<TeamModel> createTeam({
    required String name,
    String? icon,
    String? description,
    String? teamType,
  }) {
    return _dataSource.createTeam(
      name: name,
      icon: icon,
      description: description,
      teamType: teamType,
    );
  }

  Future<Map<String, dynamic>> joinTeamByInvite(String inviteCode) {
    return _dataSource.joinTeamByInvite(inviteCode);
  }

  Future<List<TeamMemberModel>> getTeamMembers(String teamId) {
    return _dataSource.getTeamMembers(teamId);
  }

  Future<TeamModel?> getFavoriteTeam() {
    return _dataSource.getFavoriteTeam();
  }

  Future<void> setFavoriteTeam(String teamId) {
    return _dataSource.setFavoriteTeam(teamId);
  }

  Future<void> clearFavoriteTeam() {
    return _dataSource.clearFavoriteTeam();
  }

  Future<void> updateTeam(String teamId,
      {String? name, String? icon, String? description}) {
    return _dataSource.updateTeam(teamId,
        name: name, icon: icon, description: description);
  }

  Future<List<TeamMemberWithUser>> getTeamMembersWithUsers(String teamId) {
    return _dataSource.getTeamMembersWithUsers(teamId);
  }

  Future<void> updateMemberRole(String teamId, String userId, String role) {
    return _dataSource.updateMemberRole(teamId, userId, role);
  }

  Future<void> updateMemberSkillLevel(
    String teamId,
    String userId,
    String? skillLevel,
  ) {
    return _dataSource.updateMemberSkillLevel(teamId, userId, skillLevel);
  }

  Future<void> updateMemberAttrs(
    String teamId,
    String userId, {
    bool? nightExempt,
    bool? dayOnly,
    bool? nightDedicated,
    List<String>? preferredShifts,
  }) {
    return _dataSource.updateMemberAttrs(
      teamId,
      userId,
      nightExempt: nightExempt,
      dayOnly: dayOnly,
      nightDedicated: nightDedicated,
      preferredShifts: preferredShifts,
    );
  }

  Future<void> removeMember(String teamId, String userId) {
    return _dataSource.removeMember(teamId, userId);
  }

  Future<void> deleteTeam(String teamId) {
    return _dataSource.deleteTeam(teamId);
  }
}
