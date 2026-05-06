import 'package:flutter/foundation.dart' show kIsWeb;
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
import 'package:moniq/presentation/widgets/common/moniq_app_bar.dart';
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
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
        appBar: AdaptiveLayout.isWide(context)
            ? null
            : const MoniqAppBar(title: '팀', showBack: false),
        body: const MoniqLoadingView(),
      );
    }

    if (teamsAsync.hasError) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
        appBar: AdaptiveLayout.isWide(context)
            ? null
            : const MoniqAppBar(title: '팀', showBack: false),
        body: MoniqErrorView(
          message: '팀 정보를 불러올 수 없습니다',
          onRetry: () => ref.read(teamViewModelProvider.notifier).refresh(),
        ),
      );
    }

    if (favoriteTeamAsync.hasError) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
        appBar: AdaptiveLayout.isWide(context)
            ? null
            : const MoniqAppBar(title: '팀', showBack: false),
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
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
        appBar: AdaptiveLayout.isWide(context)
            ? null
            : const MoniqAppBar(title: '팀', showBack: false),
        body: MoniqEmptyState.cheerful(
          title: '아직 참여한 팀이 없어요',
          message: '팀을 만들거나 초대 코드로 참여해보세요',
          action: MoniqEmptyStateAction(
            label: '팀 만들기',
            onTap: () => context.push('/teams/create'),
          ),
          secondaryAction: MoniqEmptyStateAction.outlined(
            label: '초대 코드로 참여',
            onTap: () => context.push('/teams/join'),
          ),
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
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      appBar: AdaptiveLayout.isWide(context)
          ? null
          : const MoniqAppBar(title: '팀', showBack: false),
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
    final isAdmin = ref
            .watch(teamDetailViewModelProvider(team.id))
            .valueOrNull
            ?.isAdmin ??
        false;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      appBar: MoniqAppBar(
              title: team.name,
              eyebrow: 'TEAM',
              showBack: false,
              leading: Padding(
                padding: const EdgeInsets.only(left: AppSpacing.sm),
                child: TeamProfileAvatar(icon: team.icon, radius: 16),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MoniqAppBarAction(
                    icon: Icons.ios_share_outlined,
                    onTap: () {
                      final calState = calendarAsync.valueOrNull;
                      if (calState == null) return;
                      exportTeamCalendar(context, ref, calState);
                    },
                  ),
                  if (isAdmin && kIsWeb && AdaptiveLayout.isWide(context))
                    _ExcelImportMenuButton(teamId: team.id),
                  if (isAdmin)
                    MoniqAppBarAction(
                      icon: Icons.delete_sweep_outlined,
                      tint: AppColors.error,
                      onTap: () {
                        final state = ref
                            .read(teamDetailViewModelProvider(team.id))
                            .valueOrNull;
                        if (state == null) return;
                        final scheduleRepo =
                            ref.read(scheduleRepositoryProvider);
                        showDeleteScheduleSheet(
                          context: context,
                          ref: ref,
                          scheduleRepo: scheduleRepo,
                          teamId: team.id,
                          state: state,
                        );
                      },
                    ),
                  if (!AdaptiveLayout.isWide(context))
                    Builder(
                      builder: (ctx) => MoniqAppBarAction(
                        icon: Icons.menu_rounded,
                        onTap: () => Scaffold.of(ctx).openEndDrawer(),
                      ),
                    ),
                ],
              ),
            ),  // MoniqAppBar
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
        data: (state) => RefreshIndicator(
          onRefresh: () => ref
              .read(teamCalendarViewModelProvider(team.id).notifier)
              .refresh(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
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
                legendItems: state.shiftTypes
                    .where((st) => st.isActive)
                    .map((st) => (
                          color: parseHexColor(st.color),
                          label: st.code.toUpperCase(),
                        ))
                    .toList(),
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
                  // 근무유형별 인원수 집계 (교육은 동그라미 표시에서 제외)
                  final typeCount = <String, _ShiftTypeInfo>{};
                  for (final s in shifts) {
                    if (_isEducation(s.shiftType.code, s.shiftType.name)) {
                      continue;
                    }
                    final key = s.shiftType.id;
                    typeCount.putIfAbsent(
                      key,
                      () => _ShiftTypeInfo(
                        code: s.shiftType.code,
                        name: s.shiftType.name,
                        color: s.shiftType.color,
                        count: 0,
                      ),
                    );
                    typeCount[key]!.count++;
                  }
                  if (typeCount.isEmpty) return null;
                  // 데이 > 이브닝 > 나이트 > 기타(원래순) 순서로 정렬
                  final sorted = typeCount.values.toList()
                    ..sort((a, b) =>
                        _shiftSortKey(a).compareTo(_shiftSortKey(b)));
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: sorted
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

    final cs = theme.colorScheme;

    return Drawer(
      width: 280,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(AppRadius.xl),
          bottomRight: Radius.circular(AppRadius.xl),
        ),
      ),
      elevation: 16,
      child: SafeArea(
        child: Column(
          children: [
            // ── 상단 팀 프로필 (탭 → 팀 설정) — CalendarDrawer 헤더와 같은 여백/타이포 ──
            InkWell(
              onTap: () {
                Navigator.pop(context);
                context.push('/teams/$currentTeamId/detail');
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xxl,
                  AppSpacing.xxxl,
                  AppSpacing.xxl,
                  AppSpacing.lg,
                ),
                child: Row(
                  children: [
                    TeamProfileAvatar(icon: currentTeam.icon, radius: 28),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentTeam.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: cs.primary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            'TEAM MANAGER',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: cs.onSurfaceVariant,
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),

            // ── 네비게이션 ──
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                children: [
                  _TeamDrawerNavItem(
                    icon: Icons.groups_outlined,
                    label: '팀 목록',
                    badge: '${teams.length}',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/teams/list');
                    },
                  ),
                  _TeamDrawerNavItem(
                    icon: Icons.campaign_outlined,
                    iconColor: AppColors.brandOrange,
                    label: '팀 공지사항',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/teams/$currentTeamId/announcements');
                    },
                  ),
                  _TeamDrawerNavItem(
                    icon: Icons.edit_calendar_outlined,
                    label: '원티드 입력',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/teams/$currentTeamId/wanted/entry');
                    },
                  ),
                  _TeamDrawerNavItem(
                    icon: Icons.swap_horiz,
                    label: '변경 요청',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/teams/$currentTeamId/requests');
                    },
                  ),

                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// CalendarDrawer의 _DrawerNavItem과 시각 스펙을 맞춘 팀 드로어 항목.
/// pill 모양 터치 타겟, 아이콘/라벨 간격, 뱃지 스타일을 통일한다.
class _TeamDrawerNavItem extends StatelessWidget {
  const _TeamDrawerNavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.badge,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final resolvedIconColor = iconColor ?? cs.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.borderRadiusFull,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.borderRadiusFull,
          hoverColor: cs.surfaceContainerLow,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                Icon(icon, color: resolvedIconColor, size: 24),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: cs.onSurfaceVariant,
                        ),
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xxs,
                    ),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: AppRadius.borderRadiusFull,
                    ),
                    child: Text(
                      badge!,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: cs.onPrimaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShiftTypeInfo {
  _ShiftTypeInfo({
    required this.code,
    required this.name,
    required this.color,
    required this.count,
  });

  final String code;
  final String name;
  final String color;
  int count;
}

/// 근무유형 정렬 키: 데이(0) → 이브닝(1) → 나이트(2) → 기타(3)
int _shiftSortKey(_ShiftTypeInfo info) {
  final c = info.code.toUpperCase();
  final n = info.name;
  if (c == 'D' || n.contains('데이') || n.toLowerCase().contains('day')) {
    return 0;
  }
  if (c == 'E' || n.contains('이브닝') || n.toLowerCase().contains('eve')) {
    return 1;
  }
  if (c == 'N' || n.contains('나이트') || n.toLowerCase().contains('night')) {
    return 2;
  }
  return 3;
}

/// 교육 근무유형 판별 (캘린더 동그라미 표시 제외용)
bool _isEducation(String code, String name) {
  final c = code.toUpperCase();
  if (c == 'ED' || c == 'EDU') return true;
  if (name.contains('교육')) return true;
  final lower = name.toLowerCase();
  if (lower.contains('education') || lower.contains('training')) return true;
  return false;
}

// ── Excel 가져오기 팝업 버튼 (웹 AppBar 전용) ──

class _ExcelImportMenuButton extends ConsumerWidget {
  const _ExcelImportMenuButton({required this.teamId});

  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      tooltip: 'Excel',
      icon: const Icon(Icons.table_chart_outlined),
      iconSize: 22,
      onSelected: (value) {
        final shiftRepo = ref.read(shiftRepositoryProvider);
        final scheduleRepo = ref.read(scheduleRepositoryProvider);
        final teamRepo = ref.read(teamRepositoryProvider);
        if (value == 'import') {
          importTeamExcel(
            context,
            teamId: teamId,
            shiftRepo: shiftRepo,
            scheduleRepo: scheduleRepo,
            teamRepo: teamRepo,
          );
        } else if (value == 'sample') {
          exportSampleTemplate(
            context,
            shiftRepo: shiftRepo,
            teamId: teamId,
          );
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'import',
          child: Row(
            children: [
              Icon(Icons.upload_file_outlined, size: 18),
              SizedBox(width: 10),
              Text('엑셀로 가져오기'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'sample',
          child: Row(
            children: [
              Icon(Icons.description_outlined, size: 18),
              SizedBox(width: 10),
              Text('샘플 양식 다운로드'),
            ],
          ),
        ),
      ],
    );
  }
}
