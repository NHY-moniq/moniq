import 'package:flutter/material.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/theme/app_typography.dart';

/// Consistent empty-state illustration for Moniq screens.
///
/// Fixes F3 + F12: all current empty states use Material icons and
/// formal "~합니다" copy. This surfaces the brand characters and
/// conversational "~네요/~보세요" voice.
///
/// Usage:
/// ```dart
/// MoniqEmptyState.peaceful(
///   title: '받은 알림이 없어요',
///   message: '조용한 하루네요 ☕',
///   action: MoniqEmptyStateAction(
///     label: '알림 설정 보기',
///     onTap: () {},
///   ),
/// )
/// ```
class MoniqEmptyState extends StatelessWidget {
  const MoniqEmptyState({
    super.key,
    required this.title,
    required this.message,
    required this.characterAsset,
    this.action,
    this.secondaryAction,
    this.compact = false,
  });

  /// Peaceful / no-content variant — uses the "off" grey character.
  factory MoniqEmptyState.peaceful({
    Key? key,
    required String title,
    required String message,
    MoniqEmptyStateAction? action,
    MoniqEmptyStateAction? secondaryAction,
    bool compact = false,
  }) =>
      MoniqEmptyState(
        key: key,
        title: title,
        message: message,
        characterAsset: 'assets/images/off.png',
        action: action,
        secondaryAction: secondaryAction,
        compact: compact,
      );

  /// Encouraging variant — uses the yellow "day" character.
  factory MoniqEmptyState.encouraging({
    Key? key,
    required String title,
    required String message,
    MoniqEmptyStateAction? action,
    MoniqEmptyStateAction? secondaryAction,
    bool compact = false,
  }) =>
      MoniqEmptyState(
        key: key,
        title: title,
        message: message,
        characterAsset: 'assets/images/yellow.png',
        action: action,
        secondaryAction: secondaryAction,
        compact: compact,
      );

  /// Cheerful variant — uses the orange "evening" character.
  /// Used when the empty state invites multiple onboarding choices
  /// (e.g. team_screen: "팀 만들기 / 초대 코드로 참여").
  factory MoniqEmptyState.cheerful({
    Key? key,
    required String title,
    required String message,
    MoniqEmptyStateAction? action,
    MoniqEmptyStateAction? secondaryAction,
    bool compact = false,
  }) =>
      MoniqEmptyState(
        key: key,
        title: title,
        message: message,
        characterAsset: 'assets/images/orange.png',
        action: action,
        secondaryAction: secondaryAction,
        compact: compact,
      );

  final String title;
  final String message;
  final String characterAsset;
  final MoniqEmptyStateAction? action;
  final MoniqEmptyStateAction? secondaryAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final characterSize = compact ? 96.0 : 140.0;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxxl,
          vertical: AppSpacing.xxxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Soft background blob + character
            Container(
              width: characterSize * 1.4,
              height: characterSize * 1.4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.surfaceContainerLow,
              ),
              alignment: Alignment.center,
              child: Image.asset(
                characterAsset,
                width: characterSize,
                height: characterSize,
                fit: BoxFit.contain,
              ),
            ),
            SizedBox(
              height: compact
                  ? AppSpacing.lg
                  : AppSpacing.xxl,
            ),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.headlineLarge.copyWith(
                color: cs.onSurface,
                fontSize: compact ? 18 : 22,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.xxl),
              action!,
            ],
            if (secondaryAction != null) ...[
              const SizedBox(height: AppSpacing.sm),
              secondaryAction!,
            ],
          ],
        ),
      ),
    );
  }
}

class MoniqEmptyStateAction extends StatelessWidget {
  const MoniqEmptyStateAction({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.outlined = false,
  });

  /// Outlined (secondary) variant — used as a paired secondary action.
  factory MoniqEmptyStateAction.outlined({
    Key? key,
    required String label,
    required VoidCallback onTap,
    IconData? icon,
  }) =>
      MoniqEmptyStateAction(
        key: key,
        label: label,
        onTap: onTap,
        icon: icon,
        outlined: true,
      );

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = outlined ? Colors.transparent : cs.primary;
    final fg = outlined ? cs.onSurface : cs.onPrimary;

    return Material(
      color: bg,
      borderRadius: AppRadius.borderRadiusFull,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.borderRadiusFull,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: AppRadius.borderRadiusFull,
            border: outlined
                ? Border.all(
                    color: cs.outlineVariant,
                    width: 1.5,
                  )
                : null,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxl,
            vertical: AppSpacing.md,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: AppSpacing.sm),
              ],
              Text(
                label,
                style: AppTypography.labelLarge.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
