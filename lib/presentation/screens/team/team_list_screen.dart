import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/models/team_model.dart';
import 'package:moniq/data/providers/supabase_providers.dart';
import 'package:moniq/data/providers/team_providers.dart';
import 'package:moniq/presentation/screens/calendar/calendar_providers.dart';
import 'package:moniq/presentation/screens/team/team_list_widgets.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/home_viewmodel.dart';
import 'package:moniq/presentation/viewmodels/team_calendar_viewmodel.dart';
import 'package:moniq/presentation/viewmodels/team_viewmodel.dart';
import 'package:moniq/presentation/widgets/common/moniq_app_bar.dart';
import 'package:moniq/presentation/widgets/common/moniq_bottom_sheet.dart';
import 'package:moniq/presentation/widgets/common/moniq_empty_state.dart';
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
            return MoniqEmptyState.shift(
              title: '아직 참여한 팀이 없어요',
              message: '팀을 만들거나 초대 코드로 참여해보세요',
              action: MoniqEmptyStateAction(
                label: '팀 만들기',
                icon: Icons.add_rounded,
                onTap: () => context.push('/teams/create'),
              ),
              secondaryAction: MoniqEmptyStateAction.outlined(
                label: '초대 코드로 참여',
                onTap: () => context.push('/teams/join'),
              ),
            );
          }

          final favoriteTeamId = favoriteAsync.valueOrNull?.id;
          // 조직 팀: 즐겨찾기를 최상단으로 (그 외 순서는 그대로).
          final orgTeams = teams
              .where((t) => t.teamType != 'personal')
              .toList();
          orgTeams.sort((a, b) {
            if (a.id == favoriteTeamId) return -1;
            if (b.id == favoriteTeamId) return 1;
            return 0;
          });
          final personalTeams = teams
              .where((t) => t.teamType == 'personal')
              .toList();

          // 조직 팀 중 즐겨찾기가 하나도 없으면 안내를 눈에 띄게 올린다.
          final hasOrgFavorite = orgTeams.any((t) => t.id == favoriteTeamId);

          Widget tile({
            required int sectionIndex,
            required TeamModel team,
            required bool showDragHandle,
          }) {
            final isFavorite = team.id == favoriteTeamId;
            return TeamListTile(
              key: ValueKey(team.id),
              index: sectionIndex,
              team: team,
              isFavorite: isFavorite,
              showDragHandle: showDragHandle,
              onFavorite: () => _toggleFavorite(ref, team, isFavorite),
              onDetail: () => context.push('/teams/${team.id}/detail'),
              onLeave: () => _confirmLeave(context, ref, team),
            );
          }

          Widget proxyDecorator(
            Widget child,
            int index,
            Animation<double> animation,
          ) {
            return AnimatedBuilder(
              animation: animation,
              builder: (context, child) => Material(
                elevation: 4,
                shadowColor: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.3),
                borderRadius: AppRadius.borderRadiusLg,
                child: child,
              ),
              child: child,
            );
          }

          return SlidableAutoCloseBehavior(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: AppSpacing.huge),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (orgTeams.isNotEmpty) ...[
                    TeamListSectionHeader(
                      label: '조직 팀',
                      icon: Icons.groups_rounded,
                      count: orgTeams.length,
                      hint: hasOrgFavorite
                          ? '즐겨찾기한 팀의 근무가 캘린더 탭에 보여요'
                          : '즐겨찾기하면 그 팀의 근무가 캘린더 탭에 보여요',
                      hintIcon: Icons.star_rounded,
                      emphasizeHint: !hasOrgFavorite,
                    ),
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: orgTeams.length,
                      buildDefaultDragHandles: false,
                      proxyDecorator: proxyDecorator,
                      onReorder: (oldIndex, newIndex) {
                        ref
                            .read(teamViewModelProvider.notifier)
                            .reorder(oldIndex, newIndex);
                      },
                      itemBuilder: (context, index) => tile(
                        sectionIndex: index,
                        team: orgTeams[index],
                        showDragHandle: orgTeams.length > 1,
                      ),
                    ),
                  ],
                  if (personalTeams.isNotEmpty) ...[
                    TeamListSectionHeader(
                      label: '개인 팀',
                      icon: Icons.lock_outline_rounded,
                      count: personalTeams.length,
                      hint: '나만 보는 일정이라 즐겨찾기는 없어요',
                    ),
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: personalTeams.length,
                      buildDefaultDragHandles: false,
                      proxyDecorator: proxyDecorator,
                      onReorder: (oldIndex, newIndex) {
                        // 전역 인덱스 = 조직 팀 개수 + 로컬 인덱스
                        final offset = orgTeams.length;
                        ref
                            .read(teamViewModelProvider.notifier)
                            .reorder(
                              offset + oldIndex,
                              offset + newIndex,
                            );
                      },
                      itemBuilder: (context, index) => tile(
                        sectionIndex: index,
                        team: personalTeams[index],
                        showDragHandle: personalTeams.length > 1,
                      ),
                    ),
                  ],
                  // 팀이 한두 개일 때 아래가 통째로 비지 않도록 추가 유도를 둔다.
                  TeamListAddTile(onTap: () => _showAddOptions(context)),
                ],
              ),
            ),
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
    // 로컬 캐시까지 함께 갱신해야 다음 콜드 스타트에 옛 즐겨찾기가 되살아나지 않는다.
    await ref.read(favoriteTeamProvider.notifier).select(
          isFavorite ? null : team.id,
          team: isFavorite ? null : team,
        );
    // 즐겨찾기 변경 시 개인/팀 캘린더 미리보기가 즉시 반영되도록 모두 갱신.
    // - 임시 보기 전환(override)을 비워 팀 탭이 새 즐겨찾기 팀을 따르게 한다.
    // - 개인 캘린더(home)와 팀 근무유형 미리보기 provider를 무효화한다.
    ref.read(viewingTeamIdOverrideProvider.notifier).state = null;
    ref.invalidate(favoriteTeamShiftTypesProvider);
    ref.invalidate(homeViewModelProvider);
    ref.invalidate(teamViewModelProvider);
  }

  void _showAddOptions(BuildContext context) {
    // 다른 시트와 동일한 MoniqBottomSheetShell 스타일로 통일.
    showMoniqBottomSheet<void>(
      context: context,
      eyebrow: 'TEAM',
      title: '팀 추가',
      child: Builder(
        builder: (ctx) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MoniqSheetOption(
              icon: Icons.add_circle_outline,
              label: '팀 만들기',
              onTap: () {
                Navigator.pop(ctx);
                context.push('/teams/create');
              },
            ),
            MoniqSheetOption(
              icon: Icons.vpn_key_outlined,
              label: '초대 코드로 참여',
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
        eyebrow: 'NOTICE',
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
          eyebrow: 'NOTICE',
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
      eyebrow: 'LEAVE TEAM',
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
