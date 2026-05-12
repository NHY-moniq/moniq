import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moniq/data/models/request_model.dart';
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
  RequestModel? _selectedRequest; // 웹 전용 선택 상태

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
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
    final ids = _selectedFilteredIds(
      requests,
      (r) => r.status == 'pending',
    );
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('승인 실패: $e')));
      }
    }
    _exitSelectionMode();
  }

  Future<void> _bulkReject(List<RequestModel> requests) async {
    final ids = _selectedFilteredIds(
      requests,
      (r) => r.status == 'pending',
    );
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('거절 실패: $e')));
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('취소 실패: $e')));
      }
    }
    _exitSelectionMode();
  }

  Future<void> _bulkDelete(List<RequestModel> requests) async {
    // pending은 삭제 불가, 그 외 status만 일괄 삭제
    final ids = _selectedFilteredIds(
      requests,
      (r) => r.status != 'pending',
    );
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
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
        title: _selectionMode
            ? '${_selectedIds.length}건 선택됨'
            : '근무 변경 요청',
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
                    icon: Icons.checklist_rounded,
                    onTap: () => setState(() => _selectionMode = true),
                  ),
                  if (isWide)
                    Padding(
                      padding: const EdgeInsets.only(left: AppSpacing.sm),
                      child: FilledButton.icon(
                        onPressed: () => context
                            .push('/teams/$teamId/requests/create'),
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
              onApprove: () => _bulkApprove(
                  stateAsync.valueOrNull?.requests ?? const []),
              onReject: () => _bulkReject(
                  stateAsync.valueOrNull?.requests ?? const []),
              onCancel: () => _bulkCancel(
                stateAsync.valueOrNull?.requests ?? const [],
                isAdmin: stateAsync.valueOrNull?.isAdmin ?? false,
                myUserId: ref.read(currentUserProvider)?.id,
              ),
              onDelete: () => _bulkDelete(
                  stateAsync.valueOrNull?.requests ?? const []),
            )
          : null,
      floatingActionButton: (!isWide && !_selectionMode)
          ? FloatingActionButton.extended(
              onPressed: () =>
                  context.push('/teams/$teamId/requests/create'),
              icon: const Icon(Icons.add),
              label: const Text('요청하기'),
            )
          : null,
      body: stateAsync.when(
        loading: () => const MoniqLoadingView(),
        error: (e, _) => MoniqErrorView(
          message: '요청 목록을 불러올 수 없습니다',
          onRetry: () =>
              ref.invalidate(requestListViewModelProvider(teamId)),
        ),
        data: (state) {
          // 선택된 요청이 목록에서 사라진 경우 초기화
          if (_selectedRequest != null &&
              !state.requests.any((r) => r.id == _selectedRequest!.id)) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => setState(() => _selectedRequest = null),
            );
          }

          return isWide
              ? _WebLayout(
                  teamId: teamId,
                  state: state,
                  selectionMode: _selectionMode,
                  selectedIds: _selectedIds,
                  selectedRequest: _selectedRequest,
                  myUserId: ref.read(currentUserProvider)?.id,
                  onSelectRequest: (r) =>
                      setState(() => _selectedRequest = r),
                  onToggleSelection: _toggleSelection,
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
                  onToggleSelection: _toggleSelection,
                  onToggleSelectAll: () =>
                      _toggleSelectAll(_filtered(state)),
                  onFilterChanged: (f) => ref
                      .read(requestListViewModelProvider(teamId).notifier)
                      .setFilter(f),
                  onShowDetail: (r) =>
                      _showRequestDetail(context, ref, r, state.isAdmin),
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
                );
        },
      ),
    );
  }

  void _showRequestDetail(BuildContext context, WidgetRef ref,
      RequestModel request, bool isAdmin) {
    final teamId = widget.teamId;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) => _RequestDetailSheet(
        request: request,
        isAdmin: isAdmin,
        myUserId: ref.read(currentUserProvider)?.id,
        onApprove: () async {
          await ref
              .read(requestListViewModelProvider(teamId).notifier)
              .approveRequest(request.id);
          if (ctx.mounted) Navigator.pop(ctx);
        },
        onReject: () async {
          await ref
              .read(requestListViewModelProvider(teamId).notifier)
              .rejectRequest(request.id);
          if (ctx.mounted) Navigator.pop(ctx);
        },
        onCancel: () async {
          await ref
              .read(requestListViewModelProvider(teamId).notifier)
              .cancelRequest(request.id);
          if (ctx.mounted) Navigator.pop(ctx);
        },
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
    required this.onToggleSelection,
    required this.onToggleSelectAll,
    required this.onFilterChanged,
    required this.onShowDetail,
    required this.onApprove,
    required this.onReject,
    required this.onCancel,
    required this.onDelete,
  });

  final String teamId;
  final RequestListState state;
  final bool selectionMode;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggleSelection;
  final VoidCallback onToggleSelectAll;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<RequestModel> onShowDetail;
  final ValueChanged<String> onApprove;
  final ValueChanged<String> onReject;
  final ValueChanged<String> onCancel;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered(state);

    final allVisibleIds = filtered.map((r) => r.id).toSet();
    final isAllSelected = allVisibleIds.isNotEmpty &&
        allVisibleIds.every(selectedIds.contains);

    return Column(
      children: [
        _FilterBar(
            currentFilter: state.filter, onFilterChanged: onFilterChanged),
        const Divider(height: 1),
        if (selectionMode)
          _SelectAllBar(
            isAllSelected: isAllSelected,
            visibleCount: filtered.length,
            selectedCount:
                selectedIds.where(allVisibleIds.contains).length,
            onTap: filtered.isEmpty ? null : onToggleSelectAll,
          ),
        Expanded(
          child: filtered.isEmpty
              ? MoniqEmptyState.peaceful(
                  title: '변경 요청이 없어요',
                  message: '근무 변경이 필요하면 요청을 생성해보세요',
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, i) {
                    final r = filtered[i];
                    final canDelete = r.status == 'cancelled';
                    final isSelected = selectedIds.contains(r.id);

                    final card = RequestCard(
                      request: r,
                      selectionMode: selectionMode,
                      selected: isSelected,
                      onTap: () {
                        if (selectionMode) {
                          onToggleSelection(r.id);
                        } else {
                          onShowDetail(r);
                        }
                      },
                    );

                    // selection mode 중에는 swipe-to-delete 비활성
                    if (!canDelete || selectionMode) return card;

                    return Dismissible(
                      key: ValueKey(r.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xl),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: AppRadius.borderRadiusMd,
                        ),
                        child: const Icon(Icons.delete,
                            color: Colors.white, size: 28),
                      ),
                      confirmDismiss: (_) => showMoniqConfirmSheet(
                        context: context,
                        title: '요청을 삭제할까요?',
                        message: '취소된 요청 1건이 영구적으로 삭제돼요.',
                        confirmLabel: '삭제',
                        destructive: true,
                      ),
                      onDismissed: (_) => onDelete(r.id),
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
    required this.selectedRequest,
    required this.myUserId,
    required this.onSelectRequest,
    required this.onToggleSelection,
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
  final RequestModel? selectedRequest;
  final String? myUserId;
  final ValueChanged<RequestModel?> onSelectRequest;
  final ValueChanged<String> onToggleSelection;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<String> onApprove;
  final ValueChanged<String> onReject;
  final ValueChanged<String> onCancel;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final filtered = _filtered(state);

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
                  onFilterChanged: onFilterChanged),
              const Divider(height: 1),
              Expanded(
                child: filtered.isEmpty
                    ? MoniqEmptyState.peaceful(
                        title: '변경 요청이 없어요',
                        message: '근무 변경이 필요하면 요청을 생성해보세요',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (_, i) {
                          final r = filtered[i];
                          final isCheckboxSelected =
                              selectedIds.contains(r.id);
                          final isFocused =
                              !selectionMode && selectedRequest?.id == r.id;
                          return RequestCard(
                            request: r,
                            selectionMode: selectionMode,
                            selected: selectionMode
                                ? isCheckboxSelected
                                : isFocused,
                            onTap: () {
                              if (selectionMode) {
                                onToggleSelection(r.id);
                              } else {
                                onSelectRequest(isFocused ? null : r);
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
          child: selectedRequest == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.swap_horiz_rounded,
                        size: 48,
                        color: colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.3),
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
                  key: ValueKey(selectedRequest!.id),
                  request: selectedRequest!,
                  isAdmin: state.isAdmin,
                  myUserId: myUserId,
                  onApprove: () => onApprove(selectedRequest!.id),
                  onReject: () => onReject(selectedRequest!.id),
                  onCancel: () => onCancel(selectedRequest!.id),
                ),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────
// 웹 상세 패널
// ────────────────────────────────────────

class _WebDetailPanel extends StatelessWidget {
  const _WebDetailPanel({
    super.key,
    required this.request,
    required this.isAdmin,
    required this.myUserId,
    required this.onApprove,
    required this.onReject,
    required this.onCancel,
  });

  final RequestModel request;
  final bool isAdmin;
  final String? myUserId;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onCancel;

  bool get _canCancel =>
      myUserId != null && request.requesterUserId == myUserId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final (statusColor, _, _) = _statusStyle(request.status, colorScheme);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 상단 상태 + 날짜 ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                      color: statusColor.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        StatusBadge(status: request.status),
                        const Spacer(),
                        if (request.createdAt != null)
                          Text(
                            DateFormat('yyyy.MM.dd HH:mm')
                                .format(request.createdAt!),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      changeTypeLabel(request.changeType),
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (request.requestedDate != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_outlined,
                              size: 14,
                              color: colorScheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('yyyy.MM.dd')
                                .format(request.requestedDate!),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // ── 사유 ──
              if (request.reason != null &&
                  request.reason!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                _DetailSection(
                  label: '사유',
                  content: request.reason!,
                ),
              ],

              // ── 메모 ──
              if (request.note != null && request.note!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                _DetailSection(
                  label: '메모',
                  content: request.note!,
                  isSecondary: true,
                ),
              ],

              const SizedBox(height: AppSpacing.xl),

              // ── 액션 버튼 ──
              if (request.status == 'pending') ...[
                if (isAdmin)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onReject,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colorScheme.error,
                            side: BorderSide(
                                color: colorScheme.error
                                    .withValues(alpha: 0.5)),
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
                          ),
                          child: const Text('거절'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: onApprove,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
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

// ────────────────────────────────────────
// 모바일 바텀시트
// ────────────────────────────────────────

class _RequestDetailSheet extends StatelessWidget {
  const _RequestDetailSheet({
    required this.request,
    required this.isAdmin,
    required this.myUserId,
    required this.onApprove,
    required this.onReject,
    required this.onCancel,
  });

  final RequestModel request;
  final bool isAdmin;
  final String? myUserId;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onCancel;

  bool get _canCancel =>
      myUserId != null && request.requesterUserId == myUserId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 핸들
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                StatusBadge(status: request.status),
                const Spacer(),
                if (request.createdAt != null)
                  Text(
                    DateFormat('yyyy.MM.dd HH:mm')
                        .format(request.createdAt!),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              changeTypeLabel(request.changeType),
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (request.requestedDate != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 14, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('yyyy.MM.dd')
                        .format(request.requestedDate!),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
            if (request.reason != null &&
                request.reason!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              _DetailSection(label: '사유', content: request.reason!),
            ],
            if (request.note != null && request.note!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              _DetailSection(
                  label: '메모',
                  content: request.note!,
                  isSecondary: true),
            ],
            const SizedBox(height: AppSpacing.xl),
            if (request.status == 'pending') ...[
              if (isAdmin)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onReject,
                        style: OutlinedButton.styleFrom(
                            foregroundColor: colorScheme.error),
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
      ),
    );
  }
}

// ────────────────────────────────────────
// 공통 위젯
// ────────────────────────────────────────

// 필터 바
class _FilterBar extends StatelessWidget {
  const _FilterBar(
      {required this.currentFilter, required this.onFilterChanged});
  final String currentFilter;
  final ValueChanged<String> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    const filters = [
      ('all', '전체'),
      ('pending', '대기중'),
      ('approved', '승인'),
      ('rejected', '거절'),
      ('cancelled', '취소'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: Row(
        children: filters
            .map((f) => Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: _FilterChip(
                    label: f.$2,
                    selected: currentFilter == f.$1,
                    onTap: () => onFilterChanged(f.$1),
                  ),
                ))
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
                    color: colorScheme.onSurfaceVariant)
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
    required this.request,
    required this.onTap,
    this.selectionMode = false,
    this.selected = false,
  });

  final RequestModel request;
  final VoidCallback onTap;
  final bool selectionMode;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dateFormat = DateFormat('MM.dd');
    final (statusColor, _, _) = _statusStyle(request.status, colorScheme);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primary.withValues(alpha: 0.06)
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: selected
                ? colorScheme.primary.withValues(alpha: 0.3)
                : colorScheme.outlineVariant,
          ),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 왼쪽 컬러 accent bar — 카드 전체 높이에 맞춤
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(AppRadius.sm)),
                ),
              ),
              const SizedBox(width: AppSpacing.md),

              if (selectionMode) ...[
                Align(
                  alignment: Alignment.center,
                  child: Icon(
                    selected
                        ? Icons.check_box_rounded
                        : Icons.check_box_outline_blank_rounded,
                    color:
                        selected ? AppColors.primary : colorScheme.outline,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md, horizontal: AppSpacing.xs),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 상단 라인: 요청 유형 — 날짜 — 상태 뱃지 (동일 선상)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              changeTypeLabel(request.changeType),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (request.createdAt != null) ...[
                            Text(
                              dateFormat.format(request.createdAt!),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                          ],
                          StatusBadge(status: request.status),
                        ],
                      ),
                      if (request.reason != null &&
                          request.reason!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          request.reason!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
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
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
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
  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: colorScheme.primary.withValues(alpha: 0.15),
      checkmarkColor: colorScheme.primary,
    );
  }
}

// ────────────────────────────────────────
// 헬퍼
// ────────────────────────────────────────

List<RequestModel> _filtered(RequestListState state) => state.filter == 'all'
    ? state.requests
    : state.requests.where((r) => r.status == state.filter).toList();

(Color color, Color bgColor, String label) _statusStyle(
    String status, ColorScheme colorScheme) {
  return switch (status) {
    'pending' => (
      AppColors.brandOrange,
      AppColors.brandOrange.withValues(alpha: 0.1),
      '대기중',
    ),
    'approved' => (
      AppColors.success,
      AppColors.successLight,
      '승인',
    ),
    'rejected' => (
      colorScheme.error,
      AppColors.errorLight,
      '거절',
    ),
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
              Icon(
                isAllSelected
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                size: 20,
                color: isAllSelected
                    ? AppColors.primary
                    : cs.onSurfaceVariant,
              ),
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
