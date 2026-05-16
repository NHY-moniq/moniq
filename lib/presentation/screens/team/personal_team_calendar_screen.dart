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

  static const int _maxInsightDays = 5;

  int _targetShiftCount(List<PersonalMemberShift> shifts) {
    return shifts.where((s) {
      if (isPersonalOffShift(s)) return true;
      return _includeDay && isPersonalDayShift(s);
    }).length;
  }

  List<_OverlapDaySummary> _overlapDays(
    Map<DateTime, List<PersonalMemberShift>> monthlyData,
  ) {
    final summaries = <_OverlapDaySummary>[];
    for (final entry in monthlyData.entries) {
      final count = _targetShiftCount(entry.value);
      if (count > 0) {
        summaries.add(_OverlapDaySummary(date: entry.key, count: count));
      }
    }

    summaries.sort((a, b) {
      final byCount = b.count.compareTo(a.count);
      if (byCount != 0) return byCount;
      return a.date.compareTo(b.date);
    });

    return summaries.take(_maxInsightDays).toList();
  }

  Future<void> _moveMonth(
    PersonalTeamCalendarViewModel vm,
    DateTime focusedMonth,
    int offset,
  ) async {
    final target = DateTime(focusedMonth.year, focusedMonth.month + offset, 1);
    await vm.changeMonth(target);
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
    final overlapDays = _overlapDays(state.monthlyData);
    final dateFormat = DateFormat('MM.dd (E)', 'ko_KR');
    final monthFormat = DateFormat('yyyy년 M월');
    final metricLabel = _includeDay ? '오프 + 데이' : '오프';
    final memberCount = state.members.length;
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return SingleChildScrollView(
      child: Column(
        children: [
          Padding(
            padding: AppSpacing.screenHorizontal,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: AppRadius.borderRadiusLg,
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
                      Expanded(
                        child: Text(
                          '겹침 많은 날',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      FilterChip(
                        selected: _includeDay,
                        label: const Text('데이 포함'),
                        onSelected: (selected) {
                          setState(() => _includeDay = selected);
                        },
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => _moveMonth(vm, state.focusedMonth, -1),
                        icon: const Icon(Icons.chevron_left_rounded),
                        tooltip: '이전 달',
                        visualDensity: VisualDensity.compact,
                      ),
                      Text(
                        monthFormat.format(state.focusedMonth),
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      IconButton(
                        onPressed: () => _moveMonth(vm, state.focusedMonth, 1),
                        icon: const Icon(Icons.chevron_right_rounded),
                        tooltip: '다음 달',
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '$metricLabel 기준 ${overlapDays.length}일'
                    '${memberCount > 0 ? ' · 전체 $memberCount명' : ''}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (overlapDays.isEmpty)
                    Text(
                      '선택한 기준에 해당하는 근무가 없습니다.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    )
                  else
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final d in overlapDays)
                            Padding(
                              padding: const EdgeInsets.only(
                                right: AppSpacing.sm,
                              ),
                              child: ActionChip(
                                label: Text(
                                  '${dateFormat.format(d.date)} · ${d.count}명',
                                ),
                                onPressed: () => vm.selectDate(d.date),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                        ],
                      ),
                    ),
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
