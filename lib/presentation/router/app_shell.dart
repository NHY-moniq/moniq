import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/providers/shift_providers.dart';
import 'package:moniq/data/providers/team_providers.dart';
import 'package:moniq/data/providers/schedule_providers.dart';
import 'package:moniq/presentation/layout/adaptive_layout.dart';
import 'package:moniq/presentation/screens/calendar/calendar_drawer.dart';
import 'package:moniq/presentation/screens/calendar/calendar_export.dart';
import 'package:moniq/presentation/screens/team/team_excel_import.dart';
import 'package:moniq/presentation/screens/team/team_detail_dialogs.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/theme/shift_theme.dart';
import 'package:moniq/presentation/viewmodels/home_viewmodel.dart';
import 'package:moniq/presentation/viewmodels/team_calendar_viewmodel.dart';
import 'package:moniq/presentation/viewmodels/team_detail_viewmodel.dart';

class AppShell extends ConsumerWidget {
  const AppShell({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shiftTheme = ref.watch(todayShiftThemeProvider);

    if (AdaptiveLayout.isWide(context)) {
      return _WebShell(
        navigationShell: navigationShell,
        shiftTheme: shiftTheme,
      );
    }

    return Scaffold(
      body: navigationShell,
      extendBody: true,
      bottomNavigationBar: _FloatingNavBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        shiftTheme: shiftTheme,
      ),
    );
  }
}

// ── 웹 레이아웃: 고정 사이드바 + 호버 시 우측 flyout ──

class _WebShell extends ConsumerStatefulWidget {
  const _WebShell({
    required this.navigationShell,
    required this.shiftTheme,
  });

  final StatefulNavigationShell navigationShell;
  final ShiftThemeData shiftTheme;

  @override
  ConsumerState<_WebShell> createState() => _WebShellState();
}

class _WebShellState extends ConsumerState<_WebShell> {
  bool _hovered = false;

  static const double _sidebarWidth = 220.0;
  static const double _flyoutWidth = 220.0;

  bool get _flyoutVisible => _hovered && _hasContextItems;

  bool get _hasContextItems {
    final idx = widget.navigationShell.currentIndex;
    return idx == 1 || idx == 2;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentIndex = widget.navigationShell.currentIndex;

    return Scaffold(
      body: Row(
        children: [
          // ── 사이드바 + flyout 묶음 ──
          MouseRegion(
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 사이드바: 항상 220px 고정
                Container(
                  width: _sidebarWidth,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    border: Border(
                      right: BorderSide(
                        color: colorScheme.outlineVariant,
                        width: 1,
                      ),
                    ),
                  ),
                  child: _FixedSidebar(
                    currentIndex: currentIndex,
                    shiftTheme: widget.shiftTheme,
                    onTabSelect: (index) => widget.navigationShell.goBranch(
                      index,
                      initialLocation:
                          index == widget.navigationShell.currentIndex,
                    ),
                  ),
                ),

                // 컨텍스트 flyout: hover 시에만 슬라이드
                AnimatedContainer(
                  width: _flyoutVisible ? _flyoutWidth : 0,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeInOut,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainer,
                    border: Border(
                      right: BorderSide(
                        color: colorScheme.outlineVariant,
                        width: 1,
                      ),
                    ),
                  ),
                  child: ClipRect(
                    child: OverflowBox(
                      maxWidth: _flyoutWidth,
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: _flyoutWidth,
                        child: _ContextFlyout(currentIndex: currentIndex),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── 메인 콘텐츠 ──
          Expanded(child: widget.navigationShell),
        ],
      ),
    );
  }
}

// ── 고정 사이드바 ──

class _FixedSidebar extends StatelessWidget {
  const _FixedSidebar({
    required this.currentIndex,
    required this.shiftTheme,
    required this.onTabSelect,
  });

  final int currentIndex;
  final ShiftThemeData shiftTheme;
  final ValueChanged<int> onTabSelect;

  static const _navItems = _NavItem.items;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 로고 영역
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 36,
                  height: 36,
                  errorBuilder: (_, __, ___) =>
                      const SizedBox(width: 36, height: 36),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Moniq',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: colorScheme.primary,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),

        // 구분선
        Divider(
          height: 1,
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
          indent: 16,
          endIndent: 16,
        ),
        const SizedBox(height: 12),

        // 네비게이션 항목
        ...List.generate(_navItems.length, (index) {
          final item = _navItems[index];
          final isActive = index == currentIndex;

          return _SidebarNavTile(
            icon: isActive ? item.activeIcon : item.icon,
            label: item.label,
            isActive: isActive,
            activeColor: shiftTheme.primary,
            onTap: () => onTabSelect(index),
          );
        }),

        const Spacer(),

        // 하단 여백
        const SizedBox(height: 24),
      ],
    );
  }
}

// ── 컨텍스트 flyout 패널 ──

class _ContextFlyout extends ConsumerWidget {
  const _ContextFlyout({required this.currentIndex});
  final int currentIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (currentIndex == 1)
              _CalendarContextItems()
            else if (currentIndex == 2)
              _TeamContextItems(),
          ],
        ),
      ),
    );
  }
}

// ── 캘린더 탭 컨텍스트 항목 ──

class _CalendarContextItems extends ConsumerWidget {
  const _CalendarContextItems();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeState = ref.watch(homeViewModelProvider).valueOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FlyoutSectionLabel(label: '개인 캘린더'),
        _FlyoutTile(
          icon: Icons.schedule_outlined,
          label: '내 근무 유형 설정',
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              shape: const RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
              ),
              builder: (_) => const PersonalShiftTypeSheet(),
            );
          },
        ),
        _FlyoutTile(
          icon: Icons.calendar_month_outlined,
          label: '외부 캘린더 가져오기',
          onTap: () => importDeviceCalendar(context, ref),
        ),
        _FlyoutTile(
          icon: Icons.ios_share_outlined,
          label: '캘린더 내보내기',
          onTap: homeState != null
              ? () => exportCalendar(context, ref, homeState)
              : null,
        ),
      ],
    );
  }
}

// ── 팀 탭 컨텍스트 항목 ──

class _TeamContextItems extends ConsumerWidget {
  const _TeamContextItems();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoriteTeam = ref.watch(favoriteTeamProvider).valueOrNull;
    final teamId = favoriteTeam?.id;

    final isAdmin = teamId != null
        ? (ref
                .watch(teamDetailViewModelProvider(teamId))
                .valueOrNull
                ?.isAdmin ??
            false)
        : false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FlyoutSectionLabel(label: '팀'),
        if (favoriteTeam != null)
          _FlyoutTile(
            icon: Icons.star_rounded,
            label: favoriteTeam.name,
            iconColor: Colors.amber,
            onTap: () => context.push('/teams/${favoriteTeam.id}/detail'),
          ),
        _FlyoutTile(
          icon: Icons.groups_outlined,
          label: '팀 목록',
          onTap: () => context.push('/teams/list'),
        ),
        if (teamId != null) ...[
          const _FlyoutSectionLabel(label: '가져오기 · 내보내기'),
          _FlyoutTile(
            icon: Icons.ios_share_outlined,
            label: '팀 캘린더 내보내기',
            onTap: () async {
              final calAsync =
                  ref.read(teamCalendarViewModelProvider(teamId));
              final teamRepo = ref.read(teamRepositoryProvider);
              calAsync.whenData((calState) {
                Future.delayed(const Duration(milliseconds: 100), () {
                  if (context.mounted) {
                    exportTeamCalendarStandalone(context, calState, teamRepo);
                  }
                });
              });
            },
          ),
          _FlyoutTile(
            icon: Icons.description_outlined,
            label: 'Excel 샘플 양식',
            onTap: () async {
              final shiftRepo = ref.read(shiftRepositoryProvider);
              Future.delayed(const Duration(milliseconds: 100), () {
                if (context.mounted) {
                  exportSampleTemplate(
                    context,
                    shiftRepo: shiftRepo,
                    teamId: teamId,
                  );
                }
              });
            },
          ),
          _FlyoutTile(
            icon: Icons.upload_file_outlined,
            label: 'Excel 일정 가져오기',
            onTap: () async {
              final shiftRepo = ref.read(shiftRepositoryProvider);
              final scheduleRepo = ref.read(scheduleRepositoryProvider);
              final teamRepo = ref.read(teamRepositoryProvider);
              Future.delayed(const Duration(milliseconds: 100), () {
                if (context.mounted) {
                  importTeamExcel(
                    context,
                    teamId: teamId,
                    shiftRepo: shiftRepo,
                    scheduleRepo: scheduleRepo,
                    teamRepo: teamRepo,
                  );
                }
              });
            },
          ),
          const _FlyoutSectionLabel(label: '소통'),
          _FlyoutTile(
            icon: Icons.campaign_outlined,
            label: '팀 공지사항',
            iconColor: AppColors.brandOrange,
            onTap: () => context.push('/teams/$teamId/announcements'),
          ),
          _FlyoutTile(
            icon: Icons.swap_horiz,
            label: '변경 요청',
            onTap: () => context.push('/teams/$teamId/requests'),
          ),
          if (isAdmin) ...[
            const _FlyoutSectionLabel(label: '관리'),
            _FlyoutTile(
              icon: Icons.delete_sweep_outlined,
              label: '일정 전체 삭제',
              iconColor: AppColors.error,
              onTap: () async {
                final state = ref
                    .read(teamDetailViewModelProvider(teamId))
                    .valueOrNull;
                if (state == null) return;
                final scheduleRepo = ref.read(scheduleRepositoryProvider);
                Future.delayed(const Duration(milliseconds: 100), () {
                  if (context.mounted) {
                    showDeleteScheduleSheet(
                      context: context,
                      scheduleRepo: scheduleRepo,
                      teamId: teamId,
                      state: state,
                    );
                  }
                });
              },
            ),
          ],
        ],
      ],
    );
  }
}

// ── 사이드바 네비게이션 타일 ──

class _SidebarNavTile extends StatefulWidget {
  const _SidebarNavTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
    this.activeColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isActive;
  final Color? activeColor;

  @override
  State<_SidebarNavTile> createState() => _SidebarNavTileState();
}

class _SidebarNavTileState extends State<_SidebarNavTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final activeColor = widget.activeColor ?? colorScheme.primary;
    final iconColor = widget.isActive
        ? activeColor
        : _hovered
            ? colorScheme.onSurface.withValues(alpha: 0.75)
            : colorScheme.onSurface.withValues(alpha: 0.5);
    final textColor = widget.isActive
        ? activeColor
        : colorScheme.onSurface.withValues(alpha: 0.75);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: widget.isActive
                  ? activeColor.withValues(alpha: 0.10)
                  : _hovered
                      ? colorScheme.onSurface.withValues(alpha: 0.05)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // 아이콘
                Icon(widget.icon, color: iconColor, size: 20),
                const SizedBox(width: 12),
                // 레이블
                Expanded(
                  child: Text(
                    widget.label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: widget.isActive
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: textColor,
                        ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                // 액티브 인디케이터 도트
                if (widget.isActive)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: activeColor,
                      shape: BoxShape.circle,
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

// ── flyout 패널 타일 ──

class _FlyoutTile extends StatelessWidget {
  const _FlyoutTile({
    required this.icon,
    required this.label,
    this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = iconColor ?? colorScheme.onSurface.withValues(alpha: 0.65);
    final disabled = onTap == null;

    return Opacity(
      opacity: disabled ? 0.45 : 1.0,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          hoverColor: colorScheme.onSurface.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onSurface.withValues(alpha: 0.82),
                        ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
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

class _FlyoutSectionLabel extends StatelessWidget {
  const _FlyoutSectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.38),
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
      ),
    );
  }
}

// ── 모바일 레이아웃: 플로팅 하단 NavBar ──

class _FloatingNavBar extends StatelessWidget {
  const _FloatingNavBar({
    required this.currentIndex,
    required this.onTap,
    required this.shiftTheme,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final ShiftThemeData shiftTheme;

  static const _items = _NavItem.items;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final activeColor = shiftTheme.primary;
    final activeTextColor = shiftTheme.onPrimary;
    final inactiveColor = colorScheme.onSurface.withValues(alpha: 0.6);

    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.2),
                  blurRadius: 35,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_items.length, (index) {
                final item = _items[index];
                final isActive = index == currentIndex;

                return GestureDetector(
                  onTap: () => onTap(index),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: isActive
                        ? BoxDecoration(
                            color: activeColor,
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: [
                              BoxShadow(
                                color: activeColor.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          )
                        : null,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isActive ? item.activeIcon : item.icon,
                          color: isActive ? activeTextColor : inactiveColor,
                          size: 22,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.label.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                            color: isActive ? activeTextColor : inactiveColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;

  static const items = [
    _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: '홈'),
    _NavItem(
      icon: Icons.calendar_month_outlined,
      activeIcon: Icons.calendar_month,
      label: '캘린더',
    ),
    _NavItem(
      icon: Icons.groups_outlined,
      activeIcon: Icons.groups,
      label: '팀',
    ),
    _NavItem(
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings,
      label: '설정',
    ),
  ];
}
