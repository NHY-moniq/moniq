import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/models/announcement_model.dart';
import 'package:moniq/data/models/team_model.dart';
import 'package:moniq/data/providers/announcement_providers.dart';
import 'package:moniq/data/providers/auth_providers.dart';
import 'package:moniq/presentation/screens/announcement/announcement_screen.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/team_viewmodel.dart';
import 'package:moniq/presentation/widgets/announcement/announcement_filter_sheet.dart';
import 'package:moniq/presentation/widgets/common/moniq_app_bar.dart';
import 'package:moniq/presentation/widgets/common/moniq_empty_state.dart';
import 'package:moniq/presentation/widgets/common/moniq_error_view.dart';
import 'package:moniq/presentation/widgets/common/moniq_loading_view.dart';

/// 홈탭에서 진입하는 내 팀 전체 공지사항 리스트
class MyAnnouncementsScreen extends HookConsumerWidget {
  const MyAnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final announcementsAsync = ref.watch(filteredAnnouncementsProvider);
    final pinnedIds = ref.watch(pinnedAnnouncementIdsProvider);
    final teamsAsync = ref.watch(teamViewModelProvider);
    final selectedTeamId =
        ref.watch(selectedAnnouncementTeamFilterProvider);
    final teams = teamsAsync.valueOrNull ?? const [];
    final selectedTeam = selectedTeamId == null
        ? null
        : teams.where((t) => t.id == selectedTeamId).firstOrNull;
    final filterLabel = selectedTeam?.name ?? '전체';

    return Scaffold(
      appBar: const MoniqAppBar(title: '팀 공지사항'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _onCreateTap(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('공지 작성'),
      ),
      body: Column(
        children: [
          if (teams.length > 1)
            _TeamFilterHeader(
              label: filterLabel,
              onTap: () => _showTeamFilterSheet(
                context,
                ref,
                teams,
                selectedTeamId,
              ),
            ),
          Expanded(
            child: announcementsAsync.when(
              loading: () => const MoniqLoadingView(),
              error: (e, _) => MoniqErrorView(
                message: '공지사항을 불러올 수 없습니다',
                onRetry: () => ref.invalidate(myAnnouncementsProvider),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return MoniqEmptyState.peaceful(
                    title: '공지사항이 없어요',
                    message: selectedTeam == null
                        ? '팀 관리자가 공지를 등록하면 여기에 표시돼요'
                        : '${selectedTeam.name}에 공지가 없어요',
                  );
                }

                // 개인 핀 기준 정렬: 내가 고정한 것 먼저, 그 안에서 최신순
                final sorted = [...items]..sort((x, y) {
                    final a = x.announcement;
                    final b = y.announcement;
                    final aPinned = pinnedIds.contains(a.id) ? 0 : 1;
                    final bPinned = pinnedIds.contains(b.id) ? 0 : 1;
                    if (aPinned != bPinned) return aPinned - bPinned;
                    final aDate = a.createdAt;
                    final bDate = b.createdAt;
                    if (aDate == null && bDate == null) return 0;
                    if (aDate == null) return 1;
                    if (bDate == null) return -1;
                    return bDate.compareTo(aDate);
                  });

                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(myAnnouncementsProvider),
                  child: SlidableAutoCloseBehavior(
                    child: ListView.separated(
                      padding: AppSpacing.screenAll,
                      itemCount: sorted.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) {
                        final item = sorted[index];
                        final a = item.announcement;
                        final isPinnedLocally = pinnedIds.contains(a.id);
                        return Slidable(
                          key: ValueKey(a.id),
                          startActionPane: ActionPane(
                            motion: const BehindMotion(),
                            extentRatio: 0.28,
                            children: [
                              SlidableAction(
                                onPressed: (_) => ref
                                    .read(pinnedAnnouncementIdsProvider
                                        .notifier)
                                    .toggle(a.id),
                                backgroundColor: isPinnedLocally
                                    ? AppColors.brandOrange
                                    : AppColors.primary,
                                foregroundColor: Colors.white,
                                icon: isPinnedLocally
                                    ? Icons.push_pin
                                    : Icons.push_pin_outlined,
                                label: isPinnedLocally ? '해제' : '고정',
                                borderRadius: AppRadius.borderRadiusLg,
                              ),
                            ],
                          ),
                          child: AnnouncementListTile(
                            key: ValueKey('tile_${a.id}'),
                            announcement: a,
                            teamName: item.teamName,
                            isPinnedLocally: isPinnedLocally,
                            onTap: () => _showDetail(context, ref, item),
                            onTogglePin: () => ref
                                .read(pinnedAnnouncementIdsProvider.notifier)
                                .toggle(a.id),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showTeamFilterSheet(
    BuildContext context,
    WidgetRef ref,
    List<TeamModel> teams,
    String? selectedTeamId,
  ) async {
    // teamId 가 null(전체)일 수 있어 sentinel 문자열로 감싼다.
    const allValue = '__all__';
    final options = <AnnouncementFilterOption<String>>[
      const AnnouncementFilterOption(
        value: allValue,
        label: '전체 보기',
        icon: Icons.apps_rounded,
      ),
      for (final t in teams)
        AnnouncementFilterOption(
          value: t.id,
          label: t.name,
          icon: Icons.groups_outlined,
        ),
    ];

    final picked = await showAnnouncementFilterSheet<String>(
      context: context,
      title: '팀 선택',
      selectedValue: selectedTeamId ?? allValue,
      options: options,
    );
    if (picked == null) return;
    ref.read(selectedAnnouncementTeamFilterProvider.notifier).state =
        picked.value == allValue ? null : picked.value;
  }

  Future<void> _onCreateTap(BuildContext context, WidgetRef ref) async {
    // 로그인 직후 첫 클릭 시 아직 로드 안 됐을 수 있으므로 future를 await
    List<TeamModel> teams;
    try {
      teams = await ref.read(teamViewModelProvider.future);
    } catch (_) {
      teams = [];
    }
    if (!context.mounted) return;
    if (teams.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('가입된 팀이 없습니다')),
      );
      return;
    }
    String? teamId;
    if (teams.length == 1) {
      teamId = teams.first.id;
    } else {
      teamId = await _pickTeam(context, teams);
    }
    if (teamId == null || !context.mounted) return;
    context.push('/teams/$teamId/announcements');
  }

  Future<String?> _pickTeam(BuildContext context, List<TeamModel> teams) {
    return showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                '공지를 작성할 팀 선택',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            const Divider(height: 1),
            ...teams.map(
              (t) => ListTile(
                leading: const Icon(Icons.groups_outlined),
                title: Text(t.name),
                onTap: () => Navigator.pop(ctx, t.id),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  void _showDetail(
      BuildContext context, WidgetRef ref, AnnouncementWithTeam item) {
    final a = item.announcement;
    final myUserId = ref.read(currentUserProvider)?.id;
    final isMine = myUserId != null && a.createdBy == myUserId;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (detailContext) => AnnouncementDetailPage(
          announcement: a,
          teamName: item.teamName,
          onEdit: isMine
              ? () async {
                  final updated = await showAnnouncementEditSheet(
                      detailContext, a);
                  if (updated == true) {
                    ref.invalidate(teamAnnouncementsProvider(a.teamId));
                    ref.invalidate(myAnnouncementsProvider);
                    if (detailContext.mounted) {
                      Navigator.pop(detailContext);
                    }
                  }
                }
              : null,
          onDelete: isMine
              ? () async {
                  await ref
                      .read(announcementRepositoryProvider)
                      .delete(a.id);
                  ref.invalidate(teamAnnouncementsProvider(a.teamId));
                  ref.invalidate(myAnnouncementsProvider);
                }
              : null,
        ),
      ),
    );
  }
}

/// 홈탭 공지사항 팀 필터 헤더.
///
/// 기존 [PopupMenuButton] 드롭다운을 [MoniqBottomSheet] 기반
/// [AnnouncementFilterChip]으로 통일했다.
class _TeamFilterHeader extends StatelessWidget {
  const _TeamFilterHeader({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.sm,
        AppSpacing.xxl,
        AppSpacing.xs,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: AnnouncementFilterChip(
          label: label,
          icon: Icons.groups_outlined,
          onTap: onTap,
        ),
      ),
    );
  }
}
