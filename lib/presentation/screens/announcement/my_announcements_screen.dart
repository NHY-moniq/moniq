import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/models/announcement_model.dart';
import 'package:moniq/data/providers/announcement_providers.dart';
import 'package:moniq/presentation/screens/announcement/announcement_screen.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/widgets/common/moniq_empty_state.dart';
import 'package:moniq/presentation/widgets/common/moniq_error_view.dart';
import 'package:moniq/presentation/widgets/common/moniq_loading_view.dart';

/// 홈탭에서 진입하는 내 팀 전체 공지사항 리스트
class MyAnnouncementsScreen extends HookConsumerWidget {
  const MyAnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final announcementsAsync = ref.watch(myAnnouncementsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('팀 공지사항')),
      body: announcementsAsync.when(
        loading: () => const MoniqLoadingView(),
        error: (e, _) => MoniqErrorView(
          message: '공지사항을 불러올 수 없습니다',
          onRetry: () => ref.invalidate(myAnnouncementsProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const MoniqEmptyState(
              icon: Icons.campaign_outlined,
              message: '공지사항이 없습니다',
              description: '팀 관리자가 공지를 등록하면 여기에 표시됩니다',
            );
          }

          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(myAnnouncementsProvider),
            child: ListView.separated(
              padding: AppSpacing.screenAll,
              itemCount: items.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final item = items[index];
                final a = item.announcement;
                return AnnouncementListTile(
                  teamName: item.teamName,
                  title: a.title,
                  content: a.content,
                  createdAt: a.createdAt,
                  isPinned: a.isPinned,
                  onTap: () => _showDetail(context, item),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _showDetail(BuildContext context, AnnouncementWithTeam item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AnnouncementDetailPage(
          announcement: item.announcement,
          teamName: item.teamName,
        ),
      ),
    );
  }
}
