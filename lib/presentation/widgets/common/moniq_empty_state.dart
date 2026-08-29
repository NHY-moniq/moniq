import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/theme/app_typography.dart';
import 'package:moniq/presentation/theme/shift_theme.dart';

/// Consistent empty-state illustration for Moniq screens.
///
/// Fixes F3 + F12: all current empty states use Material icons and
/// formal "~합니다" copy. This surfaces the brand characters and
/// conversational "~네요/~보세요" voice.
///
/// Usage:
/// ```dart
/// MoniqEmptyState.shift(
///   title: '받은 알림이 없어요',
///   message: '조용한 하루네요 ☕',
///   action: MoniqEmptyStateAction(
///     label: '알림 설정 보기',
///     onTap: () {},
///   ),
/// )
/// ```
class MoniqEmptyState extends ConsumerWidget {
  const MoniqEmptyState({
    super.key,
    required this.title,
    required this.message,
    required this.characterAsset,
    this.action,
    this.secondaryAction,
    this.compact = false,
  });

  /// 오늘 근무 캐릭터를 쓰는 변형.
  ///
  /// [characterAsset]을 `null`로 두면 빌드 시점에 `todayShiftThemeProvider`에서
  /// 캐릭터를 읽는다. 화면 전체가 근무 색을 따라가는데 빈 상태 캐릭터만
  /// 노란 데이 캐릭터로 고정돼 겉돌던 문제를 없앤다.
  factory MoniqEmptyState.shift({
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
        characterAsset: null,
        action: action,
        secondaryAction: secondaryAction,
        compact: compact,
      );

  final String title;
  final String message;

  /// 고정 캐릭터 에셋. `null`이면 오늘 근무 캐릭터를 따른다.
  final String? characterAsset;
  final MoniqEmptyStateAction? action;
  final MoniqEmptyStateAction? secondaryAction;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final asset =
        characterAsset ?? ref.watch(todayShiftThemeProvider).characterAsset;

    // 남은 높이에 맞춰 캐릭터와 여백을 줄인다. 예전엔 크기가 고정이라
    // 헤더·탭·하단 독이 함께 있는 화면에서는 액션 버튼이 잘려나갔다.
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxH = constraints.maxHeight;
        final baseCharacter = compact ? 96.0 : 140.0;

        // 캐릭터(1.4배 blob) + 텍스트 2줄 + 액션이 들어갈 자리를 뺀 나머지가
        // 캐릭터에 쓸 수 있는 높이다. 텍스트·버튼은 줄일 수 없으므로 고정으로 본다.
        var characterSize = baseCharacter;
        var gap = compact ? AppSpacing.lg : AppSpacing.xxl;
        var padV = AppSpacing.xxxl;
        var actionGap = AppSpacing.xxl;

        if (maxH.isFinite) {
          const textBlock = 96.0; // 제목 + 간격 + 메시지(2줄까지)
          final actionBlock = action == null ? 0.0 : 48.0;
          final secondaryBlock = secondaryAction == null ? 0.0 : 48.0;
          final fixed = textBlock + actionBlock + secondaryBlock;

          // 여유가 빠듯하면 여백부터 줄이고, 그래도 모자라면 캐릭터를 줄인다.
          var available = maxH - fixed - padV * 2 - gap - actionGap;
          if (available < baseCharacter * 1.4) {
            padV = AppSpacing.lg;
            gap = AppSpacing.md;
            actionGap = AppSpacing.lg;
            available = maxH - fixed - padV * 2 - gap - actionGap;
          }
          // 너무 작아지면 캐릭터를 감추느니 하한(64)에서 멈춘다.
          characterSize = (available / 1.4).clamp(64.0, baseCharacter);
        }

        return Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.xxxl,
              vertical: padV,
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
                    asset,
                    width: characterSize,
                    height: characterSize,
                    fit: BoxFit.contain,
                  ),
                ),
                SizedBox(height: gap),
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
                  SizedBox(height: actionGap),
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
      },
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
    // 채움 버튼은 면 요소 — 오프면 파스텔, 그 외엔 기존과 동일.
    final fills = shiftFillOf(context);
    final bg = outlined ? Colors.transparent : fills.fill;
    final fg = outlined ? cs.onSurface : fills.onFill;

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
