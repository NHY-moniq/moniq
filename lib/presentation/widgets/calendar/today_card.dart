import 'package:flutter/material.dart';
import 'package:moniq/core/utils/time_utils.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';

class TodayCard extends StatelessWidget {
  const TodayCard({
    super.key,
    required this.shiftTypeName,
    required this.shiftTypeCode,
    required this.shiftColor,
    this.startTime,
    this.endTime,
    this.teamName,
  });

  final String shiftTypeName;
  final String shiftTypeCode;
  final Color shiftColor;
  final String? startTime;
  final String? endTime;
  final String? teamName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeStr = _buildTimeString();

    return Card(
      child: Padding(
        padding: AppSpacing.cardPadding,
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: shiftColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  shiftTypeCode,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '오늘의 근무',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    shiftTypeName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (timeStr.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      timeStr,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (teamName != null) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      teamName!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _buildTimeString() {
    final start = formatTimeString(startTime);
    final end = formatTimeString(endTime);
    if (start.isEmpty && end.isEmpty) return '';
    return '$start - $end';
  }
}
