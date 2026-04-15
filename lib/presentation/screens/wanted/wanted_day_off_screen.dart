import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moniq/data/models/shift_type_model.dart';
import 'package:moniq/data/models/wanted_request_model.dart';
import 'package:moniq/data/providers/shift_providers.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/wanted_viewmodel.dart';
import 'package:moniq/presentation/widgets/common/moniq_empty_state.dart';
import 'package:moniq/presentation/widgets/common/moniq_error_view.dart';
import 'package:moniq/presentation/widgets/common/moniq_loading_view.dart';

/// 팀 근무 유형 로더
final _wantedShiftTypesProvider =
    FutureProvider.autoDispose.family<List<ShiftTypeModel>, String>(
  (ref, teamId) =>
      ref.watch(shiftRepositoryProvider).getShiftTypes(teamId),
);

/// 팀원: 희망 휴무일 입력 화면
class WantedDayOffScreen extends HookConsumerWidget {
  const WantedDayOffScreen({super.key, required this.teamId});

  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 화면 진입 시 최신 활성 요청 재조회 (관리자가 새 요청 생성 후 캐시 반영)
    useEffect(() {
      Future.microtask(
          () => ref.invalidate(wantedMemberViewModelProvider(teamId)));
      return null;
    }, const []);

    final stateAsync = ref.watch(wantedMemberViewModelProvider(teamId));
    // 진입 즉시 shift types 프리로드 (희망 근무 시트 로딩 체감 제거)
    ref.watch(_wantedShiftTypesProvider(teamId));

    // 활성 요청의 타입에 따라 타이틀 변경
    final activeType = stateAsync.valueOrNull?.activeRequest?.wantedType;
    final typeLabel = WantedType.fromString(activeType).label;

    return Scaffold(
      appBar: AppBar(
        title: Text('$typeLabel 입력'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '새로고침',
            onPressed: () =>
                ref.invalidate(wantedMemberViewModelProvider(teamId)),
          ),
        ],
      ),
      body: stateAsync.when(
        loading: () => const MoniqLoadingView(),
        error: (e, _) => MoniqErrorView(
          message: '정보를 불러올 수 없습니다',
          onRetry: () =>
              ref.invalidate(wantedMemberViewModelProvider(teamId)),
        ),
        data: (state) {
          if (state.activeRequest == null) {
            return RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(wantedMemberViewModelProvider(teamId)),
              child: ListView(
                children: const [
                  SizedBox(height: 120),
                  MoniqEmptyState(
                    icon: Icons.event_busy,
                    message: '현재 진행 중인 원티드 수집이 없습니다',
                    description: '관리자가 수집을 시작하면 여기서 입력할 수 있습니다',
                  ),
                ],
              ),
            );
          }
          return _EntryView(teamId: teamId, state: state);
        },
      ),
    );
  }
}

class _EntryView extends HookConsumerWidget {
  const _EntryView({required this.teamId, required this.state});

  final String teamId;
  final WantedMemberState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final dateFormat = DateFormat('yyyy.MM.dd');
    final request = state.activeRequest!;

    // 마감일 지났는지 체크
    final isExpired = request.deadline != null &&
        DateTime.now().isAfter(request.deadline!);

    return Column(
      children: [
        // 타입 전환 칩 (여러 활성 요청이 있을 때만 표시)
        if (state.activeRequests.length > 1)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: SizedBox(
              width: double.infinity,
              child: Wrap(
                spacing: AppSpacing.sm,
                children: state.activeRequests.map((r) {
                  final isSelected =
                      state.activeRequest?.wantedType == r.wantedType;
                  return ChoiceChip(
                    label: Text(
                      WantedType.fromString(r.wantedType).label,
                    ),
                    selected: isSelected,
                    onSelected: (_) {
                      ref
                          .read(wantedMemberViewModelProvider(teamId).notifier)
                          .selectType(r.wantedType);
                    },
                  );
                }).toList(),
              ),
            ),
          ),

        // 안내 배너
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          color: isExpired
              ? colorScheme.error.withValues(alpha: 0.08)
              : colorScheme.primary.withValues(alpha: 0.08),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isExpired
                    ? '${WantedType.fromString(request.wantedType).label} 입력 기간이 아닙니다!'
                    : '${WantedType.fromString(request.wantedType).label} 정보를 입력해주세요',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isExpired
                      ? colorScheme.error
                      : colorScheme.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '근무 생성 기간: ${dateFormat.format(request.periodStart)} ~ ${dateFormat.format(request.periodEnd)}',
                style: theme.textTheme.bodySmall,
              ),
              if (request.deadline != null)
                Text(
                  '마감일: ${dateFormat.format(request.deadline!)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.error,
                  ),
                ),
            ],
          ),
        ),

        // 내 엔트리 목록 / 신청 상태
        Expanded(
          child: _buildBody(context, ref, isExpired),
        ),

        // 하단 액션 버튼 (타입별 분기)
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: _buildActionButton(context, ref, isExpired),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, bool isExpired) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dateFormat = DateFormat('yyyy.MM.dd');
    final wantedType = WantedType.fromString(state.activeRequest?.wantedType);

    // 나이트 전담: 신청 완료 상태 표시
    if (wantedType == WantedType.nightDedicated) {
      final isApplied = state.myEntries.isNotEmpty;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isApplied ? Icons.check_circle : Icons.nightlight_round,
              size: 64,
              color: isApplied
                  ? AppColors.success
                  : colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              isApplied ? '나이트 전담 신청 완료' : '아래 버튼으로 신청하세요',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: isApplied
                    ? AppColors.success
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    if (state.myEntries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today,
              size: 48,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '아래 버튼으로 희망 날짜를 추가하세요',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    // 희망 근무 — shift type lookup 포함
    final shiftTypesAsync = wantedType == WantedType.preferredShift
        ? ref.watch(_wantedShiftTypesProvider(teamId))
        : const AsyncValue<List<ShiftTypeModel>>.data([]);
    final shiftTypeMap = {
      for (final t in (shiftTypesAsync.valueOrNull ?? [])) t.id: t,
    };

    return ListView.separated(
      padding: AppSpacing.screenAll,
      itemCount: state.myEntries.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final entry = state.myEntries[index];
        final shiftType =
            entry.shiftTypeId != null ? shiftTypeMap[entry.shiftTypeId] : null;
        return Card(
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                wantedType == WantedType.preferredShift
                    ? (shiftType?.code ?? '?')
                    : '${entry.priority}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
            title: Text(dateFormat.format(entry.wantedDate)),
            subtitle: Text([
              if (wantedType == WantedType.preferredShift && shiftType != null)
                shiftType.name,
              if (entry.reason != null && entry.reason!.isNotEmpty)
                entry.reason!,
            ].join(' · ')),
            trailing: isExpired
                ? null
                : IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => _removeEntry(context, ref, entry.id),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildActionButton(BuildContext context, WidgetRef ref, bool isExpired) {
    final wantedType = WantedType.fromString(state.activeRequest?.wantedType);
    final label = WantedType.fromString(state.activeRequest?.wantedType).label;

    if (wantedType == WantedType.nightDedicated) {
      final isApplied = state.myEntries.isNotEmpty;
      return SizedBox(
        width: double.infinity,
        child: isApplied
            ? OutlinedButton.icon(
                onPressed: (state.isSubmitting || isExpired)
                    ? null
                    : () =>
                        _removeEntry(context, ref, state.myEntries.first.id),
                icon: const Icon(Icons.close),
                label: const Text('나이트 전담 신청 취소'),
              )
            : ElevatedButton.icon(
                onPressed: (state.isSubmitting || isExpired)
                    ? null
                    : () => _applyNightDedicated(context, ref),
                icon: state.isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.nightlight_round),
                label: const Text('나이트 전담 신청하기'),
              ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: (state.isSubmitting || isExpired)
            ? null
            : () {
                if (wantedType == WantedType.preferredShift) {
                  _showPreferredShiftPicker(context, ref);
                } else {
                  _showMultiDatePicker(context, ref);
                }
              },
        icon: state.isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add),
        label: Text(wantedType == WantedType.preferredShift
            ? '$label 추가'
            : '$label 날짜 추가'),
      ),
    );
  }

  Future<void> _removeEntry(
      BuildContext context, WidgetRef ref, String entryId) async {
    final ok = await ref
        .read(wantedMemberViewModelProvider(teamId).notifier)
        .removeEntry(entryId);
    if (!context.mounted || ok) return;
    final err = ref
        .read(wantedMemberViewModelProvider(teamId))
        .valueOrNull
        ?.error;
    if (err != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err)));
    }
  }

  Future<void> _applyNightDedicated(BuildContext context, WidgetRef ref) async {
    final request = state.activeRequest!;
    final success = await ref
        .read(wantedMemberViewModelProvider(teamId).notifier)
        .addWantedDates(
          datesWithPriority: {request.periodStart: 1},
          reason: '나이트 전담 신청',
        );
    if (!context.mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('나이트 전담 신청이 완료되었습니다')),
      );
    } else {
      final err = ref
          .read(wantedMemberViewModelProvider(teamId))
          .valueOrNull
          ?.error;
      if (err != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(err)));
      }
    }
  }

  /// 희망 근무 선택 시트 — 날짜별로 근무 유형(데이/이브닝/나이트 등) 지정
  void _showPreferredShiftPicker(BuildContext context, WidgetRef ref) {
    final request = state.activeRequest!;
    final existingDates = state.myEntries
        .map((e) => DateTime(
            e.wantedDate.year, e.wantedDate.month, e.wantedDate.day))
        .toSet();
    // date → (shiftTypeId, priority)
    final selected = <DateTime, _PrefSel>{};
    String reason = '';
    String? sheetError;
    // 미리 로드된 shift types를 한 번만 읽음
    final shiftTypesAsync = ref.read(_wantedShiftTypesProvider(teamId));
    final shiftTypes = shiftTypesAsync.valueOrNull ?? [];
    String? currentShiftTypeId =
        shiftTypes.isNotEmpty ? shiftTypes.first.id : null;
    int currentPriority = 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {

          return DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (ctx, scrollController) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.md),
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(ctx).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    '희망 근무 선택',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '우선순위와 근무 유형을 고른 뒤 날짜를 탭하세요.',
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                          color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // 우선순위 선택
                  Row(
                    children: [1, 2, 3].map((p) {
                      return Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: ChoiceChip(
                          label: Text('$p순위'),
                          selected: currentPriority == p,
                          onSelected: (_) =>
                              setSheetState(() => currentPriority = p),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // 근무 유형 선택 칩
                  if (shiftTypes.isEmpty)
                    Text(
                      '등록된 근무 유형이 없습니다',
                      style: Theme.of(ctx).textTheme.bodySmall,
                    )
                  else
                    Wrap(
                      spacing: AppSpacing.sm,
                      children: shiftTypes
                          .map((t) => ChoiceChip(
                                label: Text(t.name),
                                selected: currentShiftTypeId == t.id,
                                onSelected: (_) => setSheetState(
                                    () => currentShiftTypeId = t.id),
                              ))
                          .toList(),
                    ),

                  const SizedBox(height: AppSpacing.md),

                  // 캘린더 그리드
                  Expanded(
                    child: _MultiDateShiftCalendar(
                      periodStart: request.periodStart,
                      periodEnd: request.periodEnd,
                      selectedDates: selected,
                      shiftTypes: shiftTypes,
                      existingDates: existingDates,
                      onToggle: (date) {
                        final typeId = currentShiftTypeId;
                        if (typeId == null) return;
                        setSheetState(() {
                          final existing = selected[date];
                          if (existing != null &&
                              existing.shiftTypeId == typeId &&
                              existing.priority == currentPriority) {
                            selected.remove(date);
                          } else {
                            selected[date] = _PrefSel(
                                shiftTypeId: typeId,
                                priority: currentPriority);
                          }
                        });
                      },
                      scrollController: scrollController,
                    ),
                  ),

                  if (selected.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: Text(
                        '${selected.length}일 선택됨',
                        style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                              color: Theme.of(ctx).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),

                  const SizedBox(height: AppSpacing.md),

                  TextField(
                    onChanged: (v) => reason = v,
                    decoration: const InputDecoration(
                      hintText: '사유 (선택)',
                    ),
                    maxLines: 1,
                  ),

                  if (sheetError != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      sheetError!,
                      style: Theme.of(ctx)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.error),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.lg),

                  ElevatedButton(
                    onPressed: selected.isEmpty
                        ? null
                        : () async {
                            // (shiftTypeId, priority)별로 그룹핑 후 저장
                            final grouped = <_PrefSel, List<DateTime>>{};
                            for (final e in selected.entries) {
                              grouped.putIfAbsent(e.value, () => []).add(e.key);
                            }
                            final notifier = ref.read(
                                wantedMemberViewModelProvider(teamId)
                                    .notifier);
                            var allOk = true;
                            for (final entry in grouped.entries) {
                              final ok = await notifier.addWantedDates(
                                datesWithPriority: {
                                  for (final d in entry.value)
                                    d: entry.key.priority,
                                },
                                reason: reason.isNotEmpty ? reason : null,
                                shiftTypeId: entry.key.shiftTypeId,
                              );
                              if (!ok) allOk = false;
                            }
                            if (!ctx.mounted) return;
                            if (allOk) {
                              Navigator.pop(ctx);
                            } else {
                              final err = ref
                                  .read(wantedMemberViewModelProvider(teamId))
                                  .valueOrNull
                                  ?.error;
                              setSheetState(() {
                                sheetError = err ?? '저장에 실패했습니다';
                              });
                            }
                          },
                    child: Text(
                      selected.isEmpty
                          ? '날짜를 선택해주세요'
                          : '${selected.length}일 추가',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showMultiDatePicker(BuildContext context, WidgetRef ref) {
    final request = state.activeRequest!;
    final existingDates = state.myEntries
        .map((e) => DateTime(
            e.wantedDate.year, e.wantedDate.month, e.wantedDate.day))
        .toSet();
    // 날짜 → 우선순위(1/2/3). 없으면 미선택.
    final selectedDates = <DateTime, int>{};
    int currentPriority = 1;
    String reason = '';
    String? sheetError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (ctx, scrollController) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.md),
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(ctx).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    '${WantedType.fromString(state.activeRequest?.wantedType).label} 날짜 선택',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '우선순위를 고른 뒤 날짜를 탭하세요. 다시 탭하면 해제됩니다.',
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                          color: Theme.of(ctx)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // 우선순위 선택 칩
                  Row(
                    children: [1, 2, 3].map((p) {
                      final isActive = currentPriority == p;
                      return Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: ChoiceChip(
                          label: Text('$p순위'),
                          selected: isActive,
                          onSelected: (_) =>
                              setSheetState(() => currentPriority = p),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // 캘린더 그리드
                  Expanded(
                    child: _MultiDateCalendar(
                      periodStart: request.periodStart,
                      periodEnd: request.periodEnd,
                      selectedDates: selectedDates,
                      existingDates: existingDates,
                      onToggle: (date) {
                        setSheetState(() {
                          if (selectedDates.containsKey(date)) {
                            // 같은 우선순위면 해제, 다른 우선순위면 덮어쓰기
                            if (selectedDates[date] == currentPriority) {
                              selectedDates.remove(date);
                            } else {
                              selectedDates[date] = currentPriority;
                            }
                          } else {
                            selectedDates[date] = currentPriority;
                          }
                        });
                      },
                      scrollController: scrollController,
                    ),
                  ),

                  // 선택 요약
                  if (selectedDates.isNotEmpty)
                    Padding(
                      padding:
                          const EdgeInsets.only(top: AppSpacing.sm),
                      child: Text(
                        '${selectedDates.length}일 선택됨',
                        style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                              color: Theme.of(ctx).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),

                  const SizedBox(height: AppSpacing.md),

                  // 사유 (선택)
                  TextField(
                    onChanged: (v) => reason = v,
                    decoration: const InputDecoration(
                      hintText: '사유 (선택, 선택한 날짜에 공통 적용)',
                    ),
                    maxLines: 1,
                  ),

                  if (sheetError != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: AppColors.error, size: 18),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              sheetError!,
                              style: Theme.of(ctx)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: AppColors.error,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.lg),

                  ElevatedButton(
                    onPressed: selectedDates.isEmpty
                        ? null
                        : () async {
                            final success = await ref
                                .read(wantedMemberViewModelProvider(teamId)
                                    .notifier)
                                .addWantedDates(
                                  datesWithPriority:
                                      Map.of(selectedDates),
                                  reason:
                                      reason.isNotEmpty ? reason : null,
                                );
                            if (!ctx.mounted) return;
                            if (success) {
                              Navigator.pop(ctx);
                            } else {
                              final err = ref
                                  .read(wantedMemberViewModelProvider(teamId))
                                  .valueOrNull
                                  ?.error;
                              setSheetState(() {
                                sheetError = err ?? '저장에 실패했습니다';
                              });
                              // 마감/완료 상태면 활성 요청도 갱신
                              if (err != null &&
                                  (err.contains('마감') || err.contains('완료'))) {
                                ref.invalidate(
                                    wantedMemberViewModelProvider(teamId));
                              }
                            }
                          },
                    child: Text(selectedDates.isEmpty
                        ? '날짜를 선택해주세요'
                        : '${selectedDates.length}일 추가'),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 복수 날짜 선택 캘린더 위젯
class _MultiDateCalendar extends StatefulWidget {
  const _MultiDateCalendar({
    required this.periodStart,
    required this.periodEnd,
    required this.selectedDates,
    required this.existingDates,
    required this.onToggle,
    required this.scrollController,
  });

  final DateTime periodStart;
  final DateTime periodEnd;
  final Map<DateTime, int> selectedDates;
  final Set<DateTime> existingDates;
  final ValueChanged<DateTime> onToggle;
  final ScrollController scrollController;

  @override
  State<_MultiDateCalendar> createState() => _MultiDateCalendarState();
}

class _MultiDateCalendarState extends State<_MultiDateCalendar> {
  late DateTime _currentMonth;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(
        widget.periodStart.year, widget.periodStart.month);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final dayLabels = ['월', '화', '수', '목', '금', '토', '일'];

    // 해당 월의 날짜 계산
    final firstDay =
        DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDay =
        DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final startWeekday = firstDay.weekday; // 1=월 ~ 7=일

    final days = <DateTime?>[];
    // 앞쪽 빈칸
    for (int i = 1; i < startWeekday; i++) {
      days.add(null);
    }
    // 실제 날짜
    for (int d = 1; d <= lastDay.day; d++) {
      days.add(
        DateTime(_currentMonth.year, _currentMonth.month, d),
      );
    }

    return Column(
      children: [
        // 월 네비게이션
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () {
                final prev = DateTime(
                  _currentMonth.year,
                  _currentMonth.month - 1,
                );
                final periodMonth = DateTime(
                  widget.periodStart.year,
                  widget.periodStart.month,
                );
                if (!prev.isBefore(periodMonth)) {
                  setState(() => _currentMonth = prev);
                }
              },
            ),
            Text(
              DateFormat('yyyy년 MM월').format(_currentMonth),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () {
                final next = DateTime(
                  _currentMonth.year,
                  _currentMonth.month + 1,
                );
                final periodEndMonth = DateTime(
                  widget.periodEnd.year,
                  widget.periodEnd.month,
                );
                if (!next.isAfter(
                  DateTime(
                    periodEndMonth.year,
                    periodEndMonth.month + 1,
                  ),
                )) {
                  setState(() => _currentMonth = next);
                }
              },
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),

        // 요일 헤더
        Row(
          children: dayLabels.map((label) {
            final isWeekend = label == '토' || label == '일';
            return Expanded(
              child: Center(
                child: Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isWeekend
                        ? colorScheme.error
                            .withValues(alpha: 0.6)
                        : colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.sm),

        // 날짜 그리드
        Expanded(
          child: GridView.builder(
            controller: widget.scrollController,
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
            ),
            itemCount: days.length,
            itemBuilder: (context, index) {
              final day = days[index];
              if (day == null) return const SizedBox();

              final isInPeriod = !day.isBefore(widget.periodStart) &&
                  !day.isAfter(widget.periodEnd);
              final selectedPriority = widget.selectedDates[day];
              final isSelected = selectedPriority != null;
              final isExisting = widget.existingDates.contains(day);

              return GestureDetector(
                onTap: isInPeriod && !isExisting
                    ? () => widget.onToggle(day)
                    : null,
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colorScheme.primary
                        : isExisting
                            ? colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.15)
                            : null,
                    borderRadius:
                        BorderRadius.circular(AppRadius.xs),
                    border:
                        isInPeriod && !isSelected && !isExisting
                            ? Border.all(
                                color:
                                    colorScheme.outlineVariant,
                              )
                            : null,
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Text(
                          '${day.day}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isSelected
                                ? Colors.white
                                : isExisting
                                    ? AppColors.onSurfaceVariant
                                    : isInPeriod
                                        ? null
                                        : AppColors.onSurfaceVariant
                                            .withValues(alpha: 0.3),
                            fontWeight:
                                isSelected ? FontWeight.w700 : null,
                          ),
                        ),
                      ),
                      if (isSelected)
                        Positioned(
                          top: 2,
                          right: 2,
                          child: Text(
                            '$selectedPriority',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 희망 근무용 캘린더 — 날짜별 선택된 shift type 코드를 뱃지로 표시
class _MultiDateShiftCalendar extends StatefulWidget {
  const _MultiDateShiftCalendar({
    required this.periodStart,
    required this.periodEnd,
    required this.selectedDates,
    required this.shiftTypes,
    required this.existingDates,
    required this.onToggle,
    required this.scrollController,
  });

  final DateTime periodStart;
  final DateTime periodEnd;
  final Map<DateTime, _PrefSel> selectedDates;
  final List<ShiftTypeModel> shiftTypes;
  final Set<DateTime> existingDates;
  final ValueChanged<DateTime> onToggle;
  final ScrollController scrollController;

  @override
  State<_MultiDateShiftCalendar> createState() =>
      _MultiDateShiftCalendarState();
}

class _MultiDateShiftCalendarState extends State<_MultiDateShiftCalendar> {
  late DateTime _currentMonth;

  @override
  void initState() {
    super.initState();
    _currentMonth =
        DateTime(widget.periodStart.year, widget.periodStart.month);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dayLabels = ['월', '화', '수', '목', '금', '토', '일'];
    final typeMap = {for (final t in widget.shiftTypes) t.id: t};

    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final startWeekday = firstDay.weekday;

    final days = <DateTime?>[];
    for (int i = 1; i < startWeekday; i++) {
      days.add(null);
    }
    for (int d = 1; d <= lastDay.day; d++) {
      days.add(DateTime(_currentMonth.year, _currentMonth.month, d));
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () {
                final prev = DateTime(
                    _currentMonth.year, _currentMonth.month - 1);
                final periodMonth = DateTime(
                    widget.periodStart.year, widget.periodStart.month);
                if (!prev.isBefore(periodMonth)) {
                  setState(() => _currentMonth = prev);
                }
              },
            ),
            Text(
              DateFormat('yyyy년 MM월').format(_currentMonth),
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () {
                final next = DateTime(
                    _currentMonth.year, _currentMonth.month + 1);
                final periodEndMonth = DateTime(
                    widget.periodEnd.year, widget.periodEnd.month);
                if (!next.isAfter(DateTime(
                    periodEndMonth.year, periodEndMonth.month + 1))) {
                  setState(() => _currentMonth = next);
                }
              },
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: dayLabels.map((label) {
            final isWeekend = label == '토' || label == '일';
            return Expanded(
              child: Center(
                child: Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isWeekend
                        ? colorScheme.error.withValues(alpha: 0.6)
                        : colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: GridView.builder(
            controller: widget.scrollController,
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
            ),
            itemCount: days.length,
            itemBuilder: (context, index) {
              final day = days[index];
              if (day == null) return const SizedBox();

              final isInPeriod = !day.isBefore(widget.periodStart) &&
                  !day.isAfter(widget.periodEnd);
              final sel = widget.selectedDates[day];
              final isSelected = sel != null;
              final isExisting = widget.existingDates.contains(day);
              final shiftType =
                  sel != null ? typeMap[sel.shiftTypeId] : null;

              return GestureDetector(
                onTap: isInPeriod && !isExisting
                    ? () => widget.onToggle(day)
                    : null,
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colorScheme.primary
                        : isExisting
                            ? colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.15)
                            : null,
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                    border: isInPeriod && !isSelected && !isExisting
                        ? Border.all(color: colorScheme.outlineVariant)
                        : null,
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Text(
                          '${day.day}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isSelected
                                ? Colors.white
                                : isExisting
                                    ? AppColors.onSurfaceVariant
                                    : isInPeriod
                                        ? null
                                        : AppColors.onSurfaceVariant
                                            .withValues(alpha: 0.3),
                            fontWeight:
                                isSelected ? FontWeight.w700 : null,
                          ),
                        ),
                      ),
                      if (isSelected && shiftType != null)
                        Positioned(
                          top: 2,
                          right: 2,
                          child: Text(
                            shiftType.code,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      if (isSelected)
                        Positioned(
                          bottom: 2,
                          left: 2,
                          child: Text(
                            '${sel.priority}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PrefSel {
  const _PrefSel({required this.shiftTypeId, required this.priority});
  final String shiftTypeId;
  final int priority;

  @override
  bool operator ==(Object other) =>
      other is _PrefSel &&
      other.shiftTypeId == shiftTypeId &&
      other.priority == priority;

  @override
  int get hashCode => Object.hash(shiftTypeId, priority);
}
