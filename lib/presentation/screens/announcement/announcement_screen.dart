import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moniq/data/models/announcement_model.dart';
import 'package:moniq/data/providers/announcement_providers.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/widgets/common/moniq_empty_state.dart';
import 'package:moniq/presentation/widgets/common/moniq_error_view.dart';
import 'package:moniq/presentation/widgets/common/moniq_loading_view.dart';

class AnnouncementScreen extends HookConsumerWidget {
  const AnnouncementScreen({super.key, required this.teamId});

  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final announcementsAsync =
        ref.watch(teamAnnouncementsProvider(teamId));

    return Scaffold(
      appBar: AppBar(title: const Text('팀 공지사항')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('공지 작성'),
      ),
      body: announcementsAsync.when(
        loading: () => const MoniqLoadingView(),
        error: (e, _) => MoniqErrorView(
          message: '공지사항을 불러올 수 없습니다',
          onRetry: () =>
              ref.invalidate(teamAnnouncementsProvider(teamId)),
        ),
        data: (announcements) {
          if (announcements.isEmpty) {
            return const MoniqEmptyState(
              icon: Icons.campaign_outlined,
              message: '등록된 공지사항이 없습니다',
              description: '팀원들에게 전달할 공지를 작성해보세요',
            );
          }

          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(teamAnnouncementsProvider(teamId)),
            child: ListView.separated(
              padding: AppSpacing.screenAll,
              itemCount: announcements.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final a = announcements[index];
                return AnnouncementListTile(
                  title: a.title,
                  content: a.content,
                  createdAt: a.createdAt,
                  isPinned: a.isPinned,
                  onTap: () => _showDetail(context, ref, a),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _showCreateSheet(BuildContext context, WidgetRef ref) {
    final titleC = TextEditingController();
    final contentC = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.xxl,
          right: AppSpacing.xxl,
          top: AppSpacing.xxl,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('공지사항 작성',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    )),
            const SizedBox(height: AppSpacing.xxl),
            TextField(
              controller: titleC,
              decoration: const InputDecoration(
                hintText: '제목',
                prefixIcon: Icon(Icons.title),
              ),
              maxLength: 50,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: contentC,
              decoration: const InputDecoration(
                hintText: '내용 (선택)',
                prefixIcon: Icon(Icons.notes),
              ),
              maxLines: 6,
              maxLength: 2000,
            ),
            const SizedBox(height: AppSpacing.xxl),
            ElevatedButton(
              onPressed: () async {
                final title = titleC.text.trim();
                if (title.isEmpty) return;

                final repo = ref.read(announcementRepositoryProvider);
                await repo.create(
                  teamId: teamId,
                  title: title,
                  content: contentC.text.trim().isNotEmpty
                      ? contentC.text.trim()
                      : null,
                );
                ref.invalidate(teamAnnouncementsProvider(teamId));
                ref.invalidate(myAnnouncementsProvider);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('공지사항이 등록되었습니다')),
                  );
                }
              },
              child: const Text('등록'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(
      BuildContext context, WidgetRef ref, AnnouncementModel a) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AnnouncementDetailPage(
          announcement: a,
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

// ══════════════════════════════════════════════
// 공용 위젯들 (팀 관리 + 홈탭 공유)
// ══════════════════════════════════════════════

/// 공지사항 리스트 타일 (공용)
class AnnouncementListTile extends StatelessWidget {
  const AnnouncementListTile({
    super.key,
    this.teamName,
    required this.title,
    this.content,
    this.createdAt,
    this.isPinned = false,
    required this.onTap,
  });

  final String? teamName;
  final String title;
  final String? content;
  final DateTime? createdAt;
  final bool isPinned;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MM.dd');

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.borderRadiusMd,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 팀 이름 (있는 경우)
                    if (teamName != null) ...[
                      Text(
                        teamName!,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                    ],
                    // 제목
                    Row(
                      children: [
                        if (isPinned) ...[
                          Icon(Icons.push_pin,
                              size: 14, color: AppColors.brandOrange),
                          const SizedBox(width: AppSpacing.xs),
                        ],
                        Expanded(
                          child: Text(
                            title,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    // 내용 미리보기
                    if (content != null && content!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        content!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              if (createdAt != null)
                Text(
                  dateFormat.format(createdAt!),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              const SizedBox(width: AppSpacing.xs),
              Icon(Icons.chevron_right,
                  size: 20, color: AppColors.outline),
            ],
          ),
        ),
      ),
    );
  }
}

/// 공지사항 상세 페이지 (공용)
class AnnouncementDetailPage extends StatelessWidget {
  const AnnouncementDetailPage({
    super.key,
    required this.announcement,
    this.teamName,
    this.onDelete,
  });

  final AnnouncementModel announcement;
  final String? teamName;
  final Future<void> Function()? onDelete;

  @override
  Widget build(BuildContext context) {
    final a = announcement;
    final dateFormat = DateFormat('yyyy.MM.dd HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: Text(teamName ?? '공지사항'),
        actions: [
          if (onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('공지 삭제'),
                    content: const Text('이 공지사항을 삭제하시겠습니까?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('취소'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('삭제',
                            style: TextStyle(color: AppColors.error)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await onDelete!();
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.screenAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (teamName != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: AppRadius.borderRadiusSm,
                ),
                child: Text(
                  teamName!,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            Text(
              a.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            if (a.createdAt != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                dateFormat.format(a.createdAt!),
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
            const Divider(height: AppSpacing.xxxl),
            if (a.content != null && a.content!.isNotEmpty)
              Text(
                a.content!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.6,
                    ),
              ),
          ],
        ),
      ),
    );
  }
}
