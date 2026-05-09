import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/models/personal_team_member_shift.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/personal_team_calendar_viewmodel.dart';
import 'package:moniq/presentation/widgets/calendar/moniq_calendar.dart';
import 'package:moniq/presentation/widgets/common/moniq_app_bar.dart';
import 'package:moniq/presentation/widgets/common/moniq_error_view.dart';
import 'package:moniq/presentation/widgets/common/moniq_loading_view.dart';

import 'personal_team_calendar_widgets.dart';

class PersonalTeamCalendarScreen extends ConsumerWidget {
  const PersonalTeamCalendarScreen({
    super.key,
    required this.teamId,
  });

  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(
      personalTeamCalendarViewModelProvider(teamId),
    );

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
          onRetry: () => ref.invalidate(
            personalTeamCalendarViewModelProvider(teamId),
          ),
        ),
        data: (state) => _CalendarBody(state: state, teamId: teamId),
      ),
    );
  }
}

class _CalendarBody extends ConsumerWidget {
  const _CalendarBody({
    required this.state,
    required this.teamId,
  });

  final PersonalTeamCalendarState state;
  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.read(
      personalTeamCalendarViewModelProvider(teamId).notifier,
    );
    final selectedShifts = state.shiftsForDate(state.selectedDate);

    return SingleChildScrollView(
      child: Column(
        children: [
          MoniqCalendar(
            focusedDay: state.focusedMonth,
            selectedDay: state.selectedDate,
            rowHeight: 64,
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
              final dots = dayShifts.take(3).toList();
              final cs = Theme.of(context).colorScheme;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: dots.map((s) {
                  Color color = cs.onSurfaceVariant.withValues(alpha: 0.4);
                  if (s.shiftColor != null) {
                    try {
                      final hex = s.shiftColor!.replaceFirst('#', '');
                      color = Color(int.parse('FF$hex', radix: 16));
                    } catch (_) {}
                  }
                  return Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  );
                }).toList(),
              );
            },
            // 빈 리스트: 기본 DAY/EVENING/NIGHT/OFF 범례 숨김
            legendItems: const [],
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
