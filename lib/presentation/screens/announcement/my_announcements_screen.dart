import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/models/announcement_model.dart';
import 'package:moniq/data/models/team_model.dart';
import 'package:moniq/data/providers/announcement_providers.dart';
import 'package:moniq/data/providers/auth_providers.dart';
import 'package:moniq/presentation/screens/announcement/announcement_screen.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/team_viewmodel.dart';
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _onCreateTap(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('공지 작성'),
      ),
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
                  onTap: () => _showDetail(context, ref, item),
                );
              },
            ),
          );
        },
      ),
    );
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
