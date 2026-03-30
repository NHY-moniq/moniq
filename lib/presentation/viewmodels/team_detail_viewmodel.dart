import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/models/shift_rule_model.dart';
import 'package:moniq/data/models/shift_type_model.dart';
import 'package:moniq/data/models/team_member_with_user.dart';
import 'package:moniq/data/models/team_model.dart';
import 'package:moniq/data/providers/shift_providers.dart';
import 'package:moniq/data/providers/supabase_providers.dart';
import 'package:moniq/data/providers/team_providers.dart';
import 'package:moniq/data/repositories/shift_repository.dart';
import 'package:moniq/data/repositories/team_repository.dart';

part 'team_detail_viewmodel.freezed.dart';

@freezed
class TeamDetailState with _$TeamDetailState {
  const factory TeamDetailState({
    required String teamId,
    required TeamModel team,
    required List<TeamMemberWithUser> members,
    required List<ShiftTypeModel> shiftTypes,
    required List<ShiftRuleModel> rules,
    required bool isAdmin,
    required String currentUserId,
  }) = _TeamDetailState;
}

final teamDetailViewModelProvider =
    AsyncNotifierProvider.family<TeamDetailViewModel, TeamDetailState, String>(
      TeamDetailViewModel.new,
    );

class TeamDetailViewModel extends FamilyAsyncNotifier<TeamDetailState, String> {
  late TeamRepository _teamRepository;
  late ShiftRepository _shiftRepository;

  @override
  Future<TeamDetailState> build(String teamId) async {
    final authState = ref.watch(authStateChangesProvider);
    final currentUserId =
        authState.whenOrNull(data: (auth) => auth.session?.user.id) ?? '';
    if (currentUserId.isEmpty) {
      throw Exception('Not authenticated');
    }

    _teamRepository = ref.watch(teamRepositoryProvider);
    _shiftRepository = ref.watch(shiftRepositoryProvider);

    final results = await Future.wait([
      _teamRepository.getMyTeams(),
      _teamRepository.getTeamMembersWithUsers(teamId),
      _shiftRepository.getAllShiftTypes(teamId),
    ]);

    // shift_rules는 테이블이 없을 수 있으므로 별도 try-catch
    List<ShiftRuleModel> rules = [];
    try {
      rules = await _shiftRepository.getShiftRules(teamId);
    } catch (_) {
      // shift_rules 테이블 미생성 시 빈 리스트로 진행
    }

    final teams = results[0] as List<TeamModel>;
    final team = teams.firstWhere((t) => t.id == teamId);
    final members = results[1] as List<TeamMemberWithUser>;
    final shiftTypes = results[2] as List<ShiftTypeModel>;

    final isAdmin = members.any(
      (m) => m.userId == currentUserId && m.role == 'admin',
    );

    return TeamDetailState(
      teamId: teamId,
      team: team,
      members: members,
      shiftTypes: shiftTypes,
      rules: rules,
      isAdmin: isAdmin,
      currentUserId: currentUserId,
    );
  }

  Future<void> updateTeam({
    String? name,
    String? icon,
    String? description,
  }) async {
    final current = state.valueOrNull;
    if (current == null) return;

    await _teamRepository.updateTeam(
      current.teamId,
      name: name,
      icon: icon,
      description: description,
    );
    ref.invalidateSelf();
  }

  Future<void> updateMemberRole(String userId, String role) async {
    final current = state.valueOrNull;
    if (current == null) return;

    await _teamRepository.updateMemberRole(current.teamId, userId, role);
    ref.invalidateSelf();
  }

  Future<void> removeMember(String userId) async {
    final current = state.valueOrNull;
    if (current == null) return;

    await _teamRepository.removeMember(current.teamId, userId);
    ref.invalidateSelf();
  }

  Future<void> createShiftType({
    required String name,
    required String code,
    String? startTime,
    String? endTime,
    required String color,
  }) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final displayOrder = current.shiftTypes.length;
    await _shiftRepository.createShiftType(
      current.teamId,
      name: name,
      code: code,
      startTime: startTime,
      endTime: endTime,
      color: color,
      displayOrder: displayOrder,
    );
    ref.invalidateSelf();
  }

  Future<void> updateShiftType(
    String id, {
    String? name,
    String? code,
    String? startTime,
    String? endTime,
    String? color,
  }) async {
    await _shiftRepository.updateShiftType(
      id,
      name: name,
      code: code,
      startTime: startTime,
      endTime: endTime,
      color: color,
    );
    ref.invalidateSelf();
  }

  Future<void> toggleShiftTypeActive(String id, bool isActive) async {
    await _shiftRepository.toggleShiftTypeActive(id, isActive);
    ref.invalidateSelf();
  }

  Future<void> upsertRule(
    String ruleType,
    Map<String, dynamic> ruleValue,
  ) async {
    final current = state.valueOrNull;
    if (current == null) return;

    await _shiftRepository.upsertShiftRule(
      current.teamId,
      ruleType: ruleType,
      ruleValue: ruleValue,
    );
    ref.invalidateSelf();
  }

  Future<void> leaveTeam() async {
    final current = state.valueOrNull;
    if (current == null) return;

    await _teamRepository.removeMember(
      current.teamId,
      current.currentUserId,
    );
  }

  Future<void> deleteTeam() async {
    final current = state.valueOrNull;
    if (current == null) return;
    if (!current.isAdmin) {
      throw Exception('관리자만 팀을 삭제할 수 있습니다');
    }

    await _teamRepository.deleteTeam(current.teamId);
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}
