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
import 'package:moniq/presentation/layout/adaptive_layout.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/team_calendar_viewmodel.dart';
import 'package:moniq/presentation/viewmodels/team_detail_viewmodel.dart';
import 'package:moniq/presentation/viewmodels/team_viewmodel.dart';
import 'package:moniq/presentation/screens/team/team_detail_dialogs.dart';
import 'package:moniq/presentation/widgets/calendar/moniq_calendar.dart';
import 'package:moniq/presentation/widgets/calendar/roster_panel.dart';
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
    // 두 provider 동시에 watch — 순차 로딩 없음
    final teamsAsync = ref.watch(teamViewModelProvider);
    final favoriteTeamAsync = ref.watch(favoriteTeamProvider);

    if (teamsAsync.isLoading || favoriteTeamAsync.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('팀')),
        body: const MoniqLoadingView(),
      );
    }

    if (teamsAsync.hasError) {
      return Scaffold(
        appBar: AppBar(title: const Text('팀')),
        body: MoniqErrorView(
          message: '팀 정보를 불러올 수 없습니다',
          onRetry: () => ref.read(teamViewModelProvider.notifier).refresh(),
        ),
      );
    }

    if (favoriteTeamAsync.hasError) {
      return Scaffold(
        appBar: AppBar(title: const Text('팀')),
        body: MoniqErrorView(
          message: '즐겨찾기 팀을 불러올 수 없습니다',
          onRetry: () => ref.invalidate(favoriteTeamProvider),
        ),
      );
    }

    final teams = teamsAsync.valueOrNull ?? [];
    final favoriteTeam = favoriteTeamAsync.valueOrNull;

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

    if (favoriteTeam == null) {
      return _NoFavoriteView(teams: teams);
    }

    return _TeamCalendarView(team: favoriteTeam, teams: teams);
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
                color: theme.colorScheme.onSurfaceVariant,
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
          if (!AdaptiveLayout.isWide(context))
            Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(ctx).openEndDrawer(),
              ),
            ),
        ],
      ),
      endDrawer: AdaptiveLayout.isWide(context)
          ? null
          : _TeamDrawer(teams: teams, currentTeamId: team.id, scaffoldContext: context),
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
                  // 근무유형별 인원수 집계
                  final typeCount = <String, _ShiftTypeInfo>{};
                  for (final s in shifts) {
                    final key = s.shiftType.id;
                    typeCount.putIfAbsent(
                      key,
                      () => _ShiftTypeInfo(
                        code: s.shiftType.code,
                        color: s.shiftType.color,
                        count: 0,
                      ),
                    );
                    typeCount[key]!.count++;
                  }
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: typeCount.values
                        .take(3)
                        .map((info) {
                      final color = parseHexColor(info.color);
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
                            '${info.count}',
                            style: TextStyle(
                              fontSize: 6,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context)
                                  .colorScheme
                                  .surface,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),

              const SizedBox(height: AppSpacing.sm),

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

    final teamDetail = ref.watch(teamDetailViewModelProvider(currentTeamId));
    final isAdmin = teamDetail.valueOrNull?.isAdmin ?? false;

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.66,
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: AppSpacing.screenAll,
              child: Text(
                '팀 메뉴',
                style: theme.textTheme.titleLarge,
              ),
            ),

            // ── 팀 ──
            _drawerSection(theme, '팀'),
            _drawerTile(
              icon: Icons.star,
              iconColor: Colors.amber,
              title: '현재 즐겨찾는 팀',
              trailingText: currentTeam.name,
              onTap: () {
                Navigator.pop(context);
                context.push('/teams/$currentTeamId/detail');
              },
            ),
            _drawerTile(
              icon: Icons.groups_outlined,
              title: '팀 목록',
              trailingText: '${teams.length}개',
              onTap: () {
                Navigator.pop(context);
                context.push('/teams/list');
              },
            ),

            // ── 가져오기 / 내보내기 ──
            _drawerSection(theme, '가져오기 · 내보내기'),
            _drawerTile(
              icon: Icons.ios_share_outlined,
              title: '캘린더 내보내기',
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
            _drawerTile(
              icon: Icons.description_outlined,
              title: 'Excel 샘플 양식',
              onTap: () {
                final ctx = scaffoldContext;
                final shiftRepo = ref.read(shiftRepositoryProvider);
                Navigator.pop(context);
                Future.delayed(const Duration(milliseconds: 300), () {
                  exportSampleTemplate(
                    ctx,
                    shiftRepo: shiftRepo,
                    teamId: currentTeamId,
                  );
                });
              },
            ),
            _drawerTile(
              icon: Icons.upload_file_outlined,
              title: 'Excel 일정 가져오기',
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

            // ── 관리 (관리자만) ──
            if (isAdmin) ...[
              _drawerSection(theme, '관리'),
              _drawerTile(
                icon: Icons.delete_sweep_outlined,
                iconColor: AppColors.error,
                title: '일정 전체 삭제',
                onTap: () {
                  final state = teamDetail.valueOrNull;
                  if (state == null) return;
                  final ctx = scaffoldContext;
                  // 드로어 dispose 전에 repo 캡처
                  final scheduleRepo =
                      ref.read(scheduleRepositoryProvider);
                  Navigator.pop(context);
                  Future.delayed(const Duration(milliseconds: 300), () {
                    showDeleteScheduleSheet(
                      context: ctx,
                      scheduleRepo: scheduleRepo,
                      teamId: currentTeamId,
                      state: state,
                    );
                  });
                },
              ),
            ],

            // ── 소통 ──
            _drawerSection(theme, '소통'),
            _drawerTile(
              icon: Icons.campaign_outlined,
              iconColor: AppColors.brandOrange,
              title: '팀 공지사항',
              onTap: () {
                Navigator.pop(context);
                context.push('/teams/$currentTeamId/announcements');
              },
            ),
            _drawerTile(
              icon: Icons.swap_horiz,
              title: '변경 요청',
              onTap: () {
                Navigator.pop(context);
                context.push('/teams/$currentTeamId/requests');
              },
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  Widget _drawerSection(ThemeData theme, String label) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: AppSpacing.xs,
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _drawerTile({
    required IconData icon,
    Color? iconColor,
    required String title,
    String? trailingText,
    required VoidCallback onTap,
  }) {
    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(vertical: -2),
      leading: Icon(icon, color: iconColor, size: 22),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      trailing: trailingText != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  trailingText,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, size: 18),
              ],
            )
          : const Icon(Icons.chevron_right, size: 18),
      onTap: onTap,
    );
  }
}

class _ShiftTypeInfo {
  _ShiftTypeInfo({
    required this.code,
    required this.color,
    required this.count,
  });

  final String code;
  final String color;
  int count;
}

