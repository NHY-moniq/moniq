import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moniq/core/utils/color_utils.dart';
import 'package:moniq/data/models/request_model.dart';
import 'package:moniq/data/models/shift_type_model.dart';
import 'package:moniq/data/providers/auth_providers.dart';
import 'package:moniq/presentation/layout/adaptive_layout.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/request_viewmodel.dart';
import 'package:moniq/presentation/widgets/common/moniq_app_bar.dart';
import 'package:moniq/presentation/widgets/common/moniq_bottom_sheet.dart';
import 'package:moniq/presentation/widgets/common/moniq_empty_state.dart';
import 'package:moniq/presentation/widgets/common/moniq_error_view.dart';
import 'package:moniq/presentation/widgets/common/moniq_loading_view.dart';

class RequestListScreen extends ConsumerStatefulWidget {
  const RequestListScreen({super.key, required this.teamId});

  final String teamId;

  @override
  ConsumerState<RequestListScreen> createState() => _RequestListScreenState();
}

class _RequestListScreenState extends ConsumerState<RequestListScreen> {
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};
  RequestGroup? _selectedGroup; // 웹 전용 선택 상태

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

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

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  /// 현재 사용자가 해당 요청에 대해 취소 가능한지
  bool _canCancelByUser(RequestModel r, String? myUserId) {
    if (r.status != 'pending') return false;
    return myUserId != null && r.requesterUserId == myUserId;
  }

  /// 선택된 요청 중 [filter]를 통과하는 것만 추출
  List<String> _selectedFilteredIds(
    List<RequestModel> requests,
    bool Function(RequestModel) filter,
  ) {
    return requests
        .where((r) => _selectedIds.contains(r.id) && filter(r))
        .map((r) => r.id)
        .toList();
  }

  Future<void> _bulkApprove(List<RequestModel> requests) async {
    final ids = _selectedFilteredIds(requests, (r) => r.status == 'pending');
    if (ids.isEmpty) return;
    final ok = await showMoniqConfirmSheet(
      context: context,
      title: '승인',
      message: '대기중인 ${ids.length}건이 승인됩니다.',
      confirmLabel: '확인',
    );
    if (!ok) return;
    try {
      await ref
          .read(requestListViewModelProvider(widget.teamId).notifier)
          .approveRequests(ids);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('승인 실패: $e')));
      }
    }
    _exitSelectionMode();
  }

  Future<void> _bulkReject(List<RequestModel> requests) async {
    final ids = _selectedFilteredIds(requests, (r) => r.status == 'pending');
    if (ids.isEmpty) return;
    final ok = await showMoniqConfirmSheet(
      context: context,
      title: '거절',
      message: '대기중인 ${ids.length}건이 거절됩니다.',
      confirmLabel: '확인',
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref
          .read(requestListViewModelProvider(widget.teamId).notifier)
          .rejectRequests(ids);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('거절 실패: $e')));
      }
    }
    _exitSelectionMode();
  }

  Future<void> _bulkCancel(
    List<RequestModel> requests, {
    required bool isAdmin,
    required String? myUserId,
  }) async {
    // 취소는 본인이 신청한 pending 요청에만 적용 (관리자도 동일).
    final ids = _selectedFilteredIds(
      requests,
      (r) => _canCancelByUser(r, myUserId),
    );
    if (ids.isEmpty) return;
    final ok = await showMoniqConfirmSheet(
      context: context,
      title: '요청 취소',
      message: '본인이 요청한 대기중 ${ids.length}건이 취소됩니다.',
      confirmLabel: '확인',
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref
          .read(requestListViewModelProvider(widget.teamId).notifier)
          .cancelRequests(ids);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('취소 실패: $e')));
      }
    }
    _exitSelectionMode();
  }

  Future<void> _bulkDelete(List<RequestModel> requests) async {
    // pending은 삭제 불가, 그 외 status만 일괄 삭제
    final ids = _selectedFilteredIds(requests, (r) => r.status != 'pending');
    final pendingCount = _selectedFilteredIds(
      requests,
      (r) => r.status == 'pending',
    ).length;

    // 선택에 pending만 있는 경우 → 안내 모달만 출력
    if (ids.isEmpty) {
      if (pendingCount > 0 && mounted) {
        await showMoniqInfoSheet(
          context: context,
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
      }
    }
    _exitSelectionMode();
  }

  /// 전체 선택 토글 (가시 목록 기준)
  void _toggleSelectAll(List<RequestModel> visible) {
    setState(() {
      final allIds = visible.map((r) => r.id).toSet();
      final isAllSelected =
          allIds.isNotEmpty && allIds.every(_selectedIds.contains);
      if (isAllSelected) {
        _selectedIds.removeWhere(allIds.contains);
      } else {
        _selectedIds.addAll(allIds);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final teamId = widget.teamId;
    final stateAsync = ref.watch(requestListViewModelProvider(teamId));
    final isWide = AdaptiveLayout.isWide(context);

    return Scaffold(
      appBar: MoniqAppBar(
        title: _selectionMode ? '${_selectedIds.length}건 선택됨' : '근무 변경 요청',
        leading: _selectionMode
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: _exitSelectionMode,
              )
            : null,
        trailing: _selectionMode
            ? const SizedBox.shrink()
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MoniqAppBarAction(
                    icon: Icons.history,
                    onTap: () =>
                        context.push('/teams/$teamId/requests/history'),
                  ),
                  MoniqAppBarAction(
                    icon: Icons.checklist_rounded,
                    onTap: () => setState(() => _selectionMode = true),
                  ),
                  if (isWide)
                    Padding(
                      padding: const EdgeInsets.only(left: AppSpacing.sm),
                      child: FilledButton.icon(
                        onPressed: () =>
                            context.push('/teams/$teamId/requests/create'),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('요청하기'),
                      ),
                    ),
                ],
              ),
      ),
      bottomNavigationBar: _selectionMode
          ? _SelectionBottomBar(
              requests: stateAsync.valueOrNull?.requests ?? const [],
              selectedIds: _selectedIds,
              isAdmin: stateAsync.valueOrNull?.isAdmin ?? false,
              myUserId: ref.read(currentUserProvider)?.id,
              onApprove: () =>
                  _bulkApprove(stateAsync.valueOrNull?.requests ?? const []),
              onReject: () =>
                  _bulkReject(stateAsync.valueOrNull?.requests ?? const []),
              onCancel: () => _bulkCancel(
                stateAsync.valueOrNull?.requests ?? const [],
                isAdmin: stateAsync.valueOrNull?.isAdmin ?? false,
                myUserId: ref.read(currentUserProvider)?.id,
              ),
              onDelete: () =>
                  _bulkDelete(stateAsync.valueOrNull?.requests ?? const []),
            )
          : null,
      floatingActionButton: (!isWide && !_selectionMode)
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/teams/$teamId/requests/create'),
              icon: const Icon(Icons.add),
              label: const Text('요청하기'),
            )
          : null,
      body: stateAsync.when(
        loading: () => const MoniqLoadingView(),
        error: (e, _) => MoniqErrorView(
          message: '요청 목록을 불러올 수 없습니다',
          onRetry: () => ref.invalidate(requestListViewModelProvider(teamId)),
        ),
        data: (state) {
          // 선택된 그룹의 primary가 목록에서 사라진 경우 초기화
          if (_selectedGroup != null &&
              !state.requests.any((r) => r.id == _selectedGroup!.primary.id)) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => setState(() => _selectedGroup = null),
            );
          }

          return isWide
              ? _WebLayout(
                  teamId: teamId,
                  state: state,
                  selectionMode: _selectionMode,
                  selectedIds: _selectedIds,
                  selectedGroup: _selectedGroup,
                  myUserId: ref.read(currentUserProvider)?.id,
                  onSelectGroup: (g) => setState(() => _selectedGroup = g),
                  onToggleSelectionGroup: _toggleSelectionGroup,
                  onFilterChanged: (f) => ref
                      .read(requestListViewModelProvider(teamId).notifier)
                      .setFilter(f),
                  onApprove: (id) => ref
                      .read(requestListViewModelProvider(teamId).notifier)
                      .approveRequest(id),
                  onReject: (id) => ref
                      .read(requestListViewModelProvider(teamId).notifier)
                      .rejectRequest(id),
                  onCancel: (id) => ref
                      .read(requestListViewModelProvider(teamId).notifier)
                      .cancelRequest(id),
                  onDelete: (id) => ref
                      .read(requestListViewModelProvider(teamId).notifier)
                      .deleteRequest(id),
                )
              : _MobileLayout(
                  teamId: teamId,
                  state: state,
                  selectionMode: _selectionMode,
                  selectedIds: _selectedIds,
                  onToggleSelectionGroup: _toggleSelectionGroup,
                  onLongPressGroup: (g) {
                    if (!_selectionMode) {
                      setState(() => _selectionMode = true);
                    }
                    _toggleSelectionGroup(g);
                  },
                  onToggleSelectAll: () => _toggleSelectAll(_filtered(state)),
                  onFilterChanged: (f) => ref
                      .read(requestListViewModelProvider(teamId).notifier)
                      .setFilter(f),
                  onShowDetail: (g) =>
                      _showRequestDetail(context, ref, g, state.isAdmin),
                  onApprove: (id) => ref
                      .read(requestListViewModelProvider(teamId).notifier)
                      .approveRequest(id),
                  onReject: (id) => ref
                      .read(requestListViewModelProvider(teamId).notifier)
                      .rejectRequest(id),
                  onCancel: (id) => ref
                      .read(requestListViewModelProvider(teamId).notifier)
                      .cancelRequest(id),
                  onDeleteIds: (ids) => ref
                      .read(requestListViewModelProvider(teamId).notifier)
                      .deleteRequests(ids),
                );
        },
      ),
    );
  }

  void _showRequestDetail(
    BuildContext context,
    WidgetRef ref,
    RequestGroup group,
    bool isAdmin,
  ) {
    final teamId = widget.teamId;
    final userNames =
        ref.read(requestListViewModelProvider(teamId)).valueOrNull?.userNames ??
        const {};
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
}

// ────────────────────────────────────────
// 모바일 레이아웃
// ────────────────────────────────────────

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
class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.label,
    required this.content,
    this.isSecondary = false,
  });
  final String label;
  final String content;
  final bool isSecondary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadius.xs),
          ),
          child: Text(
            content,
            style: isSecondary
                ? theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  )
                : theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

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

String _changeTypeCode(String type) => switch (type) {
  'swap' => 'S',
  'day_off' => 'O',
  'shift_change' => 'C',
  'schedule_change' => 'E',
  _ => '?',
};

class _RequestCodeBadge extends StatelessWidget {
  const _RequestCodeBadge({required this.code, required this.color});

  final String code;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
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

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Row(
      children: [
        Icon(icon, size: 14, color: cs.onSurfaceVariant),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

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
    // swap은 단방향(대상자 근무만 변경). 신청자 본인 근무는 변경되지 않으므로
    // 카드 상세에서도 대상자의 변경 전/후만 노출한다.
    if (isSwap) {
      return _BeforeAfterRow(
        before: preview.targetBeforeShiftType,
        after: preview.targetAfterShiftType,
      );
    }

    return _BeforeAfterRow(
      before: preview.requesterBeforeShiftType,
      after: preview.requesterAfterShiftType,
    );
  }
}

/// swap용 라인: 사람 + 변경 전 → 변경 후
class _SwapLine extends StatelessWidget {
  const _SwapLine({
    required this.personLabel,
    required this.before,
    required this.after,
  });

  final String personLabel;
  final ShiftTypeModel? before;
  final ShiftTypeModel? after;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(
            personLabel,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSurfaceVariant,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Expanded(
          child: _BeforeAfterRow(before: before, after: after),
        ),
      ],
    );
  }
}

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
