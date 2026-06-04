import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/widgets/common/moniq_date_picker_sheet.dart';

// ────────────────────────────────────────
// 공통 위젯
// ────────────────────────────────────────

/// Schedule generation 4-step progress indicator.
class ScheduleStepIndicator extends StatelessWidget {
  const ScheduleStepIndicator({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  final int currentStep;
  final int totalSteps;

  static const _steps = [
    _ScheduleFlowStep(label: '규칙'),
    _ScheduleFlowStep(label: '기간'),
    _ScheduleFlowStep(label: '미리보기'),
    _ScheduleFlowStep(label: '발행'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final steps = totalSteps == _steps.length
        ? _steps
        : List<_ScheduleFlowStep>.generate(
            totalSteps,
            (i) => _ScheduleFlowStep(label: '${i + 1}'),
          );
    final safeStep = currentStep.clamp(0, steps.length - 1);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.72),
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'STEP',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Row(
              children: steps.asMap().entries.map((entry) {
                final index = entry.key;
                final step = entry.value;
                return Expanded(
                  child: _ScheduleStepSegment(
                    number: index + 1,
                    label: step.label,
                    isActive: index == safeStep,
                    isCompleted: index < safeStep,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleStepSegment extends StatelessWidget {
  const _ScheduleStepSegment({
    required this.number,
    required this.label,
    required this.isActive,
    required this.isCompleted,
  });

  final int number;
  final String label;
  final bool isActive;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final fillColor = isActive || isCompleted
        ? colorScheme.primary
        : colorScheme.surfaceContainerLow;
    final textColor = isActive || isCompleted
        ? colorScheme.onPrimary
        : colorScheme.onSurfaceVariant;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: isActive ? 32 : 24,
          height: 24,
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: AppRadius.borderRadiusFull,
            border: Border.all(
              color: isActive
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
            ),
          ),
          child: Center(
            child: Text(
              '$number',
              style: theme.textTheme.labelSmall?.copyWith(
                color: textColor,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: isActive
                ? colorScheme.onSurface
                : colorScheme.onSurfaceVariant,
            fontWeight: isActive ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ScheduleFlowStep {
  const _ScheduleFlowStep({required this.label});

  final String label;
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
