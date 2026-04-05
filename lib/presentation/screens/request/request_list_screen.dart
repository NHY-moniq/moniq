import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moniq/data/models/request_model.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/request_viewmodel.dart';
import 'package:moniq/presentation/widgets/common/moniq_empty_state.dart';
import 'package:moniq/presentation/widgets/common/moniq_error_view.dart';
import 'package:moniq/presentation/widgets/common/moniq_loading_view.dart';

class RequestListScreen extends HookConsumerWidget {
  const RequestListScreen({super.key, required this.teamId});

  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(requestListViewModelProvider(teamId));

    return Scaffold(
      appBar: AppBar(title: const Text('변경 요청')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/teams/$teamId/requests/create'),
        icon: const Icon(Icons.add),
        label: const Text('요청하기'),
      ),
      body: stateAsync.when(
        loading: () => const MoniqLoadingView(),
        error: (e, _) => MoniqErrorView(
          message: '요청 목록을 불러올 수 없습니다',
          onRetry: () =>
              ref.invalidate(requestListViewModelProvider(teamId)),
        ),
        data: (state) {
          return Column(
            children: [
              // 필터 칩
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                child: Row(
                  children: [
                    _FilterChip(
                        label: '전체',
                        selected: state.filter == 'all',
                        onTap: () => ref
                            .read(requestListViewModelProvider(teamId)
                                .notifier)
                            .setFilter('all')),
                    const SizedBox(width: AppSpacing.sm),
                    _FilterChip(
                        label: '대기중',
                        selected: state.filter == 'pending',
                        onTap: () => ref
                            .read(requestListViewModelProvider(teamId)
                                .notifier)
                            .setFilter('pending')),
                    const SizedBox(width: AppSpacing.sm),
                    _FilterChip(
                        label: '승인',
                        selected: state.filter == 'approved',
                        onTap: () => ref
                            .read(requestListViewModelProvider(teamId)
                                .notifier)
                            .setFilter('approved')),
                    const SizedBox(width: AppSpacing.sm),
                    _FilterChip(
                        label: '거절',
                        selected: state.filter == 'rejected',
                        onTap: () => ref
                            .read(requestListViewModelProvider(teamId)
                                .notifier)
                            .setFilter('rejected')),
                  ],
                ),
              ),

              const Divider(height: 1),

              // 요청 목록
              Expanded(
                child: _buildList(context, ref, state),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildList(
      BuildContext context, WidgetRef ref, RequestListState state) {
    final filtered = state.filter == 'all'
        ? state.requests
        : state.requests.where((r) => r.status == state.filter).toList();

    if (filtered.isEmpty) {
      return const MoniqEmptyState(
        icon: Icons.swap_horiz,
        message: '변경 요청이 없습니다',
        description: '근무 변경이 필요하면 요청을 생성해보세요',
      );
    }

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(requestListViewModelProvider(teamId).notifier).refresh(),
      child: ListView.separated(
        padding: AppSpacing.screenAll,
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          final request = filtered[index];
          return _RequestCard(
            request: request,
            onTap: () =>
                _showRequestDetail(context, ref, request),
          );
        },
      ),
    );
  }

  void _showRequestDetail(
      BuildContext context, WidgetRef ref, RequestModel request) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('yyyy.MM.dd HH:mm');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _StatusBadge(status: request.status),
                  const Spacer(),
                  if (request.createdAt != null)
                    Text(
                      dateFormat.format(request.createdAt!),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('요청 유형',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  )),
              const SizedBox(height: AppSpacing.xs),
              Text(_changeTypeLabel(request.changeType),
                  style: theme.textTheme.bodyLarge),
              if (request.requestedDate != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text('희망 날짜',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    )),
                const SizedBox(height: AppSpacing.xs),
                Text(DateFormat('yyyy.MM.dd').format(request.requestedDate!),
                    style: theme.textTheme.bodyLarge),
              ],
              if (request.reason != null && request.reason!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text('사유',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    )),
                const SizedBox(height: AppSpacing.xs),
                Text(request.reason!, style: theme.textTheme.bodyLarge),
              ],
              if (request.note != null && request.note!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text('메모',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    )),
                const SizedBox(height: AppSpacing.xs),
                Text(request.note!, style: theme.textTheme.bodyMedium),
              ],
              const SizedBox(height: AppSpacing.xxl),

              // 관리자 액션
              if (request.status == 'pending') ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          await ref
                              .read(requestListViewModelProvider(teamId)
                                  .notifier)
                              .rejectRequest(request.id);
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        style: OutlinedButton.styleFrom(
                            foregroundColor: theme.colorScheme.error),
                        child: const Text('거절'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          await ref
                              .read(requestListViewModelProvider(teamId)
                                  .notifier)
                              .approveRequest(request.id);
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        child: const Text('승인'),
                      ),
                    ),
                  ],
                ),
              ],
              if (request.status == 'pending') ...[
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () async {
                      await ref
                          .read(requestListViewModelProvider(teamId).notifier)
                          .cancelRequest(request.id);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
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

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request, required this.onTap});

  final RequestModel request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MM.dd');

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.borderRadiusMd,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_changeTypeLabel(request.changeType),
                        style: theme.textTheme.bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w500)),
                    const SizedBox(height: AppSpacing.xs),
                    if (request.reason != null && request.reason!.isNotEmpty)
                      Text(request.reason!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    if (request.createdAt != null)
                      Text(
                        dateFormat.format(request.createdAt!),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              _StatusBadge(status: request.status),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (label, color, bgColor) = switch (status) {
      'pending' => (
        '대기중',
        AppColors.brandOrange,
        AppColors.brandOrange.withValues(alpha: 0.1),
      ),
      'approved' => (
        '승인',
        AppColors.success,
        AppColors.successLight,
      ),
      'rejected' => (
        '거절',
        colorScheme.error,
        AppColors.errorLight,
      ),
      'cancelled' => (
        '취소',
        colorScheme.onSurfaceVariant,
        colorScheme.outlineVariant,
      ),
      _ => (
        '알수없음',
        colorScheme.onSurfaceVariant,
        colorScheme.outlineVariant,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppRadius.borderRadiusSm,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

String _changeTypeLabel(String type) {
  return switch (type) {
    'swap' => '근무 교환',
    'day_off' => '휴무 요청',
    'shift_change' => '근무 변경',
    'schedule_change' => '일정 변경',
    _ => type,
  };
}
