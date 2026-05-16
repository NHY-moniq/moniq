import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:moniq/data/models/team_model.dart';
import 'package:moniq/data/providers/shift_providers.dart';
import 'package:moniq/data/providers/supabase_providers.dart';
import 'package:moniq/data/providers/team_providers.dart';
import 'package:moniq/data/repositories/team_repository.dart';

const _teamOrderKey = 'team_order';

final teamViewModelProvider =
    AsyncNotifierProvider<TeamViewModel, List<TeamModel>>(TeamViewModel.new);

class TeamViewModel extends AsyncNotifier<List<TeamModel>> {
  late TeamRepository _repository;
  static const List<_DefaultShiftSeed> _defaultShiftSeeds = [
    _DefaultShiftSeed(
      name: '데이',
      code: 'D',
      color: '#F0C040',
      startTime: '07:00:00',
      endTime: '15:00:00',
    ),
    _DefaultShiftSeed(
      name: '이브닝',
      code: 'E',
      color: '#E8923A',
      startTime: '15:00:00',
      endTime: '22:00:00',
    ),
    _DefaultShiftSeed(
      name: '나이트',
      code: 'N',
      color: '#5A8BB5',
      startTime: '22:00:00',
      endTime: '07:00:00',
    ),
    _DefaultShiftSeed(
      name: '교육',
      code: 'ED',
      color: '#9F7AEA',
      startTime: '09:00:00',
      endTime: '18:00:00',
    ),
  ];

  @override
  Future<List<TeamModel>> build() async {
    final authState = ref.watch(authStateChangesProvider);
    final userId = authState.whenOrNull(data: (auth) => auth.session?.user.id);
    if (userId == null) {
      return [];
    }

    _repository = ref.watch(teamRepositoryProvider);
    final teams = await _repository.getMyTeams();
    return _applySavedOrder(teams);
  }

  Future<List<TeamModel>> _applySavedOrder(List<TeamModel> teams) async {
    final prefs = await SharedPreferences.getInstance();
    final savedOrder = prefs.getStringList(_teamOrderKey);
    if (savedOrder == null || savedOrder.isEmpty) return teams;

    final teamMap = {for (final t in teams) t.id: t};
    final ordered = <TeamModel>[];
    for (final id in savedOrder) {
      final team = teamMap.remove(id);
      if (team != null) ordered.add(team);
    }
    ordered.addAll(teamMap.values);
    return ordered;
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final teams = List<TeamModel>.from(current);
    if (newIndex > oldIndex) newIndex--;
    final item = teams.removeAt(oldIndex);
    teams.insert(newIndex, item);

    state = AsyncData(teams);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_teamOrderKey, teams.map((t) => t.id).toList());
  }

  Future<TeamModel> createTeam({
    required String name,
    String? icon,
    String? description,
    String? teamType,
  }) async {
    final team = await _repository.createTeam(
      name: name,
      icon: icon,
      description: description,
      teamType: teamType,
    );
    await _ensureDefaultShiftTypes(team.id);

    // Refresh the team list
    ref.invalidateSelf();
    await future;

    return team;
  }

  Future<Map<String, dynamic>> joinTeam(String inviteCode) async {
    final result = await _repository.joinTeamByInvite(inviteCode);

    // Refresh the team list
    ref.invalidateSelf();
    await future;

    return result;
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  Future<void> _ensureDefaultShiftTypes(String teamId) async {
    final shiftRepo = ref.read(shiftRepositoryProvider);
    final existing = await shiftRepo.getAllShiftTypes(teamId);
    final existingCodes = existing
        .map((t) => t.code.trim().toUpperCase())
        .toSet();
    var displayOrder = existing.length;

    for (final seed in _defaultShiftSeeds) {
      if (existingCodes.contains(seed.code)) continue;
      await shiftRepo.createShiftType(
        teamId,
        name: seed.name,
        code: seed.code,
        startTime: seed.startTime,
        endTime: seed.endTime,
        color: seed.color,
        displayOrder: displayOrder,
      );
      displayOrder += 1;
    }
  }
}

class _DefaultShiftSeed {
  const _DefaultShiftSeed({
    required this.name,
    required this.code,
    required this.color,
    required this.startTime,
    required this.endTime,
  });

  final String name;
  final String code;
  final String color;
  final String startTime;
  final String endTime;
}
