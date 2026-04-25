import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/models/shift_type_model.dart';
import 'package:moniq/data/models/team_member_with_user.dart';
import 'package:moniq/data/providers/shift_providers.dart';
import 'package:moniq/data/providers/team_providers.dart';
import 'package:moniq/presentation/screens/team/custom_rules_widgets.dart';
import 'package:moniq/presentation/widgets/common/moniq_app_bar.dart';
import 'package:moniq/presentation/widgets/common/moniq_error_view.dart';
import 'package:moniq/presentation/widgets/common/moniq_loading_view.dart';

// ──────────────────────────────────────────────
// Providers (screen-local)
// ──────────────────────────────────────────────

final _shiftTypesProvider =
    FutureProvider.autoDispose.family<List<ShiftTypeModel>, String>(
  (ref, teamId) =>
      ref.watch(shiftRepositoryProvider).getShiftTypes(teamId),
);

final _teamMembersProvider =
    FutureProvider.autoDispose.family<List<TeamMemberWithUser>, String>(
  (ref, teamId) =>
      ref.watch(teamRepositoryProvider).getTeamMembersWithUsers(teamId),
);

// ──────────────────────────────────────────────
// Screen
// ──────────────────────────────────────────────

class CustomRulesScreen extends ConsumerWidget {
  const CustomRulesScreen({super.key, required this.teamId});

  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rulesAsync = ref.watch(customRulesProvider(teamId));
    final shiftTypesAsync = ref.watch(_shiftTypesProvider(teamId));
    final membersAsync = ref.watch(_teamMembersProvider(teamId));

    return Scaffold(
      appBar: const MoniqAppBar(title: '커스텀 규칙'),
      body: rulesAsync.when(
        loading: () => const MoniqLoadingView(),
        error: (e, _) => MoniqErrorView(
          message: '규칙을 불러올 수 없습니다',
          onRetry: () => ref.invalidate(customRulesProvider(teamId)),
        ),
        data: (rules) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: CustomRulesBody(
              teamId: teamId,
              rules: rules,
              shiftTypes: shiftTypesAsync.valueOrNull ?? [],
              members: membersAsync.valueOrNull ?? [],
            ),
          ),
        ),
      ),
    );
  }
}
