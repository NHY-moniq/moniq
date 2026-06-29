import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/core/utils/color_utils.dart';
import 'package:moniq/core/utils/team_icon_utils.dart';
import 'package:moniq/data/models/shift_with_type.dart';
import 'package:moniq/data/models/team_model.dart';
import 'package:moniq/data/providers/team_providers.dart';
import 'package:moniq/presentation/widgets/common/moniq_app_bar.dart';
import 'package:moniq/presentation/widgets/common/moniq_bottom_sheet.dart';
import 'package:moniq/presentation/layout/adaptive_layout.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/team_calendar_viewmodel.dart';
import 'package:moniq/presentation/viewmodels/team_viewmodel.dart';
import 'package:moniq/presentation/widgets/calendar/moniq_calendar.dart';
import 'package:moniq/presentation/widgets/calendar/roster_panel.dart';
import 'package:moniq/presentation/widgets/calendar/view_mode_toggle.dart';
import 'package:moniq/presentation/screens/calendar/calendar_export.dart';
import 'package:moniq/presentation/screens/calendar/calendar_providers.dart';
import 'package:moniq/presentation/viewmodels/home_viewmodel.dart';
import 'package:moniq/data/providers/settings_providers.dart';
import 'package:moniq/presentation/widgets/common/moniq_empty_state.dart';
import 'package:moniq/presentation/widgets/common/moniq_error_view.dart';
import 'package:moniq/presentation/widgets/common/moniq_loading_view.dart';
import 'package:moniq/presentation/screens/team/appointment_management_screen.dart';
import 'package:moniq/presentation/screens/team/personal_team_calendar_screen.dart';
import 'package:moniq/presentation/viewmodels/personal_team_calendar_viewmodel.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:moniq/presentation/router/bottom_sheet_visibility_provider.dart';

class TeamScreen extends HookConsumerWidget {
  const TeamScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 두 provider 동시에 watch — 순차 로딩 없음
    final teamsAsync = ref.watch(teamViewModelProvider);
    final favoriteTeamAsync = ref.watch(favoriteTeamProvider);
    final viewingTeamIdOverride = ref.watch(viewingTeamIdOverrideProvider);

    if (favoriteTeamAsync.isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
        appBar: AdaptiveLayout.isWide(context)
            ? null
            : const MoniqAppBar(title: '팀', showBack: false),
        body: const MoniqLoadingView(),
      );
    }

    if (favoriteTeamAsync.hasError) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
        appBar: AdaptiveLayout.isWide(context)
            ? null
            : const MoniqAppBar(title: '팀', showBack: false),
        body: MoniqErrorView(
          message: '팀 정보를 불러올 수 없습니다',
          onRetry: () {
            ref.invalidate(favoriteTeamProvider);
            ref.read(teamViewModelProvider.notifier).refresh();
          },
        ),
      );
    }

    final favoriteTeam = favoriteTeamAsync.valueOrNull;

    final canRenderOverrideTeam =
        viewingTeamIdOverride != null &&
        (teamsAsync.valueOrNull?.isNotEmpty ?? false);

    // 즐겨찾기 팀이 있거나 사용자가 팀 피커로 임시 전환한 경우 바로 캘린더 렌더링.
    if (favoriteTeam != null || canRenderOverrideTeam) {
      final teams = teamsAsync.valueOrNull ?? [favoriteTeam!];
      final viewingTeam = viewingTeamIdOverride == null
          ? favoriteTeam!
          : teams.firstWhere(
              (t) => t.id == viewingTeamIdOverride,
              orElse: () => favoriteTeam ?? teams.first,
            );
      return viewingTeam.teamType == 'personal'
          ? _PersonalTeamCalendarView(team: viewingTeam, teams: teams)
          : _TeamCalendarView(team: viewingTeam, teams: teams);
    }

    // 즐겨찾기가 없으면 팀 목록이 필요함
    if (favoriteTeam == null && teamsAsync.isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
        appBar: AdaptiveLayout.isWide(context)
            ? null
            : const MoniqAppBar(title: '팀', showBack: false),
        body: const MoniqLoadingView(),
      );
    }

    if (favoriteTeam == null && teamsAsync.hasError) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
        appBar: AdaptiveLayout.isWide(context)
            ? null
            : const MoniqAppBar(title: '팀', showBack: false),
        body: MoniqErrorView(
          message: '팀 목록을 불러올 수 없습니다',
          onRetry: () => ref.read(teamViewModelProvider.notifier).refresh(),
        ),
      );
    }

    final teams =
        teamsAsync.valueOrNull ??
        (favoriteTeam != null ? [favoriteTeam] : <TeamModel>[]);

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

    // favoriteTeam이 null이면 안내 뷰. (favoriteTeam!=null은 위에서 이미 반환)
    return _NoFavoriteView(teams: teams);
  }
}

/// 즐겨찾기 팀이 없을 때 — 팀 선택 안내
class _NoFavoriteView extends HookConsumerWidget {
  const _NoFavoriteView({required this.teams});

  final List<TeamModel> teams;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLow,
      appBar: AdaptiveLayout.isWide(context)
          ? null
          : const MoniqAppBar(title: '팀', showBack: false),
      body: ListView(
        padding: AppSpacing.screenAll,
        children: [
          const _NoFavoriteHeader(),
          const SizedBox(height: AppSpacing.xxl),
          ...List.generate(teams.length, (index) {
            final team = teams[index];
            final isPersonal = team.teamType == 'personal';
            return Padding(
              padding: EdgeInsets.only(
                bottom: index == teams.length - 1 ? 0 : AppSpacing.sm,
              ),
              child: _NoFavoriteTeamTile(
                team: team,
                isPersonal: isPersonal,
                onTap: () async {
                  if (isPersonal) {
                    ref.read(viewingTeamIdOverrideProvider.notifier).state =
                        team.id;
                    return;
                  }
                  final teamRepo = ref.read(teamRepositoryProvider);
                  await teamRepo.setFavoriteTeam(team.id);
                  ref.read(viewingTeamIdOverrideProvider.notifier).state = null;
                  ref.invalidate(favoriteTeamProvider);
                  ref.invalidate(favoriteTeamShiftTypesProvider);
                  ref.invalidate(homeViewModelProvider);
                  ref.invalidate(teamViewModelProvider);
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// 즐겨찾기 미설정 안내 — 친근한 일러스트 헤더 카드.
class _NoFavoriteHeader extends StatelessWidget {
  const _NoFavoriteHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.xxl,
        AppSpacing.xxl,
        AppSpacing.xl,
      ),
      decoration: BoxDecoration(
        borderRadius: AppRadius.borderRadiusLg,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.brandOrange.withValues(alpha: 0.14),
            cs.primary.withValues(alpha: 0.08),
          ],
        ),
        border: Border.all(color: cs.primary.withValues(alpha: 0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.surface.withValues(alpha: 0.7),
            ),
            alignment: Alignment.center,
            child: Image.asset(
              'assets/images/orange.png',
              width: 56,
              height: 56,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '기본으로 볼 팀을 골라주세요',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '선택한 팀이 팀 탭에 가장 먼저 보여요 ✨',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 팀 선택 타일 — 부드러운 InkWell 하이라이트의 카드형 행.
class _NoFavoriteTeamTile extends StatelessWidget {
  const _NoFavoriteTeamTile({
    required this.team,
    required this.isPersonal,
    required this.onTap,
  });

  final TeamModel team;
  final bool isPersonal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Material(
      color: cs.surface,
      borderRadius: AppRadius.borderRadiusMd,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: AppRadius.borderRadiusMd,
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              TeamProfileAvatar(icon: team.icon, radius: 22),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      team.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (isPersonal) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        '개인',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (isPersonal)
                Icon(
                  Icons.chevron_right_rounded,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                )
              else
                _SelectChip(cs: cs),
            ],
          ),
        ),
      ),
    );
  }
}

/// 공개 팀 우측의 '기본으로' 선택 칩.
class _SelectChip extends StatelessWidget {
  const _SelectChip({required this.cs});

  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.12),
        borderRadius: AppRadius.borderRadiusFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: 14, color: cs.secondary),
          const SizedBox(width: AppSpacing.xs),
          Text(
            '기본으로',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// 팀 캘린더 상단 팀명 탭 → 본인 속한 팀 목록 바텀시트.
/// 선택한 팀을 즐겨찾기로 설정해 즉시 캘린더가 해당 팀으로 전환된다.
/// 현재 즐겨찾기 팀에는 별 아이콘으로 표시한다.
void _showTeamPickerSheet(
  BuildContext context, {
  required WidgetRef ref,
  required List<TeamModel> teams,
  required String currentTeamId,
  String? favoriteTeamId,
}) {
  // 로그아웃 등 다른 시트와 동일한 MoniqBottomSheetShell 스타일로 통일.
  showMoniqBottomSheet<void>(
    context: context,
    eyebrow: 'TEAM',
    title: '팀 선택',
    child: Builder(
      builder: (ctx) {
                    // 조직(public) / 개인(private) 그룹핑
                    // 조직 팀: 즐겨찾기를 가장 상단으로
                    final orgTeams = teams
                        .where((t) => t.teamType != 'personal')
                        .toList();
                    orgTeams.sort((a, b) {
                      if (a.id == favoriteTeamId) return -1;
                      if (b.id == favoriteTeamId) return 1;
                      return 0;
                    });
                    final personalTeams = teams
                        .where((t) => t.teamType == 'personal')
                        .toList();

                    Widget tileFor(TeamModel t) {
                      final selected = t.id == currentTeamId;
                      final isFavorite = t.id == favoriteTeamId;
                      return _TeamPickerTile(
                        team: t,
                        selected: selected,
                        isFavorite: isFavorite,
                        onTap: selected
                            ? () => Navigator.pop(ctx)
                            : () {
                                Navigator.pop(ctx);
                                ref
                                    .read(
                                      viewingTeamIdOverrideProvider.notifier,
                                    )
                                    .state = t
                                    .id;
                              },
                      );
                    }

                    return ListView(
                      shrinkWrap: true,
                      children: [
                        if (orgTeams.isNotEmpty) ...[
                          _TeamPickerSectionHeader(
                            label: '조직',
                            subLabel: 'Public',
                            icon: Icons.groups_rounded,
                          ),
                          ...orgTeams.map(
                            (t) => Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.xs,
                              ),
                              child: tileFor(t),
                            ),
                          ),
                        ],
                        if (orgTeams.isNotEmpty && personalTeams.isNotEmpty)
                          const SizedBox(height: AppSpacing.md),
                        if (personalTeams.isNotEmpty) ...[
                          _TeamPickerSectionHeader(
                            label: '개인',
                            subLabel: 'Private',
                            icon: Icons.lock_outline_rounded,
                          ),
                          ...personalTeams.map(
                            (t) => Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.xs,
                              ),
                              child: tileFor(t),
                            ),
                          ),
                        ],
                      ],
                    );
      },
    ),
  );
}

/// 팀 선택 바텀시트의 단일 행.
/// - selected: primary outline + tonal background + trailing check
/// - isFavorite: subtitle 라인의 작은 별 + "기본 팀" 캡션 (inline 별 제거)
/// - selected & favorite 둘 다인 경우: selected 톤 우선, 캡션도 함께 노출
/// 팀 피커 섹션 헤더 — 조직(Public) / 개인(Private) 구분.
class _TeamPickerSectionHeader extends StatelessWidget {
  const _TeamPickerSectionHeader({
    required this.label,
    required this.subLabel,
    required this.icon,
  });

  final String label;
  final String subLabel;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        AppSpacing.xs,
        AppSpacing.xs,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: cs.onSurfaceVariant),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            subLabel,
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamPickerTile extends StatelessWidget {
  const _TeamPickerTile({
    required this.team,
    required this.selected,
    required this.isFavorite,
    required this.onTap,
  });

  final TeamModel team;
  final bool selected;
  final bool isFavorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // 비선택 행은 테두리 없이 plain — 선택된 행만 primary outline 강조
    final bgColor = selected
        ? cs.primary.withValues(alpha: 0.06)
        : Colors.transparent;

    final titleColor = selected ? cs.primary : cs.onSurface;
    final titleWeight = selected ? FontWeight.w800 : FontWeight.w600;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Ink(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: selected ? Border.all(color: cs.primary, width: 1.5) : null,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                TeamProfileAvatar(icon: team.icon, radius: 20),
                const SizedBox(width: AppSpacing.md),
                // 팀명 + 우측 inline "기본 팀" 뱃지
                Flexible(
                  child: Text(
                    team.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: titleWeight,
                      color: titleColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isFavorite) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Icon(Icons.star_rounded, size: 16, color: cs.secondary),
                ],
              ],
            ),
          ),
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
    // 더블탭 감지용 — 마지막 탭한 날짜 + 시각.
    final lastTap = useState<({DateTime day, int at})?>(null);
    final scrollCtrl = useScrollController();
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      appBar: MoniqAppBar(
        title: team.name,
        eyebrow: team.teamType == 'personal' ? 'PRIVATE TEAM' : 'PUBLIC TEAM',
        showBack: false,
        onTitleTap: teams.length > 1
            ? () => _showTeamPickerSheet(
                context,
                ref: ref,
                teams: teams,
                currentTeamId: team.id,
                favoriteTeamId: ref.read(favoriteTeamProvider).valueOrNull?.id,
              )
            : null,
        leading: Padding(
          padding: const EdgeInsets.only(left: AppSpacing.sm),
          child: TeamProfileAvatar(icon: team.icon, radius: 16),
        ),
        trailing: !AdaptiveLayout.isWide(context)
            ? Builder(
                builder: (ctx) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 팀 근무표 공유 / 개인 캘린더로 가져오기.
                    if (calendarAsync.valueOrNull != null)
                      MoniqAppBarAction(
                        icon: Icons.ios_share_outlined,
                        onTap: () => exportTeamCalendar(
                          context,
                          ref,
                          calendarAsync.value!,
                        ),
                      ),
                    MoniqAppBarAction(
                      icon: Icons.menu_rounded,
                      onTap: () => Scaffold.of(ctx).openEndDrawer(),
                    ),
                  ],
                ),
              )
            : null,
      ),
      // 햄버거 드로어가 열리면 하단 dock을 숨긴다 (바텀시트와 동일 처리).
      onEndDrawerChanged: (isOpened) {
        final notifier = ref.read(bottomSheetCountProvider.notifier);
        if (isOpened) {
          notifier.increment();
        } else {
          notifier.decrement();
        }
      },
      endDrawer: AdaptiveLayout.isWide(context)
          ? null
          : _TeamDrawer(
              teams: teams,
              currentTeamId: team.id,
              scaffoldContext: context,
            ),
      body: calendarAsync.when(
        loading: () => const MoniqLoadingView(),
        error: (e, _) => MoniqErrorView(
          message: '캘린더를 불러올 수 없습니다',
          onRetry: () => ref.invalidate(teamCalendarViewModelProvider(team.id)),
        ),
        data: (state) => RefreshIndicator(
          onRefresh: () => ref
              .read(teamCalendarViewModelProvider(team.id).notifier)
              .refresh(),
          child: SingleChildScrollView(
            controller: scrollCtrl,
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.sm),
                // Calendar (월/주 토글은 헤더 내부로 흡수됨)
                MoniqCalendar(
                  rowHeight: 80,
                  viewMode: state.viewMode,
                  onViewModeChanged: (_) => ref
                      .read(teamCalendarViewModelProvider(team.id).notifier)
                      .toggleViewMode(),
                  onTodayPressed: () {
                    final today = DateTime.now();
                    final todayDate = DateTime(
                      today.year,
                      today.month,
                      today.day,
                    );
                    ref
                        .read(teamCalendarViewModelProvider(team.id).notifier)
                        .changeMonth(todayDate);
                    ref
                        .read(teamCalendarViewModelProvider(team.id).notifier)
                        .selectDate(todayDate);
                  },
                  legendItems: (() {
                    // ED 등 교육 근무유형은 프리뷰 범례에서 제외하고,
                    // D → E → N → 기타 순으로 정렬해 D/E/N이 항상 앞에 오도록 함.
                    final filtered =
                        state.shiftTypes
                            .where(
                              (st) =>
                                  st.isActive &&
                                  !_isEducation(st.code, st.name),
                            )
                            .toList()
                          ..sort(
                            (a, b) => _legendSortKey(
                              a.code,
                              a.name,
                            ).compareTo(_legendSortKey(b.code, b.name)),
                          );
                    return filtered
                        .map(
                          (st) => (
                            color: parseHexColor(st.color),
                            label: st.code.toUpperCase(),
                          ),
                        )
                        .toList();
                  })(),
                  focusedDay: state.focusedMonth,
                  selectedDay: state.selectedDate,
                  startingDayOfWeek: startingDay,
                  calendarFormat: state.viewMode == CalendarViewMode.month
                      ? CalendarFormat.month
                      : CalendarFormat.week,
                  onDaySelected: (selected, focused) {
                    final nowMs = DateTime.now().millisecondsSinceEpoch;
                    final last = lastTap.value;
                    final sameDay =
                        last != null &&
                        last.day.year == selected.year &&
                        last.day.month == selected.month &&
                        last.day.day == selected.day;
                    final isDouble = sameDay && (nowMs - last.at) < 350;
                    if (isDouble) {
                      final cur = ref.read(dateExpandedProvider);
                      final next = !cur;
                      ref.read(dateExpandedProvider.notifier).state = next;
                      lastTap.value = null;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!scrollCtrl.hasClients) return;
                        final target = next
                            ? scrollCtrl.position.maxScrollExtent
                            : 0.0;
                        scrollCtrl.animateTo(
                          target,
                          duration: const Duration(milliseconds: 320),
                          curve: Curves.easeOutCubic,
                        );
                      });
                    } else {
                      lastTap.value = (day: selected, at: nowMs);
                      ref
                          .read(teamCalendarViewModelProvider(team.id).notifier)
                          .selectDate(selected);
                    }
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
                      ..sort(
                        (a, b) => _shiftSortKey(a).compareTo(_shiftSortKey(b)),
                      );
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: sorted.take(3).map((info) {
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
                                color: Theme.of(context).colorScheme.surface,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),

                const SizedBox(height: AppSpacing.sm),

                // Roster panel — 펼친 상태에서 패널 빈 영역 더블탭 시 접기.
                GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onDoubleTap: () {
                    final cur = ref.read(dateExpandedProvider);
                    if (!cur) return;
                    ref.read(dateExpandedProvider.notifier).state = false;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!scrollCtrl.hasClients) return;
                      scrollCtrl.animateTo(
                        0,
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeOutCubic,
                      );
                    });
                  },
                  child: RosterPanel(
                    date: state.selectedDate,
                    rosterEntries: state.selectedDateRoster,
                    teamId: team.id,
                  ),
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

class _PersonalTeamCalendarView extends HookConsumerWidget {
  const _PersonalTeamCalendarView({required this.team, required this.teams});

  final TeamModel team;
  final List<TeamModel> teams;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(
      personalTeamCalendarViewModelProvider(team.id),
    );

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      appBar: MoniqAppBar(
        title: team.name,
        eyebrow: team.teamType == 'personal' ? 'PRIVATE TEAM' : 'PUBLIC TEAM',
        showBack: false,
        onTitleTap: teams.length > 1
            ? () => _showTeamPickerSheet(
                context,
                ref: ref,
                teams: teams,
                currentTeamId: team.id,
                favoriteTeamId: ref.read(favoriteTeamProvider).valueOrNull?.id,
              )
            : null,
        leading: Padding(
          padding: const EdgeInsets.only(left: AppSpacing.sm),
          child: TeamProfileAvatar(icon: team.icon, radius: 16),
        ),
        trailing: !AdaptiveLayout.isWide(context)
            ? Builder(
                builder: (ctx) => MoniqAppBarAction(
                  icon: Icons.menu_rounded,
                  onTap: () => Scaffold.of(ctx).openEndDrawer(),
                ),
              )
            : null,
      ),
      // 햄버거 드로어가 열리면 하단 dock을 숨긴다 (바텀시트와 동일 처리).
      onEndDrawerChanged: (isOpened) {
        final notifier = ref.read(bottomSheetCountProvider.notifier);
        if (isOpened) {
          notifier.increment();
        } else {
          notifier.decrement();
        }
      },
      endDrawer: AdaptiveLayout.isWide(context)
          ? null
          : _TeamDrawer(
              teams: teams,
              currentTeamId: team.id,
              scaffoldContext: context,
            ),
      body: stateAsync.when(
        loading: () => const MoniqLoadingView(),
        error: (e, _) => MoniqErrorView(
          message: '개인 팀 캘린더를 불러올 수 없습니다',
          onRetry: () =>
              ref.invalidate(personalTeamCalendarViewModelProvider(team.id)),
        ),
        data: (state) => RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(personalTeamCalendarViewModelProvider(team.id)),
          child: PersonalTeamCalendarBody(state: state, teamId: team.id),
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
    final currentTeam = teams.firstWhere((t) => t.id == currentTeamId);
    final isPersonalTeam = currentTeam.teamType == 'personal';

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
                            'TEAM SETTINGS',
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
                    iconColor: AppColors.brandBlue,
                    label: '팀 목록',
                    badge: '${teams.length}',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/teams/list');
                    },
                  ),
                  _TeamDrawerNavItem(
                    icon: Icons.campaign_outlined,
                    label: '팀 공지사항',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/teams/$currentTeamId/announcements');
                    },
                  ),
                  if (isPersonalTeam) ...[
                    _TeamDrawerNavItem(
                      icon: Icons.event_note_rounded,
                      iconColor: const Color(0xFF9F7AEA),
                      label: '약속 관리',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.of(context, rootNavigator: true).push(
                          MaterialPageRoute<void>(
                            builder: (_) => AppointmentManagementScreen(
                              teamId: currentTeamId,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                  if (!isPersonalTeam) ...[
                    _TeamDrawerNavItem(
                      icon: Icons.edit_calendar_outlined,
                      iconColor: const Color(0xFF319795),
                      label: '원티드 입력',
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/teams/$currentTeamId/wanted/entry');
                      },
                    ),
                    _TeamDrawerNavItem(
                      icon: Icons.swap_horiz,
                      iconColor: const Color(0xFFED64A6),
                      label: '근무 변경 요청',
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/teams/$currentTeamId/requests');
                      },
                    ),
                  ],
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
    final accent = iconColor ?? cs.primary;

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
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                // 부드러운 컬러 칩 안에 아이콘 — 개인 드로어와 동일한 톤.
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.13),
                    borderRadius: AppRadius.borderRadiusMd,
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: accent, size: 20),
                ),
                const SizedBox(width: AppSpacing.md),
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

/// 캘린더 범례 정렬 키 — D(0) → E(1) → N(2) → 기타(3)
int _legendSortKey(String code, String name) {
  final c = code.toUpperCase();
  if (c == 'D' || name.contains('데이') || name.toLowerCase().contains('day')) {
    return 0;
  }
  if (c == 'E' || name.contains('이브닝') || name.toLowerCase().contains('eve')) {
    return 1;
  }
  if (c == 'N' ||
      name.contains('나이트') ||
      name.toLowerCase().contains('night')) {
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
