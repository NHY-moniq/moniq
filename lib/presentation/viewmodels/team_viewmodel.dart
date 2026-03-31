import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:moniq/data/models/team_model.dart';
import 'package:moniq/data/providers/supabase_providers.dart';
import 'package:moniq/data/providers/team_providers.dart';
import 'package:moniq/data/repositories/team_repository.dart';

const _teamOrderKey = 'team_order';

final teamViewModelProvider =
    AsyncNotifierProvider<TeamViewModel, List<TeamModel>>(TeamViewModel.new);

class TeamViewModel extends AsyncNotifier<List<TeamModel>> {
  late TeamRepository _repository;

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
    await prefs.setStringList(
      _teamOrderKey,
      teams.map((t) => t.id).toList(),
    );
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
}
