import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moniq/core/utils/color_utils.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/schedule_generation_viewmodel.dart';

import 'schedule_common_widgets.dart';
import 'schedule_publish_sheet.dart';
import 'schedule_violation_widgets.dart';

// ────────────────────────────────────────
// Step 2: 미리보기 & 발행
// ────────────────────────────────────────

class PreviewView extends ConsumerWidget {
  const PreviewView({
    super.key,
    required this.teamId,
    required this.state,
  });

  final String teamId;
  final ScheduleGenerationState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MM.dd\n(E)', 'ko');
    final shifts = state.previewShifts ?? [];
    final members = state.members
        .where((m) => !state.excludedMemberIds.contains(m.userId))
        .toList();

    // 그리드 구성: Map<date, Map<userId, shiftTypeId>>
    final grid = <DateTime, Map<String, String>>{};
    for (final shift in shifts) {
      final day = DateTime(
        shift.shiftDate.year,
        shift.shiftDate.month,
        shift.shiftDate.day,
      );
      grid.putIfAbsent(day, () => <String, String>{})[shift.userId] =
          shift.shiftTypeId;
    }
    final sortedDays = grid.keys.toList()..sort();

    // 근무유형 맵
    final shiftTypeMap = {
      for (final t in state.shiftTypes) t.id: t,
    };

    // 셀 빌더
    Widget buildCell(String? shiftTypeId) {
      final type =
          shiftTypeId != null ? shiftTypeMap[shiftTypeId] : null;
      final color = type != null
          ? parseHexColor(type.color)
          : AppColors.shiftOff;
      final label = type != null
          ? type.name.substring(0, 1).toUpperCase()
          : 'O';
      return Container(
        width: 44,
        height: 36,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        // -- 단계 표시 --
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: const ScheduleStepIndicator(currentStep: 1, totalSteps: 3),
        ),

        // -- 생성 성공 배너 --
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          color: AppColors.successLight,
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: AppColors.success),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '스케줄 초안이 생성되었습니다'
                  ' (v${state.generatedSchedule!.versionNo})',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),

        // -- 위반 리포트 진입 배너 (항상 표시) --
        ViolationSummaryBanner(
          state: state,
          onTap: () => _showViolationSheet(context, ref, state, teamId),
        ),

        // -- 경고 + 그리드 (스크롤 영역) --
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 경고 (SingleChildScrollView 안이므로 고정 높이 불필요)
                if ((state.validationWarnings ?? []).isNotEmpty)
                  ExpansionTile(
                    leading: const Icon(
                      Icons.warning_amber,
                      color: AppColors.brandOrange,
                    ),
                    title: Text(
                      '${state.validationWarnings!.length}건의 알림',
                      style: theme.textTheme.bodyMedium,
                    ),
                    children: state.validationWarnings!
                        .map(
                          (w) => ListTile(
                            dense: true,
                            leading: const Icon(
                              Icons.info_outline,
                              size: 18,
                            ),
                            title: Text(
                              w,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        )
                        .toList(),
                  ),

                // -- 캘린더 표 미리보기 --
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 날짜 고정 열
                    Column(
                      children: [
                        const SizedBox(height: 40),
                        ...sortedDays.map(
                          (day) => SizedBox(
                            width: 60,
                            height: 44,
                            child: Center(
                              child: Text(
                                dateFormat.format(day),
                                textAlign: TextAlign.center,
                                style: theme.textTheme.labelSmall
                                    ?.copyWith(
                                  color: AppColors.textSecondaryLight,
                                  height: 1.2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    // 멤버별 열 (가로 스크롤)
                    Flexible(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: members.map(
                                (m) => SizedBox(
                                  width: 48,
                                  height: 40,
                                  child: Center(
                                    child: Text(
                                      m.displayName.length > 3
                                          ? m.displayName
                                              .substring(0, 3)
                                          : m.displayName,
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ).toList(),
                            ),
                            ...sortedDays.map(
                              (day) => SizedBox(
                                height: 44,
                                child: Row(
                                  children: members.map(
                                    (m) => buildCell(
                                      grid[day]?[m.userId],
                                    ),
                                  ).toList(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // -- 하단 버튼 --
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: OutlinedButton(
                        onPressed: state.isPublishing
                            ? null
                            : () async {
                                await ref
                                    .read(
                                      scheduleGenerationViewModelProvider(
                                        teamId,
                                      ).notifier,
                                    )
                                    .discardDraft();
                              },
                        child: const Text('취소'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      flex: 2,
                      child: OutlinedButton.icon(
                        onPressed: state.isPublishing
                            ? null
                            : () async {
                                final notifier = ref.read(
                                  scheduleGenerationViewModelProvider(
                                    teamId,
                                  ).notifier,
                                );
                                await notifier.discardDraft();
                                await notifier.generate();
                              },
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('재생성'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      flex: 3,
                      child: ElevatedButton.icon(
                        onPressed: state.isPublishing
                            ? null
                            : () => _publish(context, ref),
                        icon: state.isPublishing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.publish, size: 18),
                        label: Text(
                          state.isPublishing ? '발행 중' : '발행',
                        ),
                      ),
                    ),
                  ],
                ),
                // 피드백 버튼 (발행 전 -- 피드백 폼만 표시)
                TextButton.icon(
                  onPressed: () => _showPublishFeedback(
                    context,
                    ref,
                    showSuccessHeader: false,
                  ),
                  icon: const Icon(Icons.rate_review_outlined, size: 16),
                  label: const Text('이 근무표 피드백 남기기'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _publish(BuildContext context, WidgetRef ref) async {
    final success = await ref
        .read(
          scheduleGenerationViewModelProvider(teamId).notifier,
        )
        .publish();
    if (success && context.mounted) {
      await _showPublishFeedback(context, ref);
      if (context.mounted) context.pop();
    }
  }

  Future<void> _showPublishFeedback(
    BuildContext context,
    WidgetRef ref, {
    bool showSuccessHeader = true,
  }) {
    return showModalBottomSheet(
      context: context,
      isDismissible: !showSuccessHeader, // 피드백만 표시 시 닫기 허용
      enableDrag: !showSuccessHeader,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => PublishSuccessSheet(
        teamId: teamId,
        ref: ref,
        showSuccessHeader: showSuccessHeader,
        onClose: () => Navigator.pop(ctx),
      ),
    );
  }
}

/// 위반 리포트 바텀시트를 표시하는 헬퍼 함수
void _showViolationSheet(
  BuildContext context,
  WidgetRef ref,
  ScheduleGenerationState state,
  String teamId,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => ViolationSheet(
      state: state,
      teamId: teamId,
    ),
  );
}
