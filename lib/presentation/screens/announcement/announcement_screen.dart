import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moniq/data/models/announcement_model.dart';
import 'package:moniq/data/providers/announcement_providers.dart';
import 'package:moniq/data/providers/auth_providers.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/theme/app_typography.dart';
import 'package:moniq/presentation/viewmodels/announcement_viewmodel.dart';
import 'package:moniq/presentation/widgets/announcement/announcement_author.dart';
import 'package:moniq/presentation/widgets/announcement/announcement_filter_sheet.dart';
import 'package:moniq/presentation/widgets/common/banner_ad_widget.dart';
import 'package:moniq/presentation/widgets/common/moniq_app_bar.dart';
import 'package:moniq/presentation/widgets/common/moniq_bottom_sheet.dart';
import 'package:moniq/presentation/widgets/common/moniq_empty_state.dart';
import 'package:moniq/presentation/widgets/common/moniq_error_view.dart';
import 'package:moniq/presentation/widgets/common/moniq_loading_view.dart';

part 'announcement_sheets.dart';
part 'announcement_widgets.dart';
part 'announcement_detail_page.dart';

/// 팀 공지사항 화면 필터 — DropdownButton 대신 바텀시트로 선택.
enum _AnnouncementFilter { all, pinned }

/// 팀 공지사항 화면의 선택된 필터.
final _teamAnnouncementFilterProvider =
    StateProvider.autoDispose<_AnnouncementFilter>(
  (_) => _AnnouncementFilter.all,
);

class AnnouncementScreen extends HookConsumerWidget {
  const AnnouncementScreen({super.key, required this.teamId});

  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final announcementsAsync =
        ref.watch(teamAnnouncementsProvider(teamId));
    final filter = ref.watch(_teamAnnouncementFilterProvider);
    final pinnedIds = ref.watch(pinnedAnnouncementIdsProvider);

    return Scaffold(
      appBar: const MoniqAppBar(title: '공지사항'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('공지 작성'),
      ),
      body: Column(
        children: [
          // 배너 광고 — 공지사항 상단. 모바일 전용(웹/미지원 시 빈 위젯, 공간 차지 안 함).
          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.xxl,
              AppSpacing.sm,
              AppSpacing.xxl,
              0,
            ),
            child: BannerAdWidget(),
          ),
          Expanded(
            child: announcementsAsync.when(
        loading: () => const MoniqLoadingView(),
        error: (e, _) => MoniqErrorView(
          message: '공지사항을 불러올 수 없습니다',
          onRetry: () =>
              ref.invalidate(teamAnnouncementsProvider(teamId)),
        ),
        data: (announcements) {
          if (announcements.isEmpty) {
            return MoniqEmptyState.encouraging(
              title: '아직 등록된 공지가 없어요',
              message: '팀원들에게 전달할 공지를 작성해보세요',
            );
          }

          // 개인 핀 기준으로 정렬: 내가 고정한 것 먼저, 그 안에서도 최신순
          final sorted = [...announcements]..sort((a, b) {
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

          final visible = filter == _AnnouncementFilter.pinned
              ? sorted.where((a) => pinnedIds.contains(a.id)).toList()
              : sorted;

          return Column(
            children: [
              _AnnouncementFilterBar(
                filter: filter,
                onTap: () => _showFilterSheet(context, ref, filter),
              ),
              Expanded(
                child: visible.isEmpty
                    ? MoniqEmptyState.peaceful(
                        title: '고정된 공지가 없어요',
                        message: '공지 카드의 핀 아이콘을 눌러 상단에 고정하세요',
                      )
                    : RefreshIndicator(
                        onRefresh: () async => ref.invalidate(
                            teamAnnouncementsProvider(teamId)),
                        child: SlidableAutoCloseBehavior(
                          child: ListView.builder(
                            padding: AppSpacing.screenAll,
                            itemCount: visible.length,
                            itemBuilder: (context, index) {
                              final a = visible[index];
                              final isPinnedLocally =
                                  pinnedIds.contains(a.id);
                              return Padding(
                                padding: const EdgeInsets.only(
                                    bottom: AppSpacing.sm),
                                child: Slidable(
                                  key: ValueKey(a.id),
                                  startActionPane: ActionPane(
                                    motion: const BehindMotion(),
                                    extentRatio: 0.28,
                                    children: [
                                      SlidableAction(
                                        onPressed: (_) => ref
                                            .read(
                                                pinnedAnnouncementIdsProvider
                                                    .notifier)
                                            .toggle(a.id),
                                        backgroundColor: isPinnedLocally
                                            ? AppColors.brandOrange
                                            : AppColors.primary,
                                        foregroundColor: Colors.white,
                                        icon: isPinnedLocally
                                            ? Icons.push_pin
                                            : Icons.push_pin_outlined,
                                        label:
                                            isPinnedLocally ? '해제' : '고정',
                                        borderRadius:
                                            AppRadius.borderRadiusLg,
                                      ),
                                    ],
                                  ),
                                  child: AnnouncementListTile(
                                    key: ValueKey('tile_${a.id}'),
                                    announcement: a,
                                    isPinnedLocally: isPinnedLocally,
                                    onTap: () =>
                                        _showDetail(context, ref, a),
                                    onTogglePin: () => ref
                                        .read(pinnedAnnouncementIdsProvider
                                            .notifier)
                                        .toggle(a.id),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
              ),
            ],
          );
        },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showFilterSheet(
    BuildContext context,
    WidgetRef ref,
    _AnnouncementFilter current,
  ) async {
    final picked = await showAnnouncementFilterSheet<_AnnouncementFilter>(
      context: context,
      title: '공지 필터',
      selectedValue: current,
      options: const [
        AnnouncementFilterOption(
          value: _AnnouncementFilter.all,
          label: '전체 공지',
          icon: Icons.campaign_outlined,
        ),
        AnnouncementFilterOption(
          value: _AnnouncementFilter.pinned,
          label: '고정된 공지만',
          icon: Icons.push_pin_outlined,
        ),
      ],
    );
    if (picked != null) {
      ref.read(_teamAnnouncementFilterProvider.notifier).state =
          picked.value;
    }
  }

  void _showCreateSheet(BuildContext context, WidgetRef ref) {
    // 다른 시트와 동일한 MoniqBottomSheetShell 스타일로 통일.
    showMoniqBottomSheet<void>(
      context: context,
      eyebrow: 'ANNOUNCE',
      title: '공지사항 작성',
      child: _AnnouncementCreateSheet(teamId: teamId),
    );
  }

  void _showDetail(
      BuildContext context, WidgetRef ref, AnnouncementModel a) {
    final myUserId = ref.read(currentUserProvider)?.id;
    final isMine = myUserId != null && a.createdBy == myUserId;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (detailContext) => AnnouncementDetailPage(
          announcement: a,
          onEdit: isMine
              ? () async {
                  final updated = await showAnnouncementEditSheet(
                      detailContext, a);
                  if (updated == true) {
                    ref.invalidate(teamAnnouncementsProvider(teamId));
                    ref.invalidate(myAnnouncementsProvider);
                    if (detailContext.mounted) {
                      Navigator.pop(detailContext);
                    }
                  }
                }
              : null,
          onDelete: () async {
            final repo = ref.read(announcementRepositoryProvider);
            await repo.delete(a.id);
            ref.invalidate(teamAnnouncementsProvider(teamId));
            ref.invalidate(myAnnouncementsProvider);
          },
        ),
      ),
    );
  }
}

