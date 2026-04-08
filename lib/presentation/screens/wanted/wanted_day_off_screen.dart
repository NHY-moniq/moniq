import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/wanted_viewmodel.dart';
import 'package:moniq/presentation/widgets/common/moniq_empty_state.dart';
import 'package:moniq/presentation/widgets/common/moniq_error_view.dart';
import 'package:moniq/presentation/widgets/common/moniq_loading_view.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('희망 휴무일 입력'),
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
                    message: '현재 진행 중인 희망 휴무 수집이 없습니다',
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
                    ? '희망 휴무일 입력 기간이 아닙니다!'
                    : '희망 휴무일을 입력해주세요',
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

        // 내 엔트리 목록
        Expanded(
          child: state.myEntries.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 48,
                        color: colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        '아래 버튼으로 희망 휴무일을 추가하세요',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: AppSpacing.screenAll,
                  itemCount: state.myEntries.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final entry = state.myEntries[index];
                    return Card(
                      child: ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${entry.priority}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        title: Text(
                          dateFormat.format(entry.wantedDate),
                        ),
                        subtitle: entry.reason != null &&
                                entry.reason!.isNotEmpty
                            ? Text(entry.reason!)
                            : null,
                        trailing: isExpired
                            ? null
                            : IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () async {
                            final ok = await ref
                                .read(wantedMemberViewModelProvider(teamId)
                                    .notifier)
                                .removeEntry(entry.id);
                            if (!context.mounted || ok) return;
                            final err = ref
                                .read(wantedMemberViewModelProvider(teamId))
                                .valueOrNull
                                ?.error;
                            if (err != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(err)),
                              );
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
        ),

        // 추가 버튼
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (state.isSubmitting || isExpired)
                    ? null
                    : () => _showMultiDatePicker(context, ref),
                icon: state.isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add),
                label: const Text('희망 휴무일 추가'),
              ),
            ),
          ),
        ),
      ],
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
                    '희망 휴무일 선택',
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
