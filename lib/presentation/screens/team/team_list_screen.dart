import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/core/utils/team_icon_utils.dart';
import 'package:moniq/data/models/team_model.dart';
import 'package:moniq/data/providers/supabase_providers.dart';
import 'package:moniq/data/providers/team_providers.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/team_calendar_viewmodel.dart';
import 'package:moniq/presentation/widgets/common/character_blob.dart';
import 'package:moniq/presentation/viewmodels/team_viewmodel.dart';
import 'package:moniq/presentation/widgets/common/moniq_app_bar.dart';
import 'package:moniq/presentation/widgets/common/moniq_bottom_sheet.dart';
import 'package:moniq/presentation/widgets/common/moniq_error_view.dart';
import 'package:moniq/presentation/widgets/common/moniq_loading_view.dart';

class TeamListScreen extends HookConsumerWidget {
  const TeamListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamsAsync = ref.watch(teamViewModelProvider);
    final favoriteAsync = ref.watch(favoriteTeamProvider);

    return Scaffold(
      appBar: MoniqAppBar(
        title: '팀 목록',
        trailing: MoniqAppBarAction(
          icon: Icons.add_rounded,
          onTap: () => _showAddOptions(context),
        ),
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
                    const Opacity(
                      opacity: 0.5,
                      child: CharacterGroup(size: 48),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    Text(
                      '참여한 팀이 없습니다',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
            );
          }

          final favoriteTeamId = favoriteAsync.valueOrNull?.id;

          return Column(
            children: [
              const _FavoriteInfoBanner(),
              Expanded(
                child: SlidableAutoCloseBehavior(
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
              itemCount: teams.length,
              buildDefaultDragHandles: false,
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
                    shadowColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
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
                  index: index,
                  team: team,
                  isFavorite: isFavorite,
                  onFavorite: () => _toggleFavorite(
                    ref,
                    team,
                    isFavorite,
                  ),
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
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _toggleFavorite(
    WidgetRef ref,
    TeamModel team,
    bool isFavorite,
  ) async {
    final teamRepo = ref.read(teamRepositoryProvider);
    if (isFavorite) {
      await teamRepo.clearFavoriteTeam();
    } else {
      await teamRepo.setFavoriteTeam(team.id);
    }
    ref.invalidate(favoriteTeamProvider);
    ref.invalidate(teamViewModelProvider);
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

  Future<void> _confirmLeave(
    BuildContext context,
    WidgetRef ref,
    TeamModel team,
  ) async {
    final userId = ref
        .read(supabaseClientProvider)
        .auth
        .currentUser
        ?.id;
    if (userId == null) return;

    final teamRepo = ref.read(teamRepositoryProvider);
    final members = await teamRepo.getTeamMembers(team.id);

    // 1) 나 혼자 → 팀 삭제
    if (members.length == 1) {
      if (!context.mounted) return;
      await showMoniqInfoSheet(
        context: context,
        title: '팀에 혼자 남으셨어요',
        message: '팀 나가기 대신 팀을 제거해주세요.',
      );
      return;
    }

    // 2) 내가 유일한 관리자 → 위임 안내
    final myMember = members.where((m) => m.userId == userId).firstOrNull;
    if (myMember != null && myMember.role == 'admin') {
      final otherAdmins = members.where(
        (m) => m.userId != userId && m.role == 'admin',
      );
      if (otherAdmins.isEmpty) {
        if (!context.mounted) return;
        final goToMembers = await showMoniqConfirmSheet(
          context: context,
          title: '관리자를 먼저 지정해주세요',
          message:
              '팀에 관리자가 최소 1명 필요해요. 다른 멤버를 관리자로 지정한 후 나갈 수 있어요.',
          confirmLabel: '멤버 관리로 이동',
          cancelLabel: '닫기',
        );
        if (goToMembers && context.mounted) {
          context.push('/teams/${team.id}/members');
        }
        return;
      }
    }

    // 3) 일반 나가기
    if (!context.mounted) return;
    final ok = await showMoniqConfirmSheet(
      context: context,
      title: '${team.name} 팀에서 나갈까요?',
      message: '나가면 팀의 근무표·요청에 더 이상 접근할 수 없어요.',
      confirmLabel: '나가기',
      destructive: true,
    );
    if (!ok) return;
    try {
      await teamRepo.removeMember(team.id, userId);
      ref.invalidate(teamViewModelProvider);
      ref.invalidate(favoriteTeamProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('팀 나가기에 실패했습니다: $e')),
        );
      }
    }
  }
}

class _FavoriteInfoBanner extends StatelessWidget {
  const _FavoriteInfoBanner();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        0,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.star_rounded, size: 15, color: cs.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '조직 팀에 즐겨찾기(★)를 설정하면 해당 팀의 근무가 캘린더 탭에 표시됩니다. 개인 팀은 즐겨찾기 대상이 아닙니다.',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: cs.onPrimaryContainer,
                    height: 1.5,
                  ),
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
    required this.index,
    required this.team,
    required this.isFavorite,
    required this.onFavorite,
    required this.onDetail,
    required this.onLeave,
  });

  final int index;
  final TeamModel team;
  final bool isFavorite;
  final VoidCallback onFavorite;
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
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            icon: Icons.settings_outlined,
            label: '설정',
          ),
          SlidableAction(
            onPressed: (_) => onLeave(),
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
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
            if (team.teamType != 'personal')
              GestureDetector(
                onTap: onFavorite,
                child: Icon(
                  isFavorite ? Icons.star : Icons.star_border,
                  color: isFavorite
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline,
                  size: 20,
                ),
              ),
            const SizedBox(width: 8),
            ReorderableDragStartListener(
              index: index,
              child: Icon(
                Icons.reorder,
                color: Theme.of(context).colorScheme.outline,
                size: 20,
              ),
            ),
          ],
        ),
        onTap: onDetail,
      ),
    );
  }
}
