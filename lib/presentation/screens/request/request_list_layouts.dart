part of 'request_list_screen.dart';

class _MobileLayout extends StatelessWidget {
  const _MobileLayout({
    required this.teamId,
    required this.state,
    required this.selectionMode,
    required this.selectedIds,
    required this.onToggleSelectionGroup,
    required this.onLongPressGroup,
    required this.onToggleSelectAll,
    required this.onFilterChanged,
    required this.onShowDetail,
    required this.onApprove,
    required this.onReject,
    required this.onCancel,
    required this.onDeleteIds,
  });

  final String teamId;
  final RequestListState state;
  final bool selectionMode;
  final Set<String> selectedIds;
  final ValueChanged<RequestGroup> onToggleSelectionGroup;
  final ValueChanged<RequestGroup> onLongPressGroup;
  final VoidCallback onToggleSelectAll;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<RequestGroup> onShowDetail;
  final ValueChanged<String> onApprove;
  final ValueChanged<String> onReject;
  final ValueChanged<String> onCancel;
  final ValueChanged<List<String>> onDeleteIds;

  @override
  Widget build(BuildContext context) {
    final groups = _filteredGroups(state);

    final allVisibleIds = groups.expand((g) => g.ids).toSet();
    final isAllSelected =
        allVisibleIds.isNotEmpty && allVisibleIds.every(selectedIds.contains);

    return Column(
      children: [
        _FilterBar(
          currentFilter: state.filter,
          onFilterChanged: onFilterChanged,
        ),
        if (selectionMode)
          _SelectAllBar(
            isAllSelected: isAllSelected,
            visibleCount: groups.length,
            selectedCount: groups
                .where((g) => g.ids.every(selectedIds.contains))
                .length,
            onTap: groups.isEmpty ? null : onToggleSelectAll,
          ),
        Expanded(
          child: groups.isEmpty
              ? MoniqEmptyState.peaceful(
                  title: '이번달·다음달 요청이 없어요',
                  message: '지난 요청은 히스토리에서 확인할 수 있어요',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    100, // FAB와 마지막 카드가 겹치지 않도록 여유
                  ),
                  itemCount: groups.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, i) {
                    final g = groups[i];
                    final canDelete = g.status == 'cancelled';
                    final isSelected = g.ids.every(selectedIds.contains);

                    final card = RequestCard(
                      group: g,
                      userNames: state.userNames,
                      selectionMode: selectionMode,
                      selected: isSelected,
                      onTap: () {
                        if (selectionMode) {
                          onToggleSelectionGroup(g);
                        } else {
                          onShowDetail(g);
                        }
                      },
                      onLongPress: () => onLongPressGroup(g),
                    );

                    // selection mode 중에는 swipe-to-delete 비활성
                    if (!canDelete || selectionMode) return card;

                    return Dismissible(
                      key: ValueKey(g.primary.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xl,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: AppRadius.borderRadiusMd,
                        ),
                        child: const Icon(
                          Icons.delete,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      confirmDismiss: (_) => showMoniqConfirmSheet(
                        context: context,
                        title: '요청을 삭제할까요?',
                        message: '취소된 요청 ${g.ids.length}건이 영구적으로 삭제돼요.',
                        confirmLabel: '삭제',
                        destructive: true,
                      ),
                      onDismissed: (_) => onDeleteIds(g.ids),
                      child: card,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────
// 웹 2-column 레이아웃
// ────────────────────────────────────────

class _WebLayout extends StatelessWidget {
  const _WebLayout({
    required this.teamId,
    required this.state,
    required this.selectionMode,
    required this.selectedIds,
    required this.selectedGroup,
    required this.myUserId,
    required this.onSelectGroup,
    required this.onToggleSelectionGroup,
    required this.onFilterChanged,
    required this.onApprove,
    required this.onReject,
    required this.onCancel,
    required this.onDelete,
  });

  final String teamId;
  final RequestListState state;
  final bool selectionMode;
  final Set<String> selectedIds;
  final RequestGroup? selectedGroup;
  final String? myUserId;
  final ValueChanged<RequestGroup?> onSelectGroup;
  final ValueChanged<RequestGroup> onToggleSelectionGroup;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<String> onApprove;
  final ValueChanged<String> onReject;
  final ValueChanged<String> onCancel;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final groups = _filteredGroups(state);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 왼쪽: 필터 + 목록 ──
        Container(
          width: 400,
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(color: colorScheme.outlineVariant),
            ),
          ),
          child: Column(
            children: [
              _FilterBar(
                currentFilter: state.filter,
                onFilterChanged: onFilterChanged,
              ),
              Expanded(
                child: groups.isEmpty
                    ? MoniqEmptyState.peaceful(
                        title: '이번달·다음달 요청이 없어요',
                        message: '지난 요청은 히스토리에서 확인할 수 있어요',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount: groups.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (_, i) {
                          final g = groups[i];
                          final isCheckboxSelected = g.ids.every(
                            selectedIds.contains,
                          );
                          final isFocused =
                              !selectionMode &&
                              selectedGroup?.primary.id == g.primary.id;
                          return RequestCard(
                            group: g,
                            userNames: state.userNames,
                            selectionMode: selectionMode,
                            selected: selectionMode
                                ? isCheckboxSelected
                                : isFocused,
                            onTap: () {
                              if (selectionMode) {
                                onToggleSelectionGroup(g);
                              } else {
                                onSelectGroup(isFocused ? null : g);
                              }
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),

        // ── 오른쪽: 상세 패널 ──
        Expanded(
          child: selectedGroup == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.swap_horiz_rounded,
                        size: 48,
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.3,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        '요청을 선택하면 상세 정보가 표시됩니다',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                )
              : _WebDetailPanel(
                  key: ValueKey(selectedGroup!.primary.id),
                  teamId: teamId,
                  group: selectedGroup!,
                  isAdmin: state.isAdmin,
                  myUserId: myUserId,
                  userNames: state.userNames,
                  onApprove: () {
                    for (final id in selectedGroup!.ids) onApprove(id);
                  },
                  onReject: () {
                    for (final id in selectedGroup!.ids) onReject(id);
                  },
                  onCancel: () {
                    for (final id in selectedGroup!.ids) onCancel(id);
                  },
                ),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────
// 웹 상세 패널
// ────────────────────────────────────────

class _WebDetailPanel extends ConsumerWidget {
  const _WebDetailPanel({
    super.key,
    required this.teamId,
    required this.group,
    required this.isAdmin,
    required this.myUserId,
    required this.userNames,
    required this.onApprove,
    required this.onReject,
    required this.onCancel,
  });

  final String teamId;
  final RequestGroup group;
  final bool isAdmin;
  final String? myUserId;
  final Map<String, String> userNames;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onCancel;

  bool get _canCancel => myUserId != null && group.requesterUserId == myUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final (statusColor, _, _) = _statusStyle(group.status, colorScheme);
    final isSwap = group.changeType == 'swap';

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 상단 상태 + 메타 ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        StatusBadge(status: group.status),
                        const Spacer(),
                        if (group.createdAt != null)
                          Text(
                            '신청일 ${DateFormat('yyyy.MM.dd HH:mm').format(_toKst(group.createdAt!))}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      group.entries.length > 1
                          ? '${changeTypeLabel(group.changeType)} · ${group.entries.length}건'
                          : changeTypeLabel(group.changeType),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

              // ── 각 entry별 변경 전/후 ──
              for (final r in group.entries) ...[
                const SizedBox(height: AppSpacing.md),
                _EntryHeader(request: r, userNames: userNames, isSwap: isSwap),
                const SizedBox(height: AppSpacing.sm),
                _ChangePreview(teamId: teamId, request: r),
              ],

              const SizedBox(height: AppSpacing.xl),

              // ── 액션 버튼 ──
              if (group.status == 'pending') ...[
                if (isAdmin)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onReject,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colorScheme.error,
                            side: BorderSide(
                              color: colorScheme.error.withValues(alpha: 0.5),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('거절'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: onApprove,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('승인'),
                        ),
                      ),
                    ],
                  ),
                if (_canCancel) ...[
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: onCancel,
                      style: TextButton.styleFrom(
                        foregroundColor: colorScheme.onSurfaceVariant,
                      ),
                      child: const Text('요청 취소'),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 상세 시트 — 각 entry의 헤더 (대상자/요청자 + 변경일)
class _EntryHeader extends StatelessWidget {
  const _EntryHeader({
    required this.request,
    required this.userNames,
    required this.isSwap,
  });

  final RequestModel request;
  final Map<String, String> userNames;
  final bool isSwap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final personName = isSwap
        ? (request.targetUserId != null
              ? userNames[request.targetUserId!]
              : null)
        : userNames[request.requesterUserId];
    final dateText = request.requestedDate != null
        ? DateFormat('yyyy.MM.dd (E)', 'ko').format(request.requestedDate!)
        : null;

    return Row(
      children: [
        Icon(
          isSwap ? Icons.swap_horiz_rounded : Icons.person_outline,
          size: 16,
          color: cs.primary,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            [
              if (personName != null && personName.isNotEmpty) personName,
              if (dateText != null) dateText,
            ].join('  ·  '),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────
// 모바일 바텀시트
// ────────────────────────────────────────

/// 히스토리 등 다른 화면에서 요청 상세 시트를 재사용하기 위한 공개 헬퍼.
void showRequestDetailSheet(
  BuildContext context,
  WidgetRef ref, {
  required RequestGroup group,
  required bool isAdmin,
  required String teamId,
  required Map<String, String> userNames,
}) {
  showMoniqBottomSheet<void>(
    context: context,
    child: Builder(
      builder: (ctx) => _RequestDetailSheet(
        teamId: teamId,
        group: group,
        isAdmin: isAdmin,
        myUserId: ref.read(currentUserProvider)?.id,
        userNames: userNames,
        onApprove: () async {
          for (final id in group.ids) {
            await ref
                .read(requestListViewModelProvider(teamId).notifier)
                .approveRequest(id);
          }
          if (ctx.mounted) Navigator.pop(ctx);
        },
        onReject: () async {
          for (final id in group.ids) {
            await ref
                .read(requestListViewModelProvider(teamId).notifier)
                .rejectRequest(id);
          }
          if (ctx.mounted) Navigator.pop(ctx);
        },
        onCancel: () async {
          for (final id in group.ids) {
            await ref
                .read(requestListViewModelProvider(teamId).notifier)
                .cancelRequest(id);
          }
          if (ctx.mounted) Navigator.pop(ctx);
        },
      ),
    ),
  );
}

class _RequestDetailSheet extends ConsumerWidget {
  const _RequestDetailSheet({
    required this.teamId,
    required this.group,
    required this.isAdmin,
    required this.myUserId,
    required this.userNames,
    required this.onApprove,
    required this.onReject,
    required this.onCancel,
  });

  final String teamId;
  final RequestGroup group;
  final bool isAdmin;
  final String? myUserId;
  final Map<String, String> userNames;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onCancel;

  bool get _canCancel => myUserId != null && group.requesterUserId == myUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSwap = group.changeType == 'swap';

    // 공용 셸(showMoniqBottomSheet)이 그랩핸들·surface·외곽 패딩·SafeArea를
    // 제공하므로, 여기서는 본문만 그린다. 내용이 길 수 있어 스크롤은 유지.
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusBadge(status: group.status),
              const Spacer(),
              if (group.createdAt != null)
                Text(
                  '신청일 ${DateFormat('yyyy.MM.dd HH:mm').format(_toKst(group.createdAt!))}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            group.entries.length > 1
                ? '${changeTypeLabel(group.changeType)} · ${group.entries.length}건'
                : changeTypeLabel(group.changeType),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),

          // ── 각 entry별 변경 전/후 ──
          for (final r in group.entries) ...[
            const SizedBox(height: AppSpacing.md),
            _EntryHeader(request: r, userNames: userNames, isSwap: isSwap),
            const SizedBox(height: AppSpacing.sm),
            _ChangePreview(teamId: teamId, request: r),
          ],

          const SizedBox(height: AppSpacing.xl),
          if (group.status == 'pending') ...[
            if (isAdmin)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onReject,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorScheme.error,
                      ),
                      child: const Text('거절'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onApprove,
                      child: const Text('승인'),
                    ),
                  ),
                ],
              ),
            if (_canCancel) ...[
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: onCancel,
                  child: const Text('요청 취소'),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

// ────────────────────────────────────────
// 공통 위젯
// ────────────────────────────────────────

// 필터 바
