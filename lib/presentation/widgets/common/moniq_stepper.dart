import 'package:flutter/material.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/theme/app_typography.dart';

/// Progress indicator for multi-step flows (Request Create, Schedule Gen).
///
/// Fixes F7: Schedule Generation has clear "Step 1 → 2 → 3" semantics
/// in the source but no UI to match. Request Create has the same issue.
///
/// Two variants:
/// - [MoniqStepper.bars] — three-bar progress (compact)
/// - [MoniqStepper.dots] — dot + label per step (verbose)
///
/// Usage:
/// ```dart
/// MoniqStepper.bars(current: 0, total: 3)
///
/// MoniqStepper.dots(
///   current: 1,
///   labels: ['기간', '미리보기', '발행'],
/// )
/// ```
class MoniqStepper extends StatelessWidget {
  const MoniqStepper._({
    required this.current,
    required this.total,
    required this.labels,
    required this.isBars,
  });

  factory MoniqStepper.bars({
    required int current,
    required int total,
  }) =>
      MoniqStepper._(
        current: current,
        total: total,
        labels: const [],
        isBars: true,
      );

  factory MoniqStepper.dots({
    required int current,
    required List<String> labels,
  }) =>
      MoniqStepper._(
        current: current,
        total: labels.length,
        labels: labels,
        isBars: false,
      );

  /// 0-indexed active step.
  final int current;
  final int total;
  final List<String> labels;
  final bool isBars;

  @override
  Widget build(BuildContext context) {
    return isBars ? _buildBars(context) : _buildDots(context);
  }

  Widget _buildBars(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: List.generate(total, (i) {
        final active = i <= current;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: i == total - 1 ? 0 : AppSpacing.sm,
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOut,
              height: 4,
              decoration: BoxDecoration(
                color: active
                    ? cs.primary
                    : cs.surfaceContainerLow,
                borderRadius: AppRadius.borderRadiusFull,
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildDots(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          Expanded(
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Connecting line
                    if (i != 0)
                      Positioned(
                        left: 0,
                        right: labels.length / 2 + 2,
                        child: Container(
                          height: 2,
                          color: i <= current
                              ? cs.primary
                              : cs.surfaceContainerLow,
                        ),
                      ),
                    if (i != labels.length - 1)
                      Positioned(
                        right: 0,
                        left: labels.length / 2 + 2,
                        child: Container(
                          height: 2,
                          color: i < current
                              ? cs.primary
                              : cs.surfaceContainerLow,
                        ),
                      ),
                    AnimatedContainer(
                      duration:
                          const Duration(milliseconds: 240),
                      width: i == current ? 32 : 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: i <= current
                            ? cs.primary
                            : cs.surfaceContainerLow,
                        borderRadius:
                            AppRadius.borderRadiusFull,
                        border: Border.all(
                          color: i == current
                              ? cs.primary
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: i < current
                          ? Icon(
                              Icons.check_rounded,
                              size: 12,
                              color: cs.onPrimary,
                            )
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  style: AppTypography.captionSmall.copyWith(
                    color: i <= current
                        ? cs.onSurface
                        : cs.onSurfaceVariant,
                    letterSpacing: 1.4,
                    fontWeight: i == current
                        ? FontWeight.w900
                        : FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
