import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/widgets/common/moniq_stepper.dart';
import 'package:moniq/presentation/widgets/common/moniq_date_picker_sheet.dart';

// ────────────────────────────────────────
// 공통 위젯
// ────────────────────────────────────────

/// Schedule generation 3-step progress indicator.
/// Thin wrapper around [MoniqStepper.dots] so existing callers keep working
/// while the visual ships from the design system.
class ScheduleStepIndicator extends StatelessWidget {
  const ScheduleStepIndicator({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  final int currentStep;
  final int totalSteps;

  static const _labels = ['기간', '미리보기', '발행'];

  @override
  Widget build(BuildContext context) {
    final labels = totalSteps == _labels.length
        ? _labels
        : List<String>.generate(totalSteps, (i) => '${i + 1}');
    return MoniqStepper.dots(current: currentStep, labels: labels);
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
        final picked = await showMoniqDatePickerSheet(
          context: context,
          initialDate: date ?? firstDate,
          title: '$label 선택',
          firstDate: firstDate,
          lastDate: lastDate,
        );
        if (picked != null) {
          onPicked(DateTime(picked.year, picked.month, picked.day));
        }
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
              Icon(Icons.calendar_today, size: 18, color: colorScheme.primary),
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
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: AppSpacing.sm),
        Text(label, style: theme.textTheme.bodyMedium),
        const Spacer(),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
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
          Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.sm),
          Text(label, style: theme.textTheme.bodyMedium),
          const Spacer(),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: onTap != null ? colorScheme.primary : null,
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: AppSpacing.xs),
            Icon(Icons.chevron_right, size: 16, color: colorScheme.primary),
          ],
        ],
      ),
    );
  }
}
