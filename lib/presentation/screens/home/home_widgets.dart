import 'package:flutter/material.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/theme/shift_theme.dart';

// ════════════════════════════════════════════════
// Weekly Hours Card
// ════════════════════════════════════════════════

class WeeklyHoursCard extends StatelessWidget {
  const WeeklyHoursCard({super.key, required this.shiftTheme});

  final ShiftThemeData shiftTheme;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        color: shiftTheme.primary.withValues(alpha: 0.08),
        borderRadius: AppRadius.borderRadiusLg,
        border: Border.all(
          color: shiftTheme.primary.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WEEKLY HOURS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: colorScheme.outline,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '32.5 ',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: shiftTheme.accentText,
                    ),
                  ),
                  TextSpan(
                    text: 'hrs',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════
// On-Shift Team Card (overlapping avatars)
// ════════════════════════════════════════════════

class OnShiftTeamCard extends StatelessWidget {
  const OnShiftTeamCard({super.key, required this.shiftTheme});

  final ShiftThemeData shiftTheme;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        color: shiftTheme.primary.withValues(alpha: 0.08),
        borderRadius: AppRadius.borderRadiusLg,
        border: Border.all(
          color: shiftTheme.primary.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ON-SHIFT TEAM',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: colorScheme.outline,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Overlapping avatars
          SizedBox(
            height: 40,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (int i = 0; i < 3; i++)
                  Positioned(
                    left: i * 26.0,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colorScheme.surfaceContainerHigh,
                        border: Border.all(
                          color: shiftTheme.background,
                          width: 3,
                        ),
                      ),
                      child: Icon(
                        Icons.person,
                        size: 18,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                Positioned(
                  left: 3 * 26.0,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colorScheme.surface,
                      border: Border.all(
                        color: shiftTheme.background,
                        width: 3,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '+4',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: colorScheme.outline,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════
// Announcement Card
// ════════════════════════════════════════════════

class AnnouncementCard extends StatelessWidget {
  const AnnouncementCard({super.key, required this.shiftTheme});

  final ShiftThemeData shiftTheme;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: shiftTheme.primary.withValues(alpha: 0.06),
        borderRadius: AppRadius.borderRadiusLg,
        border: Border.all(
          color: shiftTheme.primary.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: shiftTheme.primary.withValues(alpha: 0.15),
              borderRadius: AppRadius.borderRadiusMd,
            ),
            child: Icon(
              Icons.campaign_outlined,
              size: 20,
              color: shiftTheme.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '팀 공지사항',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  '아직 공지사항이 없습니다',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: colorScheme.outline,
          ),
        ],
      ),
    );
  }
}
