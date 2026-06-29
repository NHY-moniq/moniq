import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/providers/settings_providers.dart';
import 'package:moniq/data/providers/supabase_providers.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/personal_team_calendar_viewmodel.dart';
import 'package:moniq/presentation/widgets/calendar/view_mode_toggle.dart';
import 'package:moniq/presentation/widgets/calendar/weekly_member_grid.dart';

/// 친목 팀 상세 화면에 임베드되는 주간 멤버 그리드 섹션.
///
/// `멤버 근무 현황` 화면과 동일한 [personalTeamCalendarViewModelProvider]를
/// 재사용해 선택 멤버·주차 상태를 공유한다. 월 토글이나 멤버 선택처럼 더
/// 넓은 화면이 필요한 동작은 전체 캘린더 화면으로 자연스럽게 연결한다.
class PersonalTeamWeeklyGridSection extends ConsumerWidget {
  const PersonalTeamWeeklyGridSection({super.key, required this.teamId});

  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(
      personalTeamCalendarViewModelProvider(teamId),
    );
    final calendarStartDay = ref.watch(calendarStartDayProvider);
    final startsOnSunday = calendarStartDay == 'sunday';
    final currentUserId = ref
        .watch(supabaseClientProvider)
        .auth
        .currentUser
        ?.id;

    void openFullCalendar() {
      context.push('/teams/$teamId/personal-calendar');
    }

    return stateAsync.when(
      loading: () => const _GridSectionPlaceholder(
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (e, _) => _GridSectionPlaceholder(
        child: Center(
          child: SelectableText.rich(
            TextSpan(
              text: '근무 정보를 불러올 수 없습니다',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
      data: (state) {
        final vm = ref.read(
          personalTeamCalendarViewModelProvider(teamId).notifier,
        );

        return MemberShiftGrid(
          selectedDate: state.selectedDate,
          focusedMonth: state.focusedMonth,
          members: state.selectedMembers,
          monthlyData: state.monthlyData,
          startsOnSunday: startsOnSunday,
          currentUserId: currentUserId,
          // 임베드 섹션은 주간 그리드 미리보기만 — 겹침 마커는 전체 화면에서.
          overlapDates: const <DateTime>{},
          // 임베드 섹션은 주간 그리드만 보여주고, 월 보기는 전체 화면으로 위임.
          viewMode: CalendarViewMode.week,
          onViewModeChanged: (mode) {
            if (mode == CalendarViewMode.month) openFullCalendar();
          },
          onDateSelected: vm.selectDate,
          onMoveWeek: (delta) => vm.moveWeek(delta),
          onMoveMonth: (_) => openFullCalendar(),
          onToday: () => vm.goToTodayWeek(startsOnSunday),
          onSelectMembers: openFullCalendar,
        );
      },
    );
  }
}

class _GridSectionPlaceholder extends StatelessWidget {
  const _GridSectionPlaceholder({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: child,
      ),
    );
  }
}
