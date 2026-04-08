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

    // shift_rules 테이블 없을 수 있으므로 에러 무시 래핑
    Future<List<ShiftRuleModel>> safeGetRules() async {
      try {
        return await _shiftRepository.getShiftRules(teamId);
      } catch (_) {
        return [];
      }
    }

    // 모든 쿼리를 병렬 실행 (기존: getMyTeams=직렬2개 + getShiftRules=별도 직렬)
    final results = await Future.wait([
      _teamRepository.getTeamById(teamId),           // 단일 팀 직접 조회 (1쿼리)
      _teamRepository.getTeamMembersWithUsers(teamId),
      _shiftRepository.getAllShiftTypes(teamId),
      safeGetRules(),                                 // 병렬로 이동
    ]);

    final team = results[0] as TeamModel;
    final members = results[1] as List<TeamMemberWithUser>;
    final shiftTypes = results[2] as List<ShiftTypeModel>;
    final rules = results[3] as List<ShiftRuleModel>;

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

  Future<void> updateMemberSkillLevel(
    String userId,
    String? skillLevel,
  ) async {
    final current = state.valueOrNull;
    if (current == null) return;

    await _teamRepository.updateMemberSkillLevel(
      current.teamId,
      userId,
      skillLevel,
    );
    ref.invalidateSelf();
  }

  Future<void> updateMemberAttrs(
    String userId, {
    bool? nightExempt,
    bool? dayOnly,
    bool? nightDedicated,
  }) async {
    final current = state.valueOrNull;
    if (current == null) return;

    await _teamRepository.updateMemberAttrs(
      current.teamId,
      userId,
      nightExempt: nightExempt,
      dayOnly: dayOnly,
      nightDedicated: nightDedicated,
    );
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

  /// 팀 나가기 전 상태를 분석하여 결과를 반환한다.
  /// - [LeaveResult.onlyMember]: 나 혼자 → 팀 삭제 필요
  /// - [LeaveResult.lastAdmin]: 내가 유일한 관리자 → 관리자 위임 필요
  /// - [LeaveResult.canLeave]: 바로 나가기 가능
  LeaveResult checkLeaveCondition() {
    final current = state.valueOrNull;
    if (current == null) return LeaveResult.canLeave;

    // 1) 나 혼자인 팀이면 → 팀 삭제
    if (current.members.length == 1) {
      return LeaveResult.onlyMember;
    }

    // 2) 내가 관리자인데 다른 관리자가 없으면 → 위임 필요
    if (current.isAdmin) {
      final otherAdmins = current.members.where(
        (m) =>
            m.userId != current.currentUserId &&
            m.role == 'admin',
      );
      if (otherAdmins.isEmpty) {
        return LeaveResult.lastAdmin;
      }
    }

    return LeaveResult.canLeave;
  }

  Future<void> leaveTeam() async {
    final current = state.valueOrNull;
    if (current == null) return;

    await _teamRepository.removeMember(
      current.teamId,
      current.currentUserId,
    );
  }

  /// 나 혼자 남은 팀에서 나가기 → 팀 삭제까지 수행
  Future<void> leaveAndDeleteTeam() async {
    final current = state.valueOrNull;
    if (current == null) return;

    await _teamRepository.deleteTeam(current.teamId);
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

enum LeaveResult {
  /// 바로 나가기 가능
  canLeave,

  /// 나 혼자 남은 팀 → 나가면 팀 삭제됨
  onlyMember,

  /// 내가 유일한 관리자 → 다른 멤버에게 관리자 위임 필요
  lastAdmin,
}
