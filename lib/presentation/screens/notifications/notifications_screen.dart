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

// ---------------------------------------------------------------------------
// 카테고리 분류 (UI 표시용)
// ---------------------------------------------------------------------------

/// 알림 카테고리 — 이동할 화면 종류
enum _NotifTarget {
  requests, // 변경 요청 화면
  teamCalendar, // 팀 탭(캘린더) — 즐겨찾기 팀 전환 후 이동
  wanted, // 원티드 입력
  announcements, // 팀 공지
  none,
}

/// [_NotifTarget] → 화면에 표시할 카테고리 라벨.
String _categoryLabel(_NotifTarget target) {
  switch (target) {
    case _NotifTarget.teamCalendar:
      return '근무 변경';
    case _NotifTarget.requests:
      return '요청';
    case _NotifTarget.announcements:
      return '공지';
    case _NotifTarget.wanted:
      return '원티드';
    case _NotifTarget.none:
      return '기타';
  }
}

/// 카테고리 표시 순서.
const _categoryOrder = [
  '근무 변경',
  '요청',
  '공지',
  '원티드',
  '기타',
];

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
DateTime? _extractChangeDate(NotificationModel n) {
  final raw = n.data['change_date'] as String?;
  if (raw != null && raw.isNotEmpty) {
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) return parsed;
  }
  final text = '${n.title} ${n.body}';
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
  final shortPattern = RegExp(r'(\d{1,2})[월/](\s*\d{1,2})');
  final shortMatch = shortPattern.firstMatch(text);
  if (shortMatch != null) {
    final m = int.tryParse(shortMatch.group(1)!);
    final d = int.tryParse(shortMatch.group(2)!.trim());
    if (m != null && d != null && m >= 1 && m <= 12 && d >= 1 && d <= 31) {
      return DateTime(n.createdAt.year, m, d);
    }
  }
  return DateTime(n.createdAt.year, n.createdAt.month, n.createdAt.day);
}

// ---------------------------------------------------------------------------
// 메인 화면
// ---------------------------------------------------------------------------

class NotificationsScreen extends StatefulHookConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState
    extends ConsumerState<NotificationsScreen> {
  // ── 그룹 펼치기/접기 상태 (카테고리명 → 펼침 여부)
  final Map<String, bool> _expanded = {
    for (final c in _categoryOrder) c: true,
  };

  // ── 선택 모드 상태
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

  void _enterSelectionMode(String firstId) {
    setState(() {
      _selectionMode = true;
      _selectedIds
        ..clear()
        ..add(firstId);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _selectionMode = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _deleteSelected() async {
    final ids = List<String>.from(_selectedIds);
    final repo = ref.read(notificationRepositoryProvider);
    for (final id in ids) {
      await repo.delete(id);
    }
    ref.invalidate(myNotificationsProvider);
    ref.invalidate(unreadNotificationCountProvider);
    _exitSelectionMode();
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(filteredNotificationsProvider);
    final teamsAsync = ref.watch(teamViewModelProvider);
    final selectedTeamId =
        ref.watch(selectedNotificationTeamFilterProvider);
    final unreadOnly = ref.watch(notificationUnreadOnlyProvider);
    final teams = teamsAsync.valueOrNull ?? const [];
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLow,
      appBar: _selectionMode
          ? _SelectionAppBar(
              count: _selectedIds.length,
              onCancel: _exitSelectionMode,
              onDelete: _selectedIds.isNotEmpty ? _deleteSelected : null,
            )
          : MoniqAppBar(
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
                return _GroupedNotificationList(
                  items: items,
                  expanded: _expanded,
                  selectionMode: _selectionMode,
                  selectedIds: _selectedIds,
                  onToggleGroup: (cat) {
                    setState(() {
                      _expanded[cat] = !(_expanded[cat] ?? true);
                    });
                  },
                  onTap: (n) async {
                    if (_selectionMode) {
                      _toggleSelection(n.id);
                      return;
                    }
                    if (!n.isRead) {
                      final repo = ref.read(notificationRepositoryProvider);
                      await repo.markAsRead(n.id);
                      ref.invalidate(myNotificationsProvider);
                      ref.invalidate(unreadNotificationCountProvider);
                    }
                    if (!context.mounted) return;
                    await _navigateForNotification(context, ref, n);
                  },
                  onLongPress: (n) {
                    if (!_selectionMode) {
                      _enterSelectionMode(n.id);
                    }
                  },
                  onDelete: (n) async {
                    final repo = ref.read(notificationRepositoryProvider);
                    await repo.delete(n.id);
                    ref.invalidate(myNotificationsProvider);
                    ref.invalidate(unreadNotificationCountProvider);
                  },
                  onRefresh: () async {
                    ref.invalidate(myNotificationsProvider);
                    ref.invalidate(unreadNotificationCountProvider);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 선택 모드 앱바
// ---------------------------------------------------------------------------

class _SelectionAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _SelectionAppBar({
    required this.count,
    required this.onCancel,
    required this.onDelete,
  });

  final int count;
  final VoidCallback onCancel;
  final VoidCallback? onDelete;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppBar(
      backgroundColor: cs.surfaceContainerLow,
      leading: IconButton(
        icon: const Icon(Icons.close_rounded),
        onPressed: onCancel,
        tooltip: '선택 취소',
      ),
      title: Text(
        '$count개 선택됨',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
      actions: [
        IconButton(
          icon: Icon(
            Icons.delete_outline_rounded,
            color: onDelete != null ? cs.error : cs.onSurface.withValues(alpha: 0.3),
          ),
          onPressed: onDelete,
          tooltip: '선택 항목 삭제',
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 그룹핑된 리스트
// ---------------------------------------------------------------------------

class _GroupedNotificationList extends StatelessWidget {
  const _GroupedNotificationList({
    required this.items,
    required this.expanded,
    required this.selectionMode,
    required this.selectedIds,
    required this.onToggleGroup,
    required this.onTap,
    required this.onLongPress,
    required this.onDelete,
    required this.onRefresh,
  });

  final List<NotificationModel> items;
  final Map<String, bool> expanded;
  final bool selectionMode;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggleGroup;
  final ValueChanged<NotificationModel> onTap;
  final ValueChanged<NotificationModel> onLongPress;
  final ValueChanged<NotificationModel> onDelete;
  final Future<void> Function() onRefresh;

  /// items를 카테고리별로 그룹핑. 순서는 [_categoryOrder] 기준.
  Map<String, List<NotificationModel>> _group() {
    final map = <String, List<NotificationModel>>{};
    for (final n in items) {
      final label = _categoryLabel(_classifyNotification(n));
      map.putIfAbsent(label, () => []).add(n);
    }
    // categoryOrder 순으로 정렬
    return {
      for (final cat in _categoryOrder)
        if (map.containsKey(cat)) cat: map[cat]!,
    };
  }

  @override
  Widget build(BuildContext context) {
    final groups = _group();

    // 플랫 아이템 리스트 구성: 헤더 + (펼쳐진 경우) 알림 타일
    final rows = <_ListRow>[];
    for (final entry in groups.entries) {
      final cat = entry.key;
      final notifs = entry.value;
      final isExpanded = expanded[cat] ?? true;
      rows.add(_ListRow.header(cat, notifs.length));
      if (isExpanded) {
        for (final n in notifs) {
          rows.add(_ListRow.tile(n));
        }
      }
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: AppSpacing.screenAll,
        itemCount: rows.length,
        itemBuilder: (context, index) {
          final row = rows[index];
          if (row.isHeader) {
            return _GroupHeader(
              category: row.category!,
              count: row.count!,
              isExpanded: expanded[row.category!] ?? true,
              onToggle: () => onToggleGroup(row.category!),
            );
          }
          final n = row.notification!;
          final isSelected = selectedIds.contains(n.id);
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _NotificationTile(
              item: n,
              selectionMode: selectionMode,
              isSelected: isSelected,
              onTap: () => onTap(n),
              onLongPress: () => onLongPress(n),
              onDelete: () => onDelete(n),
            ),
          );
        },
      ),
    );
  }
}

/// 리스트 행 — 헤더 또는 타일을 구분하는 sealed-style 데이터 클래스.
class _ListRow {
  _ListRow._({
    required this.isHeader,
    this.category,
    this.count,
    this.notification,
  });

  factory _ListRow.header(String category, int count) => _ListRow._(
        isHeader: true,
        category: category,
        count: count,
      );

  factory _ListRow.tile(NotificationModel n) => _ListRow._(
        isHeader: false,
        notification: n,
      );

  final bool isHeader;
  final String? category;
  final int? count;
  final NotificationModel? notification;
}

// ---------------------------------------------------------------------------
// 그룹 헤더
// ---------------------------------------------------------------------------

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.category,
    required this.count,
    required this.isExpanded,
    required this.onToggle,
  });

  final String category;
  final int count;
  final bool isExpanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return InkWell(
      onTap: onToggle,
      borderRadius: AppRadius.borderRadiusSm,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.sm,
          horizontal: AppSpacing.xs,
        ),
        child: Row(
          children: [
            Text(
              '$category  ($count건)',
              style: theme.textTheme.labelMedium?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
            const Spacer(),
            Icon(
              isExpanded
                  ? Icons.expand_more_rounded
                  : Icons.chevron_right_rounded,
              size: 18,
              color: cs.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 알림 타일
// ---------------------------------------------------------------------------

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.item,
    required this.selectionMode,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
    required this.onDelete,
  });

  final NotificationModel item;
  final bool selectionMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isUnread = !item.isRead;
    final dateLabel = _formatRelative(item.createdAt);

    // ── 배경 및 텍스트 색상 (작업 2)
    final Color tileBg;
    final Color titleColor;
    final Color bodyColor;

    if (isSelected) {
      tileBg = cs.primary.withValues(alpha: 0.12);
      titleColor = cs.onSurface;
      bodyColor = cs.onSurface;
    } else if (isUnread) {
      tileBg = cs.primaryContainer.withValues(alpha: 0.2);
      titleColor = cs.onSurface;
      bodyColor = cs.onSurface;
    } else {
      // 읽음: surfaceContainerLowest + 텍스트 dim
      tileBg = cs.surfaceContainerLowest;
      titleColor = cs.onSurface.withValues(alpha: 0.45);
      bodyColor = cs.onSurface.withValues(alpha: 0.45);
    }

    final borderColor = isSelected
        ? cs.primary.withValues(alpha: 0.5)
        : isUnread
            ? cs.primary.withValues(alpha: 0.3)
            : cs.outlineVariant.withValues(alpha: 0.3);

    Widget tile = InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: AppRadius.borderRadiusMd,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: tileBg,
          borderRadius: AppRadius.borderRadiusMd,
          border: Border.all(color: borderColor),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 체크박스 (선택 모드) 또는 읽지 않음 dot
            if (selectionMode)
              Padding(
                padding: const EdgeInsets.only(
                  top: 2,
                  right: AppSpacing.sm,
                ),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: Checkbox(
                    value: isSelected,
                    onChanged: (_) => onTap(),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    side: BorderSide(
                      color: cs.outline,
                      width: 1.5,
                    ),
                  ),
                ),
              )
            else if (isUnread)
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
                            fontWeight: isUnread && !isSelected
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: titleColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        dateLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant.withValues(
                            alpha: isUnread ? 1.0 : 0.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    item.body,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: bodyColor,
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
    );

    // 선택 모드일 때는 Dismissible 비활성화 (스와이프 충돌 방지)
    if (selectionMode) return tile;

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
      child: tile,
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

// ---------------------------------------------------------------------------
// 필터 헤더
// ---------------------------------------------------------------------------

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
              icon: unreadOnly
                  ? Icons.mark_email_unread
                  : Icons.mark_email_read,
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

// ---------------------------------------------------------------------------
// 칩 위젯
// ---------------------------------------------------------------------------

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
    final isDark = cs.brightness == Brightness.dark;
    final bg = active
        ? cs.primary.withValues(alpha: 0.15)
        : (isDark ? cs.surfaceContainer : cs.surfaceContainerLowest);
    final fg = active ? cs.primary : cs.onSurface;
    final borderColor = active
        ? cs.primary.withValues(alpha: 0.5)
        : cs.outlineVariant.withValues(alpha: 0.5);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 2),
            Icon(trailing, size: 16, color: cs.onSurfaceVariant),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 알림 탭 네비게이션
// ---------------------------------------------------------------------------

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
      final focusDate = _extractChangeDate(n);
      if (focusDate != null) {
        ref
            .read(pendingTeamCalendarFocusProvider(teamId).notifier)
            .state = focusDate;
      }
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
