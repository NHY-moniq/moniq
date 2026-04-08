import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';

// ────────────────────────────────────────
// 공통 위젯
// ────────────────────────────────────────

class ScheduleStepIndicator extends StatelessWidget {
  const ScheduleStepIndicator({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  final int currentStep;
  final int totalSteps;

  static const _labels = ['설정', '미리보기', '완료'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: List.generate(totalSteps * 2 - 1, (i) {
        if (i.isOdd) {
          // 연결선
          final stepIdx = i ~/ 2;
          final isDone = stepIdx < currentStep;
          return Expanded(
            child: Container(
              height: 2,
              color: isDone
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
            ),
          );
        }

        final stepIdx = i ~/ 2;
        final isDone = stepIdx < currentStep;
        final isCurrent = stepIdx == currentStep;

        return Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isCurrent
                    ? colorScheme.primary
                    : isDone
                        ? AppColors.success
                        : colorScheme.outlineVariant,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: isDone
                    ? Icon(
                        Icons.check,
                        size: 16,
                        color: colorScheme.surface,
                      )
                    : Text(
                        '${stepIdx + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isCurrent
                              ? colorScheme.onPrimary
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              _labels[stepIdx],
              style: theme.textTheme.labelSmall?.copyWith(
                color: isCurrent
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
                fontWeight: isCurrent
                    ? FontWeight.w600
                    : FontWeight.normal,
              ),
            ),
          ],
        );
      }),
    );
  }
}

class ScheduleDatePickerRow extends StatelessWidget {
  const ScheduleDatePickerRow({
    super.key,
    required this.label,
    this.date,
    required this.firstDate,
    required this.lastDate,
    required this.onPicked,
  });

  final String label;
  final DateTime? date;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<DateTime> onPicked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final fmt = DateFormat('yyyy년 MM월 dd일');

    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? firstDate,
          firstDate: firstDate,
          lastDate: lastDate,
        );
        if (picked != null) onPicked(picked);
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Row(
            children: [
              Text(
                date != null ? fmt.format(date!) : '선택',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(
                Icons.calendar_today,
                size: 18,
                color: colorScheme.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ScheduleInfoRow extends StatelessWidget {
  const ScheduleInfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(label, style: theme.textTheme.bodyMedium),
        const Spacer(),
        Text(
          value,
          style: theme.textTheme.bodyMedium
              ?.copyWith(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

class ScheduleTappableInfoRow extends StatelessWidget {
  const ScheduleTappableInfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.xs),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(label, style: theme.textTheme.bodyMedium),
          const Spacer(),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: onTap != null
                  ? colorScheme.primary
                  : null,
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: AppSpacing.xs),
            Icon(
              Icons.chevron_right,
              size: 16,
              color: colorScheme.primary,
            ),
          ],
        ],
      ),
    );
  }
}
