import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:moniq/data/models/team_model.dart';
import 'package:moniq/data/providers/team_providers.dart';
import 'package:moniq/data/repositories/team_repository.dart';

final teamViewModelProvider =
    AsyncNotifierProvider<TeamViewModel, List<TeamModel>>(TeamViewModel.new);

class TeamViewModel extends AsyncNotifier<List<TeamModel>> {
  late TeamRepository _repository;

  @override
  Future<List<TeamModel>> build() async {
    _repository = ref.watch(teamRepositoryProvider);
    return _repository.getMyTeams();
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
