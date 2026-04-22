import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moniq/data/models/notification_model.dart';
import 'package:moniq/data/providers/notification_providers.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/widgets/common/moniq_empty_state.dart';
import 'package:moniq/presentation/widgets/common/moniq_error_view.dart';
import 'package:moniq/presentation/widgets/common/moniq_loading_view.dart';

class NotificationsScreen extends HookConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(myNotificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('알림'),
        actions: [
          TextButton(
            onPressed: () async {
              final repo = ref.read(notificationRepositoryProvider);
              await repo.markAllAsRead();
              ref.invalidate(myNotificationsProvider);
              ref.invalidate(unreadNotificationCountProvider);
            },
            child: const Text('모두 읽음'),
          ),
        ],
      ),
      body: listAsync.when(
        loading: () => const MoniqLoadingView(),
        error: (e, _) => MoniqErrorView(
          message: '알림을 불러올 수 없습니다',
          onRetry: () => ref.invalidate(myNotificationsProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const MoniqEmptyState(
              icon: Icons.notifications_off_outlined,
              message: '받은 알림이 없습니다',
              description: '팀의 공지·근무 변경 등이 여기에 표시됩니다',
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(myNotificationsProvider);
              ref.invalidate(unreadNotificationCountProvider);
            },
            child: ListView.separated(
              padding: AppSpacing.screenAll,
              itemCount: items.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                return _NotificationTile(
                  item: items[index],
                  onTap: () async {
                    final n = items[index];
                    if (!n.isRead) {
                      final repo = ref.read(notificationRepositoryProvider);
                      await repo.markAsRead(n.id);
                      ref.invalidate(myNotificationsProvider);
                      ref.invalidate(unreadNotificationCountProvider);
                    }
                  },
                  onDelete: () async {
                    final n = items[index];
                    final repo = ref.read(notificationRepositoryProvider);
                    await repo.delete(n.id);
                    ref.invalidate(myNotificationsProvider);
                    ref.invalidate(unreadNotificationCountProvider);
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.item,
    required this.onTap,
    required this.onDelete,
  });

  final NotificationModel item;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isUnread = !item.isRead;
    final dateLabel = _formatRelative(item.createdAt);

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        decoration: BoxDecoration(
          color: cs.error.withValues(alpha: 0.12),
          borderRadius: AppRadius.borderRadiusMd,
        ),
        child: Icon(Icons.delete_outline, color: cs.error),
      ),
      onDismissed: (_) => onDelete(),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.borderRadiusMd,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: isUnread
                ? cs.primaryContainer.withValues(alpha: 0.2)
                : cs.surfaceContainerLow,
            borderRadius: AppRadius.borderRadiusMd,
            border: Border.all(
              color: isUnread
                  ? cs.primary.withValues(alpha: 0.3)
                  : cs.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isUnread)
                Container(
                  margin: const EdgeInsets.only(
                    top: 6,
                    right: AppSpacing.sm,
                  ),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: cs.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: isUnread
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          dateLabel,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      item.body,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurface,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatRelative(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return DateFormat('MM.dd').format(dt);
  }
}
