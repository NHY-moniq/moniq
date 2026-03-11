import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/core/utils/color_utils.dart';
import 'package:moniq/data/models/shift_with_type.dart';
import 'package:moniq/data/models/team_model.dart';
import 'package:moniq/data/providers/team_providers.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/team_calendar_viewmodel.dart';
import 'package:moniq/presentation/viewmodels/team_viewmodel.dart';
import 'package:moniq/presentation/widgets/calendar/moniq_calendar.dart';
import 'package:moniq/presentation/widgets/calendar/roster_panel.dart';
import 'package:moniq/presentation/widgets/calendar/shift_marker.dart';
import 'package:moniq/presentation/widgets/calendar/view_mode_toggle.dart';
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
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      child: Icon(
                        _teamIcon(team.icon),
                        color: AppColors.primary,
                      ),
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

    return Scaffold(
      appBar: AppBar(
        title: Text(team.name),
        actions: [
          Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(ctx).openEndDrawer(),
            ),
          ),
        ],
      ),
      endDrawer: _TeamDrawer(teams: teams, currentTeamId: team.id),
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 우측 Drawer — 팀 메뉴
class _TeamDrawer extends HookConsumerWidget {
  const _TeamDrawer({required this.teams, required this.currentTeamId});

  final List<TeamModel> teams;
  final String currentTeamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

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

            // 팀 전환
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: const Text('팀 전환'),
              subtitle: Text(
                '현재: ${teams.firstWhere((t) => t.id == currentTeamId).name}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondaryLight,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _showTeamSwitcher(context, ref);
              },
            ),

            // 팀 관리
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('팀 관리'),
              onTap: () {
                Navigator.pop(context);
                context.push('/teams/$currentTeamId/detail');
              },
            ),

            const Divider(),

            // 변경 요청 (Phase 5)
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: const Text('변경 요청'),
              enabled: false,
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }

  void _showTeamSwitcher(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
              child: Text(
                '팀 전환',
                style: Theme.of(ctx)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            ...teams.map((team) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor: team.id == currentTeamId
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : AppColors.textSecondaryLight.withValues(alpha: 0.1),
                    child: Icon(
                      _teamIcon(team.icon),
                      color: team.id == currentTeamId
                          ? AppColors.primary
                          : AppColors.textSecondaryLight,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    team.name,
                    style: TextStyle(
                      fontWeight: team.id == currentTeamId
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  trailing: team.id == currentTeamId
                      ? const Icon(Icons.check_circle,
                          color: AppColors.primary)
                      : null,
                  onTap: () async {
                    if (team.id == currentTeamId) {
                      Navigator.pop(ctx);
                      return;
                    }
                    final teamRepo = ref.read(teamRepositoryProvider);
                    await teamRepo.setFavoriteTeam(team.id);
                    ref.invalidate(favoriteTeamProvider);
                    ref.invalidate(teamViewModelProvider);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                )),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}

IconData _teamIcon(String? icon) {
  switch (icon) {
    case 'local_hospital':
      return Icons.local_hospital;
    case 'business':
      return Icons.business;
    case 'school':
      return Icons.school;
    case 'store':
      return Icons.store;
    case 'engineering':
      return Icons.engineering;
    case 'groups':
    default:
      return Icons.groups;
  }
}
