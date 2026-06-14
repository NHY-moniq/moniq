import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/core/utils/team_icon_utils.dart';
import 'package:moniq/data/models/team_model.dart';
import 'package:moniq/data/providers/supabase_providers.dart';
import 'package:moniq/data/providers/team_providers.dart';
import 'package:moniq/presentation/screens/calendar/calendar_providers.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/home_viewmodel.dart';
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

          Widget tile({
            required int sectionIndex,
            required int globalIndex,
            required TeamModel team,
          }) {
            final isFavorite = team.id == favoriteTeamId;
            return _TeamSlidableTile(
              key: ValueKey(team.id),
              index: sectionIndex,
              team: team,
              isFavorite: isFavorite,
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

          return Column(
            children: [
              const _FavoriteInfoBanner(),
              Expanded(
                child: SlidableAutoCloseBehavior(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (orgTeams.isNotEmpty) ...[
                          const _TeamListSectionHeader(
                            label: '조직',
                            subLabel: 'Public',
                            icon: Icons.groups_rounded,
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
                              globalIndex: index,
                              team: orgTeams[index],
                            ),
                          ),
                        ],
                        if (orgTeams.isNotEmpty &&
                            personalTeams.isNotEmpty)
                          const SizedBox(height: AppSpacing.md),
                        if (personalTeams.isNotEmpty) ...[
                          const _TeamListSectionHeader(
                            label: '개인',
                            subLabel: 'Private',
                            icon: Icons.lock_outline_rounded,
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
                              globalIndex: orgTeams.length + index,
                              team: personalTeams[index],
                            ),
                          ),
                        ],
                      ],
                    ),
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
    // 즐겨찾기 변경 시 개인/팀 캘린더 미리보기가 즉시 반영되도록 모두 갱신.
    // - 임시 보기 전환(override)을 비워 팀 탭이 새 즐겨찾기 팀을 따르게 한다.
    // - 개인 캘린더(home)와 팀 근무유형 미리보기 provider를 무효화한다.
    ref.read(viewingTeamIdOverrideProvider.notifier).state = null;
    ref.invalidate(favoriteTeamProvider);
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

/// 팀 목록 화면의 섹션 헤더 — 조직(Public) / 개인(Private) 구분.
class _TeamListSectionHeader extends StatelessWidget {
  const _TeamListSectionHeader({
    required this.label,
    required this.subLabel,
    required this.icon,
  });

  final String label;
  final String subLabel;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          // 아이콘을 은은한 칩에 담아 헤더에 무게감을 준다.
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              borderRadius: AppRadius.borderRadiusSm,
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 13, color: cs.onSurfaceVariant),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            subLabel.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
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
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.4),
        borderRadius: AppRadius.borderRadiusMd,
        border: Border.all(
          color: cs.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 별 아이콘을 작은 흰 칩에 담아 포인트를 준다.
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: AppRadius.borderRadiusSm,
            ),
            alignment: Alignment.center,
            child: Icon(Icons.star_rounded, size: 15, color: cs.primary),
          ),
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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final hasDesc =
        team.description != null && team.description!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: ClipRRect(
        // 카드와 슬라이드 액션의 모서리를 맞춰 둥근 느낌을 유지.
        borderRadius: AppRadius.borderRadiusLg,
        child: Slidable(
          endActionPane: ActionPane(
            motion: const BehindMotion(),
            extentRatio: 0.4,
            children: [
              SlidableAction(
                onPressed: (_) => onDetail(),
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                icon: Icons.settings_outlined,
                label: '설정',
              ),
              SlidableAction(
                onPressed: (_) => onLeave(),
                backgroundColor: cs.error,
                foregroundColor: cs.onError,
                icon: Icons.exit_to_app,
                label: '나가기',
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onDetail,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm + 2,
                ),
                decoration: BoxDecoration(
                  // 즐겨찾기 팀은 primary 틴트 + 보더로 또렷하게 강조.
                  color: isFavorite
                      ? cs.primaryContainer.withValues(alpha: 0.32)
                      : cs.surfaceContainerLow,
                  borderRadius: AppRadius.borderRadiusLg,
                  border: Border.all(
                    color: isFavorite
                        ? cs.primary.withValues(alpha: 0.55)
                        : cs.outlineVariant.withValues(alpha: 0.6),
                    width: isFavorite ? 1.4 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    // 아바타 — 은은한 링으로 입체감.
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: cs.outlineVariant.withValues(alpha: 0.5),
                        ),
                      ),
                      child: TeamProfileAvatar(icon: team.icon, radius: 22),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            team.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: cs.onSurface,
                            ),
                          ),
                          if (hasDesc) ...[
                            const SizedBox(height: 2),
                            Text(
                              team.description!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    if (team.teamType != 'personal')
                      GestureDetector(
                        onTap: onFavorite,
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            isFavorite
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            color: isFavorite ? cs.primary : cs.outline,
                            size: 22,
                          ),
                        ),
                      ),
                    ReorderableDragStartListener(
                      index: index,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.drag_handle_rounded,
                          color: cs.outline.withValues(alpha: 0.8),
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
