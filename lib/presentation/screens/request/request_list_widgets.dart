part of 'request_list_screen.dart';

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.currentFilter,
    required this.onFilterChanged,
  });
  final String currentFilter;
  final ValueChanged<String> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    const filters = [
      ('pending', '대기중'),
      ('approved', '승인'),
      ('rejected', '거절'),
      ('all', '전체'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: filters
            .map(
              (f) => Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: _FilterChip(
                  label: f.$2,
                  selected: currentFilter == f.$1,
                  onTap: () => onFilterChanged(f.$1),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

// 상세 섹션

// ────────────────────────────────────────
// 요청 카드 (공용)
// ────────────────────────────────────────

class RequestCard extends StatelessWidget {
  const RequestCard({
    super.key,
    required this.group,
    required this.onTap,
    this.onLongPress,
    required this.userNames,
    this.selectionMode = false,
    this.selected = false,
  });

  final RequestGroup group;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Map<String, String> userNames;
  final bool selectionMode;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final stampFormat = DateFormat('yyyy.MM.dd (E) HH:mm', 'ko');
    final entryDateFormat = DateFormat('M/d (E)', 'ko');
    final (statusColor, _, _) = _statusStyle(group.status, colorScheme);

    final createdAt = group.createdAt;
    final changeLabel = changeTypeLabel(group.changeType);
    final requesterName = userNames[group.requesterUserId];

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      shadowColor: statusColor.withValues(alpha: 0.15),
      color: selected ? colorScheme.primary.withValues(alpha: 0.06) : null,
      shape: selected
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              side: BorderSide(
                color: colorScheme.primary.withValues(alpha: 0.3),
              ),
            )
          : null,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(width: 4, color: statusColor),
              if (selectionMode) ...[
                const SizedBox(width: AppSpacing.md),
                MoniqSelectionCheck(selected: selected),
              ],
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1행: 변경 유형 + (N건) + 상태 뱃지
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              group.entries.length > 1
                                  ? '$changeLabel · ${group.entries.length}건'
                                  : changeLabel,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          StatusBadge(status: group.status),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (requesterName != null && requesterName.isNotEmpty)
                        _MetaInfoRow(label: '신청자', value: requesterName),
                      Builder(
                        builder: (_) {
                          final dates = group.entries
                              .where((r) => r.requestedDate != null)
                              .map(
                                (r) => entryDateFormat.format(r.requestedDate!),
                              )
                              .toList();
                          if (dates.isEmpty) return const SizedBox.shrink();
                          return _MetaInfoRow(
                            label: '변경일',
                            value: dates.join(', '),
                          );
                        },
                      ),
                      _MetaInfoRow(
                        label: '신청일',
                        value: createdAt != null
                            ? stampFormat.format(_toKst(createdAt))
                            : '-',
                      ),
                    ],
                  ),
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
// 상태 뱃지 (공용)
// ────────────────────────────────────────

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (color, bgColor, label) = _statusStyle(status, colorScheme);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ────────────────────────────────────────
// 필터 칩
// ────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bg = selected
        ? cs.primary.withValues(alpha: 0.10)
        : cs.surfaceContainerHigh;
    final fg = selected ? cs.primary : cs.onSurfaceVariant;
    return Material(
      color: bg,
      shape: StadiumBorder(
        side: selected
            ? BorderSide(color: cs.primary.withValues(alpha: 0.45))
            : BorderSide(color: Colors.transparent),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: fg,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────
// 헬퍼
// ────────────────────────────────────────

/// 같은 시점에 같은 사용자가 같은 유형으로 제출한 요청을 한 묶음으로 본다.
/// 한 번 제출에서 여러 entry가 만들어진 경우 (createdAt이 초/100ms 단위로 거의 동일),
/// 동일 그룹으로 보고 카드 1장에 묶어 표시한다.
class RequestGroup {
  RequestGroup(this.entries) : assert(entries.length > 0);
  final List<RequestModel> entries;

  RequestModel get primary => entries.first;
  List<String> get ids => entries.map((e) => e.id).toList();
  String get status => primary.status;
  String get changeType => primary.changeType;
  String get requesterUserId => primary.requesterUserId;
  DateTime? get createdAt => primary.createdAt;
}

/// 그룹핑 키: 동일 신청자 + 변경 유형 + 상태 + (createdAt 분 단위)
String _groupKey(RequestModel r) {
  final t = r.createdAt;
  final minute = t == null
      ? 'x'
      : '${t.toUtc().millisecondsSinceEpoch ~/ 60000}';
  return '${r.requesterUserId}|${r.changeType}|${r.status}|$minute';
}

/// 메인 리스트: 이번달 + 다음달의 요청만 노출하고, 취소 건은 제외 (히스토리에서 확인).
List<RequestModel> _filtered(RequestListState state) {
  final now = DateTime.now();
  final thisMonthStart = DateTime(now.year, now.month, 1);
  final afterNextMonth = DateTime(now.year, now.month + 2, 1);

  final base = state.requests.where((r) {
    if (r.status == 'cancelled') return false;
    final d = r.requestedDate ?? r.createdAt;
    if (d == null) return false;
    return !d.isBefore(thisMonthStart) && d.isBefore(afterNextMonth);
  });

  if (state.filter == 'all') return base.toList();
  return base.where((r) => r.status == state.filter).toList();
}

/// `_filtered` 결과를 RequestGroup 단위로 변환. createdAt 내림차순.
List<RequestGroup> _filteredGroups(RequestListState state) =>
    groupHistoryRequests(_filtered(state));

/// 임의의 요청 리스트를 [RequestGroup]으로 묶는다. (히스토리에서도 재사용)
List<RequestGroup> groupHistoryRequests(List<RequestModel> requests) {
  final map = <String, List<RequestModel>>{};
  for (final r in requests) {
    map.putIfAbsent(_groupKey(r), () => []).add(r);
  }
  final groups = map.values.map((list) {
    final sorted = [...list]
      ..sort((a, b) {
        final da = a.requestedDate ?? a.createdAt;
        final db = b.requestedDate ?? b.createdAt;
        if (da == null || db == null) return 0;
        return da.compareTo(db);
      });
    return RequestGroup(sorted);
  }).toList();
  groups.sort((a, b) {
    final da = a.createdAt;
    final db = b.createdAt;
    if (da == null || db == null) return 0;
    return db.compareTo(da);
  });
  return groups;
}

(Color color, Color bgColor, String label) _statusStyle(
  String status,
  ColorScheme colorScheme,
) {
  return switch (status) {
    'pending' => (
      AppColors.brandOrange,
      AppColors.brandOrange.withValues(alpha: 0.1),
      '대기중',
    ),
    'approved' => (AppColors.success, AppColors.successLight, '승인'),
    'rejected' => (colorScheme.error, AppColors.errorLight, '거절'),
    'cancelled' => (
      colorScheme.onSurfaceVariant,
      colorScheme.surfaceContainerHighest,
      '취소',
    ),
    _ => (
      colorScheme.onSurfaceVariant,
      colorScheme.surfaceContainerHighest,
      '알수없음',
    ),
  };
}

String changeTypeLabel(String type) => switch (type) {
  'swap' => '멤버 간 근무 변경',
  'day_off' => '내 근무 변경 (휴무)',
  'shift_change' => '내 근무 변경',
  'schedule_change' => '일정 변경',
  _ => type,
};

/// Supabase가 UTC로 저장한 timestamp를 한국 시간(KST = UTC+9)으로 변환.
/// 디바이스 타임존과 무관하게 항상 KST를 반환한다.
DateTime _toKst(DateTime dt) => dt.toUtc().add(const Duration(hours: 9));

// ────────────────────────────────────────
// 선택 모드 — 필터 바 아래 전체 선택/해제 행
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
// 공용 선택 인디케이터 (request 탭 전역 재사용)
// ────────────────────────────────────────

/// 선택 모드에서 사용하는 세련된 커스텀 체크 인디케이터.
///
/// 둥근 사각형(radius 7) 형태로, 미선택 시 투명 배경 + 1.5px 테두리,
/// 선택 시 primary 채움 + onPrimary 체크 아이콘으로 부드럽게 전환된다.
class MoniqSelectionCheck extends StatelessWidget {
  const MoniqSelectionCheck({
    super.key,
    required this.selected,
    this.size = 22,
  });

  final bool selected;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: selected ? AppColors.primary : cs.outlineVariant,
          width: 1.5,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.28),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutBack,
        scale: selected ? 1 : 0,
        child: Icon(
          Icons.check_rounded,
          size: size * 0.66,
          weight: 800,
          color: cs.onPrimary,
        ),
      ),
    );
  }
}

// ────────────────────────────────────────
// 선택 모드 하단 액션 바
// ────────────────────────────────────────

class _SelectionBottomBar extends StatelessWidget {
  const _SelectionBottomBar({
    required this.requests,
    required this.selectedIds,
    required this.isAdmin,
    required this.myUserId,
    required this.onApprove,
    required this.onReject,
    required this.onCancel,
    required this.onDelete,
  });

  final List<RequestModel> requests;
  final Set<String> selectedIds;
  final bool isAdmin;
  final String? myUserId;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onCancel;
  final VoidCallback onDelete;

  bool _canMemberCancel(RequestModel r) =>
      r.status == 'pending' &&
      myUserId != null &&
      r.requesterUserId == myUserId;

  int _countWhere(bool Function(RequestModel) pred) =>
      requests.where((r) => selectedIds.contains(r.id) && pred(r)).length;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final pendingCount = _countWhere((r) => r.status == 'pending');
    final memberCancelCount = _countWhere(_canMemberCancel);
    // pending 제외(승인/거절/취소)된 항목만 실제 삭제됨
    final deletableCount = _countWhere((r) => r.status != 'pending');
    final selectedCount = selectedIds.length;

    final approveEnabled = isAdmin && pendingCount > 0;
    final rejectEnabled = isAdmin && pendingCount > 0;
    // 취소는 관리자/멤버 모두 본인이 요청한 pending에만 가능
    final cancelEnabled = memberCancelCount > 0;
    // 선택이 있으면 활성화 — pending만 선택해도 안내 메시지 노출 위해
    final deleteEnabled = selectedCount > 0;

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
              if (isAdmin) ...[
                Expanded(
                  child: _BottomActionButton(
                    icon: Icons.check_circle_outline_rounded,
                    label: '승인',
                    count: pendingCount,
                    enabled: approveEnabled,
                    onTap: onApprove,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _BottomActionButton(
                    icon: Icons.cancel_outlined,
                    label: '거절',
                    count: pendingCount,
                    enabled: rejectEnabled,
                    onTap: onReject,
                    color: cs.error,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _BottomActionButton(
                    icon: Icons.block_rounded,
                    label: '취소',
                    count: memberCancelCount,
                    enabled: cancelEnabled,
                    onTap: onCancel,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
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
              ] else ...[
                Expanded(
                  child: _BottomActionButton(
                    icon: Icons.block_rounded,
                    label: '취소',
                    count: memberCancelCount,
                    enabled: cancelEnabled,
                    onTap: onCancel,
                    color: cs.error,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: fg, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
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
// 상세 뷰: 메타 행 (아이콘 + 텍스트)
// ────────────────────────────────────────

// ────────────────────────────────────────
// 상세 뷰: 근무 변경 전/후 미리보기
// ────────────────────────────────────────

class _ChangePreview extends ConsumerWidget {
  const _ChangePreview({required this.teamId, required this.request});

  final String teamId;
  final RequestModel request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final previewAsync = ref.watch(
      requestChangePreviewProvider('$teamId|${request.id}'),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '근무 변경',
            style: theme.textTheme.labelMedium?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          previewAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (_, __) => Text(
              '근무 정보를 불러올 수 없어요',
              style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
            ),
            data: (preview) => _previewBody(context, preview),
          ),
        ],
      ),
    );
  }

  Widget _previewBody(BuildContext context, RequestChangePreview preview) {
    final isSwap = request.changeType == 'swap';
    // swap은 양방향 교환 — 신청자/대상자 각각의 변경 전→후를 모두 노출한다.
    // (예: 백하은 D→N, 이지영 N→D)
    if (isSwap) {
      // 한쪽이 OFF(근무 없음)이면 교환이 불가능하므로 경고를 표시한다.
      // (승인 시에도 차단되고 알림이 뜬다)
      final offBlocked = preview.requesterBeforeShiftType == null ||
          preview.targetBeforeShiftType == null;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _NamedBeforeAfterRow(
            name: preview.requesterName ?? '신청자',
            before: preview.requesterBeforeShiftType,
            after: preview.requesterAfterShiftType,
          ),
          const SizedBox(height: AppSpacing.sm),
          _NamedBeforeAfterRow(
            name: preview.targetName ?? '대상자',
            before: preview.targetBeforeShiftType,
            after: preview.targetAfterShiftType,
          ),
          if (offBlocked) ...[
            const SizedBox(height: AppSpacing.sm),
            _OffSwapWarning(),
          ],
        ],
      );
    }

    return _BeforeAfterRow(
      before: preview.requesterBeforeShiftType,
      after: preview.requesterAfterShiftType,
    );
  }
}

/// 한쪽이 OFF라 교환할 수 없는 swap 경고 배너.
class _OffSwapWarning extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: cs.error),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '한쪽이 OFF(근무 없음)라 교환할 수 없어요',
              style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
            ),
          ),
        ],
      ),
    );
  }
}

/// 이름 + 변경 전 → 변경 후 (swap 카드용)
class _NamedBeforeAfterRow extends StatelessWidget {
  const _NamedBeforeAfterRow({
    required this.name,
    required this.before,
    required this.after,
  });
  final String name;
  final ShiftTypeModel? before;
  final ShiftTypeModel? after;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: theme.textTheme.labelMedium?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        _BeforeAfterRow(before: before, after: after),
      ],
    );
  }
}

/// swap용 라인: 사람 + 변경 전 → 변경 후

/// 변경 전 [chip] → 변경 후 [chip]
class _BeforeAfterRow extends StatelessWidget {
  const _BeforeAfterRow({required this.before, required this.after});
  final ShiftTypeModel? before;
  final ShiftTypeModel? after;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Row(
      children: [
        Expanded(
          child: _ShiftTypeChip(label: '변경 전', shiftType: before),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Icon(
            Icons.arrow_forward_rounded,
            size: 18,
            color: cs.onSurfaceVariant,
          ),
        ),
        Expanded(
          child: _ShiftTypeChip(label: '변경 후', shiftType: after),
        ),
      ],
    );
  }
}

/// shiftType이 null이면 OFF로 표시.
class _ShiftTypeChip extends StatelessWidget {
  const _ShiftTypeChip({required this.label, required this.shiftType});

  final String label;
  final ShiftTypeModel? shiftType;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final color = shiftType != null
        ? parseHexColor(shiftType!.color)
        : AppColors.shiftOff;
    final code = shiftType?.code ?? 'OFF';
    final name = shiftType?.name ?? '휴무';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  code,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: color,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 카드 부가 정보 key-value 행 (신청자/변경일/신청일)
class _MetaInfoRow extends StatelessWidget {
  const _MetaInfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 44,
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 10,
                height: 1.3,
                color: cs.onSurfaceVariant.withValues(alpha: 0.65),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 10,
                height: 1.3,
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
