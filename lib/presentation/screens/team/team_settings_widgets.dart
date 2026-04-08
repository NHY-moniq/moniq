import 'package:flutter/material.dart';
import 'package:moniq/core/utils/color_utils.dart';
import 'package:moniq/data/models/shift_type_model.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
  });

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            subtitle!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class RuleCard extends StatelessWidget {
  const RuleCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Column(children: children),
      ),
    );
  }
}

class NumberRuleRow extends StatelessWidget {
  const NumberRuleRow({
    super.key,
    required this.label,
    required this.value,
    required this.suffix,
    required this.readOnly,
    required this.onChanged,
    this.minValue = 1,
  });

  final String label;
  final int value;
  final String suffix;
  final bool readOnly;
  final ValueChanged<int> onChanged;
  final int minValue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.remove_circle_outline,
              size: 20,
            ),
            onPressed: readOnly || value <= minValue
                ? null
                : () => onChanged(value - 1),
            visualDensity: VisualDensity.compact,
          ),
          SizedBox(
            width: 28,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.add_circle_outline,
              size: 20,
            ),
            onPressed:
                readOnly ? null : () => onChanged(value + 1),
            visualDensity: VisualDensity.compact,
          ),
          SizedBox(
            width: 80,
            child: Text(
              suffix,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class ToggleRuleRow extends StatelessWidget {
  const ToggleRuleRow({
    super.key,
    required this.label,
    this.description,
    required this.value,
    required this.readOnly,
    required this.onChanged,
  });

  final String label;
  final String? description;
  final bool value;
  final bool readOnly;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (description != null)
                  Text(
                    description!,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                  ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: readOnly ? null : onChanged,
            activeColor: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }
}

/// 근무 유형별 인원 설정 행
class ShiftStaffingRow extends StatelessWidget {
  const ShiftStaffingRow({
    super.key,
    required this.shiftType,
    required this.value,
    required this.suffix,
    required this.readOnly,
    required this.onChanged,
    this.minValue = 0,
  });

  final ShiftTypeModel shiftType;
  final int value;
  final String suffix;
  final bool readOnly;
  final ValueChanged<int> onChanged;
  final int minValue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: parseHexColor(shiftType.color),
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: Text(
              shiftType.code,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              shiftType.name,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.remove_circle_outline,
              size: 20,
            ),
            onPressed: readOnly || value <= minValue
                ? null
                : () => onChanged(value - 1),
            visualDensity: VisualDensity.compact,
          ),
          SizedBox(
            width: 28,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.add_circle_outline,
              size: 20,
            ),
            onPressed:
                readOnly ? null : () => onChanged(value + 1),
            visualDensity: VisualDensity.compact,
          ),
          SizedBox(
            width: 80,
            child: Text(
              suffix,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(
                    color: AppColors.textSecondaryLight,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
