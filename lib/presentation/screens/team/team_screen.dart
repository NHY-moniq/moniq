import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/core/utils/color_utils.dart';
import 'package:moniq/core/utils/team_icon_utils.dart';
import 'package:moniq/data/models/shift_with_type.dart';
import 'package:moniq/data/models/team_model.dart';
import 'package:moniq/data/providers/schedule_providers.dart';
import 'package:moniq/data/providers/shift_providers.dart';
import 'package:moniq/data/providers/team_providers.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/team_calendar_viewmodel.dart';
import 'package:moniq/presentation/viewmodels/team_viewmodel.dart';
import 'package:moniq/presentation/widgets/calendar/moniq_calendar.dart';
import 'package:moniq/presentation/widgets/calendar/roster_panel.dart';
import 'package:moniq/presentation/widgets/calendar/shift_marker.dart';
import 'package:moniq/presentation/widgets/calendar/view_mode_toggle.dart';
import 'package:moniq/data/providers/settings_providers.dart';
import 'package:moniq/presentation/widgets/common/character_blob.dart';
import 'package:moniq/presentation/screens/calendar/calendar_export.dart';
import 'package:moniq/presentation/screens/team/team_excel_import.dart';
import 'package:moniq/presentation/widgets/common/moniq_empty_state.dart';
import 'package:moniq/presentation/widgets/common/moniq_error_view.dart';
import 'package:moniq/presentation/widgets/common/moniq_loading_view.dart';
import 'package:table_calendar/table_calendar.dart';

class TeamScreen extends HookConsumerWidget {
  const TeamScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamsAsync = ref.watch(teamViewModelProvider);

    return teamsAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('팀')),
        body: const MoniqLoadingView(),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('팀')),
        body: MoniqErrorView(
          message: '팀 정보를 불러올 수 없습니다',
          onRetry: () => ref.read(teamViewModelProvider.notifier).refresh(),
        ),
      ),
      data: (teams) {
        if (teams.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('팀')),
            body: MoniqEmptyState(
              icon: Icons.groups_outlined,
              character: CharacterType.orange,
              message: '아직 참여한 팀이 없어요',
              description: '팀을 만들거나 초대 코드로 참여해보세요',
              actionLabel: '팀 만들기',
              onAction: () => context.push('/teams/create'),
              secondaryActionLabel: '초대 코드로 참여',
              onSecondaryAction: () => context.push('/teams/join'),
            ),
          );
        }

        final favoriteTeamAsync = ref.watch(favoriteTeamProvider);

        return favoriteTeamAsync.when(
          loading: () => Scaffold(
            appBar: AppBar(title: const Text('팀')),
            body: const MoniqLoadingView(),
          ),
          error: (e, _) => Scaffold(
            appBar: AppBar(title: const Text('팀')),
            body: MoniqErrorView(
              message: '즐겨찾기 팀을 불러올 수 없습니다',
              onRetry: () => ref.invalidate(favoriteTeamProvider),
            ),
          ),
          data: (favoriteTeam) {
            if (favoriteTeam == null) {
              return _NoFavoriteView(teams: teams);
            }
            return _TeamCalendarView(team: favoriteTeam, teams: teams);
          },
        );
      },
    );
  }
}

/// 즐겨찾기 팀이 없을 때 — 팀 선택 안내
class _NoFavoriteView extends HookConsumerWidget {
  const _NoFavoriteView({required this.teams});

  final List<TeamModel> teams;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('팀')),
      body: Padding(
        padding: AppSpacing.screenAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '기본 팀을 선택해주세요',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '팀 탭에서 표시할 팀을 선택합니다',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            Expanded(
              child: ListView.separated(
                itemCount: teams.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final team = teams[index];
                  return ListTile(
                    leading: TeamProfileAvatar(
                      icon: team.icon,
                      radius: 20,
                    ),
                    title: Text(team.name),
                    trailing: const Icon(Icons.star_outline),
                    onTap: () async {
                      final teamRepo = ref.read(teamRepositoryProvider);
                      await teamRepo.setFavoriteTeam(team.id);
                      ref.invalidate(favoriteTeamProvider);
                      ref.invalidate(teamViewModelProvider);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 팀 캘린더 메인 뷰
class _TeamCalendarView extends HookConsumerWidget {
  const _TeamCalendarView({required this.team, required this.teams});

  final TeamModel team;
  final List<TeamModel> teams;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendarAsync = ref.watch(teamCalendarViewModelProvider(team.id));
    final calendarStartDay = ref.watch(calendarStartDayProvider);
    final startingDay = calendarStartDay == 'sunday'
        ? StartingDayOfWeek.sunday
        : StartingDayOfWeek.monday;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            TeamProfileAvatar(icon: team.icon, radius: 16),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    team.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(ctx).openEndDrawer(),
            ),
          ),
        ],
      ),
      endDrawer: _TeamDrawer(teams: teams, currentTeamId: team.id, scaffoldContext: context),
      body: calendarAsync.when(
        loading: () => const MoniqLoadingView(),
        error: (e, _) => MoniqErrorView(
          message: '캘린더를 불러올 수 없습니다',
          onRetry: () =>
              ref.invalidate(teamCalendarViewModelProvider(team.id)),
        ),
        data: (state) => SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // View mode toggle
              Center(
                child: ViewModeToggle(
                  currentMode: state.viewMode,
                  onChanged: (_) => ref
                      .read(teamCalendarViewModelProvider(team.id).notifier)
                      .toggleViewMode(),
                ),
              ),

              // Calendar
              MoniqCalendar(
                focusedDay: state.focusedMonth,
                selectedDay: state.selectedDate,
                startingDayOfWeek: startingDay,
                calendarFormat: state.viewMode == CalendarViewMode.month
                    ? CalendarFormat.month
                    : CalendarFormat.week,
                onDaySelected: (selected, focused) {
                  ref
                      .read(teamCalendarViewModelProvider(team.id).notifier)
                      .selectDate(selected);
                },
                onPageChanged: (focused) {
                  ref
                      .read(teamCalendarViewModelProvider(team.id).notifier)
                      .changeMonth(focused);
                },
                eventLoader: (day) {
                  final key = DateTime(day.year, day.month, day.day);
                  return state.monthlyShifts[key] ?? [];
                },
                markerBuilder: (context, day, events) {
                  if (events.isEmpty) return null;
                  final shifts = events.cast<ShiftWithType>();
                  // 고유한 shift type별 도트 표시
                  final uniqueColors = <String, String>{};
                  for (final s in shifts) {
                    uniqueColors[s.shiftType.id] = s.shiftType.color;
                  }
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: uniqueColors.values
                        .take(3)
                        .map((c) => ShiftMarker(color: parseHexColor(c)))
                        .toList(),
                  );
                },
              ),

              const Divider(),

              // Roster panel
              RosterPanel(
                date: state.selectedDate,
                rosterEntries: state.selectedDateRoster,
                teamId: team.id,
              ),

              // 하단 네비게이션 바 겹침 방지
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }
}

/// 우측 Drawer — 팀 메뉴
class _TeamDrawer extends HookConsumerWidget {
  const _TeamDrawer({
    required this.teams,
    required this.currentTeamId,
    required this.scaffoldContext,
  });

  final List<TeamModel> teams;
  final String currentTeamId;
  final BuildContext scaffoldContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentTeam = teams.firstWhere(
      (t) => t.id == currentTeamId,
    );

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: AppSpacing.screenAll,
              child: Text(
                '팀 메뉴',
                style: theme.textTheme.titleLarge,
              ),
            ),
            const Divider(),

            // 현재 즐겨찾는 팀 -> 팀 설정
            ListTile(
              leading: const Icon(Icons.star, color: Colors.amber),
              title: const Text('현재 즐겨찾는 팀'),
              subtitle: Text(
                currentTeam.name,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondaryLight,
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                context.push('/teams/$currentTeamId/detail');
              },
            ),

            // 팀 목록
            ListTile(
              leading: const Icon(Icons.groups_outlined),
              title: const Text('팀 목록'),
              subtitle: Text(
                '${teams.length}개 팀',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondaryLight,
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                context.push('/teams/list');
              },
            ),

            const Divider(),

            // 캘린더 내보내기
            ListTile(
              leading: const Icon(Icons.ios_share_outlined),
              title: const Text('캘린더 내보내기'),
              subtitle: Text(
                '이미지 또는 스프레드시트로 내보내기',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondaryLight,
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                final calendarAsync = ref.read(
                    teamCalendarViewModelProvider(currentTeamId));
                final teamRepo = ref.read(teamRepositoryProvider);
                final ctx = scaffoldContext;
                Navigator.pop(context);
                calendarAsync.whenData((calState) {
                  Future.delayed(const Duration(milliseconds: 300), () {
                    exportTeamCalendarStandalone(ctx, calState, teamRepo);
                  });
                });
              },
            ),

            // Excel 일정 가져오기
            ListTile(
              leading: const Icon(Icons.upload_file_outlined),
              title: const Text('Excel 일정 가져오기'),
              subtitle: Text(
                '엑셀 파일에서 근무 일정 가져오기',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondaryLight,
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                final ctx = scaffoldContext;
                final shiftRepo = ref.read(shiftRepositoryProvider);
                final scheduleRepo = ref.read(scheduleRepositoryProvider);
                final teamRepo = ref.read(teamRepositoryProvider);
                Navigator.pop(context);
                Future.delayed(const Duration(milliseconds: 300), () {
                  importTeamExcel(
                    ctx,
                    teamId: currentTeamId,
                    shiftRepo: shiftRepo,
                    scheduleRepo: scheduleRepo,
                    teamRepo: teamRepo,
                  );
                });
              },
            ),

            // 변경 요청
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: const Text('변경 요청'),
              onTap: () {
                Navigator.pop(context);
                context.push('/teams/$currentTeamId/requests');
              },
            ),
          ],
        ),
      ),
    );
  }
}

