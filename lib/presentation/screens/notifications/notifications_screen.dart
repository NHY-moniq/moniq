import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moniq/data/models/notification_model.dart';
import 'package:moniq/data/models/team_model.dart';
import 'package:moniq/data/providers/notification_providers.dart';
import 'package:moniq/data/providers/team_providers.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/team_calendar_viewmodel.dart';
import 'package:moniq/presentation/viewmodels/team_viewmodel.dart';
import 'package:moniq/presentation/widgets/common/moniq_app_bar.dart';
import 'package:moniq/presentation/widgets/common/moniq_bottom_sheet.dart';
import 'package:moniq/presentation/widgets/common/moniq_empty_state.dart';
import 'package:moniq/presentation/widgets/common/moniq_error_view.dart';
import 'package:moniq/presentation/widgets/common/moniq_loading_view.dart';

class NotificationsScreen extends HookConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(filteredNotificationsProvider);
    final teamsAsync = ref.watch(teamViewModelProvider);
    final selectedTeamId =
        ref.watch(selectedNotificationTeamFilterProvider);
    final unreadOnly = ref.watch(notificationUnreadOnlyProvider);
    final teams = teamsAsync.valueOrNull ?? const [];
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLow,
      appBar: MoniqAppBar(
        title: '알림함',
        eyebrow: 'NOTIFICATIONS',
        trailing: MoniqAppBarAction(
          icon: Icons.done_all_rounded,
          label: '모두 읽음',
          onTap: () async {
            final repo = ref.read(notificationRepositoryProvider);
            await repo.markAllAsRead();
            ref.invalidate(myNotificationsProvider);
            ref.invalidate(unreadNotificationCountProvider);
          },
        ),
      ),
      body: Column(
        children: [
          _NotificationFilterHeader(
            teams: teams,
            selectedTeamId: selectedTeamId,
            unreadOnly: unreadOnly,
            onTeamSelect: (id) => ref
                .read(selectedNotificationTeamFilterProvider.notifier)
                .state = id,
            onToggleUnread: () => ref
                .read(notificationUnreadOnlyProvider.notifier)
                .update((v) => !v),
          ),
          Expanded(
            child: listAsync.when(
              loading: () => const MoniqLoadingView(),
              error: (e, _) => MoniqErrorView(
                message: '알림을 불러올 수 없습니다',
                onRetry: () => ref.invalidate(myNotificationsProvider),
              ),
              data: (items) {
                if (items.isEmpty) {
                  final msg = unreadOnly
                      ? '안 읽은 알림이 없어요'
                      : selectedTeamId != null
                          ? '이 팀의 알림이 없어요'
                          : '받은 알림이 없어요';
                  return MoniqEmptyState.peaceful(
                    title: msg,
                    message: '30일 이내 알림만 표시돼요',
                  );
                }
                // 날짜 그룹별로 가벼운 섹션 헤더를 삽입한 평탄화 리스트.
                final rows = _buildGroupedRows(items);
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(myNotificationsProvider);
                    ref.invalidate(unreadNotificationCountProvider);
                  },
                  child: ListView.separated(
                    padding: AppSpacing.screenAll,
                    itemCount: rows.length,
                    separatorBuilder: (_, index) {
                      // 다음 행이 헤더면 섹션 간격을 더 넓게.
                      final next = rows[index + 1];
                      return SizedBox(
                        height: next is _HeaderRow
                            ? AppSpacing.lg
                            : AppSpacing.sm,
                      );
                    },
                    itemBuilder: (context, index) {
                      final row = rows[index];
                      if (row is _HeaderRow) {
                        return _SectionHeader(label: row.label);
                      }
                      final item = (row as _ItemRow).item;
                      return _NotificationTile(
                        item: item,
                        onTap: () async {
                          if (!item.isRead) {
                            final repo =
                                ref.read(notificationRepositoryProvider);
                            await repo.markAsRead(item.id);
                            ref.invalidate(myNotificationsProvider);
                            ref.invalidate(unreadNotificationCountProvider);
                          }
                          if (!context.mounted) return;
                          await _navigateForNotification(context, ref, item);
                        },
                        onDelete: () async {
                          final repo =
                              ref.read(notificationRepositoryProvider);
                          await repo.delete(item.id);
                          ref.invalidate(myNotificationsProvider);
                          ref.invalidate(unreadNotificationCountProvider);
                        },
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
}

/// 리스트 행 — 섹션 헤더 또는 알림 항목.
sealed class _Row {
  const _Row();
}

class _HeaderRow extends _Row {
  const _HeaderRow(this.label);
  final String label;
}

class _ItemRow extends _Row {
  const _ItemRow(this.item);
  final NotificationModel item;
}

/// 정렬된(최신순) 알림을 날짜 구간별 헤더와 함께 평탄화한다.
/// 구간: 오늘 / 어제 / 이번 주 / 이전.
List<_Row> _buildGroupedRows(List<NotificationModel> items) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final weekStart = today.subtract(const Duration(days: 7));

  String bucketOf(DateTime dt) {
    final d = DateTime(dt.year, dt.month, dt.day);
    if (!d.isBefore(today)) return '오늘';
    if (!d.isBefore(yesterday)) return '어제';
    if (!d.isBefore(weekStart)) return '이번 주';
    return '이전';
  }

  final rows = <_Row>[];
  String? current;
  for (final item in items) {
    final bucket = bucketOf(item.createdAt);
    if (bucket != current) {
      current = bucket;
      rows.add(_HeaderRow(bucket));
    }
    rows.add(_ItemRow(item));
  }
  return rows;
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.xxs),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: cs.onSurfaceVariant,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _NotificationFilterHeader extends StatelessWidget {
  const _NotificationFilterHeader({
    required this.teams,
    required this.selectedTeamId,
    required this.unreadOnly,
    required this.onTeamSelect,
    required this.onToggleUnread,
  });

  final List<TeamModel> teams;
  final String? selectedTeamId;
  final bool unreadOnly;
  final ValueChanged<String?> onTeamSelect;
  final VoidCallback onToggleUnread;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final selectedTeam = selectedTeamId == null
        ? null
        : teams.where((t) => t.id == selectedTeamId).firstOrNull;
    final teamLabel = selectedTeam?.name ?? '전체';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.sm,
        AppSpacing.xxl,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          if (teams.length > 1)
            InkWell(
              onTap: () => _openTeamFilterSheet(context),
              borderRadius: BorderRadius.circular(999),
              child: _Chip(
                icon: Icons.groups_outlined,
                label: teamLabel,
                trailing: Icons.expand_more_rounded,
                cs: cs,
              ),
            ),
          if (teams.length > 1) const SizedBox(width: AppSpacing.sm),
          InkWell(
            onTap: onToggleUnread,
            borderRadius: BorderRadius.circular(999),
            child: _Chip(
              icon:
                  unreadOnly ? Icons.mark_email_unread : Icons.mark_email_read,
              label: '안 읽음만',
              cs: cs,
              active: unreadOnly,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openTeamFilterSheet(BuildContext context) async {
    await showMoniqBottomSheet<void>(
      context: context,
      title: '팀 선택',
      eyebrow: 'FILTER',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MoniqSheetOption(
            icon: Icons.all_inbox_outlined,
            label: '전체 보기',
            description: '모든 팀의 알림을 표시해요',
            onTap: () {
              onTeamSelect(null);
              Navigator.pop(context);
            },
            trailing: selectedTeamId == null
                ? Icon(
                    Icons.check_circle_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  )
                : null,
          ),
          for (final t in teams)
            MoniqSheetOption(
              icon: Icons.groups_outlined,
              label: t.name,
              onTap: () {
                onTeamSelect(t.id);
                Navigator.pop(context);
              },
              trailing: selectedTeamId == t.id
                  ? Icon(
                      Icons.check_circle_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    required this.cs,
    this.trailing,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final IconData? trailing;
  final ColorScheme cs;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // request_list_screen의 `_FilterChip`과 톤 통일:
    // 선택 시 primary tint pill + 또렷한 라벨, 비선택은 차분한 surface.
    final bg = active
        ? cs.primary.withValues(alpha: 0.10)
        : cs.surfaceContainerHigh;
    final fg = active ? cs.primary : cs.onSurfaceVariant;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 7,
      ),
      decoration: ShapeDecoration(
        color: bg,
        shape: StadiumBorder(
          side: active
              ? BorderSide(color: cs.primary.withValues(alpha: 0.45))
              : const BorderSide(color: Colors.transparent),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: fg),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: fg,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 2),
            Icon(trailing, size: 16, color: fg),
          ],
        ],
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
    final isDark = cs.brightness == Brightness.dark;
    final isUnread = !item.isRead;
    final dateLabel = _formatRelative(item.createdAt);
    final accent = _NotifAccent.of(item, cs);

    // 설정 페이지(MoniqCard)와 동일한 카드 surface 토큰을 사용해 톤을 통일.
    final readSurface =
        isDark ? cs.surfaceContainer : cs.surfaceContainerLowest;
    // 안 읽음: 타입 악센트 컬러를 아주 옅게 깐 강조 배경 + 좌측 컬러 바.
    final bg = isUnread
        ? Color.alphaBlend(
            accent.color.withValues(alpha: isDark ? 0.10 : 0.06),
            readSurface,
          )
        : readSurface;

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        decoration: BoxDecoration(
          color: cs.error.withValues(alpha: 0.12),
          borderRadius: AppRadius.borderRadiusLg,
        ),
        child: Icon(Icons.delete_outline_rounded, color: cs.error),
      ),
      onDismissed: (_) => onDelete(),
      child: Material(
        color: bg,
        borderRadius: AppRadius.borderRadiusLg,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: AppRadius.borderRadiusLg,
              border: Border.all(
                color: isUnread
                    ? accent.color.withValues(alpha: 0.28)
                    : cs.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 좌측 컬러 바 — 안 읽음일 때만 또렷하게.
                  Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: isUnread
                          ? accent.color
                          : Colors.transparent,
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.lg,
                        AppSpacing.lg,
                        AppSpacing.lg,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 타입별 아이콘 칩.
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: accent.color
                                  .withValues(alpha: isDark ? 0.18 : 0.12),
                              borderRadius: AppRadius.borderRadiusSm,
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              accent.icon,
                              size: 20,
                              color: accent.color,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.title,
                                        style: theme.textTheme.bodyLarge
                                            ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: isUnread
                                              ? cs.onSurface
                                              : cs.onSurface
                                                  .withValues(alpha: 0.85),
                                          height: 1.25,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isUnread) ...[
                                      const SizedBox(width: AppSpacing.sm),
                                      Container(
                                        margin: const EdgeInsets.only(top: 6),
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: accent.color,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  item.body,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: cs.onSurfaceVariant,
                                    height: 1.4,
                                  ),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.schedule_rounded,
                                      size: 13,
                                      color: cs.onSurfaceVariant
                                          .withValues(alpha: 0.7),
                                    ),
                                    const SizedBox(width: AppSpacing.xxs),
                                    Text(
                                      dateLabel,
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                        color: cs.onSurfaceVariant
                                            .withValues(alpha: 0.85),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
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

/// 알림 타입별 아이콘 + 악센트 컬러. `_classifyNotification`의 분류를
/// 시각 표현으로 매핑한다(데이터/라우팅 로직과 독립적인 표시용 헬퍼).
class _NotifAccent {
  const _NotifAccent(this.icon, this.color);
  final IconData icon;
  final Color color;

  static _NotifAccent of(NotificationModel n, ColorScheme cs) {
    switch (_classifyNotification(n)) {
      case _NotifTarget.requests:
        return _NotifAccent(Icons.swap_horiz_rounded, cs.tertiary);
      case _NotifTarget.teamCalendar:
        return _NotifAccent(Icons.event_available_rounded, cs.primary);
      case _NotifTarget.wanted:
        return _NotifAccent(Icons.event_note_rounded, cs.secondary);
      case _NotifTarget.announcements:
        return _NotifAccent(Icons.campaign_rounded, cs.tertiary);
      case _NotifTarget.none:
        return _NotifAccent(
          Icons.notifications_rounded,
          cs.onSurfaceVariant,
        );
    }
  }
}

/// 알림 카테고리 — 이동할 화면 종류
enum _NotifTarget {
  requests, // 변경 요청 화면
  teamCalendar, // 팀 탭(캘린더) — 즐겨찾기 팀 전환 후 이동
  wanted, // 원티드 입력
  announcements, // 팀 공지
  none,
}

/// data.type 우선, 없으면 제목/본문 텍스트로 fallback 매칭
_NotifTarget _classifyNotification(NotificationModel n) {
  final type = n.data['type'] as String?;
  switch (type) {
    case 'request':
    case 'swap_request':
    case 'shift_change_request':
      return _NotifTarget.requests;
    case 'shift_changed':
    case 'schedule_published':
      return _NotifTarget.teamCalendar;
    case 'wanted_open':
    case 'wanted_close':
      return _NotifTarget.wanted;
    case 'announcement':
      return _NotifTarget.announcements;
  }

  // legacy 알림 — type 없을 때 제목/본문으로 추정
  final text = '${n.title} ${n.body}';
  if (text.contains('요청')) return _NotifTarget.requests;
  if (text.contains('원티드')) return _NotifTarget.wanted;
  if (text.contains('공지')) return _NotifTarget.announcements;
  if (text.contains('근무표') ||
      text.contains('근무 변경') ||
      text.contains('근무 추가') ||
      text.contains('근무 삭제') ||
      text.contains('근무가 변경') ||
      text.contains('근무가 추가') ||
      text.contains('근무가 삭제')) {
    return _NotifTarget.teamCalendar;
  }
  return _NotifTarget.none;
}

/// 알림 페이로드 또는 본문 텍스트에서 변경 발생일 추출.
/// 우선순위: data.change_date(YYYY-MM-DD) → 본문에서 'M/D' or 'YYYY.MM.DD' 패턴.
DateTime? _extractChangeDate(NotificationModel n) {
  final raw = n.data['change_date'] as String?;
  if (raw != null && raw.isNotEmpty) {
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) return parsed;
  }
  // 본문 fallback — 'M/D', 'M월 D일', 'YYYY.MM.DD' 패턴
  final text = '${n.title} ${n.body}';
  // YYYY-MM-DD or YYYY.MM.DD or YYYY/MM/DD
  final fullPattern = RegExp(r'(\d{4})[./-](\d{1,2})[./-](\d{1,2})');
  final fullMatch = fullPattern.firstMatch(text);
  if (fullMatch != null) {
    final y = int.tryParse(fullMatch.group(1)!);
    final m = int.tryParse(fullMatch.group(2)!);
    final d = int.tryParse(fullMatch.group(3)!);
    if (y != null && m != null && d != null) {
      return DateTime(y, m, d);
    }
  }
  // 'M/D' or 'M월 D일' — 현재 연도로 가정
  final shortPattern = RegExp(r'(\d{1,2})[월/](\s*\d{1,2})');
  final shortMatch = shortPattern.firstMatch(text);
  if (shortMatch != null) {
    final m = int.tryParse(shortMatch.group(1)!);
    final d = int.tryParse(shortMatch.group(2)!.trim());
    if (m != null && d != null && m >= 1 && m <= 12 && d >= 1 && d <= 31) {
      // createdAt 연도를 우선 사용 (오래된 알림은 그 시점의 연도)
      return DateTime(n.createdAt.year, m, d);
    }
  }
  // 최종 fallback: 알림 생성 시점의 월 (오래된 알림에서 정확한 shift_date 추출 불가 시)
  return DateTime(n.createdAt.year, n.createdAt.month, n.createdAt.day);
}

Future<void> _navigateForNotification(
  BuildContext context,
  WidgetRef ref,
  NotificationModel n,
) async {
  final target = _classifyNotification(n);
  final teamId = (n.data['team_id'] as String?) ?? n.teamId;
  if (target == _NotifTarget.none || teamId == null) return;

  switch (target) {
    case _NotifTarget.requests:
      context.push('/teams/$teamId/requests');
      break;
    case _NotifTarget.wanted:
      context.push('/teams/$teamId/wanted/entry');
      break;
    case _NotifTarget.announcements:
      context.push('/teams/$teamId/announcements');
      break;
    case _NotifTarget.teamCalendar:
      // 변경 발생일이 있으면 해당 월에 포커스되도록 pending 설정
      final focusDate = _extractChangeDate(n);
      if (focusDate != null) {
        ref
            .read(pendingTeamCalendarFocusProvider(teamId).notifier)
            .state = focusDate;
      }
      // 알림 발생 팀을 즐겨찾기로 설정 후 팀 탭으로 이동.
      try {
        await ref.read(teamRepositoryProvider).setFavoriteTeam(teamId);
        ref.invalidate(favoriteTeamProvider);
        ref.invalidate(teamCalendarViewModelProvider(teamId));
      } catch (_) {}
      if (!context.mounted) return;
      context.go('/teams');
      break;
    case _NotifTarget.none:
      break;
  }
}
