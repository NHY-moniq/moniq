import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/presentation/theme/shift_theme.dart';

class AppShell extends ConsumerWidget {
  const AppShell({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shiftTheme = ref.watch(todayShiftThemeProvider);

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

class _FloatingNavBar extends StatelessWidget {
  const _FloatingNavBar({
    required this.currentIndex,
    required this.onTap,
    required this.shiftTheme,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final ShiftThemeData shiftTheme;

  static const _items = [
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final activeColor = shiftTheme.primary;
    final activeTextColor = shiftTheme.onPrimary;
    final inactiveColor = colorScheme.onSurface.withValues(
      alpha: 0.6,
    );

    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh.withValues(
                alpha: 0.8,
              ),
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
                                color: activeColor.withValues(
                                  alpha: 0.3,
                                ),
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
                          color: isActive
                              ? activeTextColor
                              : inactiveColor,
                          size: 22,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.label.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                            color: isActive
                                ? activeTextColor
                                : inactiveColor,
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
}
