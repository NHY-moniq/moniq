import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moniq/data/models/personal_team_member_shift.dart';
import 'package:moniq/data/providers/settings_providers.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/personal_team_calendar_viewmodel.dart';
import 'package:moniq/presentation/widgets/calendar/moniq_calendar.dart';
import 'package:moniq/presentation/widgets/calendar/view_mode_toggle.dart';
import 'package:moniq/presentation/widgets/common/moniq_app_bar.dart';
import 'package:moniq/presentation/widgets/common/moniq_bottom_sheet.dart';
import 'package:moniq/presentation/widgets/common/moniq_error_view.dart';
import 'package:moniq/presentation/widgets/common/moniq_loading_view.dart';
import 'package:table_calendar/table_calendar.dart';

import 'personal_team_calendar_widgets.dart';

class PersonalTeamCalendarScreen extends ConsumerWidget {
  const PersonalTeamCalendarScreen({super.key, required this.teamId});

  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(personalTeamCalendarViewModelProvider(teamId));

    return Scaffold(
      appBar: MoniqAppBar(
        title: '멤버 근무 현황',
        onLeadingTap: () {
          if (Navigator.of(context).canPop()) {
            context.pop();
          } else {
            context.go('/teams');
          }
        },
      ),
      body: stateAsync.when(
        loading: () => const MoniqLoadingView(),
        error: (e, _) => MoniqErrorView(
          message: '근무 정보를 불러올 수 없습니다',
          onRetry: () =>
              ref.invalidate(personalTeamCalendarViewModelProvider(teamId)),
        ),
        data: (state) => _CalendarBody(state: state, teamId: teamId),
      ),
    );
  }
}

class _CalendarBody extends ConsumerStatefulWidget {
  const _CalendarBody({required this.state, required this.teamId});

  final PersonalTeamCalendarState state;
  final String teamId;

  @override
  ConsumerState<_CalendarBody> createState() => _CalendarBodyState();
}

class _CalendarBodyState extends ConsumerState<_CalendarBody> {
  bool _includeDay = false;
  bool _isOverlapCardExpanded = true;

  static const int _maxInsightDays = 10;
  static const int _offInsightMinCount = 1;

  int _targetShiftCount({
    required List<PersonalTeamMember> members,
    required List<PersonalMemberShift> dayShifts,
  }) {
    final shiftByUser = <String, PersonalMemberShift>{
      for (final shift in dayShifts) shift.userId: shift,
    };

    var count = 0;
    for (final member in members) {
      final shift = shiftByUser[member.userId];
      if (shift == null || (shift.shiftCode ?? '').trim().isEmpty) {
        count += 1;
        continue;
      }
      if (isPersonalOffShift(shift)) {
        count += 1;
        continue;
      }
      if (_includeDay && isPersonalDayShift(shift)) {
        count += 1;
      }
    }
    return count;
  }

  List<DateTime> _monthDays(DateTime focusedMonth) {
    final firstDay = DateTime(focusedMonth.year, focusedMonth.month, 1);
    final lastDay = DateTime(focusedMonth.year, focusedMonth.month + 1, 0);
    final days = <DateTime>[];

    for (var day = 1; day <= lastDay.day; day++) {
      days.add(DateTime(firstDay.year, firstDay.month, day));
    }

    return days;
  }

  List<_OverlapDaySummary> _overlapDays(PersonalTeamCalendarState state) {
    final summaries = <_OverlapDaySummary>[];
    for (final date in _monthDays(state.focusedMonth)) {
      final dayShifts =
          state.monthlyData[date] ?? const <PersonalMemberShift>[];
      final count = _targetShiftCount(
        members: state.members,
        dayShifts: dayShifts,
      );
      if (count > 0) {
        summaries.add(_OverlapDaySummary(date: date, count: count));
      }
    }

    summaries.sort((a, b) {
      final byCount = b.count.compareTo(a.count);
      if (byCount != 0) return byCount;
      return a.date.compareTo(b.date);
    });

    return summaries;
  }

  int _majorityThreshold(int memberCount) {
    if (memberCount <= 0) return _offInsightMinCount;
    return (memberCount ~/ 2) + 1;
  }

  List<MapEntry<int, List<_OverlapDaySummary>>> _groupedOverlapDays(
    List<_OverlapDaySummary> overlapDays,
  ) {
    final grouped = <int, List<_OverlapDaySummary>>{};
    for (final day in overlapDays) {
      grouped.putIfAbsent(day.count, () => []).add(day);
    }

    final entries = grouped.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    for (final entry in entries) {
      entry.value.sort((a, b) => a.date.compareTo(b.date));
    }
    return entries;
  }

  Future<void> _moveMonth(
    PersonalTeamCalendarViewModel vm,
    DateTime focusedMonth,
    int offset,
  ) async {
    final target = DateTime(focusedMonth.year, focusedMonth.month + offset, 1);
    await vm.changeMonth(target);
  }

  Future<void> _showOverlapInfo(BuildContext context) async {
    await showMoniqInfoSheet(
      context: context,
      title: '표시 기준',
      message:
          '겹침 많은 날은 오프 기준으로 계산합니다.\n'
          '원하면 데이 포함을 켜서 오프 + 데이 기준으로 볼 수 있어요.',
    );
  }

  Future<void> _selectOverlapDate(
    PersonalTeamCalendarViewModel vm,
    DateTime date,
  ) async {
    await vm.changeMonth(date);
    vm.selectDate(date);
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final teamId = widget.teamId;
    final vm = ref.read(personalTeamCalendarViewModelProvider(teamId).notifier);
    final calendarStartDay = ref.watch(calendarStartDayProvider);
    final startingDay = calendarStartDay == 'sunday'
        ? StartingDayOfWeek.sunday
        : StartingDayOfWeek.monday;
    final selectedShifts = state.shiftsForDate(state.selectedDate);
    final allOverlapDays = _overlapDays(state);
    final dateFormat = DateFormat('MM.dd(E)', 'ko_KR');
    final monthFormat = DateFormat('yyyy년 M월');
    final memberCount = state.members.length;
    final majorityThreshold = _majorityThreshold(memberCount);
    final majorityOverlapDays = allOverlapDays
        .where((d) => d.count >= majorityThreshold)
        .toList();
    final showMajorityDays = majorityOverlapDays.isNotEmpty;
    final overlapDays = showMajorityDays
        ? majorityOverlapDays
        : allOverlapDays.take(_maxInsightDays).toList();
    final groupedOverlapDays = _groupedOverlapDays(overlapDays);
    final overlapSectionEntries = groupedOverlapDays.asMap().entries.toList();
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return SingleChildScrollView(
      child: Column(
        children: [
          Padding(
            padding: AppSpacing.screenHorizontal,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLowest,
                borderRadius: AppRadius.borderRadiusLg,
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.38),
                ),
                boxShadow: [
                  BoxShadow(
                    color: cs.shadow.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '겹침 많은 날',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      IconButton(
                        onPressed: () => _showOverlapInfo(context),
                        icon: const Icon(Icons.info_outline_rounded, size: 18),
                        visualDensity: VisualDensity.compact,
                        tooltip: '표시 기준',
                      ),
                      const Spacer(),
                      FilterChip(
                        selected: _includeDay,
                        label: const Text('데이 포함'),
                        onSelected: (selected) {
                          setState(() => _includeDay = selected);
                        },
                        visualDensity: VisualDensity.compact,
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _isOverlapCardExpanded = !_isOverlapCardExpanded;
                          });
                        },
                        icon: Icon(
                          _isOverlapCardExpanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                        ),
                        tooltip: _isOverlapCardExpanded ? '접기' : '펼치기',
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  if (_isOverlapCardExpanded) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () =>
                              _moveMonth(vm, state.focusedMonth, -1),
                          icon: const Icon(Icons.chevron_left_rounded),
                          tooltip: '이전 달',
                          visualDensity: VisualDensity.compact,
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              monthFormat.format(state.focusedMonth),
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () =>
                              _moveMonth(vm, state.focusedMonth, 1),
                          icon: const Icon(Icons.chevron_right_rounded),
                          tooltip: '다음 달',
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (overlapDays.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.lg,
                        ),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withValues(
                            alpha: 0.5,
                          ),
                          borderRadius: AppRadius.borderRadiusMd,
                        ),
                        child: Text(
                          '선택한 기준에 해당하는 근무가 없습니다.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final entry in overlapSectionEntries) ...[
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.sm,
                              ),
                              child: _OverlapDaySection(
                                count: entry.value.key,
                                days: entry.value.value,
                                dateFormat: dateFormat,
                                onSelectDate: (date) {
                                  _selectOverlapDate(vm, date);
                                },
                              ),
                            ),
                            if (entry.key < overlapSectionEntries.length - 1)
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.sm,
                                ),
                                child: Divider(
                                  color: cs.outlineVariant.withValues(
                                    alpha: 0.45,
                                  ),
                                  height: 1,
                                ),
                              ),
                          ],
                        ],
                      ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          MoniqCalendar(
            focusedDay: state.focusedMonth,
            selectedDay: state.selectedDate,
            rowHeight: 80,
            viewMode: state.viewMode,
            onViewModeChanged: vm.setViewMode,
            calendarFormat: state.viewMode == CalendarViewMode.month
                ? CalendarFormat.month
                : CalendarFormat.week,
            startingDayOfWeek: startingDay,
            legendItems: const [
              (color: personalShiftDayColor, label: 'D'),
              (color: personalShiftEveningColor, label: 'E'),
              (color: personalShiftNightColor, label: 'N'),
            ],
            // eventLoader가 있어야 markerBuilder가 호출됨
            eventLoader: (day) {
              final key = DateTime(day.year, day.month, day.day);
              return state.monthlyData[key] ?? [];
            },
            onDaySelected: (selected, focused) => vm.selectDate(selected),
            onPageChanged: (focused) => vm.changeMonth(focused),
            markerBuilder: (context, date, events) {
              final dayShifts = events.cast<PersonalMemberShift>();
              if (dayShifts.isEmpty) return null;

              final typeCount = <String, int>{};
              for (final shift in dayShifts) {
                final code = personalShiftDenCode(shift);
                if (code == null) continue;
                typeCount[code] = (typeCount[code] ?? 0) + 1;
              }
              if (typeCount.isEmpty) return null;

              final sortedCodes = typeCount.keys.toList()
                ..sort(
                  (a, b) => personalShiftDenSortKey(
                    a,
                  ).compareTo(personalShiftDenSortKey(b)),
                );

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: sortedCodes.take(3).map((code) {
                  final color = personalShiftColorByCode(code);

                  return Container(
                    width: 12,
                    height: 12,
                    margin: const EdgeInsets.symmetric(horizontal: 0.5),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${typeCount[code]}',
                        style: TextStyle(
                          fontSize: 6,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.surface,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          Padding(
            padding: AppSpacing.screenHorizontal,
            child: PersonalDayDetailPanel(
              date: state.selectedDate,
              shifts: selectedShifts,
              members: state.members,
            ),
          ),
          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }
}

class _OverlapDaySummary {
  const _OverlapDaySummary({required this.date, required this.count});

  final DateTime date;
  final int count;
}

class _OverlapDaySection extends StatefulWidget {
  const _OverlapDaySection({
    required this.count,
    required this.days,
    required this.dateFormat,
    required this.onSelectDate,
  });

  final int count;
  final List<_OverlapDaySummary> days;
  final DateFormat dateFormat;
  final ValueChanged<DateTime> onSelectDate;

  @override
  State<_OverlapDaySection> createState() => _OverlapDaySectionState();
}

class _OverlapDaySectionState extends State<_OverlapDaySection> {
  static const int _maxColumns = 3;
  static const int _previewLines = 2;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context).textTheme;
    final shouldCollapse = widget.days.length > (_maxColumns * _previewLines);
    final visibleCount = !_expanded && shouldCollapse
        ? _maxColumns * _previewLines
        : widget.days.length;
    final visibleDays = widget.days.take(visibleCount).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: AppRadius.borderRadiusFull,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '${widget.count}명 겹침',
              style: theme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              '${widget.days.length}일',
              style: theme.labelMedium?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (shouldCollapse)
              TextButton(
                onPressed: () {
                  setState(() => _expanded = !_expanded);
                },
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 0),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(_expanded ? '접기' : '펼치기'),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth =
                (constraints.maxWidth - (AppSpacing.sm * 2)) / _maxColumns;

            return Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final day in visibleDays)
                  SizedBox(
                    width: itemWidth,
                    child: _OverlapDayChip(
                      label: widget.dateFormat.format(day.date),
                      onTap: () => widget.onSelectDate(day.date),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _OverlapDayChip extends StatelessWidget {
  const _OverlapDayChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.borderRadiusFull,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: AppRadius.borderRadiusFull,
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.8)),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
