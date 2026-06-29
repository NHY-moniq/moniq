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
import 'package:moniq/presentation/widgets/calendar/view_mode_toggle.dart';
import 'package:moniq/presentation/widgets/calendar/weekly_member_grid.dart';
import 'package:moniq/presentation/widgets/common/moniq_app_bar.dart';
import 'package:moniq/presentation/widgets/common/moniq_bottom_sheet.dart';
import 'package:moniq/presentation/widgets/common/moniq_error_view.dart';
import 'package:moniq/presentation/widgets/common/moniq_loading_view.dart';

import 'personal_team_calendar_widgets.dart';

part 'personal_team_calendar_screen_widgets.dart';

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
        data: (state) =>
            PersonalTeamCalendarBody(state: state, teamId: teamId),
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

/// 친목 팀 멤버 근무 현황 본문.
///
/// 멤버 근무 현황 전용 화면([PersonalTeamCalendarScreen])과 팀 탭 메인
/// ([TeamScreen]의 친목 팀 뷰)에서 동일한 본문으로 재사용된다.
class PersonalTeamCalendarBody extends ConsumerStatefulWidget {
  const PersonalTeamCalendarBody({
    super.key,
    required this.state,
    required this.teamId,
  });

  final PersonalTeamCalendarState state;
  final String teamId;

  @override
  ConsumerState<PersonalTeamCalendarBody> createState() =>
      _PersonalTeamCalendarBodyState();
}

class _PersonalTeamCalendarBodyState
    extends ConsumerState<PersonalTeamCalendarBody> {
  bool _includeDay = false;
  bool _isOverlapCardExpanded = false;
  // 과반수 이상만 표시(false) ↔ 전체 겹침 표시(true) 토글
  bool _showAllOverlaps = false;

  static const int _offInsightMinCount = 1;

  DateTime _dateKey(DateTime date) {
    return DateTime(date.year, date.month, date.day);
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
      eyebrow: 'VIEW',
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
              // 내용이 시트 최대 높이를 넘으면 카드 영역만 스크롤되고
              // 확인 버튼은 항상 하단에 고정되어 잘리지 않는다.
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      infoItem(
                        icon: Icons.event_busy_outlined,
                        title: '겹침 기준',
                        body: [
                          bold('오프'),
                          normal('가 겹치는 날을 봅니다. '),
                          bold('데이 포함'),
                          normal('을 켜면 '),
                          bold('데이'),
                          normal('까지 함께 계산해요.'),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      infoItem(
                        icon: Icons.groups_2_outlined,
                        title: '표시 방식',
                        body: [
                          normal('인원의 '),
                          bold('과반수'),
                          normal('가 겹치는 날을 먼저, 없으면 '),
                          bold('겹친 날 전체'),
                          normal('를 보여줍니다.'),
                        ],
                      ),
                    ],
                  ),
                ),
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

  /// 겹침 칩 탭 핸들러.
  ///
  /// 대상 날짜가 현재 표시 중인 주/월 밖이면 먼저 그 기간으로 이동한 뒤
  /// 선택한다. 그리드는 선택일 변경에 맞춰 해당 열을 자동으로 중앙 정렬한다.
  Future<void> _selectOverlapDate(
    PersonalTeamCalendarViewModel vm,
    DateTime date,
  ) async {
    final state = widget.state;
    final target = _dateKey(date);

    if (state.viewMode == CalendarViewMode.month) {
      final sameMonth =
          target.year == state.focusedMonth.year &&
          target.month == state.focusedMonth.month;
      if (!sameMonth) {
        await vm.changeMonth(DateTime(target.year, target.month));
      }
      vm.selectDate(target);
      return;
    }

    // 주 모드: 대상이 현재 표시 주 밖이면 그 주로 이동한 뒤 선택.
    final startsOnSunday = ref.read(calendarStartDayProvider) == 'sunday';
    final currentStart = personalWeekStart(state.selectedDate, startsOnSunday);
    final targetStart = personalWeekStart(target, startsOnSunday);
    final deltaWeeks = targetStart.difference(currentStart).inDays ~/ 7;
    if (deltaWeeks != 0) await vm.moveWeek(deltaWeeks);
    vm.selectDate(target);
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final teamId = widget.teamId;
    final vm = ref.read(personalTeamCalendarViewModelProvider(teamId).notifier);
    final calendarStartDay = ref.watch(calendarStartDayProvider);
    final startsOnSunday = calendarStartDay == 'sunday';
    final currentUserId = ref
        .watch(supabaseClientProvider)
        .auth
        .currentUser
        ?.id;
    final selectedMembers = state.selectedMembers;
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
                        onTap: () => setState(() => _includeDay = !_includeDay),
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
          // ② 이 날 약속 잡기 카드 — 그리드 위로 끌어올려 주요 행동을 강조.
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: AppSpacing.screenHorizontal,
            child: _AppointmentEntryCard(
              dateLabel: _fullDateLabel(state.selectedDate),
              participantCount: selectedMembers.length,
              overlapCount: selectedDateOverlapCount,
              onTap: () => _showAppointmentSheet(context, state, vm),
            ),
          ),
          // ③ 멤버 근무 그리드 — 주/월 공통, 좌우 여백은 최소화.
          const SizedBox(height: AppSpacing.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: MemberShiftGrid(
              selectedDate: state.selectedDate,
              focusedMonth: state.focusedMonth,
              members: selectedMembers,
              monthlyData: state.monthlyData,
              startsOnSunday: startsOnSunday,
              currentUserId: currentUserId,
              viewMode: state.viewMode,
              overlapDates: highlightedOverlapCountByDate.keys.toSet(),
              onViewModeChanged: vm.setViewMode,
              onDateSelected: vm.selectDate,
              onMoveWeek: (delta) => vm.moveWeek(delta),
              onMoveMonth: (delta) => vm.changeMonth(
                DateTime(
                  state.focusedMonth.year,
                  state.focusedMonth.month + delta,
                ),
              ),
              onToday: () => state.viewMode == CalendarViewMode.month
                  ? vm.goToTodayMonth()
                  : vm.goToTodayWeek(startsOnSunday),
              onSelectMembers: () =>
                  _showMemberSelectionSheet(context, state, vm),
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
