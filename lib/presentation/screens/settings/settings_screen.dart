import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/core/utils/auth_error_utils.dart';
import 'package:moniq/data/providers/auth_providers.dart';
import 'package:moniq/data/providers/settings_providers.dart';
import 'package:moniq/presentation/layout/adaptive_layout.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/theme/app_typography.dart';
import 'package:moniq/presentation/theme/shift_theme.dart';
import 'package:moniq/presentation/viewmodels/auth_viewmodel.dart';
import 'package:moniq/presentation/widgets/common/moniq_app_bar.dart';
import 'package:moniq/presentation/widgets/common/moniq_bottom_sheet.dart';
import 'package:moniq/presentation/widgets/common/moniq_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Refactored Settings screen.
///
/// Fixes from Tone Audit:
///   F1 · Uses MoniqAppBar instead of native AppBar
///   F2 · Profile becomes a shift-themed hero card with the brand character
///   F5 · Logout/delete confirmations use MoniqBottomSheet, not AlertDialog
///   F10 · All radii flow through AppRadius (no hardcoded 12/16/20)
///   F13 · MONIQ ID uses Jakarta Sans 900 + tabular figures (no monospace)
class SettingsScreen extends HookConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLow,
      appBar: AdaptiveLayout.isWide(context)
          ? null
          : const MoniqAppBar(
              title: '내 계정',
              eyebrow: 'MY ACCOUNT',
              showBack: false,
            ),
      body: MaxWidthLayout(
        maxWidth: 680,
        child: ListView(
          padding: const EdgeInsets.only(
            top: AppSpacing.sm,
            // 하단 BottomNavigation(72)과 safe area에 가려지지 않도록 충분히 확보
            bottom: 120,
          ),
          children: const [
            // 프로필 hero — 좌우 패딩 없이 edge-to-edge
            _ShiftThemedProfileHero(),
            SizedBox(height: AppSpacing.xxl),
            // 그 외 섹션은 좌우 패딩 유지
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: _AppSettingsSection(),
            ),
            SizedBox(height: AppSpacing.lg),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: _NotificationsSection(),
            ),
            SizedBox(height: AppSpacing.lg),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: _AccountSection(),
            ),
            SizedBox(height: AppSpacing.lg),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: _InfoSection(),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// F2 FIX · Shift-themed profile hero with brand character
// ═══════════════════════════════════════════════════════

class _ShiftThemedProfileHero extends ConsumerWidget {
  const _ShiftThemedProfileHero();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shift = ref.watch(todayShiftThemeProvider);
    final user = ref.watch(currentUserProvider);
    final meta = user?.userMetadata;
    final name = meta?['display_name'] as String? ?? 'User';
    final avatarUrl = meta?['avatar_url'] as String?;
    final initial = name.isNotEmpty ? name.characters.first.toUpperCase() : 'M';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: AppRadius.borderRadiusLg,
        boxShadow: [
          BoxShadow(
            color: shift.cardColor.withValues(alpha: 0.35),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: AppRadius.borderRadiusLg,
        child: Container(
          color: shift.cardColor,
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Stack(
            children: [
              // 마스코트는 카드 우하단 코너로 살짝 걸쳐서 표시.
              // 카드 높이보다 크면 상단이 잘리므로 사이즈/오프셋을 컴팩트하게.
              Positioned(
                right: -6,
                bottom: -10,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: 0.28,
                    child: Transform.rotate(
                      angle: 0.18,
                      child: Image.asset(
                        shift.characterAsset,
                        width: 96,
                        height: 96,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  _HeroAvatar(
                    url: avatarUrl,
                    initial: initial,
                    onEdit: () => context.go('/settings/profile'),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PROFILE · ${shift.displayName.toUpperCase()}',
                          style: AppTypography.captionSmall.copyWith(
                            color: shift.onPrimary.withValues(alpha: 0.75),
                            letterSpacing: 1.6,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          name,
                          style: AppTypography.headlineLarge.copyWith(
                            color: shift.onPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _MoniqIdPill(
                          userId: user?.id,
                          onColor: shift.onPrimary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroAvatar extends StatelessWidget {
  const _HeroAvatar({
    required this.url,
    required this.initial,
    required this.onEdit,
  });

  final String? url;
  final String initial;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // 그림자가 사각형처럼 보이지 않도록 다크 모드에서도 자연스러운 강도로 유지
    final shadowColor =
        Colors.black.withValues(alpha: isDark ? 0.24 : 0.10);
    // edit 펜 아이콘 — 흰색 배지 위라 항상 어두운 색
    const editIconColor = Color(0xFF1A1A1A);

    final hasImage = url != null && url!.isNotEmpty;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 아바타 본체 — BoxDecoration.image로 원형 클리핑을 결정적으로 보장.
        // (ClipOval + CachedNetworkImage 조합은 일부 케이스에서 사각 잔상이 남는
        //  걸 봤어서 가장 견고한 방식을 사용.)
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            image: hasImage
                ? DecorationImage(
                    image: CachedNetworkImageProvider(url!),
                    fit: BoxFit.cover,
                  )
                : null,
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: 18,
                spreadRadius: -2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: hasImage ? null : _InitialBadge(text: initial),
        ),
        Positioned(
          bottom: -2,
          right: -2,
          child: Material(
            color: Colors.white,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onEdit,
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(
                  Icons.edit_rounded,
                  size: 14,
                  color: editIconColor,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _InitialBadge extends StatelessWidget {
  const _InitialBadge({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        style: AppTypography.displayMedium.copyWith(
          color: const Color(0xFF453900),
          fontWeight: FontWeight.w900,
          fontSize: 28,
        ),
      ),
    );
  }
}

/// F13 fix — MONIQ ID pill without hardcoded monospace font.
class _MoniqIdPill extends StatelessWidget {
  const _MoniqIdPill({required this.userId, required this.onColor});
  final String? userId;
  final Color onColor;

  String _format(String? uid) {
    if (uid == null || uid.length < 6) return 'MQ-000-XXX';
    final h = uid.substring(0, 6).toUpperCase();
    return 'MQ-${h.substring(0, 3)}-${h.substring(3, 6)}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.4),
        borderRadius: AppRadius.borderRadiusFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'MONIQ ID · ',
            style: AppTypography.captionSmall.copyWith(
              color: onColor.withValues(alpha: 0.75),
              letterSpacing: 1.2,
            ),
          ),
          Text(
            _format(userId),
            style: AppTypography.captionSmall.copyWith(
              color: onColor,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// Grouped setting sections (F10 · radius consistency)
// ═══════════════════════════════════════════════════════

/// 설정 카드 배경 — 홈탭 카드와 동일한 시프트 색 틴트.
Color _settingsCardTint(BuildContext context, WidgetRef ref) {
  final shift = ref.watch(todayShiftThemeProvider);
  final isDark = Theme.of(context).colorScheme.brightness == Brightness.dark;
  return shift.primary.withValues(alpha: isDark ? 0.18 : 0.08);
}

class _AppSettingsSection extends ConsumerWidget {
  const _AppSettingsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final startDay = ref.watch(calendarStartDayProvider);
    final fontScale = ref.watch(fontScaleProvider);

    return MoniqGroupedCard(
      backgroundColor: _settingsCardTint(context, ref),
      heading: '앱 설정',
      children: [
        MoniqCardRow(
          icon: Icons.palette_outlined,
          label: '화면 모드',
          subtitle: '시프트에 따라 자동',
          valuePill: switch (themeMode) {
            ThemeMode.light => '라이트',
            ThemeMode.dark => '다크',
            ThemeMode.system => 'Auto',
          },
          onTap: () => _pickThemeMode(context, ref, themeMode),
        ),
        MoniqCardRow(
          icon: Icons.text_fields_rounded,
          label: '글자 크기',
          subtitle: '텍스트 가독성 조절',
          valuePill: '${(fontScale * 100).round()}%',
          onTap: () => _pickFontScale(context, ref, fontScale),
        ),
        MoniqCardRow(
          icon: Icons.calendar_month_outlined,
          label: '주 시작일',
          valuePill: startDay == 'monday' ? '월' : '일',
          onTap: () {
            ref
                .read(calendarStartDayProvider.notifier)
                .setStartDay(startDay == 'monday' ? 'sunday' : 'monday');
          },
        ),
      ],
    );
  }

  Future<void> _pickThemeMode(
    BuildContext ctx,
    WidgetRef ref,
    ThemeMode current,
  ) async {
    await showMoniqBottomSheet<void>(
      context: ctx,
      title: '화면 모드',
      eyebrow: 'APPEARANCE',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final mode in ThemeMode.values)
            MoniqSheetOption(
              icon: switch (mode) {
                ThemeMode.light => Icons.light_mode_outlined,
                ThemeMode.dark => Icons.dark_mode_outlined,
                ThemeMode.system => Icons.brightness_auto_outlined,
              },
              label: switch (mode) {
                ThemeMode.light => '라이트 모드',
                ThemeMode.dark => '다크 모드',
                ThemeMode.system => '시스템 설정을 따라요',
              },
              onTap: () {
                ref.read(themeModeProvider.notifier).setThemeMode(mode);
                Navigator.pop(ctx);
              },
              trailing: current == mode
                  ? Icon(
                      Icons.check_circle_rounded,
                      color: Theme.of(ctx).colorScheme.primary,
                    )
                  : null,
            ),
        ],
      ),
    );
  }

  Future<void> _pickFontScale(
    BuildContext ctx,
    WidgetRef ref,
    double current,
  ) async {
    await showMoniqBottomSheet<void>(
      context: ctx,
      title: '글자 크기',
      eyebrow: 'TEXT SIZE',
      child: _FontScalePicker(initial: current, ref: ref),
    );
  }
}

class _FontScalePicker extends StatefulWidget {
  const _FontScalePicker({required this.initial, required this.ref});
  final double initial;
  final WidgetRef ref;
  @override
  State<_FontScalePicker> createState() => _FontScalePickerState();
}

class _FontScalePickerState extends State<_FontScalePicker> {
  late double v = widget.initial;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '다람쥐는 도토리를 좋아해요',
          textAlign: TextAlign.center,
          style: AppTypography.titleLarge.copyWith(fontSize: 16 * v),
        ),
        const SizedBox(height: AppSpacing.lg),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 6,
            activeTrackColor: cs.primary,
            inactiveTrackColor: cs.surfaceContainerLow,
          ),
          child: Slider(
            min: 0.8,
            max: 1.4,
            divisions: 6,
            value: v,
            label: '${(v * 100).round()}%',
            onChanged: (x) {
              setState(() => v = x);
              widget.ref.read(fontScaleProvider.notifier).setFontScale(x);
            },
          ),
        ),
      ],
    );
  }
}

class _NotificationsSection extends ConsumerWidget {
  const _NotificationsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(notificationEnabledProvider);
    final cs = Theme.of(context).colorScheme;
    return MoniqGroupedCard(
      backgroundColor: _settingsCardTint(context, ref),
      heading: '알림',
      children: [
        MoniqCardRow(
          icon: Icons.notifications_outlined,
          label: '푸시 알림',
          subtitle: '스케줄·요청·공지',
          trailing: Switch.adaptive(
            value: enabled,
            activeTrackColor: cs.primary,
            onChanged: (v) async {
              final n = ref.read(notificationEnabledProvider.notifier);
              v ? await n.enable() : await n.disable();
            },
          ),
        ),
      ],
    );
  }
}

class _AccountSection extends ConsumerWidget {
  const _AccountSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MoniqGroupedCard(
      backgroundColor: _settingsCardTint(context, ref),
      heading: '계정',
      children: [
        MoniqCardRow(
          icon: Icons.person_outline_rounded,
          label: '프로필 편집',
          onTap: () => context.go('/settings/profile'),
        ),
        MoniqCardRow(
          icon: Icons.logout_rounded,
          label: '로그아웃',
          onTap: () => _confirmSignOut(context, ref),
        ),
        MoniqCardRow(
          icon: Icons.delete_forever_rounded,
          label: '계정 삭제',
          destructive: true,
          onTap: () => _confirmDelete(context, ref),
        ),
      ],
    );
  }

  // F5 fix — replaces AlertDialog with a MoniqBottomSheet.
  Future<void> _confirmSignOut(BuildContext ctx, WidgetRef ref) async {
    final ok = await showMoniqConfirmSheet(
      context: ctx,
      title: '로그아웃할까요?',
      eyebrow: 'SIGN OUT',
      message: '언제든 다시 로그인하실 수 있어요.',
      confirmLabel: '로그아웃',
    );
    if (!ok) return;
    try {
      await ref.read(authViewModelProvider.notifier).signOut();
      if (ctx.mounted) ctx.go('/login');
    } catch (error) {
      if (!ctx.mounted) return;
      ScaffoldMessenger.of(
        ctx,
      ).showSnackBar(SnackBar(content: Text(friendlyAuthError(error))));
    }
  }

  Future<void> _confirmDelete(BuildContext ctx, WidgetRef ref) async {
    final ok = await showMoniqConfirmSheet(
      context: ctx,
      title: '정말 탈퇴하시겠어요?',
      eyebrow: 'DELETE ACCOUNT',
      message: '탈퇴하면 되돌릴 수 없어요. 본인이 유일한 관리자인 팀은 먼저 정리해주세요.',
      confirmLabel: '탈퇴하기',
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(authViewModelProvider.notifier).deleteAccount();
      if (ctx.mounted) ctx.go('/login');
    } catch (e) {
      if (!ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(switch (e) {
            AuthException() => e.message,
            PostgrestException() => e.message,
            _ => '탈퇴에 실패했어요. 잠시 후 다시 시도해주세요.',
          }),
        ),
      );
    }
  }
}

class _InfoSection extends ConsumerWidget {
  const _InfoSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MoniqGroupedCard(
      backgroundColor: _settingsCardTint(context, ref),
      heading: '정보',
      children: [
        MoniqCardRow(
          icon: Icons.privacy_tip_outlined,
          label: '개인정보 처리방침',
          onTap: () {},
        ),
        const MoniqCardRow(
          icon: Icons.info_outline_rounded,
          label: '앱 버전',
          valuePill: '1.0.0',
        ),
      ],
    );
  }
}
