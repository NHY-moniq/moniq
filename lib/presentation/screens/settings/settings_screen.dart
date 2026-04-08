import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/providers/auth_providers.dart';
import 'package:moniq/data/providers/settings_providers.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/auth_viewmodel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SettingsScreen extends HookConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLow,
      appBar: AppBar(
        backgroundColor: colorScheme.surfaceContainerLow,
        title: const Text('설정'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl,
          vertical: AppSpacing.sm,
        ),
        children: const [
          _ProfileHeader(),
          SizedBox(height: AppSpacing.xxxl),
          _AppSettingsCard(),
          SizedBox(height: AppSpacing.xxl),
          _NotificationsCard(),
          SizedBox(height: AppSpacing.xxl),
          _AccountCard(),
          SizedBox(height: AppSpacing.xxl),
          _InfoCard(),
          SizedBox(height: AppSpacing.massive),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════
// Profile Header
// ════════════════════════════════════════════════

class _ProfileHeader extends ConsumerWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentUser = ref.watch(currentUserProvider);
    final userMeta = currentUser?.userMetadata;
    final displayName =
        userMeta?['display_name'] as String? ?? 'User';
    final avatarUrl = userMeta?['avatar_url'] as String?;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xxl),
      child: Column(
        children: [
          // Avatar with edit button
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 132,
                height: 132,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.surfaceContainerHighest,
                  border: Border.all(
                    color: colorScheme.surfaceContainerLowest,
                    width: 4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.shadow.withValues(
                        alpha: 0.12,
                      ),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: _buildAvatarContent(
                    context,
                    avatarUrl,
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () => context.go('/settings/profile'),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colorScheme.tertiaryContainer,
                      border: Border.all(
                        color: colorScheme.surfaceContainerLowest,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.shadow.withValues(
                            alpha: 0.15,
                          ),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.edit,
                      size: 18,
                      color: colorScheme.onTertiaryContainer,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Display name
          Text(
            displayName,
            style: Theme.of(context)
                .textTheme
                .displayMedium
                ?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Moniq ID badge
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: AppRadius.borderRadiusFull,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'MONIQ ID:',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.0,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  _generateMoniqId(currentUser?.id),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarContent(
    BuildContext context,
    String? avatarUrl,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: avatarUrl,
        fit: BoxFit.cover,
        width: 132,
        height: 132,
        errorWidget: (_, __, ___) => Icon(
          Icons.person,
          size: 56,
          color: colorScheme.onSurfaceVariant,
        ),
      );
    }
    return Icon(
      Icons.person,
      size: 56,
      color: colorScheme.onSurfaceVariant,
    );
  }

  String _generateMoniqId(String? userId) {
    if (userId == null || userId.length < 6) return 'MQ-000-XXX';
    final hash = userId.substring(0, 6).toUpperCase();
    return 'MQ-${hash.substring(0, 3)}-${hash.substring(3, 6)}';
  }
}

// ════════════════════════════════════════════════
// App Settings Card
// ════════════════════════════════════════════════

class _AppSettingsCard extends ConsumerWidget {
  const _AppSettingsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final themeMode = ref.watch(themeModeProvider);
    final fontScale = ref.watch(fontScaleProvider);
    final calendarStartDay = ref.watch(calendarStartDayProvider);

    return _SettingsCard(
      icon: Icons.settings,
      iconColor: colorScheme.primary,
      title: '앱 설정',
      children: [
        // Theme Toggle
        _SettingsRow(
          label: '화면 모드',
          subtitle: '라이트/다크 모드 전환',
          trailing: _PillToggle(
            options: const ['라이트', '다크'],
            icons: const [Icons.light_mode, Icons.dark_mode],
            selectedIndex:
                themeMode == ThemeMode.dark ? 1 : 0,
            onChanged: (index) {
              final mode = index == 0
                  ? ThemeMode.light
                  : ThemeMode.dark;
              ref
                  .read(themeModeProvider.notifier)
                  .setThemeMode(mode);
            },
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),

        // Font Size Slider
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      '글자 크기',
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '텍스트 가독성 조절',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                            color:
                                colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
                Text(
                  'Aa',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: colorScheme.primary,
                inactiveTrackColor:
                    colorScheme.surfaceContainerLow,
                thumbColor: colorScheme.primary,
                overlayColor:
                    colorScheme.primary.withValues(
                  alpha: 0.12,
                ),
                trackHeight: 12,
                thumbShape: _RoundThumbShape(
                  thumbRadius: 12,
                  borderColor:
                      colorScheme.surfaceContainerLowest,
                ),
              ),
              child: Slider(
                value: fontScale,
                min: 0.8,
                max: 1.4,
                divisions: 6,
                label: '${(fontScale * 100).round()}%',
                onChanged: (value) {
                  ref
                      .read(fontScaleProvider.notifier)
                      .setFontScale(value);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xxl),

        // Calendar Start Day
        _SettingsRow(
          label: '캘린더 시작 요일',
          subtitle: '캘린더 레이아웃 설정',
          trailing: _PillDropdown(
            value: calendarStartDay,
            items: const {
              'monday': '월요일',
              'sunday': '일요일',
            },
            onChanged: (day) {
              ref
                  .read(calendarStartDayProvider.notifier)
                  .setStartDay(day);
            },
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════
// Notifications Card
// ════════════════════════════════════════════════

class _NotificationsCard extends ConsumerWidget {
  const _NotificationsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isEnabled = ref.watch(notificationEnabledProvider);

    return _SettingsCard(
      icon: Icons.notifications,
      iconColor: colorScheme.secondary,
      title: '알림',
      children: [
        _NotificationRow(
          icon: Icons.schedule,
          iconBgColor:
              colorScheme.secondaryContainer.withValues(
            alpha: 0.3,
          ),
          iconColor: colorScheme.secondary,
          label: '근무 알림',
          value: isEnabled,
          activeColor: colorScheme.secondary,
          onChanged: (value) async {
            if (value) {
              await ref
                  .read(
                    notificationEnabledProvider.notifier,
                  )
                  .enable();
            } else {
              await ref
                  .read(
                    notificationEnabledProvider.notifier,
                  )
                  .disable();
            }
          },
        ),
        Divider(
          color: colorScheme.surfaceContainerLow,
          height: 1,
        ),
        _NotificationRow(
          icon: Icons.diversity_3,
          iconBgColor:
              colorScheme.primaryContainer.withValues(
            alpha: 0.3,
          ),
          iconColor: colorScheme.primary,
          label: '팀 업데이트',
          value: isEnabled,
          activeColor: colorScheme.primary,
          onChanged: (value) async {
            if (value) {
              await ref
                  .read(
                    notificationEnabledProvider.notifier,
                  )
                  .enable();
            } else {
              await ref
                  .read(
                    notificationEnabledProvider.notifier,
                  )
                  .disable();
            }
          },
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════
// Account Card
// ════════════════════════════════════════════════

class _AccountCard extends ConsumerWidget {
  const _AccountCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return _SettingsCard(
      icon: Icons.person_outline,
      iconColor: colorScheme.primary,
      title: '계정',
      children: [
        _AccountTile(
          icon: Icons.person_outline,
          label: '프로필',
          onTap: () => context.go('/settings/profile'),
        ),
        Divider(
          color: colorScheme.surfaceContainerLow,
          height: 1,
        ),
        _AccountTile(
          icon: Icons.logout,
          label: '로그아웃',
          onTap: () => _handleSignOut(context, ref),
        ),
        Divider(
          color: colorScheme.surfaceContainerLow,
          height: 1,
        ),
        _AccountTile(
          icon: Icons.delete_forever,
          label: '계정 삭제',
          isDestructive: true,
          onTap: () => _handleDeleteAccount(context, ref),
        ),
      ],
    );
  }

  Future<void> _handleSignOut(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text(
          '정말 로그아웃 하시겠습니까?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref
          .read(authViewModelProvider.notifier)
          .signOut();
      if (context.mounted) {
        context.go('/login');
      }
    }
  }

  Future<void> _handleDeleteAccount(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('계정 삭제'),
        content: const Text(
          '계정을 삭제하면 되돌릴 수 없습니다.\n'
          '계정이 유일한 관리자인 팀에 속해 있다면 삭제할 수 없습니다.\n'
          '정말 삭제하시겠습니까?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              '삭제',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ref
          .read(authViewModelProvider.notifier)
          .deleteAccount();
      if (!context.mounted) return;
      context.go('/login');
    } catch (error) {
      if (!context.mounted) return;

      final message = switch (error) {
        AuthException() => error.message,
        PostgrestException() => error.message,
        _ =>
          '계정 삭제에 실패했습니다. 잠시 후 다시 시도해주세요.',
      };

      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('계정 삭제 실패'),
          content: SelectableText.rich(
            TextSpan(
              text: message,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('확인'),
            ),
          ],
        ),
      );
    }
  }
}

// ════════════════════════════════════════════════
// Info Card
// ════════════════════════════════════════════════

class _InfoCard extends StatelessWidget {
  const _InfoCard();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return _SettingsCard(
      icon: Icons.info_outline,
      iconColor: colorScheme.tertiary,
      title: '정보',
      children: [
        _AccountTile(
          icon: Icons.privacy_tip_outlined,
          label: '개인정보 처리방침',
          onTap: () {},
        ),
        Divider(
          color: colorScheme.surfaceContainerLow,
          height: 1,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.lg,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      colorScheme.surfaceContainerLow,
                ),
                child: Icon(
                  Icons.info_outline,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Text(
                '앱 버전',
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const Spacer(),
              Text(
                '1.0.0',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════
// Shared Components
// ════════════════════════════════════════════════

/// Reusable card wrapper matching design spec
class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxxl),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: AppRadius.borderRadiusXl,
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(
              alpha: 0.06,
            ),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          Row(
            children: [
              Icon(icon, color: iconColor, size: 28),
              const SizedBox(width: AppSpacing.md),
              Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
          ...children,
        ],
      ),
    );
  }
}

/// Settings row with label + subtitle + trailing widget
class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.label,
    required this.subtitle,
    required this.trailing,
  });

  final String label;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        trailing,
      ],
    );
  }
}

/// Pill toggle (Light/Dark style) matching design spec
class _PillToggle extends StatelessWidget {
  const _PillToggle({
    required this.options,
    required this.icons,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<String> options;
  final List<IconData> icons;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: AppRadius.borderRadiusFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < options.length; i++)
            GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: i == selectedIndex
                      ? colorScheme.primary
                      : Colors.transparent,
                  borderRadius: AppRadius.borderRadiusFull,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icons[i],
                      size: 14,
                      color: i == selectedIndex
                          ? colorScheme.onPrimary
                          : colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      options[i].toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: i == selectedIndex
                            ? colorScheme.onPrimary
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Pill-shaped dropdown matching design spec
class _PillDropdown extends StatelessWidget {
  const _PillDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String value;
  final Map<String, String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxl,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: AppRadius.borderRadiusFull,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          icon: Icon(
            Icons.expand_more,
            size: 18,
            color: colorScheme.primary,
          ),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: colorScheme.primary,
          ),
          dropdownColor: colorScheme.surfaceContainerLowest,
          borderRadius: AppRadius.borderRadiusLg,
          items: items.entries.map((entry) {
            return DropdownMenuItem<String>(
              value: entry.key,
              child: Text(entry.value),
            );
          }).toList(),
          onChanged: (day) {
            if (day != null) onChanged(day);
          },
        ),
      ),
    );
  }
}

/// Notification toggle row with icon circle
class _NotificationRow extends StatelessWidget {
  const _NotificationRow({
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.activeColor,
    required this.onChanged,
  });

  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String label;
  final bool value;
  final Color activeColor;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.lg,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconBgColor,
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Switch(
            value: value,
            activeTrackColor: activeColor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// Account list item with icon circle
class _AccountTile extends StatelessWidget {
  const _AccountTile({
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
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color =
        isDestructive ? colorScheme.error : colorScheme.onSurface;

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.borderRadiusMd,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.lg,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDestructive
                    ? colorScheme.error.withValues(
                        alpha: 0.1,
                      )
                    : colorScheme.surfaceContainerLow,
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom round thumb with white border for slider
class _RoundThumbShape extends SliderComponentShape {
  const _RoundThumbShape({
    required this.thumbRadius,
    required this.borderColor,
  });

  final double thumbRadius;
  final Color borderColor;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return Size.fromRadius(thumbRadius);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;

    // Shadow
    canvas.drawCircle(
      center + const Offset(0, 2),
      thumbRadius,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.1)
        ..maskFilter = const MaskFilter.blur(
          BlurStyle.normal,
          4,
        ),
    );

    // White border
    canvas.drawCircle(
      center,
      thumbRadius,
      Paint()..color = borderColor,
    );

    // Thumb fill
    canvas.drawCircle(
      center,
      thumbRadius - 4,
      Paint()..color = sliderTheme.thumbColor ?? Colors.amber,
    );
  }
}
