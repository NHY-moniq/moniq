import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moniq/data/models/schedule_model.dart';
import 'package:moniq/presentation/screens/schedule/widgets/schedule_history_feedback_sheet.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';

export 'package:moniq/presentation/screens/schedule/widgets/schedule_history_detail_body.dart';
export 'package:moniq/presentation/screens/schedule/widgets/schedule_history_feedback_sheet.dart';

// ── 버전 카드 ──

class ScheduleHistoryVersionCard extends ConsumerWidget {
  const ScheduleHistoryVersionCard({
    super.key,
    required this.schedule,
    required this.teamId,
  });
  final ScheduleModel schedule;
  final String teamId;

  void _showFeedbackSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.lg),
        ),
      ),
      builder: (_) => ScheduleHistoryFeedbackSheet(
        scheduleId: schedule.id,
        teamId: teamId,
        versionLabel: 'v${schedule.versionNo}',
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final fmt = DateFormat('yyyy.MM.dd');
    final isPublished = schedule.status == 'published';

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        onTap: () => context.push(
          '/teams/$teamId/schedule/history/${schedule.id}',
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              // 버전 배지
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isPublished
                      ? colorScheme.primary.withValues(alpha: 0.12)
                      : colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Center(
                  child: Text(
                    'v${schedule.versionNo}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isPublished
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
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
                      '${fmt.format(schedule.periodStart)} ~ ${fmt.format(schedule.periodEnd)}',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isPublished
                                ? AppColors.success
                                    .withValues(alpha: 0.12)
                                : AppColors.brandOrange
                                    .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(
                              AppRadius.xs,
                            ),
                          ),
                          child: Text(
                            isPublished ? '발행됨' : '초안',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isPublished
                                  ? AppColors.success
                                  : AppColors.brandOrange,
                            ),
                          ),
                        ),
                        if (schedule.createdAt != null) ...[
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            DateFormat('MM.dd HH:mm')
                                .format(schedule.createdAt!.toLocal()),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // 피드백 버튼
              IconButton(
                icon: const Icon(Icons.rate_review_outlined),
                color: AppColors.brandOrange,
                tooltip: '피드백 남기기',
                onPressed: () => _showFeedbackSheet(context),
              ),
              GestureDetector(
                onTap: () => context.push(
                  '/teams/$teamId/schedule/history/${schedule.id}',
                ),
                child: Icon(
                  Icons.chevron_right,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
