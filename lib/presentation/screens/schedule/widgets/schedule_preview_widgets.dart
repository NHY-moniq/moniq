import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moniq/core/utils/color_utils.dart';
import 'package:moniq/presentation/layout/adaptive_layout.dart';
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
    final colorScheme = theme.colorScheme;
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
    final shiftTypeMap = {for (final t in state.shiftTypes) t.id: t};

    // 통계 계산
    final hardCount = (state.validationWarnings ?? []).length;
    final customViolCount = state.customRuleViolations.length;
    final totalHard = hardCount + customViolCount;
    final softTotal =
        state.softViolations.values.fold(0, (s, v) => s + v.length);
    final wantedPct = state.wantedTotal > 0
        ? (state.wantedSatisfied / state.wantedTotal * 100).round()
        : null;

    // ── 셀 빌더 ──
    Widget buildCell(String? shiftTypeId) {
      final type = shiftTypeId != null ? shiftTypeMap[shiftTypeId] : null;
      final color =
          type != null ? parseHexColor(type.color) : AppColors.shiftOff;
      final label =
          type != null ? type.name.substring(0, 1).toUpperCase() : 'O';
      return Container(
        width: 44,
        height: 36,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(AppRadius.xs),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Center(
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    // ── 상태 카드 (성공 + 위반 요약 통합) ──
    Widget statusCard() {
      final hasHard = totalHard > 0;
      final statusColor = hasHard ? AppColors.error : AppColors.success;
      final statusIcon =
          hasHard ? Icons.assignment_late_outlined : Icons.check_circle_outline;
      final statusText = hasHard ? '위반 항목 있음' : '위반 없음';

      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: InkWell(
          onTap: () => _showViolationSheet(context, ref, state, teamId),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: colorScheme.outlineVariant),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 상단 행: 버전 뱃지 + 상태 텍스트 + 화살표
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Text(
                        'v${state.generatedSchedule!.versionNo}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '초안 생성 완료',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Icon(Icons.chevron_right,
                        size: 18, color: colorScheme.onSurfaceVariant),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                // 구분선
                Divider(
                    height: 1, color: colorScheme.outlineVariant),
                const SizedBox(height: AppSpacing.sm),
                // 통계 행
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    // 하드 위반 / 없음
                    _StatChip(
                      icon: statusIcon,
                      label: totalHard > 0 ? '하드 $totalHard건' : statusText,
                      color: statusColor,
                    ),
                    // 원티드
                    if (wantedPct != null)
                      _StatChip(
                        icon: Icons.favorite_outline,
                        label: '원티드 $wantedPct%',
                        color: wantedPct >= 80
                            ? AppColors.success
                            : AppColors.brandOrange,
                      ),
                    // 소프트
                    if (softTotal > 0)
                      _StatChip(
                        icon: Icons.warning_amber_outlined,
                        label: '소프트 $softTotal건',
                        color: AppColors.brandOrange,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ── 액션 버튼 (세로 스택) ──
    Widget actionButtons() => Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 발행하기 — 가장 중요한 액션
              ElevatedButton.icon(
                onPressed:
                    state.isPublishing ? null : () => _publish(context, ref),
                icon: state.isPublishing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.publish_rounded, size: 18),
                label: Text(
                  state.isPublishing ? '발행 중...' : '발행하기',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              // 재생성
              OutlinedButton.icon(
                onPressed: state.isPublishing
                    ? null
                    : () async {
                        final notifier = ref.read(
                          scheduleGenerationViewModelProvider(teamId).notifier,
                        );
                        await notifier.discardDraft();
                        await notifier.generate();
                      },
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('재생성'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              // 취소 + 피드백 (작게)
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: state.isPublishing
                          ? null
                          : () async {
                              await ref
                                  .read(
                                    scheduleGenerationViewModelProvider(teamId)
                                        .notifier,
                                  )
                                  .discardDraft();
                            },
                      style: TextButton.styleFrom(
                        foregroundColor: colorScheme.onSurfaceVariant,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      child: const Text('취소'),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => _showPublishFeedback(context, ref,
                          showSuccessHeader: false),
                      icon: const Icon(Icons.rate_review_outlined, size: 15),
                      label: const Text('피드백'),
                      style: TextButton.styleFrom(
                        foregroundColor: colorScheme.onSurfaceVariant,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );

    // ── 멤버 이름 고정 열 ──
    Widget memberColumn() => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            ...members.map(
              (m) => SizedBox(
                width: 72,
                height: 44,
                child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      m.displayName.length > 4
                          ? m.displayName.substring(0, 4)
                          : m.displayName,
                      style: theme.textTheme.labelSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );

    // ── 날짜 그리드 (가로 스크롤) ──
    Widget dateGrid() => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: sortedDays
                    .map(
                      (day) => SizedBox(
                        width: 48,
                        height: 40,
                        child: Center(
                          child: Text(
                            dateFormat.format(day),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              ...members.map(
                (m) => SizedBox(
                  height: 44,
                  child: Row(
                    children: sortedDays
                        .map((day) => buildCell(grid[day]?[m.userId]))
                        .toList(),
                  ),
                ),
              ),
            ],
          ),
        );

    // ── 웹 2-column 레이아웃 ──
    if (AdaptiveLayout.isWide(context)) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 왼쪽: 정보 + 액션 패널
          Container(
            width: 360,
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: colorScheme.outlineVariant, width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  child: const ScheduleStepIndicator(
                    currentStep: 1,
                    totalSteps: 3,
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        statusCard(),
                        const SizedBox(height: AppSpacing.lg),
                        actionButtons(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 오른쪽: 그리드
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  memberColumn(),
                  Flexible(child: dateGrid()),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // ── 모바일 레이아웃 ──
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: const ScheduleStepIndicator(currentStep: 1, totalSteps: 3),
        ),
        statusCard(),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.sm),
                // 캘린더 표 미리보기
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    memberColumn(),
                    Flexible(child: dateGrid()),
                  ],
                ),
              ],
            ),
          ),
        ),
        // 하단 버튼
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.md,
            ),
            child: actionButtons(),
          ),
        ),
      ],
    );
  }

  Future<void> _publish(BuildContext context, WidgetRef ref) async {
    final success = await ref
        .read(scheduleGenerationViewModelProvider(teamId).notifier)
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
      isDismissible: !showSuccessHeader,
      enableDrag: !showSuccessHeader,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
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

/// 위반 리포트 바텀시트 헬퍼
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
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.md)),
    ),
    builder: (ctx) => ViolationSheet(state: state, teamId: teamId),
  );
}

// ── 통계 칩 ──
class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
