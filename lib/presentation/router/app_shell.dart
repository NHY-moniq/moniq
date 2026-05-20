import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/core/utils/auth_error_utils.dart';
import 'package:moniq/core/utils/team_icon_utils.dart';
import 'package:moniq/data/models/team_model.dart';
import 'package:moniq/data/providers/auth_providers.dart';
import 'package:moniq/data/providers/notification_providers.dart';
import 'package:moniq/presentation/layout/adaptive_layout.dart';
import 'package:moniq/presentation/router/bottom_sheet_visibility_provider.dart';
import 'package:moniq/presentation/screens/calendar/calendar_drawer.dart';
import 'package:moniq/presentation/screens/calendar/calendar_export.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/theme/shift_theme.dart';
import 'package:moniq/presentation/viewmodels/auth_viewmodel.dart';
import 'package:moniq/presentation/viewmodels/team_calendar_viewmodel.dart';
import 'package:moniq/presentation/viewmodels/team_viewmodel.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

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

    // 모달 바텀시트가 열려 있으면 하단 dock을 슬라이드 아웃한다.
    final sheetOpen = ref.watch(bottomSheetOpenProvider);

    return Scaffold(
      body: navigationShell,
      extendBody: true,
      bottomNavigationBar: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) => SizeTransition(
          sizeFactor: animation,
          axisAlignment: -1,
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: sheetOpen
            ? const SizedBox.shrink(key: ValueKey('dock-hidden'))
            : _FloatingNavBar(
                key: const ValueKey('dock-visible'),
                currentIndex: navigationShell.currentIndex,
                onTap: (index) => navigationShell.goBranch(
                  index,
                  initialLocation:
                      index == navigationShell.currentIndex,
                ),
                shiftTheme: shiftTheme,
              ),
      ),
    );
  }
}

// ── 웹 레이아웃: 고정 사이드바 + 호버 시 우측 flyout ──

class _WebShell extends ConsumerStatefulWidget {
  const _WebShell({required this.navigationShell, required this.shiftTheme});

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
          Expanded(
            child: Column(
              children: [
                _WebTopActionsBar(
                  onBranchSelect: (index) => widget.navigationShell.goBranch(
                    index,
                    initialLocation:
                        index == widget.navigationShell.currentIndex,
                  ),
                ),
                Expanded(child: widget.navigationShell),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WebTopActionsBar extends ConsumerWidget {
  const _WebTopActionsBar({required this.onBranchSelect});

  final ValueChanged<int> onBranchSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final unread = ref.watch(unreadNotificationCountProvider).valueOrNull ?? 0;

    return Container(
      height: 60,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              _SidebarIconButton(
                icon: Icons.notifications_outlined,
                onTap: () => context.push('/notifications'),
              ),
              if (unread > 0)
                Positioned(
                  right: 2,
                  top: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.error,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      unread > 99 ? '99+' : '$unread',
                      style: TextStyle(
                        color: colorScheme.onError,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 6),
          _UserAvatarButton(onBranchSelect: onBranchSelect),
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
        // 로고 영역 (탭 → 홈 탭)
        InkWell(
          onTap: () => onTabSelect(0),
          hoverColor: colorScheme.onSurface.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 8, 16),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset(
                    'assets/icon/app_icon.png',
                    width: 32,
                    height: 32,
                    errorBuilder: (_, __, ___) =>
                        const SizedBox(width: 32, height: 32),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'OnorOff',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: colorScheme.primary,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
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

        // 네비게이션 항목 (홈/캘린더/팀 — 설정 index 3 제외)
        ...List.generate(3, (index) {
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

        _SidebarUserSection(onSettingsTap: () => onTabSelect(3)),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FlyoutCalendarHeader(),
        _FlyoutTile(
          icon: Icons.schedule_outlined,
          label: '내 근무 유형 설정',
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(AppRadius.xl),
                ),
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
      ],
    );
  }
}

class _FlyoutCalendarHeader extends ConsumerWidget {
  const _FlyoutCalendarHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final currentUser = ref.watch(currentUserProvider);
    final userMeta = currentUser?.userMetadata;
    final displayName = userMeta?['display_name'] as String? ?? 'OnorOff';
    final avatarUrl = userMeta?['avatar_url'] as String?;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child: avatarUrl != null && avatarUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: avatarUrl,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Icon(
                      Icons.person_rounded,
                      size: 20,
                      color: cs.onPrimaryContainer,
                    ),
                  )
                : Icon(
                    Icons.person_rounded,
                    size: 20,
                    color: cs.onPrimaryContainer,
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.primary,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                Text(
                  'MY CALENDAR',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontSize: 9,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w600,
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

// ── 팀 탭 컨텍스트 항목 ──

class _TeamContextItems extends ConsumerWidget {
  const _TeamContextItems();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamsAsync = ref.watch(teamViewModelProvider);
    final favoriteAsync = ref.watch(favoriteTeamProvider);
    final favoriteTeam = favoriteAsync.valueOrNull;
    final viewingTeamIdOverride = ref.watch(viewingTeamIdOverrideProvider);
    final teams = teamsAsync.valueOrNull ?? const <TeamModel>[];

    TeamModel? currentTeam;
    if (viewingTeamIdOverride != null) {
      for (final t in teams) {
        if (t.id == viewingTeamIdOverride) {
          currentTeam = t;
          break;
        }
      }
    }
    currentTeam ??= favoriteTeam;
    currentTeam ??= teams.isNotEmpty ? teams.first : null;

    final teamId = currentTeam?.id;
    final isPersonalTeam = currentTeam?.teamType == 'personal';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (currentTeam != null) _FlyoutTeamHeader(team: currentTeam),
        _FlyoutTile(
          icon: Icons.groups_outlined,
          label: '팀 목록',
          onTap: () => context.push('/teams/list'),
        ),
        if (favoriteAsync.isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: LinearProgressIndicator(minHeight: 2),
          )
        else if (teamId != null) ...[
          _FlyoutTile(
            icon: Icons.campaign_outlined,
            label: '팀 공지사항',
            iconColor: AppColors.brandOrange,
            onTap: () => context.push('/teams/$teamId/announcements'),
          ),
          if (isPersonalTeam)
            _FlyoutTile(
              icon: Icons.calendar_today_outlined,
              label: '멤버 근무 현황',
              onTap: () => context.push('/teams/$teamId/personal-calendar'),
            ),
          if (!isPersonalTeam) ...[
            _FlyoutTile(
              icon: Icons.edit_calendar_outlined,
              label: '원티드 입력',
              onTap: () => context.push('/teams/$teamId/wanted/entry'),
            ),
            _FlyoutTile(
              icon: Icons.swap_horiz,
              label: '근무 변경 요청',
              onTap: () => context.push('/teams/$teamId/requests'),
            ),
          ],
        ],
      ],
    );
  }
}

// ── 팀 flyout 헤더 (모바일 드로어 프로필과 동일 스타일) ──

class _FlyoutTeamHeader extends StatelessWidget {
  const _FlyoutTeamHeader({required this.team});

  final TeamModel team;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/teams/${team.id}/detail'),
        hoverColor: cs.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              TeamProfileAvatar(icon: team.icon, radius: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      team.name,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.primary,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    Text(
                      'TEAM SETTINGS',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontSize: 9,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: cs.onSurfaceVariant, size: 16),
            ],
          ),
        ),
      ),
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

// ── 유저 아바타 드롭다운 버튼 ──

class _UserAvatarButton extends ConsumerStatefulWidget {
  const _UserAvatarButton({required this.onBranchSelect});

  final ValueChanged<int> onBranchSelect;

  @override
  ConsumerState<_UserAvatarButton> createState() => _UserAvatarButtonState();
}

class _UserAvatarButtonState extends ConsumerState<_UserAvatarButton>
    with SingleTickerProviderStateMixin {
  final _buttonKey = GlobalKey();
  bool _hovered = false;
  OverlayEntry? _overlayEntry;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _removeOverlay();
    _animController.dispose();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _toggleDropdown() {
    if (_overlayEntry != null) {
      _animController.reverse().then((_) => _removeOverlay());
      return;
    }
    _showDropdown();
  }

  void _showDropdown() {
    final renderBox =
        _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    // Capture the State's context before OverlayEntry builder shadows it.
    final stateContext = context;

    _overlayEntry = OverlayEntry(
      builder: (overlayContext) => Stack(
        children: [
          // 백드롭 탭으로 닫기
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                _animController.reverse().then((_) => _removeOverlay());
                if (mounted) setState(() {});
              },
            ),
          ),
          Positioned(
            top: offset.dy + size.height + 4,
            right:
                MediaQuery.of(overlayContext).size.width -
                offset.dx -
                size.width,
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: _DropdownMenu(
                  mountedContext: stateContext,
                  onClose: () {
                    _animController.reverse().then((_) => _removeOverlay());
                    if (mounted) setState(() {});
                  },
                  onBranchSelect: widget.onBranchSelect,
                  onSignOut: () =>
                      ref.read(authViewModelProvider.notifier).signOut(),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    _animController.forward(from: 0);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final user = ref.watch(currentUserProvider);
    final metadata = user?.userMetadata;
    final avatarUrl = metadata?['avatar_url'] as String?;
    final displayName =
        metadata?['display_name'] as String? ?? user?.email ?? '';
    final initial = displayName.isNotEmpty
        ? displayName[0].toUpperCase()
        : null;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        key: _buttonKey,
        onTap: _toggleDropdown,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: _hovered
                ? colorScheme.onSurface.withValues(alpha: 0.06)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildAvatar(avatarUrl, initial, colorScheme),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: colorScheme.onSurface.withValues(alpha: 0.65),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(
    String? avatarUrl,
    String? initial,
    ColorScheme colorScheme,
  ) {
    return CircleAvatar(
      radius: AppSizing.avatarSm / 2,
      backgroundColor: colorScheme.primaryContainer,
      child: avatarUrl != null && avatarUrl.isNotEmpty
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: avatarUrl,
                width: AppSizing.avatarSm,
                height: AppSizing.avatarSm,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _AvatarFallback(initial: initial),
              ),
            )
          : _AvatarFallback(initial: initial),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({this.initial});
  final String? initial;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (initial != null) {
      return Text(
        initial!,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: colorScheme.onPrimaryContainer,
        ),
      );
    }
    return Icon(
      Icons.person_rounded,
      size: 18,
      color: colorScheme.onPrimaryContainer,
    );
  }
}

class _DropdownMenu extends StatelessWidget {
  const _DropdownMenu({
    required this.mountedContext,
    required this.onClose,
    required this.onBranchSelect,
    required this.onSignOut,
  });

  // Context from the parent ConsumerState — survives after the overlay is removed.
  final BuildContext mountedContext;
  final VoidCallback onClose;
  final ValueChanged<int> onBranchSelect;
  // signOut action using the parent State's ref (not the overlay's ref).
  final Future<void> Function() onSignOut;

  Future<void> _confirmSignOut() async {
    onClose();
    if (!mountedContext.mounted) return;

    final confirmed = await showDialog<bool>(
      context: mountedContext,
      builder: (ctx) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('정말 로그아웃 하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('로그아웃', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mountedContext.mounted) return;

    try {
      await onSignOut();
      // GoRouter redirect handles navigation to /login via authStateChangesProvider.
    } catch (error) {
      if (!mountedContext.mounted) return;
      ScaffoldMessenger.of(
        mountedContext,
      ).showSnackBar(SnackBar(content: Text(friendlyAuthError(error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLowest,
          border: Border.all(color: colorScheme.outlineVariant, width: 1),
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DropdownItem(
              icon: Icons.person_outline_rounded,
              label: '프로필 편집',
              onTap: () {
                onClose();
                context.go('/settings/profile');
              },
            ),
            _DropdownItem(
              icon: Icons.settings_outlined,
              label: '설정',
              onTap: () {
                onClose();
                onBranchSelect(3);
              },
            ),
            Divider(
              height: 1,
              color: colorScheme.outlineVariant.withValues(alpha: 0.6),
            ),
            _DropdownItem(
              icon: Icons.logout_rounded,
              label: '로그아웃',
              isDestructive: true,
              onTap: () => _confirmSignOut(),
            ),
          ],
        ),
      ),
    );
  }
}

class _DropdownItem extends StatefulWidget {
  const _DropdownItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  State<_DropdownItem> createState() => _DropdownItemState();
}

class _DropdownItemState extends State<_DropdownItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = widget.isDestructive
        ? AppColors.error
        : colorScheme.onSurface.withValues(alpha: 0.82);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: _hovered
                ? colorScheme.onSurface.withValues(alpha: 0.06)
                : Colors.transparent,
          ),
          child: Row(
            children: [
              Icon(widget.icon, size: 18, color: color),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 사이드바 아이콘 버튼 (알림 등) ──

class _SidebarIconButton extends StatefulWidget {
  const _SidebarIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_SidebarIconButton> createState() => _SidebarIconButtonState();
}

class _SidebarIconButtonState extends State<_SidebarIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _hovered
                ? cs.onSurface.withValues(alpha: 0.07)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Icon(
            widget.icon,
            size: 18,
            color: cs.onSurface.withValues(alpha: 0.55),
          ),
        ),
      ),
    );
  }
}

// ── 사이드바 하단 유저 섹션 ──

class _SidebarUserSection extends ConsumerStatefulWidget {
  const _SidebarUserSection({required this.onSettingsTap});

  final VoidCallback onSettingsTap;

  @override
  ConsumerState<_SidebarUserSection> createState() =>
      _SidebarUserSectionState();
}

class _SidebarUserSectionState extends ConsumerState<_SidebarUserSection> {
  bool _settingsHovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final metadata = user?.userMetadata;
    final avatarUrl = metadata?['avatar_url'] as String?;
    final displayName =
        metadata?['display_name'] as String? ?? user?.email ?? '';
    final initial = displayName.isNotEmpty
        ? displayName[0].toUpperCase()
        : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Divider(
          height: 1,
          indent: 12,
          endIndent: 12,
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: AppSizing.avatarSm / 2,
                backgroundColor: colorScheme.primaryContainer,
                child: avatarUrl != null && avatarUrl.isNotEmpty
                    ? ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: avatarUrl,
                          width: AppSizing.avatarSm,
                          height: AppSizing.avatarSm,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              _AvatarFallback(initial: initial),
                        ),
                      )
                    : _AvatarFallback(initial: initial),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  displayName,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) => setState(() => _settingsHovered = true),
                onExit: (_) => setState(() => _settingsHovered = false),
                child: GestureDetector(
                  onTap: widget.onSettingsTap,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _settingsHovered
                          ? colorScheme.onSurface.withValues(alpha: 0.06)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                    child: Icon(
                      Icons.settings_outlined,
                      size: 18,
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────

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
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.38),
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
    super.key,
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
    _NavItem(icon: Icons.groups_outlined, activeIcon: Icons.groups, label: '팀'),
    _NavItem(
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings,
      label: '설정',
    ),
  ];
}
