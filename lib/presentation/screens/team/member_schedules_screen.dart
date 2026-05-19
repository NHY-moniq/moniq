import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moniq/data/models/personal_team_member_shift.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/personal_team_calendar_viewmodel.dart';
import 'package:moniq/presentation/widgets/calendar/moniq_calendar.dart';
import 'package:moniq/presentation/widgets/calendar/view_mode_toggle.dart';
import 'package:moniq/presentation/widgets/common/moniq_app_bar.dart';
import 'package:moniq/presentation/widgets/common/moniq_empty_state.dart';
import 'package:moniq/presentation/widgets/common/moniq_error_view.dart';
import 'package:moniq/presentation/widgets/common/moniq_loading_view.dart';
import 'package:table_calendar/table_calendar.dart';

/// 멤버별 근무 현황 — 멤버 칩 선택 후 해당 멤버의 즐겨찾기 팀 근무 일정을 캘린더로 노출.
class MemberSchedulesScreen extends ConsumerStatefulWidget {
  const MemberSchedulesScreen({super.key, required this.teamId});

  final String teamId;

  @override
  ConsumerState<MemberSchedulesScreen> createState() =>
      _MemberSchedulesScreenState();
}

class _MemberSchedulesScreenState extends ConsumerState<MemberSchedulesScreen> {
  String? _selectedUserId;
  CalendarViewMode _viewMode = CalendarViewMode.month;

  @override
  Widget build(BuildContext context) {
    final stateAsync =
        ref.watch(personalTeamCalendarViewModelProvider(widget.teamId));
    return Scaffold(
      appBar: const MoniqAppBar(
        title: '멤버별 근무 현황',
        eyebrow: 'MEMBER SCHEDULES',
        showBack: true,
      ),
      body: stateAsync.when(
        loading: () => const MoniqLoadingView(),
        error: (e, _) => MoniqErrorView(
          message: '근무 정보를 불러올 수 없어요',
          onRetry: () => ref
              .invalidate(personalTeamCalendarViewModelProvider(widget.teamId)),
        ),
        data: (state) {
          if (state.members.isEmpty) {
            return MoniqEmptyState.peaceful(
              title: '멤버가 없어요',
              message: '먼저 개인팀에 팀원을 추가해주세요',
            );
          }
          final selectedId = _selectedUserId ?? state.members.first.userId;
          final vm = ref.read(personalTeamCalendarViewModelProvider(widget.teamId).notifier);
          return _Body(
            state: state,
            selectedUserId: selectedId,
            viewMode: _viewMode,
            onSelectMember: (id) =>
                setState(() => _selectedUserId = id),
            onSelectDate: vm.selectDate,
            onChangeMonth: vm.changeMonth,
            onViewModeChanged: (m) => setState(() => _viewMode = m),
          );
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.state,
    required this.selectedUserId,
    required this.viewMode,
    required this.onSelectMember,
    required this.onSelectDate,
    required this.onChangeMonth,
    required this.onViewModeChanged,
  });

  final PersonalTeamCalendarState state;
  final String selectedUserId;
  final CalendarViewMode viewMode;
  final ValueChanged<String> onSelectMember;
  final ValueChanged<DateTime> onSelectDate;
  final ValueChanged<DateTime> onChangeMonth;
  final ValueChanged<CalendarViewMode> onViewModeChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final selectedMember = state.members.firstWhere(
      (m) => m.userId == selectedUserId,
      orElse: () => state.members.first,
    );

    // 선택 멤버의 해당 월 shifts (date → 단일 shift) 추출.
    final dateToShift = <DateTime, PersonalMemberShift>{};
    for (final entry in state.monthlyData.entries) {
      final shift = entry.value.firstWhere(
        (s) => s.userId == selectedUserId,
        orElse: () => PersonalMemberShift(
          userId: selectedUserId,
          date: entry.key,
        ),
      );
      dateToShift[entry.key] = shift;
    }

    // 범례 — 멤버 본인의 근무 유형만.
    final legendBuckets = <String, _ShiftBucket>{};
    for (final s in dateToShift.values) {
      if (s.shiftCode == null && s.shiftName == null) continue;
      final key = s.shiftName ?? s.shiftCode!;
      legendBuckets.putIfAbsent(
        key,
        () => _ShiftBucket(
          code: s.shiftCode ?? key,
          color: s.shiftColor ?? '#A0AEC0',
        ),
      );
    }
    final legendItems = legendBuckets.values.map((info) {
      Color color = const Color(0xFFA0AEC0);
      try {
        final hex = info.color.replaceFirst('#', '');
        color = Color(int.parse('FF$hex', radix: 16));
      } catch (_) {}
      return (color: color, label: info.code.toUpperCase());
    }).toList();

    final dateFormat = DateFormat('M월 d일 (E)', 'ko');
    final selectedShift = dateToShift[DateTime(
      state.selectedDate.year,
      state.selectedDate.month,
      state.selectedDate.day,
    )];

    return Column(
      children: [
        // 멤버 칩 선택자
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final m in state.members) ...[
                  ChoiceChip(
                    selected: m.userId == selectedUserId,
                    label: Text(m.displayName),
                    onSelected: (_) => onSelectMember(m.userId),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
              ],
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                MoniqCalendar(
                  focusedDay: state.focusedMonth,
                  selectedDay: state.selectedDate,
                  rowHeight: 70,
                  viewMode: viewMode,
                  onViewModeChanged: onViewModeChanged,
                  calendarFormat: viewMode == CalendarViewMode.month
                      ? CalendarFormat.month
                      : CalendarFormat.week,
                  legendItems: legendItems,
                  eventLoader: (day) {
                    final key = DateTime(day.year, day.month, day.day);
                    final s = dateToShift[key];
                    return (s != null && s.shiftCode != null) ? [s] : [];
                  },
                  onDaySelected: (sel, _) => onSelectDate(sel),
                  onPageChanged: onChangeMonth,
                  // 셀에 단문자 컬러 박스 표시
                  previewBuilder: (day) {
                    final key = DateTime(day.year, day.month, day.day);
                    final s = dateToShift[key];
                    if (s == null || s.shiftCode == null) {
                      return const [];
                    }
                    Color color = AppColors.shiftOff;
                    try {
                      final hex = (s.shiftColor ?? '#A0AEC0')
                          .replaceFirst('#', '');
                      color = Color(int.parse('FF$hex', radix: 16));
                    } catch (_) {}
                    final code = (s.shiftCode ?? '?').toUpperCase();
                    return [
                      CalendarPreview(
                        text: code.length > 1 ? code[0] : code,
                        color: color,
                        isWork: true,
                      ),
                    ];
                  },
                  markerBuilder: (_, __, ___) => null,
                ),
                const SizedBox(height: AppSpacing.lg),
                // 선택일 상세
                Padding(
                  padding: AppSpacing.screenHorizontal,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${selectedMember.displayName} · ${dateFormat.format(state.selectedDate)}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        if (selectedShift == null ||
                            selectedShift.shiftCode == null)
                          Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppColors.shiftOff
                                      .withValues(alpha: 0.18),
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.sm),
                                ),
                                child: const Text(
                                  'O',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.shiftOff,
                                    height: 1,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Text(
                                '오프',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          )
                        else
                          _ShiftDetailTile(shift: selectedShift),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxxl),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ShiftDetailTile extends StatelessWidget {
  const _ShiftDetailTile({required this.shift});

  final PersonalMemberShift shift;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Color color = AppColors.shiftDay;
    try {
      final hex = (shift.shiftColor ?? '#A0AEC0').replaceFirst('#', '');
      color = Color(int.parse('FF$hex', radix: 16));
    } catch (_) {}
    final code = (shift.shiftCode ?? '?').toUpperCase();
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Text(
            code.length > 1 ? code : code,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: ThemeData.estimateBrightnessForColor(color) ==
                      Brightness.dark
                  ? Colors.white
                  : Colors.black87,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Text(
          shift.shiftName ?? code,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ShiftBucket {
  _ShiftBucket({required this.code, required this.color});
  final String code;
  final String color;
}
