import 'package:flutter/material.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/widgets/common/character_blob.dart';

class MoniqEmptyState extends StatelessWidget {
  const MoniqEmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.description,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.character,
  });

  final IconData icon;
  final String message;
  final String? description;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  /// 캐릭터 타입을 지정하면 아이콘 대신 캐릭터 블롭을 표시
  final CharacterType? character;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: AppSpacing.screenAll,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (character != null)
              Opacity(
                opacity: 0.6,
                child: CharacterBlob(
                  type: character!,
                  size: 80,
                ),
              )
            else
              Icon(
                icon,
                size: 64,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
              ),
            const SizedBox(height: AppSpacing.xxl),
            Text(
              message,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            if (description != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                description!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.xxxl),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
              ),
            ],
            if (secondaryActionLabel != null &&
                onSecondaryAction != null) ...[
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onSecondaryAction,
                  child: Text(secondaryActionLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
