import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/models/announcement_model.dart';
import 'package:moniq/data/models/team_model.dart';
import 'package:moniq/data/providers/announcement_providers.dart';
import 'package:moniq/data/providers/auth_providers.dart';
import 'package:moniq/presentation/screens/announcement/announcement_screen.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/team_viewmodel.dart';
import 'package:moniq/presentation/widgets/announcement/announcement_filter_sheet.dart';
import 'package:moniq/presentation/widgets/common/moniq_app_bar.dart';
import 'package:moniq/presentation/widgets/common/moniq_empty_state.dart';
import 'package:moniq/presentation/widgets/common/moniq_error_view.dart';
import 'package:moniq/presentation/widgets/common/moniq_loading_view.dart';

/// 홈탭에서 진입하는 내 팀 전체 공지사항 리스트 (무한 스크롤)
class MyAnnouncementsScreen extends HookConsumerWidget {
  const MyAnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(myAnnouncementsProvider);
    final teamsAsync = ref.watch(teamViewModelProvider);
    final selectedTeamId =
        ref.watch(selectedAnnouncementTeamFilterProvider);
    final teams = teamsAsync.valueOrNull ?? const [];
    final selectedTeam = selectedTeamId == null
        ? null
        : teams.where((t) => t.id == selectedTeamId).firstOrNull;
    final filterLabel = selectedTeam?.name ?? '전체';

    final scrollCtrl = useScrollController();

    // 하단 도달 시 loadMore 호출
    useEffect(() {
      void listener() {
        final pos = scrollCtrl.position;
        if (pos.pixels >= pos.maxScrollExtent - 200) {
          ref.read(myAnnouncementsProvider.notifier).loadMore();
        }
      }

      scrollCtrl.addListener(listener);
      return () => scrollCtrl.removeListener(listener);
    }, [scrollCtrl]);

    return Scaffold(
      appBar: const MoniqAppBar(title: '공지사항'),
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
            child: listAsync.when(
              loading: () => const MoniqLoadingView(),
              error: (e, _) => MoniqErrorView(
                message: '공지사항을 불러올 수 없습니다',
                onRetry: () => ref
                    .read(myAnnouncementsProvider.notifier)
                    .refresh(),
              ),
              data: (listState) {
                final items = listState.items;

                if (items.isEmpty && !listState.isLoadingMore) {
                  return MoniqEmptyState.peaceful(
                    title: '공지사항이 없어요',
                    message: selectedTeam == null
                        ? '팀 관리자가 공지를 등록하면 여기에 표시돼요'
                        : '${selectedTeam.name}에 공지가 없어요',
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => ref
                      .read(myAnnouncementsProvider.notifier)
                      .refresh(),
                  child: ListView.builder(
                    controller: scrollCtrl,
                    padding: AppSpacing.screenAll,
                    // 아이템 + 구분선 + (로딩 스피너 or 빈 공간)
                    itemCount: items.length * 2 + 1,
                    itemBuilder: (context, index) {
                      // 홀수 인덱스: 구분선
                      if (index.isOdd && index < items.length * 2) {
                        return const SizedBox(height: AppSpacing.sm);
                      }
                      // 마지막 인덱스: 하단 로딩 인디케이터
                      if (index == items.length * 2) {
                        return _BottomLoadingIndicator(
                          visible: listState.isLoadingMore,
                        );
                      }
                      final itemIndex = index ~/ 2;
                      final item = items[itemIndex];
                      final a = item.announcement;
                      return AnnouncementListTile(
                        announcement: a,
                        teamName: item.teamName,
                        onTap: () => _showDetail(context, ref, item),
                      );
                    },
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
    BuildContext context,
    WidgetRef ref,
    AnnouncementWithTeam item,
  ) {
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
                    detailContext,
                    a,
                  );
                  if (updated == true) {
                    ref.invalidate(
                      teamAnnouncementsProvider(a.teamId),
                    );
                    ref
                        .read(myAnnouncementsProvider.notifier)
                        .refresh();
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
                  ref
                      .read(myAnnouncementsProvider.notifier)
                      .refresh();
                }
              : null,
        ),
      ),
    );
  }
}

/// 홈탭 공지사항 팀 필터 헤더.
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

/// 리스트 하단 로딩 인디케이터 (hasMore && isLoadingMore 시 표시).
class _BottomLoadingIndicator extends StatelessWidget {
  const _BottomLoadingIndicator({required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return const SizedBox(
      height: AppSpacing.huge,
      child: Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}
