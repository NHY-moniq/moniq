import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moniq/data/models/request_model.dart';
import 'package:moniq/presentation/layout/adaptive_layout.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/request_viewmodel.dart';
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

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('선택 삭제'),
        content: Text('선택한 ${_selectedIds.length}건을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ref
          .read(requestListViewModelProvider(widget.teamId).notifier)
          .deleteRequests(_selectedIds.toList());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
      }
    }
    _exitSelectionMode();
  }

  @override
  Widget build(BuildContext context) {
    final teamId = widget.teamId;
    final stateAsync = ref.watch(requestListViewModelProvider(teamId));
    final isWide = AdaptiveLayout.isWide(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_selectionMode ? '${_selectedIds.length}건 선택됨' : '변경 요청'),
        leading: _selectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _exitSelectionMode,
              )
            : null,
        actions: [
          if (_selectionMode)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.error),
              onPressed: _selectedIds.isEmpty ? null : _deleteSelected,
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.checklist_rounded),
              tooltip: '선택 모드',
              onPressed: () => setState(() => _selectionMode = true),
            ),
            // 웹에서는 AppBar에 요청하기 버튼
            if (isWide)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: FilledButton.icon(
                  onPressed: () =>
                      context.push('/teams/$teamId/requests/create'),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('요청하기'),
                ),
              ),
          ],
        ],
      ),
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
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<RequestModel> onShowDetail;
  final ValueChanged<String> onApprove;
  final ValueChanged<String> onReject;
  final ValueChanged<String> onCancel;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered(state);

    return Column(
      children: [
        _FilterBar(
            currentFilter: state.filter, onFilterChanged: onFilterChanged),
        const Divider(height: 1),
        Expanded(
          child: filtered.isEmpty
              ? const MoniqEmptyState(
                  icon: Icons.swap_horiz,
                  message: '변경 요청이 없습니다',
                  description: '근무 변경이 필요하면 요청을 생성해보세요',
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
                      selectionMode: selectionMode && canDelete,
                      selected: isSelected,
                      onTap: () {
                        if (selectionMode && canDelete) {
                          onToggleSelection(r.id);
                        } else {
                          onShowDetail(r);
                        }
                      },
                    );

                    if (!canDelete) return card;

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
                      confirmDismiss: (_) async {
                        return await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('요청 삭제'),
                                content:
                                    const Text('이 취소된 요청을 삭제하시겠습니까?'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(ctx, false),
                                    child: const Text('취소'),
                                  ),
                                  TextButton(
                                    style: TextButton.styleFrom(
                                        foregroundColor: AppColors.error),
                                    onPressed: () =>
                                        Navigator.pop(ctx, true),
                                    child: const Text('삭제'),
                                  ),
                                ],
                              ),
                            ) ??
                            false;
                      },
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
                    ? const MoniqEmptyState(
                        icon: Icons.swap_horiz,
                        message: '변경 요청이 없습니다',
                        description: '근무 변경이 필요하면 요청을 생성해보세요',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (_, i) {
                          final r = filtered[i];
                          final isSelected =
                              selectedRequest?.id == r.id;
                          return RequestCard(
                            request: r,
                            selectionMode: false,
                            selected: isSelected,
                            onTap: () => onSelectRequest(
                                isSelected ? null : r),
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
    required this.onApprove,
    required this.onReject,
    required this.onCancel,
  });

  final RequestModel request;
  final bool isAdmin;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onCancel;

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
    required this.onApprove,
    required this.onReject,
    required this.onCancel,
  });

  final RequestModel request;
  final bool isAdmin;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onCancel;

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
        child: Row(
          children: [
            // 왼쪽 컬러 accent bar
            Container(
              width: 4,
              height: 72,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(AppRadius.sm)),
              ),
            ),
            const SizedBox(width: AppSpacing.md),

            if (selectionMode) ...[
              Icon(
                selected
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                color: selected ? AppColors.primary : colorScheme.outline,
              ),
              const SizedBox(width: AppSpacing.sm),
            ],

            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.md, horizontal: AppSpacing.xs),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            changeTypeLabel(request.changeType),
                            style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600),
                          ),
                          if (request.reason != null &&
                              request.reason!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              request.reason!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          if (request.createdAt != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              dateFormat.format(request.createdAt!),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    StatusBadge(status: request.status),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
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
      'swap' => '근무 교환',
      'day_off' => '휴무 요청',
      'shift_change' => '근무 변경',
      'schedule_change' => '일정 변경',
      _ => type,
    };
