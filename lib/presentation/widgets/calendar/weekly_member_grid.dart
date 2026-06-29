import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:moniq/data/models/personal_team_member_shift.dart';
import 'package:moniq/presentation/screens/team/personal_team_calendar_widgets.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/widgets/calendar/view_mode_toggle.dart';

/// [date]가 속한 주의 시작일(자정)을 반환한다.
/// [startsOnSunday]가 true면 일요일, 아니면 월요일을 주 시작으로 본다.
DateTime personalWeekStart(DateTime date, bool startsOnSunday) {
  final base = DateTime(date.year, date.month, date.day);
  // DateTime.weekday: 월=1 … 일=7
  final diff = startsOnSunday ? base.weekday % 7 : base.weekday - 1;
  return base.subtract(Duration(days: diff));
}

DateTime _addDays(DateTime base, int days) =>
    DateTime(base.year, base.month, base.day + days);

DateTime _dateKey(DateTime date) => DateTime(date.year, date.month, date.day);

const _weekdayLabels = {
  DateTime.monday: '월',
  DateTime.tuesday: '화',
  DateTime.wednesday: '수',
  DateTime.thursday: '목',
  DateTime.friday: '금',
  DateTime.saturday: '토',
  DateTime.sunday: '일',
};

/// 가로축=요일/일자 × 세로축=멤버 매트릭스 그리드.
///
/// 친목(personal) 팀 캘린더의 기본 뷰로, 각 셀에 멤버의 그 날 근무를
/// 색 + 약자로 표시한다. [viewMode]에 따라 주(7일) 또는 월(1일~말일)
/// 단위로 동일한 셀/헤더/하이라이트 위젯을 재사용한다.
class MemberShiftGrid extends StatelessWidget {
  const MemberShiftGrid({
    super.key,
    required this.selectedDate,
    required this.focusedMonth,
    required this.members,
    required this.monthlyData,
    required this.startsOnSunday,
    required this.currentUserId,
    required this.viewMode,
    required this.overlapDates,
    required this.onViewModeChanged,
    required this.onDateSelected,
    required this.onMoveWeek,
    required this.onMoveMonth,
    required this.onToday,
    required this.onSelectMembers,
  });

  /// 주를 결정하는 기준일이자 선택 강조 대상 날짜.
  final DateTime selectedDate;

  /// 월 모드에서 표시할 달.
  final DateTime focusedMonth;
  final List<PersonalTeamMember> members;
  final Map<DateTime, List<PersonalMemberShift>> monthlyData;
  final bool startsOnSunday;
  final String? currentUserId;
  final CalendarViewMode viewMode;

  /// 겹침으로 강조할 날짜(자정 정규화) 집합. 일자 헤더에 마커로 표시한다.
  final Set<DateTime> overlapDates;
  final ValueChanged<CalendarViewMode> onViewModeChanged;
  final ValueChanged<DateTime> onDateSelected;
  final ValueChanged<int> onMoveWeek;
  final ValueChanged<int> onMoveMonth;
  final VoidCallback onToday;
  final VoidCallback onSelectMembers;

  bool get _isMonth => viewMode == CalendarViewMode.month;

  List<DateTime> _buildDays() {
    if (!_isMonth) {
      final start = personalWeekStart(selectedDate, startsOnSunday);
      return [for (var i = 0; i < 7; i++) _addDays(start, i)];
    }
    final last = DateTime(focusedMonth.year, focusedMonth.month + 1, 0);
    return [
      for (var d = 1; d <= last.day; d++)
        DateTime(focusedMonth.year, focusedMonth.month, d),
    ];
  }

  String _label() {
    if (_isMonth) {
      return DateFormat('yyyy년 M월').format(focusedMonth);
    }
    final weekStart = personalWeekStart(selectedDate, startsOnSunday);
    final nth = ((weekStart.day - 1) ~/ 7) + 1;
    return '${weekStart.month}월 $nth주';
  }

  @override
  Widget build(BuildContext context) {
    final days = _buildDays();
    final today = _dateKey(DateTime.now());
    final selected = _dateKey(selectedDate);
    final hasToday = !today.isBefore(days.first) && !today.isAfter(days.last);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MemberGridNavBar(
          label: _label(),
          hasToday: hasToday,
          viewMode: viewMode,
          isMonth: _isMonth,
          onViewModeChanged: onViewModeChanged,
          onPrev: () => _isMonth ? onMoveMonth(-1) : onMoveWeek(-1),
          onNext: () => _isMonth ? onMoveMonth(1) : onMoveWeek(1),
          onToday: onToday,
        ),
        const SizedBox(height: AppSpacing.sm),
        if (members.isEmpty)
          _GridEmptyState(onSelectMembers: onSelectMembers)
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final isTablet = constraints.maxWidth >= 600;
              // 멤버 컬럼은 이름만 표시하므로 최소 폭으로 줄여 일자 셀에
              // 더 많은 가로 공간을 내준다.
              final nameColWidth = isTablet ? 64.0 : 50.0;
              const gap = 2.0;
              final available =
                  constraints.maxWidth - nameColWidth - gap * (days.length - 1);
              final dayCellWidth = available / days.length;
              // 월 모드는 항상 가로 스크롤(일셀폭 44 고정). 주 모드는 폭이
              // 좁을 때만 스크롤로 전환한다.
              final useScroll = !_isMonth && dayCellWidth < 36;
              final showShiftName = !_isMonth && isTablet;

              final shiftByDateUser =
                  <DateTime, Map<String, PersonalMemberShift>>{
                    for (final day in days)
                      day: {
                        for (final shift
                            in monthlyData[day] ??
                                const <PersonalMemberShift>[])
                          shift.userId: shift,
                      },
                  };

              // 선택일이 표시 중인 열에 있으면 그 열을 화면 중앙으로 정렬한다.
              final selectedColumn = days.indexOf(selected);

              return _GridMatrix(
                days: days,
                members: members,
                shiftByDateUser: shiftByDateUser,
                overlapDates: overlapDates,
                today: today,
                selected: selected,
                currentUserId: currentUserId,
                nameColWidth: nameColWidth,
                useScroll: useScroll,
                forceScroll: _isMonth,
                showShiftName: showShiftName,
                viewportWidth: constraints.maxWidth - nameColWidth,
                autoCenterIndex: selectedColumn >= 0 ? selectedColumn : null,
                monthKey: focusedMonth.year * 12 + focusedMonth.month,
                onDateSelected: onDateSelected,
              );
            },
          ),
      ],
    );
  }
}

/// 상단 네비게이션 바: 이전/라벨/다음 + 오늘 + 월/주 토글을 한 줄에 배치한다.
class _MemberGridNavBar extends StatelessWidget {
  const _MemberGridNavBar({
    required this.label,
    required this.hasToday,
    required this.viewMode,
    required this.isMonth,
    required this.onViewModeChanged,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
  });

  final String label;
  final bool hasToday;
  final CalendarViewMode viewMode;
  final bool isMonth;
  final ValueChanged<CalendarViewMode> onViewModeChanged;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        _NavPill(
          icon: Icons.chevron_left_rounded,
          onTap: onPrev,
          tooltip: isMonth ? '이전 달' : '이전 주',
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: cs.onSurface,
                  ),
                ),
              ),
              if (!hasToday) ...[
                const SizedBox(width: AppSpacing.xs),
                _TodayPill(onTap: onToday),
              ],
            ],
          ),
        ),
        _NavPill(
          icon: Icons.chevron_right_rounded,
          onTap: onNext,
          tooltip: isMonth ? '다음 달' : '다음 주',
        ),
        ViewModeToggle(currentMode: viewMode, onChanged: onViewModeChanged),
      ],
    );
  }
}

class _NavPill extends StatelessWidget {
  const _NavPill({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: cs.surfaceContainerHigh,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(icon, size: 20, color: cs.onSurface),
          ),
        ),
      ),
    );
  }
}

class _TodayPill extends StatelessWidget {
  const _TodayPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: cs.primaryContainer.withValues(alpha: 0.55),
      borderRadius: AppRadius.borderRadiusFull,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.borderRadiusFull,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Text(
            '오늘',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: cs.onPrimaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}

/// 헤더 + 멤버 행 매트릭스.
///
/// 폭이 좁거나 월 모드면 이름 컬럼 고정 + 일자 가로 스크롤 구조로 그린다.
/// 월 모드에서는 선택/오늘 열을 화면 중앙에 오도록 자동 정렬한다.
class _GridMatrix extends StatefulWidget {
  const _GridMatrix({
    required this.days,
    required this.members,
    required this.shiftByDateUser,
    required this.overlapDates,
    required this.today,
    required this.selected,
    required this.currentUserId,
    required this.nameColWidth,
    required this.useScroll,
    required this.forceScroll,
    required this.showShiftName,
    required this.viewportWidth,
    required this.autoCenterIndex,
    required this.monthKey,
    required this.onDateSelected,
  });

  static const double headerHeight = 40;
  static const double rowHeight = 46;
  static const double scrollCellWidth = 44;

  final List<DateTime> days;
  final List<PersonalTeamMember> members;
  final Map<DateTime, Map<String, PersonalMemberShift>> shiftByDateUser;
  final Set<DateTime> overlapDates;
  final DateTime today;
  final DateTime selected;
  final String? currentUserId;
  final double nameColWidth;
  final bool useScroll;
  final bool forceScroll;
  final bool showShiftName;
  final double viewportWidth;

  /// 월 모드에서 가운데로 정렬할 열 인덱스(선택일). 주 모드면 null.
  final int? autoCenterIndex;
  final int monthKey;
  final ValueChanged<DateTime> onDateSelected;

  bool get scrollActive => useScroll || forceScroll;

  @override
  State<_GridMatrix> createState() => _GridMatrixState();
}

class _GridMatrixState extends State<_GridMatrix> {
  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.scrollActive) _scheduleCenter(animate: false);
  }

  @override
  void didUpdateWidget(_GridMatrix oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.scrollActive) return;
    if (!oldWidget.scrollActive) {
      // 막 스크롤 모드로 진입(주→월 등) — 즉시 중앙으로 점프.
      _scheduleCenter(animate: false);
    } else if (widget.monthKey != oldWidget.monthKey ||
        widget.autoCenterIndex != oldWidget.autoCenterIndex) {
      // 달 이동 또는 선택일 변경 시 선택 열을 부드럽게 중앙으로.
      _scheduleCenter(animate: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _scheduleCenter({required bool animate}) {
    final index = widget.autoCenterIndex;
    if (index == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_controller.hasClients) return;
      final target =
          (index * _GridMatrix.scrollCellWidth) -
          (widget.viewportWidth - _GridMatrix.scrollCellWidth) / 2;
      final clamped = target.clamp(0.0, _controller.position.maxScrollExtent);
      if (animate) {
        _controller.animateTo(
          clamped,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      } else {
        _controller.jumpTo(clamped);
      }
    });
  }

  bool _isToday(DateTime day) => day == widget.today;
  bool _isSelected(DateTime day) => day == widget.selected;
  bool _hasOverlap(DateTime day) => widget.overlapDates.contains(day);

  PersonalMemberShift? _shiftFor(DateTime day, String userId) =>
      widget.shiftByDateUser[day]?[userId];

  Color _zebra(BuildContext context, int index) {
    final cs = Theme.of(context).colorScheme;
    return index.isOdd
        ? cs.surfaceContainerHighest.withValues(alpha: 0.18)
        : Colors.transparent;
  }

  @override
  Widget build(BuildContext context) {
    final members = widget.members;
    final days = widget.days;

    if (widget.scrollActive) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 고정 이름 컬럼.
          Column(
            children: [
              SizedBox(
                width: widget.nameColWidth,
                height: _GridMatrix.headerHeight,
              ),
              for (var i = 0; i < members.length; i++)
                Container(
                  width: widget.nameColWidth,
                  height: _GridMatrix.rowHeight,
                  color: _zebra(context, i),
                  child: _MemberNameCell(
                    member: members[i],
                    isSelf: members[i].userId == widget.currentUserId,
                  ),
                ),
            ],
          ),
          // 가로 스크롤되는 일자 영역.
          Expanded(
            child: SingleChildScrollView(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      for (final day in days)
                        SizedBox(
                          width: _GridMatrix.scrollCellWidth,
                          child: _WeekdayHeaderCell(
                            date: day,
                            isToday: _isToday(day),
                            isSelected: _isSelected(day),
                            hasOverlap: _hasOverlap(day),
                            onTap: () => widget.onDateSelected(day),
                          ),
                        ),
                    ],
                  ),
                  for (var i = 0; i < members.length; i++)
                    Container(
                      color: _zebra(context, i),
                      child: Row(
                        children: [
                          for (final day in days)
                            SizedBox(
                              width: _GridMatrix.scrollCellWidth,
                              child: _DaySlot(
                                date: day,
                                member: members[i],
                                shift: _shiftFor(day, members[i].userId),
                                isToday: _isToday(day),
                                isSelected: _isSelected(day),
                                showShiftName: widget.showShiftName,
                                onTap: () => widget.onDateSelected(day),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Row(
          children: [
            SizedBox(
              width: widget.nameColWidth,
              height: _GridMatrix.headerHeight,
            ),
            for (final day in days)
              Expanded(
                child: _WeekdayHeaderCell(
                  date: day,
                  isToday: _isToday(day),
                  isSelected: _isSelected(day),
                  hasOverlap: _hasOverlap(day),
                  onTap: () => widget.onDateSelected(day),
                ),
              ),
          ],
        ),
        for (var i = 0; i < members.length; i++)
          Container(
            color: _zebra(context, i),
            child: Row(
              children: [
                SizedBox(
                  width: widget.nameColWidth,
                  height: _GridMatrix.rowHeight,
                  child: _MemberNameCell(
                    member: members[i],
                    isSelf: members[i].userId == widget.currentUserId,
                  ),
                ),
                for (final day in days)
                  Expanded(
                    child: _DaySlot(
                      date: day,
                      member: members[i],
                      shift: _shiftFor(day, members[i].userId),
                      isToday: _isToday(day),
                      isSelected: _isSelected(day),
                      showShiftName: widget.showShiftName,
                      onTap: () => widget.onDateSelected(day),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

Color _columnTint(
  ColorScheme cs, {
  required bool isToday,
  required bool isSelected,
}) {
  if (isSelected) return cs.primary.withValues(alpha: 0.10);
  if (isToday) return cs.primary.withValues(alpha: 0.06);
  return Colors.transparent;
}

class _WeekdayHeaderCell extends StatelessWidget {
  const _WeekdayHeaderCell({
    required this.date,
    required this.isToday,
    required this.isSelected,
    required this.hasOverlap,
    required this.onTap,
  });

  final DateTime date;
  final bool isToday;
  final bool isSelected;
  final bool hasOverlap;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Color weekdayColor;
    if (date.weekday == DateTime.saturday) {
      weekdayColor = cs.tertiary;
    } else if (date.weekday == DateTime.sunday) {
      weekdayColor = cs.error;
    } else {
      weekdayColor = cs.onSurfaceVariant;
    }

    final dateNumber = isToday
        ? Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: cs.primary,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: cs.onPrimary,
              ),
            ),
          )
        : Text(
            '${date.day}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
              color: isSelected ? cs.primary : cs.onSurface,
            ),
          );

    return InkWell(
      onTap: onTap,
      child: Container(
        height: _GridMatrix.headerHeight,
        color: _columnTint(cs, isToday: isToday, isSelected: isSelected),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _weekdayLabels[date.weekday] ?? '',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: weekdayColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  dateNumber,
                ],
              ),
            ),
            if (hasOverlap)
              const Positioned(top: 4, right: 4, child: _OverlapHeaderDot()),
          ],
        ),
      ),
    );
  }
}

/// 겹침 날짜를 헤더에 표시하는 작은 점 마커.
///
/// 이전 월 캘린더의 코너 점과 동일한 톤으로, error 강조색에 표면색
/// 테두리 + 은은한 글로우를 더해 또렷하게 보이도록 한다.
class _OverlapHeaderDot extends StatelessWidget {
  const _OverlapHeaderDot();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        color: cs.error,
        shape: BoxShape.circle,
        border: Border.all(
          color: cs.surface,
          width: 1.2,
          strokeAlign: BorderSide.strokeAlignOutside,
        ),
        boxShadow: [
          BoxShadow(
            color: cs.error.withValues(alpha: 0.28),
            blurRadius: 5,
            spreadRadius: 0.5,
          ),
        ],
      ),
    );
  }
}

class _MemberNameCell extends StatelessWidget {
  const _MemberNameCell({required this.member, required this.isSelf});

  final PersonalTeamMember member;
  final bool isSelf;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          member.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: isSelf ? cs.primary : cs.onSurface,
          ),
        ),
      ),
    );
  }
}

/// 컬럼 배경 + 탭 영역 + 중앙 근무 칩.
class _DaySlot extends StatelessWidget {
  const _DaySlot({
    required this.date,
    required this.member,
    required this.shift,
    required this.isToday,
    required this.isSelected,
    required this.showShiftName,
    required this.onTap,
  });

  final DateTime date;
  final PersonalTeamMember member;
  final PersonalMemberShift? shift;
  final bool isToday;
  final bool isSelected;
  final bool showShiftName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final spec = _resolveShift(context, shift);
    final weekday = _weekdayLabels[date.weekday] ?? '';

    return Semantics(
      label: '${member.displayName} $weekday ${spec.semanticName}',
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: _GridMatrix.rowHeight,
          color: _columnTint(cs, isToday: isToday, isSelected: isSelected),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: _ShiftCell(spec: spec, showShiftName: showShiftName),
        ),
      ),
    );
  }
}

class _ShiftCell extends StatelessWidget {
  const _ShiftCell({required this.spec, required this.showShiftName});

  final _ShiftCellSpec spec;
  final bool showShiftName;

  @override
  Widget build(BuildContext context) {
    final showName = showShiftName && spec.name.isNotEmpty;

    return Container(
      height: 28,
      width: double.infinity,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: spec.color.withValues(
          alpha: spec.kind == _ShiftKind.off ? 0.10 : 0.18,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            spec.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: spec.color,
              height: 1,
            ),
          ),
          if (showName) ...[
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                spec.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: spec.color,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

enum _ShiftKind { off, den, custom }

class _ShiftCellSpec {
  const _ShiftCellSpec({
    required this.kind,
    required this.label,
    required this.name,
    required this.color,
    required this.semanticName,
  });

  final _ShiftKind kind;
  final String label;
  final String name;
  final Color color;
  final String semanticName;
}

_ShiftCellSpec _resolveShift(BuildContext context, PersonalMemberShift? shift) {
  final cs = Theme.of(context).colorScheme;

  // 근무 데이터가 없는 날(미입력)도 오프 셀로 표시한다.
  _ShiftCellSpec offSpec() => _ShiftCellSpec(
    kind: _ShiftKind.off,
    label: 'O',
    name: '오프',
    color: cs.onSurfaceVariant,
    semanticName: '오프',
  );

  if (shift == null) return offSpec();

  if (isPersonalOffShift(shift)) return offSpec();

  final rawCode = (shift.shiftCode ?? '').trim();
  if (rawCode.isEmpty) return offSpec();

  final denCode = personalShiftDenCode(shift);
  if (denCode != null) {
    return _ShiftCellSpec(
      kind: _ShiftKind.den,
      label: denCode,
      name: _denLabel(denCode),
      color: personalShiftColorByCode(denCode),
      semanticName: _denLabel(denCode),
    );
  }

  final upper = rawCode.toUpperCase();
  final label = upper.length > 2 ? upper.substring(0, 2) : upper;
  final name = (shift.shiftName ?? '').trim();
  return _ShiftCellSpec(
    kind: _ShiftKind.custom,
    label: label,
    name: name,
    color: resolvePersonalShiftColor(context, shift),
    semanticName: name.isNotEmpty ? name : label,
  );
}

String _denLabel(String code) {
  switch (code) {
    case 'D':
      return '데이';
    case 'E':
      return '이브닝';
    case 'N':
      return '나이트';
    default:
      return code;
  }
}

class _GridEmptyState extends StatelessWidget {
  const _GridEmptyState({required this.onSelectMembers});

  final VoidCallback onSelectMembers;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xxl,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: AppRadius.borderRadiusLg,
      ),
      child: Column(
        children: [
          Icon(Icons.group_off_outlined, size: 36, color: cs.onSurfaceVariant),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '표시할 멤버가 없습니다',
            style: textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.tonal(
            onPressed: onSelectMembers,
            child: const Text('멤버 선택'),
          ),
        ],
      ),
    );
  }
}
