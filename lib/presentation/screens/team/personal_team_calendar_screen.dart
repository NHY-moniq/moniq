import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moniq/data/datasources/push_service.dart';
import 'package:moniq/data/models/personal_team_member_shift.dart';
import 'package:moniq/data/providers/appointment_providers.dart';
import 'package:moniq/data/providers/settings_providers.dart';
import 'package:moniq/data/providers/supabase_providers.dart';
import 'package:moniq/presentation/screens/team/appointment_management_screen.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/screens/calendar/calendar_providers.dart';
import 'package:moniq/presentation/screens/calendar/calendar_dialogs.dart'
    as calendar_dialogs;
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
        trailing: _AppointmentBarAction(teamId: teamId),
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

/// AppBar 약속 진입 버튼.
class _AppointmentBarAction extends StatelessWidget {
  const _AppointmentBarAction({required this.teamId});

  final String teamId;

  @override
  Widget build(BuildContext context) {
    return MoniqAppBarAction(
      icon: Icons.event_note_rounded,
      // 루트 네비게이터로 띄워 하단 dock 위에 풀스크린으로 표시.
      onTap: () => Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(
          builder: (_) => AppointmentManagementScreen(teamId: teamId),
        ),
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
  bool _isOverlapCardExpanded = false;
  // 과반수 이상만 표시(false) ↔ 전체 겹침 표시(true) 토글
  bool _showAllOverlaps = false;

  static const int _offInsightMinCount = 1;

  DateTime _dateKey(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  List<PersonalMemberShift> _filterShiftsByMembers(
    List<PersonalMemberShift> shifts,
    Set<String> memberIds,
  ) {
    if (memberIds.isEmpty) return const [];
    return shifts.where((shift) => memberIds.contains(shift.userId)).toList();
  }

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
    final selectedMembers = state.selectedMembers;
    if (selectedMembers.isEmpty) return const [];

    final summaries = <_OverlapDaySummary>[];
    for (final date in _monthDays(state.focusedMonth)) {
      final dayShifts =
          state.monthlyData[date] ?? const <PersonalMemberShift>[];
      final count = _targetShiftCount(
        members: selectedMembers,
        dayShifts: dayShifts,
      );
      // 겹침은 2명 이상부터 의미가 있으므로 1명은 제외한다.
      if (count >= 2) {
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

  Future<void> _showOverlapInfo(BuildContext context) async {
    await showMoniqBottomSheet<void>(
      context: context,
      title: '표시 기준',
      child: Builder(
        builder: (sheetContext) {
          final cs = Theme.of(sheetContext).colorScheme;
          final textTheme = Theme.of(sheetContext).textTheme;

          Widget infoItem({
            required IconData icon,
            required String title,
            required List<InlineSpan> body,
          }) {
            return Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.36),
                borderRadius: AppRadius.borderRadiusLg,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer.withValues(alpha: 0.5),
                      borderRadius: AppRadius.borderRadiusFull,
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, size: 18, color: cs.primary),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: textTheme.titleSmall?.copyWith(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        RichText(
                          text: TextSpan(
                            style: textTheme.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                              height: 1.45,
                            ),
                            children: body,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          TextSpan normal(String text) => TextSpan(text: text);
          TextSpan bold(String text) => TextSpan(
            text: text,
            style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w900),
          );

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              infoItem(
                icon: Icons.event_busy_outlined,
                title: '기본 기준',
                body: [bold('오프'), normal('가 겹치는 날을 계산합니다.')],
              ),
              const SizedBox(height: AppSpacing.sm),
              infoItem(
                icon: Icons.add_rounded,
                title: '데이 포함',
                body: [
                  normal('옵션을 켜면 '),
                  bold('오프 + 데이'),
                  normal('가 겹치는 날까지 함께 봅니다.'),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              infoItem(
                icon: Icons.groups_2_outlined,
                title: '표시 방식',
                body: [
                  normal('선택한 인원의 '),
                  bold('과반수'),
                  normal('가 겹치는 날이 있으면 그 날들을 먼저 보여줍니다.\n'),
                  normal('과반수 겹침이 없으면 '),
                  bold('겹침이 있는 날 전체'),
                  normal('를 보여줍니다.'),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.borderRadiusFull,
                  ),
                ),
                onPressed: () => Navigator.pop(sheetContext),
                child: const Text('확인'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showMemberSelectionSheet(
    BuildContext context,
    PersonalTeamCalendarState state,
    PersonalTeamCalendarViewModel vm,
  ) async {
    var draftIds = Set<String>.of(state.selectedMemberIds);

    await showMoniqBottomSheet<void>(
      context: context,
      eyebrow: 'MEMBERS',
      title: '일정 확인 멤버',
      child: StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final cs = Theme.of(sheetContext).colorScheme;
          final theme = Theme.of(sheetContext);
          final selectedCount = draftIds.length;
          final allSelected =
              state.members.isNotEmpty && selectedCount == state.members.length;

          void updateDraft(Set<String> nextIds) {
            setSheetState(() => draftIds = nextIds);
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.48),
                  borderRadius: AppRadius.borderRadiusMd,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.people_alt_outlined,
                      size: 18,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        selectedCount == state.members.length
                            ? '전체 ${state.members.length}명 기준으로 확인 중'
                            : '$selectedCount명 기준으로 확인 중',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        updateDraft(
                          allSelected
                              ? <String>{}
                              : state.members
                                    .map((member) => member.userId)
                                    .toSet(),
                        );
                      },
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 0),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(allSelected ? '전체 해제' : '전체 선택'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(sheetContext).size.height * 0.46,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: state.members.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final member = state.members[index];
                    final selected = draftIds.contains(member.userId);
                    return _MemberSelectionTile(
                      member: member,
                      selected: selected,
                      onTap: () {
                        final nextIds = Set<String>.of(draftIds);
                        if (selected) {
                          nextIds.remove(member.userId);
                        } else {
                          nextIds.add(member.userId);
                        }
                        updateDraft(nextIds);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: draftIds.isEmpty
                    ? null
                    : () {
                        vm.setSelectedMemberIds(draftIds);
                        Navigator.pop(sheetContext);
                      },
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.borderRadiusFull,
                  ),
                ),
                child: const Text('적용'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showAppointmentSheet(
    BuildContext context,
    PersonalTeamCalendarState state,
    PersonalTeamCalendarViewModel vm,
  ) async {
    await showMoniqBottomSheet<void>(
      context: context,
      eyebrow: 'APPOINTMENT',
      title: '약속 잡기',
      child: _AppointmentSheetContent(
        state: state,
        vm: vm,
        onSaved: () {
          if (!context.mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('약속을 개인 캘린더에 추가했습니다.')));
        },
      ),
    );
  }

  String _fullDateLabel(DateTime date) {
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    return '${date.year}년 ${date.month}월 ${date.day}일 (${weekdays[date.weekday - 1]})';
  }

  Future<void> _selectOverlapDate(
    PersonalTeamCalendarViewModel vm,
    DateTime date,
  ) async {
    vm.selectDate(date);
    if (date.year != widget.state.focusedMonth.year ||
        date.month != widget.state.focusedMonth.month) {
      await vm.changeMonth(DateTime(date.year, date.month));
    }
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
    final selectedMembers = state.selectedMembers;
    // 1명만 선택하면 개인 캘린더처럼 날짜별 근무 코드(D/E/N/오프)를 표시한다.
    final isSingleMember = selectedMembers.length == 1;
    final singleMemberId = isSingleMember ? selectedMembers.first.userId : null;
    final selectedShifts = _filterShiftsByMembers(
      state.shiftsForDate(state.selectedDate),
      state.selectedMemberIds,
    );
    final allOverlapDays = _overlapDays(state);
    final dateFormat = DateFormat('MM.dd(E)', 'ko_KR');
    final monthFormat = DateFormat('yyyy년 M월');
    final memberCount = selectedMembers.length;
    final majorityThreshold = _majorityThreshold(memberCount);
    final majorityOverlapDays = allOverlapDays
        .where((d) => d.count >= majorityThreshold)
        .toList();
    // 과반수 이상 겹치는 날이 있으면 기본은 그것만, 토글 시 전체 표시.
    final hasMajorityDays = majorityOverlapDays.isNotEmpty;
    final showMajorityDays = hasMajorityDays && !_showAllOverlaps;
    final overlapDays = showMajorityDays ? majorityOverlapDays : allOverlapDays;
    final highlightedOverlapCountByDate = {
      for (final summary in overlapDays) summary.date: summary.count,
    };
    final selectedDateOverlapCount =
        highlightedOverlapCountByDate[_dateKey(state.selectedDate)] ?? 0;
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
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
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
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _OverlapControlChip(
                        icon: Icons.people_alt_outlined,
                        label: '${selectedMembers.length}명',
                        onTap: () =>
                            _showMemberSelectionSheet(context, state, vm),
                      ),
                      _OverlapControlChip(
                        label: '데이 포함',
                        selected: _includeDay,
                        onTap: () =>
                            setState(() => _includeDay = !_includeDay),
                      ),
                      // 과반수 이상 겹치는 날이 있을 때만 노출 — 전체/과반수만 2분할 토글
                      if (hasMajorityDays)
                        _OverlapScopeToggle(
                          showAll: _showAllOverlaps,
                          onChanged: (v) =>
                              setState(() => _showAllOverlaps = v),
                        ),
                    ],
                  ),
                  if (!_isOverlapCardExpanded) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _OverlapCollapsedSummary(
                      monthLabel: monthFormat.format(state.focusedMonth),
                      days: overlapDays,
                    ),
                  ],
                  if (_isOverlapCardExpanded) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Center(
                      child: Text(
                        monthFormat.format(state.focusedMonth),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
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
              final key = _dateKey(day);
              final dayShifts = _filterShiftsByMembers(
                state.monthlyData[key] ?? const <PersonalMemberShift>[],
                state.selectedMemberIds,
              );
              // 1명 모드: 오프 날도 'O'를 렌더링하도록 빈 날엔 오프 센티넬 주입.
              if (isSingleMember && dayShifts.isEmpty) {
                return [
                  PersonalMemberShift(userId: singleMemberId!, date: day),
                ];
              }
              return dayShifts;
            },
            cornerBadgeBuilder: (context, date) {
              final key = _dateKey(date);
              if ((highlightedOverlapCountByDate[key] ?? 0) <= 0) {
                return null;
              }
              return const _OverlapCornerDot();
            },
            onDaySelected: (selected, focused) => vm.selectDate(selected),
            onPageChanged: (focused) => vm.changeMonth(focused),
            markerBuilder: (context, date, events) {
              final dayShifts = events
                  .whereType<PersonalMemberShift>()
                  .toList();
              if (dayShifts.isEmpty) return null;

              // 1명 모드: 개인 캘린더처럼 단일 근무 코드 셀(D/E/N/오프) 표시.
              if (isSingleMember) {
                return _SingleMemberDayCell(shift: dayShifts.first);
              }

              final typeCount = <String, int>{};
              for (final shift in dayShifts) {
                final code = personalShiftDenCode(shift);
                if (code == null) continue;
                typeCount[code] = (typeCount[code] ?? 0) + 1;
              }

              final sortedCodes = typeCount.keys.toList()
                ..sort(
                  (a, b) => personalShiftDenSortKey(
                    a,
                  ).compareTo(personalShiftDenSortKey(b)),
                );

              return _PersonalCalendarMarker(
                sortedCodes: sortedCodes,
                typeCount: typeCount,
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          Padding(
            padding: AppSpacing.screenHorizontal,
            child: _AppointmentEntryCard(
              dateLabel: _fullDateLabel(state.selectedDate),
              participantCount: selectedMembers.length,
              overlapCount: selectedDateOverlapCount,
              onTap: () => _showAppointmentSheet(context, state, vm),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: AppSpacing.screenHorizontal,
            child: PersonalDayDetailPanel(
              date: state.selectedDate,
              shifts: selectedShifts,
              members: selectedMembers,
            ),
          ),
          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }
}

class _AppointmentSheetContent extends ConsumerStatefulWidget {
  const _AppointmentSheetContent({
    required this.state,
    required this.vm,
    required this.onSaved,
  });

  final PersonalTeamCalendarState state;
  final PersonalTeamCalendarViewModel vm;
  final VoidCallback onSaved;

  @override
  ConsumerState<_AppointmentSheetContent> createState() =>
      _AppointmentSheetContentState();
}

class _AppointmentSheetContentState
    extends ConsumerState<_AppointmentSheetContent> {
  late final TextEditingController _titleController;
  late Set<String> _participantIds;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _participantIds = widget.state.selectedMemberIds.isNotEmpty
        ? Set<String>.of(widget.state.selectedMemberIds)
        : widget.state.members.map((member) => member.userId).toSet();
    _titleController.addListener(_handleTitleChanged);
  }

  @override
  void dispose() {
    _titleController
      ..removeListener(_handleTitleChanged)
      ..dispose();
    super.dispose();
  }

  void _handleTitleChanged() {
    if (mounted) setState(() {});
  }

  bool get _isAllDay => _startTime == null && _endTime == null;

  bool get _canSave =>
      _titleController.text.trim().isNotEmpty &&
      _participantIds.isNotEmpty &&
      !_isSaving;

  void _setAllDay(bool value) {
    setState(() {
      if (value) {
        _startTime = null;
        _endTime = null;
      } else {
        _startTime ??= const TimeOfDay(hour: 9, minute: 0);
        _endTime ??= const TimeOfDay(hour: 10, minute: 0);
      }
    });
  }

  void _pickTime({required bool isStart}) {
    calendar_dialogs.showCupertinoTimePicker(
      context: context,
      initialHour: isStart
          ? _startTime?.hour ?? 9
          : _endTime?.hour ?? (_startTime?.hour ?? 9) + 1,
      initialMinute: isStart
          ? _startTime?.minute ?? 0
          : _endTime?.minute ?? _startTime?.minute ?? 0,
      onChanged: (hour, minute) {
        if (!mounted) return;
        final picked = TimeOfDay(hour: hour, minute: minute);
        setState(() {
          if (isStart) {
            _startTime = picked;
            _endTime ??= picked.replacing(hour: (picked.hour + 1) % 24);
          } else {
            _endTime = picked;
          }
        });
      },
    );
  }

  Future<void> _saveAppointment() async {
    if (!_canSave) return;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await widget.vm.createAppointment(
        date: widget.state.selectedDate,
        title: _titleController.text,
        participantIds: _participantIds,
        startTime: _timeParam(_startTime),
        endTime: _timeParam(_endTime),
      );
      // 생성자 본인 캘린더는 RPC가 즉시 반영 → 본인 것만 새로고침.
      await ref.read(personalEventDataSourceProvider).pullFromRemote();
      ref.read(eventRefreshProvider.notifier).state++;
      // 약속 목록/배지 갱신
      ref.invalidate(teamAppointmentsProvider(widget.state.teamId));
      // 참여자(생성자 제외)에게 알림 — 각자 약속 관리에서 직접 추가
      final myId = ref.read(supabaseClientProvider).auth.currentUser?.id;
      final targets = _participantIds.where((id) => id != myId).toList();
      if (targets.isNotEmpty) {
        await PushService.instance.sendToUsers(
          userIds: targets,
          title: 'OnorOff',
          body:
              "'${_titleController.text.trim()}' 약속에 초대받았어요 · "
              '${_fullDateLabel(widget.state.selectedDate)}',
          data: {'type': 'appointment', 'teamId': widget.state.teamId},
        );
      }
      if (!mounted) return;
      Navigator.pop(context);
      widget.onSaved();
    } catch (e) {
      if (!mounted) return;
      final message = switch (e) {
        PersonalTeamAppointmentSetupException(:final message) => message,
        _ => '약속을 추가할 수 없습니다. 잠시 후 다시 시도해주세요.',
      };
      setState(() {
        _isSaving = false;
        _errorMessage = message;
      });
    }
  }

  String _timeLabel(TimeOfDay? time, {required String fallback}) {
    if (time == null) return fallback;
    return _timeParam(time)!;
  }

  String? _timeParam(TimeOfDay? time) {
    if (time == null) return null;
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _fullDateLabel(DateTime date) {
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    return '${date.year}년 ${date.month}월 ${date.day}일 (${weekdays[date.weekday - 1]})';
  }

  Widget _participantTile(int index) {
    final member = widget.state.members[index];
    final selected = _participantIds.contains(member.userId);
    return _MemberSelectionTile(
      member: member,
      selected: selected,
      onTap: () {
        final nextIds = Set<String>.of(_participantIds);
        if (selected) {
          nextIds.remove(member.userId);
        } else {
          nextIds.add(member.userId);
        }
        setState(() => _participantIds = nextIds);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final selectedCount = _participantIds.length;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.44),
              borderRadius: AppRadius.borderRadiusLg,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.event_available_outlined,
                  size: 20,
                  color: cs.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    _fullDateLabel(widget.state.selectedDate),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _titleController,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: '약속 이름',
              filled: true,
              fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.36),
              border: OutlineInputBorder(
                borderRadius: AppRadius.borderRadiusLg,
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              SizedBox(
                width: 64,
                height: 50,
                child: _AllDayCheckboxButton(
                  selected: _isAllDay,
                  onChanged: _setAllDay,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: _AppointmentTimeButton(
                    label: '시작',
                    value: _timeLabel(_startTime, fallback: '--:--'),
                    onTap: () => _pickTime(isStart: true),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: _AppointmentTimeButton(
                    label: '종료',
                    value: _timeLabel(_endTime, fallback: '--:--'),
                    onTap: () => _pickTime(isStart: false),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Text(
                '참여자',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '$selectedCount명',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  setState(() {
                    _participantIds =
                        _participantIds.length == widget.state.members.length
                        ? <String>{}
                        : widget.state.members
                              .map((member) => member.userId)
                              .toSet();
                  });
                },
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 0),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  _participantIds.length == widget.state.members.length
                      ? '전체 해제'
                      : '전체 선택',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // 참여자 카드 — 한 줄에 2명씩 배치해 시트가 길어지지 않게.
          for (var index = 0; index < widget.state.members.length; index += 2)
            Padding(
              padding: EdgeInsets.only(
                bottom: index + 2 >= widget.state.members.length
                    ? 0
                    : AppSpacing.sm,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _participantTile(index)),
                  const SizedBox(width: AppSpacing.sm),
                  index + 1 < widget.state.members.length
                      ? Expanded(child: _participantTile(index + 1))
                      : const Spacer(),
                ],
              ),
            ),
          if (_errorMessage != null) ...[
            const SizedBox(height: AppSpacing.md),
            _AppointmentErrorBanner(message: _errorMessage!),
          ],
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: _canSave ? _saveAppointment : null,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.borderRadiusFull,
              ),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('약속 추가'),
          ),
        ],
      ),
    );
  }
}

class _AppointmentEntryCard extends StatelessWidget {
  const _AppointmentEntryCard({
    required this.dateLabel,
    required this.participantCount,
    required this.overlapCount,
    required this.onTap,
  });

  final String dateLabel;
  final int participantCount;
  final int overlapCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.borderRadiusLg,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: cs.primaryContainer.withValues(alpha: 0.22),
            borderRadius: AppRadius.borderRadiusLg,
            border: Border.all(color: cs.primary.withValues(alpha: 0.24)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: AppRadius.borderRadiusMd,
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.event_available_outlined,
                  color: cs.onPrimary,
                  size: 21,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '이 날 약속 잡기',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          dateLabel,
                          style: textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        _AppointmentMetaPill(label: '$participantCount명 기준'),
                        if (overlapCount > 0)
                          _SelectedOverlapPill(count: overlapCount),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppointmentMetaPill extends StatelessWidget {
  const _AppointmentMetaPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: AppRadius.borderRadiusFull,
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.55)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: cs.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _SelectedOverlapPill extends StatelessWidget {
  const _SelectedOverlapPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.52),
        borderRadius: AppRadius.borderRadiusFull,
        border: Border.all(color: cs.error.withValues(alpha: 0.22)),
      ),
      child: Text(
        '겹침 $count명',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: cs.onErrorContainer,
        ),
      ),
    );
  }
}

class _AppointmentErrorBanner extends StatelessWidget {
  const _AppointmentErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.42),
        borderRadius: AppRadius.borderRadiusLg,
        border: Border.all(color: cs.error.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: cs.onErrorContainer,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: textTheme.bodySmall?.copyWith(
                color: cs.onErrorContainer,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AllDayCheckboxButton extends StatelessWidget {
  const _AllDayCheckboxButton({
    required this.selected,
    required this.onChanged,
  });

  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!selected),
        borderRadius: AppRadius.borderRadiusMd,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: selected ? cs.primary : cs.surface,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: selected
                        ? cs.primary
                        : cs.outlineVariant.withValues(alpha: 0.9),
                    width: 1.4,
                  ),
                ),
                alignment: Alignment.center,
                child: selected
                    ? Icon(Icons.check_rounded, size: 15, color: cs.onPrimary)
                    : null,
              ),
              const SizedBox(height: 4),
              Text(
                '종일',
                maxLines: 1,
                style: textTheme.labelSmall?.copyWith(
                  color: selected ? cs.primary : cs.onSurfaceVariant,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppointmentTimeButton extends StatelessWidget {
  const _AppointmentTimeButton({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.borderRadiusMd,
        child: Container(
          constraints: const BoxConstraints(minHeight: 50),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: AppRadius.borderRadiusMd,
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.62),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 13,
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: cs.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 1명 선택 시: 개인 캘린더처럼 그 날의 근무 코드(D/E/N/기타) 또는 오프(O)를
/// 색 알약으로 표시한다.
class _SingleMemberDayCell extends StatelessWidget {
  const _SingleMemberDayCell({required this.shift});

  final PersonalMemberShift shift;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final rawCode = (shift.shiftCode ?? '').trim();
    final isOff = rawCode.isEmpty || isPersonalOffShift(shift);
    final denCode = personalShiftDenCode(shift); // D/E/N 또는 null

    final label = isOff ? 'O' : rawCode.toUpperCase();
    final color = isOff
        ? cs.onSurfaceVariant
        : (denCode != null
              ? personalShiftColorByCode(denCode)
              : resolvePersonalShiftColor(context, shift));

    // 개인 캘린더와 동일하게 셀 폭에 가까운 넓은 띠로 표시.
    return Container(
      width: 44,
      padding: const EdgeInsets.symmetric(vertical: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: isOff ? 0.12 : 0.18),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: isOff ? cs.onSurfaceVariant : color,
          height: 1,
        ),
      ),
    );
  }
}

class _PersonalCalendarMarker extends StatelessWidget {
  const _PersonalCalendarMarker({
    required this.sortedCodes,
    required this.typeCount,
  });

  final List<String> sortedCodes;
  final Map<String, int> typeCount;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: sortedCodes.take(3).map((code) {
        final color = personalShiftColorByCode(code);

        return Container(
          width: 12,
          height: 12,
          margin: const EdgeInsets.symmetric(horizontal: 0.5),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Center(
            child: Text(
              '${typeCount[code]}',
              style: TextStyle(
                fontSize: 6,
                fontWeight: FontWeight.w800,
                color: cs.surface,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _OverlapCornerDot extends StatelessWidget {
  const _OverlapCornerDot();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: cs.error,
        shape: BoxShape.circle,
        border: Border.all(
          color: cs.surface,
          width: 1.4,
          strokeAlign: BorderSide.strokeAlignOutside,
        ),
        boxShadow: [
          BoxShadow(
            color: cs.error.withValues(alpha: 0.24),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}

class _OverlapControlChip extends StatelessWidget {
  const _OverlapControlChip({
    this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData? icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = selected
        ? cs.primaryContainer.withValues(alpha: 0.55)
        : cs.surfaceContainerLow;
    final borderColor = selected
        ? cs.primary.withValues(alpha: 0.5)
        : cs.outlineVariant.withValues(alpha: 0.8);
    final iconColor = selected ? cs.primary : cs.onSurfaceVariant;
    final fg = selected ? cs.onPrimaryContainer : cs.onSurface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.borderRadiusFull,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: AppRadius.borderRadiusFull,
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: iconColor),
                const SizedBox(width: AppSpacing.xs),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 전체 / 과반수만 2분할 토글 — "누르는 것"임을 직관적으로 보여준다.
class _OverlapScopeToggle extends StatelessWidget {
  const _OverlapScopeToggle({required this.showAll, required this.onChanged});

  final bool showAll;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget seg(String label, bool selected, VoidCallback onTap) {
      return GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: selected ? cs.primary : Colors.transparent,
            borderRadius: AppRadius.borderRadiusFull,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: selected ? cs.onPrimary : cs.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: AppRadius.borderRadiusFull,
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          seg('과반수', !showAll, () => onChanged(false)),
          seg('전체', showAll, () => onChanged(true)),
        ],
      ),
    );
  }
}

class _OverlapCollapsedSummary extends StatelessWidget {
  const _OverlapCollapsedSummary({
    required this.monthLabel,
    required this.days,
  });

  final String monthLabel;
  final List<_OverlapDaySummary> days;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final maxCount = days.isEmpty
        ? 0
        : days.map((day) => day.count).reduce((a, b) => a > b ? a : b);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.36),
        borderRadius: AppRadius.borderRadiusMd,
      ),
      child: Row(
        children: [
          Icon(Icons.auto_graph_rounded, size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: AppSpacing.xs),
          Text(
            monthLabel,
            style: textTheme.labelMedium?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          Text(
            days.isEmpty ? '겹침 없음' : '최대 $maxCount명 · ${days.length}일',
            style: textTheme.labelMedium?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberSelectionTile extends StatelessWidget {
  const _MemberSelectionTile({
    required this.member,
    required this.selected,
    required this.onTap,
  });

  final PersonalTeamMember member;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.borderRadiusLg,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: selected
                ? cs.primaryContainer.withValues(alpha: 0.16)
                : cs.surface,
            borderRadius: AppRadius.borderRadiusMd,
            border: Border.all(
              color: selected
                  ? cs.primary.withValues(alpha: 0.38)
                  : cs.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: Row(
            children: [
              _MemberSelectionAvatar(member: member),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  member.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: selected ? cs.primary : cs.surfaceContainerHighest,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? cs.primary : cs.outlineVariant,
                  ),
                ),
                child: selected
                    ? Icon(Icons.check_rounded, size: 15, color: cs.onPrimary)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberSelectionAvatar extends StatelessWidget {
  const _MemberSelectionAvatar({required this.member});

  final PersonalTeamMember member;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final avatarUrl = member.avatarUrl;

    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 14,
        backgroundColor: cs.primaryContainer,
        backgroundImage: NetworkImage(avatarUrl),
        onBackgroundImageError: (_, __) {},
      );
    }

    return CircleAvatar(
      radius: 14,
      backgroundColor: cs.primaryContainer.withValues(alpha: 0.72),
      child: Text(
        _initials(member.displayName),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: cs.onPrimaryContainer,
        ),
      ),
    );
  }

  String _initials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.substring(0, 1).toUpperCase();
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
  static const int _previewLines = 1;
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
            color: cs.surfaceContainerLow,
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
