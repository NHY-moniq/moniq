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

part 'request_list_layouts.dart';
part 'request_list_widgets.dart';

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
      eyebrow: 'APPROVE',
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
      eyebrow: 'REJECT',
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
      eyebrow: 'CANCEL',
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
