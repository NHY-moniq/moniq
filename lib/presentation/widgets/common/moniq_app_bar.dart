import 'package:flutter/material.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/theme/app_typography.dart';

/// Unified app bar for all Moniq screens.
///
/// Replaces the inconsistent mix of native `AppBar(title: Text(...))`,
/// Home's custom avatar row, and Calendar's double-title approach.
///
/// Visual anatomy:
///   ┌───────────────────────────────────────┐
///   │  ← │ MONIQ ID · EYEBROW            🔔 │   ← eyebrow row (optional)
///   │  ← │ Screen Title                  🔔 │   ← title row
///   └───────────────────────────────────────┘
///
/// Usage:
/// ```dart
/// MoniqAppBar(
///   title: '알림함',
///   eyebrow: 'HELLO, JOY',
///   onLeadingTap: () => context.pop(),
///   trailing: MoniqAppBarAction(
///     icon: Icons.done_all,
///     label: '모두 읽음',
///     onTap: markAllRead,
///   ),
/// )
/// ```
class MoniqAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const MoniqAppBar({
    super.key,
    required this.title,
    this.eyebrow,
    this.leading,
    this.onLeadingTap,
    this.trailing,
    this.backgroundColor,
    this.showBack = true,
    this.onTitleTap,
    this.titleTrailing,
  });

  /// Screen title — 800 weight, 20-22px.
  final String title;

  /// Optional small uppercase line above the title (e.g. "HELLO, JOY").
  /// Matches the design system's caption-small token.
  final String? eyebrow;

  /// Custom leading widget. If null and [showBack] is true, renders
  /// a pill-style back button that calls [onLeadingTap].
  final Widget? leading;

  /// Called when the default back button is tapped.
  /// Defaults to `Navigator.maybePop`.
  final VoidCallback? onLeadingTap;

  /// Right-side action — usually a single [MoniqAppBarAction].
  final Widget? trailing;

  /// Background color. Defaults to `Scaffold`'s background for a flush look.
  final Color? backgroundColor;

  /// Whether the automatic back button is shown when no [leading] is provided.
  final bool showBack;

  /// 제목을 탭했을 때 호출. 지정 시 제목이 InkWell 로 감싸지며 우측에
  /// 작은 chevron 아이콘이 추가된다 (드롭다운 affordance).
  final VoidCallback? onTitleTap;

  /// 제목 우측에 작은 chevron 등 추가 위젯을 표시. onTitleTap 사용 시
  /// 기본값으로 arrow_drop_down 아이콘이 자동 추가된다.
  final Widget? titleTrailing;

  @override
  Size get preferredSize =>
      Size.fromHeight(eyebrow != null ? 72 : 56);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasEyebrow = eyebrow != null && eyebrow!.isNotEmpty;

    Widget? resolvedLeading = leading;
    if (resolvedLeading == null && showBack && Navigator.of(context).canPop()) {
      resolvedLeading = _BackPill(
        onTap: onLeadingTap ?? () => Navigator.of(context).maybePop(),
      );
    }

    return Material(
      color: backgroundColor ?? Colors.transparent,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (resolvedLeading != null) ...[
                resolvedLeading,
                const SizedBox(width: AppSpacing.sm),
              ] else
                const SizedBox(width: AppSpacing.md),
              Expanded(
                child: () {
                  final titleColumn = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasEyebrow)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            eyebrow!,
                            style: AppTypography.captionSmall.copyWith(
                              color: cs.onSurfaceVariant,
                              letterSpacing: 1.8,
                            ),
                          ),
                        ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: AppTypography.headlineMedium.copyWith(
                                color: cs.onSurface,
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (titleTrailing != null) ...[
                            const SizedBox(width: 4),
                            titleTrailing!,
                          ] else if (onTitleTap != null) ...[
                            const SizedBox(width: 2),
                            Icon(
                              Icons.arrow_drop_down_rounded,
                              size: 24,
                              color: cs.onSurfaceVariant,
                            ),
                          ],
                        ],
                      ),
                    ],
                  );
                  if (onTitleTap == null) return titleColumn;
                  return InkWell(
                    onTap: onTitleTap,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      child: titleColumn,
                    ),
                  );
                }(),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact action for use in [MoniqAppBar.trailing].
///
/// Renders as either an icon-only pill button or a label+icon pill,
/// always circular-pill to match the design system.
class MoniqAppBarAction extends StatelessWidget {
  const MoniqAppBarAction({
    super.key,
    required this.icon,
    required this.onTap,
    this.label,
    this.badgeCount,
    this.tint,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? label;
  final int? badgeCount;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = tint ?? cs.onSurface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.borderRadiusFull,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal:
                label == null ? AppSpacing.sm : AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, size: 22, color: color),
                  if (badgeCount != null && badgeCount! > 0)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                        ),
                        decoration: BoxDecoration(
                          color: cs.error,
                          shape: badgeCount! > 9
                              ? BoxShape.rectangle
                              : BoxShape.circle,
                          borderRadius: badgeCount! > 9
                              ? AppRadius.borderRadiusFull
                              : null,
                        ),
                        child: Text(
                          badgeCount! > 99
                              ? '99+'
                              : '$badgeCount',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              if (label != null) ...[
                const SizedBox(width: AppSpacing.xs),
                Text(
                  label!,
                  style: AppTypography.labelMedium.copyWith(
                    color: color,
                    fontSize: 12,
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

class _BackPill extends StatelessWidget {
  const _BackPill({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.borderRadiusFull,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: AppRadius.borderRadiusFull,
          ),
          child: Icon(
            Icons.arrow_back_rounded,
            size: 20,
            color: cs.onSurface,
          ),
        ),
      ),
    );
  }
}
