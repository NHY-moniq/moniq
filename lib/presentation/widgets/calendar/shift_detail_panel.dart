import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:moniq/core/utils/color_utils.dart';
import 'package:moniq/core/utils/time_utils.dart';
import 'package:moniq/data/models/shift_with_type.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';

class ShiftDetailPanel extends StatelessWidget {
  const ShiftDetailPanel({
    super.key,
    required this.date,
    required this.shifts,
  });

  final DateTime date;
  final List<ShiftWithType> shifts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStr = DateFormat('M월 d일 (E)', 'ko_KR').format(date);

    return Padding(
      padding: AppSpacing.screenHorizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dateStr,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (shifts.isEmpty)
            Text(
              '배정된 근무가 없습니다',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondaryLight,
              ),
            )
          else
            ...shifts.map((s) => _ShiftDetailRow(shiftWithType: s)),
        ],
      ),
    );
  }
}

class _ShiftDetailRow extends StatelessWidget {
  const _ShiftDetailRow({required this.shiftWithType});

  final ShiftWithType shiftWithType;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final type = shiftWithType.shiftType;
    final shift = shiftWithType.shift;
    final color = parseHexColor(type.color);
    final timeStr = _buildTimeString();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: AppRadius.borderRadiusSm,
            ),
            child: Center(
              child: Text(
                type.code,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (timeStr.isNotEmpty)
                  Text(
                    timeStr,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
              ],
            ),
          ),
          if (shiftWithType.teamName != null)
            Text(
              shiftWithType.teamName!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondaryLight,
              ),
            ),
          if (shift.note != null && shift.note!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.sm),
              child: Icon(
                Icons.note_outlined,
                size: 16,
                color: AppColors.textSecondaryLight,
              ),
            ),
        ],
      ),
    );
  }

  String _buildTimeString() {
    final start = formatTimeString(shiftWithType.shiftType.startTime);
    final end = formatTimeString(shiftWithType.shiftType.endTime);
    if (start.isEmpty && end.isEmpty) return '';
    return '$start - $end';
  }
}
