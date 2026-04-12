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

// ── 웹 레이아웃: 고정 사이드바 + 호버 시 우측 컨텍스트 패널 ──

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
  // 터치 기기에서 탭으로 flyout 고정 (hover 미지원 시 사용)
  bool _pinned = false;

  // 사이드바 너비: 축소(아이콘만) / 확장(아이콘+레이블)
  static const double _sidebarCollapsedWidth = 72.0;
  static const double _sidebarWidth = 200.0;
  // 우측 컨텍스트 패널 너비
  static const double _flyoutWidth = 220.0;

  bool get _active => _hovered || _pinned;
  bool get _flyoutVisible => _active && _hasContextItems;

  void _onTabSelect(int index) {
    final hasContext = index == 1 || index == 2;
    setState(() {
      if (hasContext) {
        // 같은 탭 재탭 → toggle, 다른 탭 → 열기
        _pinned = (index == widget.navigationShell.currentIndex)
            ? !_pinned
            : true;
      } else {
        _pinned = false;
      }
    });
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

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
          // ── 사이드바 + 우측 flyout 묶음 ──
          TapRegion(
            onTapOutside: (_) => setState(() => _pinned = false),
            child: MouseRegion(
              onEnter: (_) => setState(() => _hovered = true),
              onExit: (_) => setState(() {
                _hovered = false;
                _pinned = false;
              }),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 사이드바: 기본 아이콘만, hover/탭 시 레이블 포함으로 확장
                  AnimatedContainer(
                      width: _active ? _sidebarWidth : _sidebarCollapsedWidth,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerLow,
                        border: Border(
                          right: BorderSide(
                            color: colorScheme.outlineVariant,
                            width: 1,
                          ),
                        ),
                      ),
                      child: ClipRect(
                        child: OverflowBox(
                          maxWidth: _sidebarWidth,
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            width: _sidebarWidth,
                            child: _FixedSidebar(
                              currentIndex: currentIndex,
                              expanded: _active,
                              shiftTheme: widget.shiftTheme,
                              onTabSelect: _onTabSelect,
                            ),
                          ),
                        ),
                      ),
                  ),

                  // 컨텍스트 flyout (hover 또는 탭 시 오른쪽에 슬라이드)
                  AnimatedContainer(
                    width: _flyoutVisible ? _flyoutWidth : 0,
                  duration: const Duration(milliseconds: 200),
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
          ),

          // ── 메인 콘텐츠 ──
          Expanded(child: widget.navigationShell),
        ],
      ),
    );
  }
}

// ── 고정 사이드바 (아이콘 + 레이블 항상 표시) ──

class _FixedSidebar extends StatelessWidget {
  const _FixedSidebar({
    required this.currentIndex,
    required this.expanded,
    required this.shiftTheme,
    required this.onTabSelect,
  });

  final int currentIndex;
  final bool expanded;
  final ShiftThemeData shiftTheme;
  final ValueChanged<int> onTabSelect;

  static const _navItems = _NavItem.items;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.xl),

        // 로고
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Image.asset(
                'assets/images/logo.png',
                width: 36,
                height: 36,
                errorBuilder: (_, __, ___) =>
                    const SizedBox(width: 36, height: 36),
              ),
              if (expanded) ...[
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Moniq',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: colorScheme.primary,
                      ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.xl),

        // 메인 네비게이션
        ...List.generate(_navItems.length, (index) {
          final item = _navItems[index];
          final isActive = index == currentIndex;
          final activeColor = shiftTheme.primary;
          final inactiveColor = colorScheme.onSurface.withValues(alpha: 0.6);

          return _SidebarNavTile(
            icon: isActive ? item.activeIcon : item.icon,
            label: item.label,
            showLabel: expanded,
            isActive: isActive,
            activeColor: activeColor,
            inactiveColor: inactiveColor,
            onTap: () => onTabSelect(index),
          );
        }),

        const Spacer(),
        const SizedBox(height: AppSpacing.xl),
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

// ── 공통 사이드바 타일 (고정 사이드바용, 항상 레이블 표시) ──

class _SidebarNavTile extends StatelessWidget {
  const _SidebarNavTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.showLabel = true,
    this.isActive = false,
    this.activeColor,
    this.inactiveColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool showLabel;
  final bool isActive;
  final Color? activeColor;
  final Color? inactiveColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveActiveColor = activeColor ?? colorScheme.primary;
    final effectiveInactiveColor =
        inactiveColor ?? colorScheme.onSurface.withValues(alpha: 0.6);
    final iconColor = isActive ? effectiveActiveColor : effectiveInactiveColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: colorScheme.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 22),
              if (showLabel) ...[
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight:
                              isActive ? FontWeight.w700 : FontWeight.w500,
                          color: isActive
                              ? effectiveActiveColor
                              : colorScheme.onSurface.withValues(alpha: 0.85),
                        ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ],
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
    final color = iconColor ?? colorScheme.onSurface.withValues(alpha: 0.7);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: colorScheme.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            children: [
              Icon(icon, color: color, size: 19),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                        color:
                            colorScheme.onSurface.withValues(alpha: 0.85),
                      ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
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
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 2),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.4),
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
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
