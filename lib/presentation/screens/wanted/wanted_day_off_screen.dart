import 'package:flutter/material.dart';
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
    final stateAsync = ref.watch(wantedMemberViewModelProvider(teamId));

    return Scaffold(
      appBar: AppBar(title: const Text('희망 휴무일 입력')),
      body: stateAsync.when(
        loading: () => const MoniqLoadingView(),
        error: (e, _) => MoniqErrorView(
          message: '정보를 불러올 수 없습니다',
          onRetry: () =>
              ref.invalidate(wantedMemberViewModelProvider(teamId)),
        ),
        data: (state) {
          if (state.activeRequest == null) {
            return const MoniqEmptyState(
              icon: Icons.event_busy,
              message: '현재 진행 중인 희망 휴무 수집이 없습니다',
              description: '관리자가 수집을 시작하면 여기서 입력할 수 있습니다',
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
                          decoration: BoxDecoration(
                            color: colorScheme.primary
                                .withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.event,
                            color: colorScheme.primary,
                            size: 20,
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
                          onPressed: () => ref
                              .read(wantedMemberViewModelProvider(teamId)
                                  .notifier)
                              .removeEntry(entry.id),
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
    final selectedDates = <DateTime>{};
    String reason = '';

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
                    '날짜를 탭하여 여러 날을 선택할 수 있습니다',
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                          color: Theme.of(ctx)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // 캘린더 그리드
                  Expanded(
                    child: _MultiDateCalendar(
                      periodStart: request.periodStart,
                      periodEnd: request.periodEnd,
                      selectedDates: selectedDates,
                      existingDates: existingDates,
                      onToggle: (date) {
                        setSheetState(() {
                          if (selectedDates.contains(date)) {
                            selectedDates.remove(date);
                          } else {
                            selectedDates.add(date);
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

                  const SizedBox(height: AppSpacing.lg),

                  ElevatedButton(
                    onPressed: selectedDates.isEmpty
                        ? null
                        : () async {
                            final success = await ref
                                .read(wantedMemberViewModelProvider(teamId)
                                    .notifier)
                                .addWantedDates(
                                  dates: selectedDates.toList()
                                    ..sort(),
                                  reason:
                                      reason.isNotEmpty ? reason : null,
                                );
                            if (success && ctx.mounted) {
                              Navigator.pop(ctx);
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
  final Set<DateTime> selectedDates;
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

              final isInPeriod =
                  !day.isBefore(widget.periodStart) &&
                      !day.isAfter(widget.periodEnd);
              final isSelected =
                  widget.selectedDates.contains(day);
              final isExisting =
                  widget.existingDates.contains(day);

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
                  child: Center(
                    child: Text(
                      '${day.day}',
                      style:
                          theme.textTheme.bodyMedium?.copyWith(
                        color: isSelected
                            ? colorScheme.surface
                            : isExisting
                                ? colorScheme.onSurfaceVariant
                                : isInPeriod
                                    ? null
                                    : colorScheme
                                        .onSurfaceVariant
                                        .withValues(alpha: 0.3),
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : null,
                      ),
                    ),
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
