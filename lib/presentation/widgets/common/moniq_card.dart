import 'package:flutter/material.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/theme/app_typography.dart';

/// Standard content card — enforces AppRadius.lg (24) per design system.
///
/// Fixes F10: eliminates ad-hoc `BorderRadius.circular(12/16/20/24)` scattered
/// through members_widgets, team_detail_widgets, notifications_screen, etc.
///
/// Two variants:
/// - [MoniqCard] — plain content card on `surfaceContainerLowest`
/// - [MoniqGroupedCard] — iOS-style grouped card for settings-type lists,
///   with an optional section heading and auto-dividers between children.
class MoniqCard extends StatelessWidget {
  const MoniqCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.xxl),
    this.onTap,
    this.accentBorderColor,
    this.backgroundColor,
    this.elevated = true,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? accentBorderColor;
  final Color? backgroundColor;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = backgroundColor ?? cs.surfaceContainerLowest;

    final decoration = BoxDecoration(
      color: bg,
      borderRadius: AppRadius.borderRadiusLg,
      border: accentBorderColor != null
          ? Border(
              left: BorderSide(
                color: accentBorderColor!,
                width: 4,
              ),
            )
          : null,
      boxShadow: elevated
          ? [
              BoxShadow(
                color: cs.shadow.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ]
          : null,
    );

    final body = Padding(padding: padding, child: child);

    if (onTap == null) {
      return Container(decoration: decoration, child: body);
    }

    return Material(
      color: Colors.transparent,
      borderRadius: AppRadius.borderRadiusLg,
      child: Ink(
        decoration: decoration,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.borderRadiusLg,
          child: body,
        ),
      ),
    );
  }
}

/// Grouped card for settings-like lists. Children are separated by
/// a thin divider-variant line and wrapped by a common heading+radius.
class MoniqGroupedCard extends StatelessWidget {
  const MoniqGroupedCard({
    super.key,
    required this.children,
    this.heading,
    this.padding = EdgeInsets.zero,
    this.backgroundColor,
  });

  final List<Widget> children;
  final String? heading;
  final EdgeInsets padding;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (heading != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Text(
              heading!.toUpperCase(),
              style: AppTypography.captionSmall.copyWith(
                color: cs.onSurfaceVariant,
                letterSpacing: 1.6,
              ),
            ),
          ),
        Container(
          padding: padding,
          decoration: BoxDecoration(
            color: backgroundColor ??
                cs.surfaceContainerLowest,
            borderRadius: AppRadius.borderRadiusLg,
            boxShadow: [
              BoxShadow(
                color: cs.shadow.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _withDividers(context, children),
          ),
        ),
      ],
    );
  }

  List<Widget> _withDividers(
      BuildContext context, List<Widget> items) {
    if (items.length <= 1) return items;
    final cs = Theme.of(context).colorScheme;
    final out = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      out.add(items[i]);
      if (i != items.length - 1) {
        out.add(
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
            ),
            child: Divider(
              height: 1,
              thickness: 1,
              color: cs.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
        );
      }
    }
    return out;
  }
}

/// Pre-styled row for use inside a [MoniqGroupedCard].
/// Matches the settings Before/After mockup: icon tile + label + sub + value.
class MoniqCardRow extends StatelessWidget {
  const MoniqCardRow({
    super.key,
    required this.icon,
    required this.label,
    this.subtitle,
    this.trailing,
    this.valuePill,
    this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final String? subtitle;

  /// Fully custom trailing widget (e.g. a Switch).
  final Widget? trailing;

  /// Compact pill used for read-only state like "한국어" / "월" / "Auto".
  final String? valuePill;

  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color =
        destructive ? cs.error : cs.onSurface;

    final trailingWidget = trailing ??
        (valuePill != null
            ? _ValuePill(text: valuePill!)
            : Icon(
                Icons.chevron_right_rounded,
                color: cs.onSurfaceVariant,
              ));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.borderRadiusMd,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: destructive
                      ? cs.error.withValues(alpha: 0.1)
                      : cs.surfaceContainerLow,
                  borderRadius: AppRadius.borderRadiusMd,
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTypography.bodyLarge
                          .copyWith(
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: AppTypography.caption
                            .copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              trailingWidget,
            ],
          ),
        ),
      ),
    );
  }
}

class _ValuePill extends StatelessWidget {
  const _ValuePill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: AppRadius.borderRadiusFull,
      ),
      child: Text(
        text,
        style: AppTypography.caption.copyWith(
          fontWeight: FontWeight.w700,
          color: cs.onSurfaceVariant,
        ),
      ),
    );
  }
}
