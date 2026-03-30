import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/core/utils/team_icon_utils.dart';
import 'package:moniq/data/models/team_model.dart';
import 'package:moniq/data/providers/supabase_providers.dart';
import 'package:moniq/data/providers/team_providers.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/team_calendar_viewmodel.dart';
import 'package:moniq/presentation/viewmodels/team_viewmodel.dart';
import 'package:moniq/presentation/widgets/common/moniq_error_view.dart';
import 'package:moniq/presentation/widgets/common/moniq_loading_view.dart';

class TeamListScreen extends HookConsumerWidget {
  const TeamListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamsAsync = ref.watch(teamViewModelProvider);
    final favoriteAsync = ref.watch(favoriteTeamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('팀 목록'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddOptions(context),
          ),
        ],
      ),
      body: teamsAsync.when(
        loading: () => const MoniqLoadingView(),
        error: (e, _) => MoniqErrorView(
          message: '팀 목록을 불러올 수 없습니다',
          onRetry: () =>
              ref.read(teamViewModelProvider.notifier).refresh(),
        ),
        data: (teams) {
          if (teams.isEmpty) {
            return Center(
              child: Padding(
                padding: AppSpacing.screenAll,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.groups_outlined,
                      size: 64,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const Text('참여한 팀이 없습니다'),
                  ],
                ),
              ),
            );
          }

          final favoriteTeamId = favoriteAsync.valueOrNull?.id;

          return SlidableAutoCloseBehavior(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.sm,
              ),
              itemCount: teams.length,
              onReorder: (oldIndex, newIndex) {
                ref
                    .read(teamViewModelProvider.notifier)
                    .reorder(oldIndex, newIndex);
              },
              proxyDecorator: (child, index, animation) {
                return AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) => Material(
                    elevation: 4,
                    shadowColor: AppColors.primary.withValues(alpha: 0.3),
                    borderRadius: AppRadius.borderRadiusLg,
                    child: child,
                  ),
                  child: child,
                );
              },
              itemBuilder: (context, index) {
                final team = teams[index];
                final isFavorite = team.id == favoriteTeamId;

                return _TeamSlidableTile(
                  key: ValueKey(team.id),
                  team: team,
                  isFavorite: isFavorite,
                  onDetail: () => context.push(
                    '/teams/${team.id}/detail',
                  ),
                  onLeave: () => _confirmLeave(
                    context,
                    ref,
                    team,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _showAddOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add_circle_outline),
              title: const Text('팀 만들기'),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/teams/create');
              },
            ),
            ListTile(
              leading: const Icon(Icons.vpn_key_outlined),
              title: const Text('초대 코드로 참여'),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/teams/join');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmLeave(
    BuildContext context,
    WidgetRef ref,
    TeamModel team,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('팀 나가기'),
        content: Text(
          '${team.name} 팀에서 나가시겠습니까?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final userId = ref
                  .read(supabaseClientProvider)
                  .auth
                  .currentUser
                  ?.id;
              if (userId == null) return;

              await ref
                  .read(teamRepositoryProvider)
                  .removeMember(team.id, userId);
              ref.invalidate(teamViewModelProvider);
              ref.invalidate(favoriteTeamProvider);
            },
            child: const Text(
              '나가기',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamSlidableTile extends StatelessWidget {
  const _TeamSlidableTile({
    super.key,
    required this.team,
    required this.isFavorite,
    required this.onDetail,
    required this.onLeave,
  });

  final TeamModel team;
  final bool isFavorite;
  final VoidCallback onDetail;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    return Slidable(
      endActionPane: ActionPane(
        motion: const BehindMotion(),
        extentRatio: 0.4,
        children: [
          SlidableAction(
            onPressed: (_) => onDetail(),
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            icon: Icons.settings_outlined,
            label: '설정',
          ),
          SlidableAction(
            onPressed: (_) => onLeave(),
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
            icon: Icons.exit_to_app,
            label: '나가기',
          ),
        ],
      ),
      child: ListTile(
        leading: TeamProfileAvatar(
          icon: team.icon,
          radius: 20,
        ),
        title: Text(team.name),
        subtitle: team.description != null &&
                team.description!.isNotEmpty
            ? Text(
                team.description!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isFavorite ? Icons.star : Icons.star_border,
              color: isFavorite ? Colors.amber : Colors.grey.shade400,
              size: 20,
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.reorder,
              color: Colors.grey.shade400,
              size: 20,
            ),
          ],
        ),
        onTap: onDetail,
      ),
    );
  }
}
