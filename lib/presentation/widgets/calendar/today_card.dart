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

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            shiftColor,
            shiftColor.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: AppRadius.borderRadiusLg,
        boxShadow: [
          BoxShadow(
            color: shiftColor.withValues(alpha: 0.25),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: AppRadius.borderRadiusFull,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_awesome,
                  size: 12,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
                const SizedBox(width: 4),
                Text(
                  '오늘의 근무',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Shift name
          Text(
            shiftTypeName,
            style: theme.textTheme.headlineLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),

          // Time + Team
          Text(
            [
              if (timeStr.isNotEmpty) timeStr,
              if (teamName != null) teamName!,
            ].join(' · '),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  String _buildTimeString() {
    final start = formatTimeString(startTime);
    final end = formatTimeString(endTime);
    if (start.isEmpty && end.isEmpty) return '';
    return '$start – $end';
  }
}
