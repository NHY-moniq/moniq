import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moniq/data/models/request_model.dart';
import 'package:moniq/presentation/screens/request/request_list_screen.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/request_viewmodel.dart';
import 'package:moniq/presentation/widgets/common/moniq_app_bar.dart';
import 'package:moniq/presentation/widgets/common/moniq_bottom_sheet.dart';
import 'package:moniq/presentation/widgets/common/moniq_empty_state.dart';
import 'package:moniq/presentation/widgets/common/moniq_error_view.dart';
import 'package:moniq/presentation/widgets/common/moniq_loading_view.dart';

/// 근무 변경 요청 히스토리 — 최근 6개월. 그 이전 기록은 자동 삭제.
class RequestHistoryScreen extends ConsumerStatefulWidget {
  const RequestHistoryScreen({super.key, required this.teamId});

  final String teamId;

  @override
  ConsumerState<RequestHistoryScreen> createState() =>
      _RequestHistoryScreenState();
}

class _RequestHistoryScreenState extends ConsumerState<RequestHistoryScreen> {
  bool _purgedOldRecords = false;

  // 선택 모드 상태 (메인 요청 목록과 동일한 패턴)
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

  /// 그룹 단위 토글: 전체 entry 묶음 선택/해제.
  void _toggleSelectionGroup(RequestGroup g) {
    setState(() {
      final allSelected = g.ids.every(_selectedIds.contains);
      if (allSelected) {
        _selectedIds.removeAll(g.ids);
      } else {
        _selectedIds.addAll(g.ids);
      }
    });
  }

  /// 레코드 길게 누르기 → 선택 모드 진입 + 해당 그룹 선택
  void _onLongPressGroup(RequestGroup g) {
    if (!_selectionMode) {
      setState(() => _selectionMode = true);
    }
    _toggleSelectionGroup(g);
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  /// 전체 선택 토글 (가시 목록 기준 — 현재 히스토리에 보이는 그룹 ids 합집합)
  void _toggleSelectAll(List<RequestGroup> visible) {
    setState(() {
      final allIds = visible.expand((g) => g.ids).toSet();
      final isAllSelected =
          allIds.isNotEmpty && allIds.every(_selectedIds.contains);
      if (isAllSelected) {
        _selectedIds.removeWhere(allIds.contains);
      } else {
        _selectedIds.addAll(allIds);
      }
    });
  }

  /// pending(대기중)은 삭제 불가 규칙을 적용해 선택된 레코드를 일괄 삭제한다.
  /// 메인 요청 목록의 `_bulkDelete`와 동일한 규칙을 따른다.
  Future<void> _bulkDelete(List<RequestModel> requests) async {
    // pending은 삭제 불가, 그 외 status만 일괄 삭제
    final ids = requests
        .where((r) => _selectedIds.contains(r.id) && r.status != 'pending')
        .map((r) => r.id)
        .toList();
    final pendingCount = requests
        .where((r) => _selectedIds.contains(r.id) && r.status == 'pending')
        .length;

    // 선택에 pending만 있는 경우 → 안내 모달만 출력
    if (ids.isEmpty) {
      if (pendingCount > 0 && mounted) {
        await showMoniqInfoSheet(
          context: context,
          eyebrow: 'NOTICE',
          title: '삭제 불가',
          message: '대기중인 건은 삭제가 불가능합니다.',
        );
      }
      return;
    }

    // 혼합 또는 비-pending 단독 → 확인 모달에서 안내 후 삭제
    final message = pendingCount > 0
        ? '대기중인 $pendingCount건은 삭제가 불가능하여 제외하고 '
            '${ids.length}건에 대해서 삭제를 진행합니다.'
        : '${ids.length}건이 영구적으로 삭제돼요.';
    final confirm = await showMoniqConfirmSheet(
      context: context,
      eyebrow: 'DELETE',
      title: '선택한 요청을 삭제할까요?',
      message: message,
      confirmLabel: '삭제',
      destructive: true,
    );
    if (!confirm) return;

    try {
      await ref
          .read(requestListViewModelProvider(widget.teamId).notifier)
          .deleteRequests(ids);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
      }
    }
    if (mounted) _exitSelectionMode();
  }

  /// 6개월보다 오래된 요청을 정리한다. 권한이 없는 건은 RLS가 막아 무시됨.
  Future<void> _purgeStale(List<RequestModel> requests) async {
    if (_purgedOldRecords) return;
    _purgedOldRecords = true;

    final cutoff = _sixMonthsAgo();
    final oldIds = requests
        .where((r) {
          final d = r.requestedDate ?? r.createdAt;
          return d != null && d.isBefore(cutoff);
        })
        .map((r) => r.id)
        .toList();

    if (oldIds.isEmpty) return;
    try {
      await ref
          .read(requestListViewModelProvider(widget.teamId).notifier)
          .deleteRequests(oldIds);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final stateAsync = ref.watch(requestListViewModelProvider(widget.teamId));

    return Scaffold(
      appBar: MoniqAppBar(
        title: _selectionMode
            ? '${_selectedIds.length}건 선택됨'
            : '요청 히스토리',
        showBack: !_selectionMode,
        leading: _selectionMode
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: _exitSelectionMode,
              )
            : null,
        trailing: _selectionMode
            ? null
            : MoniqAppBarAction(
                icon: Icons.refresh_rounded,
                onTap: () =>
                    ref.invalidate(requestListViewModelProvider(widget.teamId)),
              ),
      ),
      bottomNavigationBar: _selectionMode
          ? _HistoryDeleteBar(
              requests: stateAsync.valueOrNull?.requests ?? const [],
              selectedIds: _selectedIds,
              onDelete: () => _bulkDelete(
                stateAsync.valueOrNull?.requests ?? const [],
              ),
            )
          : null,
      body: stateAsync.when(
        loading: () => const MoniqLoadingView(),
        error: (e, _) => MoniqErrorView(
          message: '히스토리를 불러올 수 없습니다',
          onRetry: () =>
              ref.invalidate(requestListViewModelProvider(widget.teamId)),
        ),
        data: (state) {
          // 첫 진입 시 오래된 기록 정리
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _purgeStale(state.requests);
          });

          final history = _historyItems(state.requests);
          if (history.isEmpty) {
            return MoniqEmptyState.peaceful(
              title: '히스토리가 없어요',
              message: '최근 6개월의 요청만 보관돼요',
            );
          }

          // 6개월 이내 요청을 그룹화한 뒤 월별 섹션으로 분리.
          final groups = groupHistoryRequests(history);

          final monthMap = <String, List<RequestGroup>>{};
          final yearMonthFormat = DateFormat('yyyy년 M월', 'ko');
          for (final g in groups) {
            final d = g.createdAt ?? g.primary.requestedDate!;
            final key = yearMonthFormat.format(DateTime(d.year, d.month));
            monthMap.putIfAbsent(key, () => []).add(g);
          }

          // 전체 선택/해제 바 계산용 — 현재 보이는 전체 그룹 ids 합집합
          final allVisibleIds = groups.expand((g) => g.ids).toSet();
          final isAllSelected = allVisibleIds.isNotEmpty &&
              allVisibleIds.every(_selectedIds.contains);
          final selectedGroupCount = groups
              .where((g) => g.ids.every(_selectedIds.contains))
              .length;

          return Column(
            children: [
              if (_selectionMode)
                _SelectAllBar(
                  isAllSelected: isAllSelected,
                  visibleCount: groups.length,
                  selectedCount: selectedGroupCount,
                  onTap: groups.isEmpty
                      ? null
                      : () => _toggleSelectAll(groups),
                ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  itemCount: monthMap.length,
                  itemBuilder: (context, index) {
                    final monthLabel = monthMap.keys.elementAt(index);
                    final items = monthMap[monthLabel]!;
                    return _MonthSection(
                      label: monthLabel,
                      groups: items,
                      userNames: state.userNames,
                      teamId: widget.teamId,
                      isAdmin: state.isAdmin,
                      selectionMode: _selectionMode,
                      selectedIds: _selectedIds,
                      onToggleSelectionGroup: _toggleSelectionGroup,
                      onLongPressGroup: _onLongPressGroup,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

DateTime _sixMonthsAgo() {
  final now = DateTime.now();
  return DateTime(now.year, now.month - 6, now.day);
}

/// 최근 6개월 이내, 신청일 기준 내림차순
List<RequestModel> _historyItems(List<RequestModel> all) {
  final cutoff = _sixMonthsAgo();
  final items = all.where((r) {
    final d = r.createdAt ?? r.requestedDate;
    return d != null && !d.isBefore(cutoff);
  }).toList();
  items.sort((a, b) {
    final da = a.createdAt ?? a.requestedDate!;
    final db = b.createdAt ?? b.requestedDate!;
    return db.compareTo(da);
  });
  return items;
}

class _MonthSection extends StatelessWidget {
  const _MonthSection({
    required this.label,
    required this.groups,
    required this.userNames,
    required this.teamId,
    required this.isAdmin,
    required this.selectionMode,
    required this.selectedIds,
    required this.onToggleSelectionGroup,
    required this.onLongPressGroup,
  });

  final String label;
  final List<RequestGroup> groups;
  final Map<String, String> userNames;
  final String teamId;
  final bool isAdmin;
  final bool selectionMode;
  final Set<String> selectedIds;
  final ValueChanged<RequestGroup> onToggleSelectionGroup;
  final ValueChanged<RequestGroup> onLongPressGroup;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final approved = groups.where((g) => g.status == 'approved').length;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '$approved 승인 · ${groups.length}건',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          for (var idx = 0; idx < groups.length; idx++)
            _HistoryRecordTile(
              group: groups[idx],
              userNames: userNames,
              teamId: teamId,
              isAdmin: isAdmin,
              showDivider: idx != groups.length - 1,
              selectionMode: selectionMode,
              selected: groups[idx].ids.every(selectedIds.contains),
              onToggleSelectionGroup: onToggleSelectionGroup,
              onLongPressGroup: onLongPressGroup,
            ),
        ],
      ),
    );
  }
}

/// 타임라인 형태의 히스토리 레코드 한 줄
class _HistoryRecordTile extends ConsumerWidget {
  const _HistoryRecordTile({
    required this.group,
    required this.userNames,
    required this.teamId,
    required this.isAdmin,
    required this.showDivider,
    required this.selectionMode,
    required this.selected,
    required this.onToggleSelectionGroup,
    required this.onLongPressGroup,
  });

  final RequestGroup group;
  final Map<String, String> userNames;
  final String teamId;
  final bool isAdmin;
  final bool showDivider;
  final bool selectionMode;
  final bool selected;
  final ValueChanged<RequestGroup> onToggleSelectionGroup;
  final ValueChanged<RequestGroup> onLongPressGroup;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final (statusLabel, statusColor) = _statusMeta(group.status);
    final dayFormat = DateFormat('MM.dd');
    final weekdayFormat = DateFormat('EEEE', 'ko');

    // 표시 날짜: 신청일(createdAt)
    final date = group.createdAt;

    final requesterName = userNames[group.requesterUserId];

    return Column(
      children: [
        Material(
          color: selected
              ? cs.primary.withValues(alpha: 0.06)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            onTap: () {
              if (selectionMode) {
                onToggleSelectionGroup(group);
              } else {
                showRequestDetailSheet(
                  context,
                  ref,
                  group: group,
                  isAdmin: isAdmin,
                  teamId: teamId,
                  userNames: userNames,
                );
              }
            },
            onLongPress: () => onLongPressGroup(group),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Row(
                children: [
                  if (selectionMode) ...[
                    MoniqSelectionCheck(selected: selected),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  SizedBox(
                    width: 52,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          date != null ? dayFormat.format(date) : '--.--',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          date != null ? weekdayFormat.format(date) : '',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.entries.length > 1
                              ? '${changeTypeLabel(group.changeType)} · ${group.entries.length}건'
                              : changeTypeLabel(group.changeType),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (requesterName != null &&
                            requesterName.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            requesterName,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    statusLabel,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (!selectionMode) ...[
                    const SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 0.5,
            color: cs.outline.withValues(alpha: 0.2),
          ),
      ],
    );
  }
}

(String, Color) _statusMeta(String status) {
  return switch (status) {
    'approved' => ('승인', const Color(0xFF10B981)),
    'rejected' => ('거절', const Color(0xFFEF4444)),
    'cancelled' => ('취소', const Color(0xFF6B7280)),
    _ => ('대기중', const Color(0xFFF59E0B)),
  };
}

// ────────────────────────────────────────
// 선택 모드 — 전체 선택/해제 행 (메인 목록 _SelectAllBar 룩앤필 재현)
// ────────────────────────────────────────

class _SelectAllBar extends StatelessWidget {
  const _SelectAllBar({
    required this.isAllSelected,
    required this.visibleCount,
    required this.selectedCount,
    required this.onTap,
  });

  final bool isAllSelected;
  final int visibleCount;
  final int selectedCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Material(
      color: cs.surfaceContainerLow,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              MoniqSelectionCheck(selected: isAllSelected, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Text(
                isAllSelected ? '전체 해제' : '전체 선택',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '$selectedCount / $visibleCount',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────
// 선택 모드 하단 삭제 바 (삭제 전용)
// ────────────────────────────────────────

class _HistoryDeleteBar extends StatelessWidget {
  const _HistoryDeleteBar({
    required this.requests,
    required this.selectedIds,
    required this.onDelete,
  });

  final List<RequestModel> requests;
  final Set<String> selectedIds;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // pending 제외(승인/거절/취소)된 항목만 실제 삭제됨
    final deletableCount = requests
        .where((r) => selectedIds.contains(r.id) && r.status != 'pending')
        .length;
    // 선택이 있으면 활성화 — pending만 선택해도 안내 메시지 노출 위해
    final deleteEnabled = selectedIds.isNotEmpty;

    return Material(
      color: cs.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Expanded(
                child: _BottomActionButton(
                  icon: Icons.delete_outline_rounded,
                  label: '삭제',
                  count: deletableCount,
                  enabled: deleteEnabled,
                  onTap: onDelete,
                  color: cs.error,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomActionButton extends StatelessWidget {
  const _BottomActionButton({
    required this.icon,
    required this.label,
    required this.count,
    required this.enabled,
    required this.onTap,
    required this.color,
  });

  final IconData icon;
  final String label;
  final int count;
  final bool enabled;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = enabled ? color : cs.onSurface.withValues(alpha: 0.38);
    final bg = enabled
        ? color.withValues(alpha: 0.1)
        : cs.surfaceContainerHighest.withValues(alpha: 0.4);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md,
            horizontal: AppSpacing.sm,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: fg, size: 22),
              const SizedBox(width: AppSpacing.sm),
              Text(
                count > 0 ? '$label ($count)' : label,
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
