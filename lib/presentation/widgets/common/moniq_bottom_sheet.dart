import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/presentation/router/bottom_sheet_visibility_provider.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/theme/app_typography.dart';

/// Themed bottom sheet for Moniq.
///
/// Fixes F5: all existing sheets use `showModalBottomSheet` with no styling,
/// so the "팀 만들기 / 초대코드로 참여" dialogs look like raw Material.
///
/// Features:
/// - 32px top radius (design system Card token)
/// - Cream surface color
/// - 48×4 handle bar
/// - Consistent 24px padding
/// - Optional eyebrow + title header
///
/// Usage:
/// ```dart
/// showMoniqBottomSheet<String>(
///   context: context,
///   title: '팀 참여하기',
///   eyebrow: 'TEAM',
///   child: Column(children: [...]),
/// );
/// ```
Future<T?> showMoniqBottomSheet<T>({
  required BuildContext context,
  required Widget child,
  String? title,
  String? eyebrow,
  bool isScrollControlled = true,
  bool useSafeArea = true,
}) async {
  // Hide the app shell's floating bottom dock while the sheet is open so it
  // does not bleed through the semi-transparent barrier. The counter is
  // restored in `finally`, covering both normal dismissal and errors.
  final notifier =
      ProviderScope.containerOf(context, listen: false)
          .read(bottomSheetCountProvider.notifier);
  notifier.increment();
  try {
    return await showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      useSafeArea: useSafeArea,
      // ShellRoute의 BottomNavigation을 가리도록 root Navigator 사용
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.42),
      builder: (ctx) => MoniqBottomSheetShell(
        title: title,
        eyebrow: eyebrow,
        child: child,
      ),
    );
  } finally {
    notifier.decrement();
  }
}

/// The visual shell used by [showMoniqBottomSheet].
/// Exposed so it can be embedded without the modal wrapper.
class MoniqBottomSheetShell extends StatelessWidget {
  const MoniqBottomSheetShell({
    super.key,
    required this.child,
    this.title,
    this.eyebrow,
  });

  final Widget child;
  final String? title;
  final String? eyebrow;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final media = MediaQuery.of(context);
    final viewInsets = media.viewInsets;
    // 시트가 화면을 가득 채우지 않도록 최대 높이를 제한한다.
    // (멤버 목록 등 항목이 많아도 시트가 과도하게 길어지지 않게 함)
    final maxHeight = media.size.height * 0.7;

    return Padding(
      padding: viewInsets,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerLowest,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Grab handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Center(
                child: Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: AppRadius.borderRadiusFull,
                  ),
                ),
              ),
            ),
            if (title != null || eyebrow != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xxl,
                  AppSpacing.lg,
                  AppSpacing.xxl,
                  AppSpacing.sm,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    if (eyebrow != null)
                      Text(
                        eyebrow!,
                        style: AppTypography.captionSmall
                            .copyWith(
                          color: cs.onSurfaceVariant,
                          letterSpacing: 1.8,
                        ),
                      ),
                    if (eyebrow != null && title != null)
                      const SizedBox(height: 2),
                    if (title != null)
                      Text(
                        title!,
                        style: AppTypography.headlineLarge
                            .copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                  ],
                ),
              ),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xxl,
                  AppSpacing.md,
                  AppSpacing.xxl,
                  AppSpacing.xxl,
                ),
                child: child,
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

/// One-shot confirmation sheet — replaces yes/no AlertDialogs.
///
/// Returns `true` when the user taps the confirm button, `false` otherwise.
///
/// Usage:
/// ```dart
/// final ok = await showMoniqConfirmSheet(
///   context: context,
///   title: '정말 삭제할까요?',
///   message: '되돌릴 수 없어요.',
///   confirmLabel: '삭제',
///   destructive: true,
/// );
/// ```
Future<bool> showMoniqConfirmSheet({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  String? eyebrow,
  String cancelLabel = '취소',
  bool destructive = false,
}) async {
  final ok = await showMoniqBottomSheet<bool>(
    context: context,
    title: title,
    eyebrow: eyebrow,
    child: MoniqConfirmSheetBody(
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      destructive: destructive,
    ),
  );
  return ok ?? false;
}

/// Single-button info sheet — replaces AlertDialogs with a single 확인.
Future<void> showMoniqInfoSheet({
  required BuildContext context,
  required String title,
  required String message,
  String? eyebrow,
  String dismissLabel = '확인',
}) async {
  await showMoniqBottomSheet<void>(
    context: context,
    title: title,
    eyebrow: eyebrow,
    child: Builder(
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              message,
              style: AppTypography.bodyMedium.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: cs.primary,
                padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.md),
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.borderRadiusFull,
                ),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                dismissLabel,
                style: AppTypography.labelLarge.copyWith(
                  color: cs.onPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

/// Body of a confirm sheet — outlined cancel + filled confirm pill row.
/// Pops `true` on confirm, `false` on cancel.
class MoniqConfirmSheetBody extends StatelessWidget {
  const MoniqConfirmSheetBody({
    super.key,
    required this.message,
    required this.confirmLabel,
    this.cancelLabel = '취소',
    this.destructive = false,
  });

  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          message,
          style: AppTypography.bodyMedium.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        IntrinsicHeight(
          child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.borderRadiusFull,
                  ),
                  side: BorderSide(color: cs.outlineVariant),
                ),
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  cancelLabel,
                  style: AppTypography.labelLarge.copyWith(
                    color: cs.onSurface,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              flex: 2,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor:
                      destructive ? cs.error : cs.primary,
                  padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.borderRadiusFull,
                  ),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  confirmLabel,
                  style: AppTypography.labelLarge.copyWith(
                    color:
                        destructive ? cs.onError : cs.onPrimary,
                    fontWeight: FontWeight.w900,
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

/// Themed destructive confirmation dialog.
///
/// A polished replacement for the default [AlertDialog] used for
/// destructive actions (e.g. "이번 달 일정 모두 삭제"). Uses design system
/// tokens only — fully dark-mode safe.
///
/// Visual structure:
///  - Top icon chip (48×48, [ColorScheme.errorContainer] background +
///    [ColorScheme.onErrorContainer] foreground)
///  - Centered headline title
///  - Centered body message with relaxed line-height
///  - Right-aligned action row: text "취소" + filled destructive confirm
///
/// Pops `true` on confirm, `false` on cancel (including barrier dismiss).
Future<bool> showMoniqDestructiveConfirm({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = '삭제',
  String cancelLabel = '취소',
  IconData icon = Icons.delete_outline_rounded,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.42),
    builder: (ctx) => _MoniqDestructiveConfirmDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      icon: icon,
    ),
  );
  return result ?? false;
}

class _MoniqDestructiveConfirmDialog extends StatelessWidget {
  const _MoniqDestructiveConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.icon,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Dialog(
      backgroundColor: cs.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.borderRadiusLg,
      ),
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxl,
        vertical: AppSpacing.xxl,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Destructive icon chip
            Center(
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.errorContainer,
                  borderRadius: AppRadius.borderRadiusMd,
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  size: 22,
                  color: cs.onErrorContainer,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Title
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.titleLarge.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            // Message
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Actions — right aligned
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: cs.onSurfaceVariant,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.sm,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.borderRadiusFull,
                    ),
                  ),
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    cancelLabel,
                    style: AppTypography.labelLarge.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.error,
                    foregroundColor: cs.onError,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                      vertical: AppSpacing.sm + 2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.borderRadiusFull,
                    ),
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(
                    confirmLabel,
                    style: AppTypography.labelLarge.copyWith(
                      color: cs.onError,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Themed informational confirmation dialog.
///
/// Visual sibling of [showMoniqDestructiveConfirm], but tuned for
/// *non-destructive* confirmations — e.g. "이 동작을 진행할까요?" prompts that
/// just need a soft, branded acknowledgement instead of a warning.
///
/// Visual structure mirrors the destructive variant:
///  - Top icon chip (40×40, [ColorScheme.primaryContainer] background +
///    [ColorScheme.onPrimaryContainer] foreground)
///  - Centered headline title
///  - Centered body message with relaxed line-height
///  - Right-aligned action row: text "취소" + filled primary confirm
///
/// Pops `true` on confirm, `false` on cancel (including barrier dismiss).
Future<bool> showMoniqInfoConfirm({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = '진행',
  String cancelLabel = '취소',
  IconData icon = Icons.star_outline_rounded,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.42),
    builder: (ctx) => _MoniqInfoConfirmDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      icon: icon,
    ),
  );
  return result ?? false;
}

class _MoniqInfoConfirmDialog extends StatelessWidget {
  const _MoniqInfoConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.icon,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Dialog(
      backgroundColor: cs.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.borderRadiusLg,
      ),
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxl,
        vertical: AppSpacing.xxl,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Info icon chip
            Center(
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: AppRadius.borderRadiusMd,
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  size: 24,
                  color: cs.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Title
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.titleLarge.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            // Message
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Actions — right aligned
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: cs.onSurfaceVariant,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.sm,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.borderRadiusFull,
                    ),
                  ),
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    cancelLabel,
                    style: AppTypography.labelLarge.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                      vertical: AppSpacing.sm + 2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.borderRadiusFull,
                    ),
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(
                    confirmLabel,
                    style: AppTypography.labelLarge.copyWith(
                      color: cs.onPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Pre-styled row for sheet option lists.
/// Replaces ad-hoc `ListTile` use inside bottom sheets.
class MoniqSheetOption extends StatelessWidget {
  const MoniqSheetOption({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.description,
    this.accentColor,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String? description;
  final VoidCallback onTap;
  final Color? accentColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = accentColor ?? cs.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.borderRadiusLg,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.lg,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: AppRadius.borderRadiusMd,
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTypography.titleMedium
                          .copyWith(
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                      ),
                    ),
                    if (description != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        description!,
                        style: AppTypography.caption
                            .copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              trailing ??
                  Icon(
                    Icons.chevron_right_rounded,
                    color: cs.onSurfaceVariant,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
