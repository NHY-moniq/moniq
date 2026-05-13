import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moniq/core/utils/color_utils.dart';
import 'package:moniq/data/models/shift_type_model.dart';
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

class PreviewView extends HookConsumerWidget {
  const PreviewView({super.key, required this.teamId, required this.state});

  final String teamId;
  final ScheduleGenerationState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isWideLayout = AdaptiveLayout.isWide(context);
    final hasManualEdits = useState(false);
    useEffect(() {
      hasManualEdits.value = false;
      return null;
    }, [state.generatedSchedule?.id]);
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
    String canonicalCode(ShiftTypeModel t) {
      final code = t.code.trim().toUpperCase();
      final name = t.name;
      if (code == 'D' || name.contains('데이') || name.contains('주간')) {
        return 'D';
      }
      if (code == 'E' || name.contains('이브닝') || name.contains('저녁')) {
        return 'E';
      }
      if (code == 'N' || name.contains('나이트') || name.contains('야간')) {
        return 'N';
      }
      if (code.isNotEmpty) return code;
      return name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';
    }

    int codePriority(String code) {
      switch (code) {
        case 'D':
          return 0;
        case 'E':
          return 1;
        case 'N':
          return 2;
        default:
          return 99;
      }
    }

    final orderedShiftTypes = [...state.shiftTypes]
      ..sort((a, b) {
        final pa = codePriority(canonicalCode(a));
        final pb = codePriority(canonicalCode(b));
        if (pa != pb) return pa.compareTo(pb);
        return a.displayOrder.compareTo(b.displayOrder);
      });
    final orderedCodes = <String>[];
    final codeColors = <String, Color>{};
    for (final type in orderedShiftTypes) {
      final code = canonicalCode(type);
      if (!orderedCodes.contains(code)) {
        orderedCodes.add(code);
      }
      codeColors.putIfAbsent(code, () => parseHexColor(type.color));
    }

    // ── 레이아웃 상수 ──
    const double memberRowHeight = 52.0;
    const double memberColWidth = 80.0;
    const double summaryRowHeight = 56.0;

    // ── 멤버별 근무 횟수 집계 ──
    final memberShiftCounts = <String, Map<String, int>>{};
    for (final m in members) {
      final counts = <String, int>{};
      for (final day in sortedDays) {
        final shiftTypeId = grid[day]?[m.userId];
        final type = shiftTypeId != null ? shiftTypeMap[shiftTypeId] : null;
        if (type != null) {
          final code = canonicalCode(type);
          counts[code] = (counts[code] ?? 0) + 1;
        }
      }
      memberShiftCounts[m.userId] = counts;
    }

    // ── 날짜별 근무 인원 집계 ──
    final dayShiftCounts = <DateTime, Map<String, int>>{};
    for (final day in sortedDays) {
      final counts = <String, int>{};
      for (final m in members) {
        final shiftTypeId = grid[day]?[m.userId];
        final type = shiftTypeId != null ? shiftTypeMap[shiftTypeId] : null;
        if (type != null) {
          final code = canonicalCode(type);
          counts[code] = (counts[code] ?? 0) + 1;
        }
      }
      dayShiftCounts[day] = counts;
    }

    // 통계 계산
    final hardCount = (state.validationWarnings ?? []).length;
    final customViolCount = state.customRuleViolations.length;
    final totalHard = hardCount + customViolCount;
    final softTotal = state.softViolations.values.fold(
      0,
      (s, v) => s + v.length,
    );
    final wantedPct = state.wantedTotal > 0
        ? (state.wantedSatisfied / state.wantedTotal * 100).round()
        : null;

    // ── 셀 빌더 ──
    Widget buildCell(
      String? shiftTypeId, {
      Future<void> Function(String? nextShiftTypeId)? onPick,
      bool editable = false,
    }) {
      final type = shiftTypeId != null ? shiftTypeMap[shiftTypeId] : null;
      final color = type != null
          ? parseHexColor(type.color)
          : AppColors.shiftOff;
      final label = type != null ? canonicalCode(type) : 'O';
      final cell = Container(
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

      if (onPick == null) return cell;

      return PopupMenuButton<String>(
        tooltip: '근무 수정',
        enabled: editable,
        padding: EdgeInsets.zero,
        splashRadius: 18,
        itemBuilder: (ctx) => [
          PopupMenuItem<String>(
            value: '__off__',
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppColors.shiftOff,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text('OFF'),
              ],
            ),
          ),
          ...orderedShiftTypes.map(
            (t) => PopupMenuItem<String>(
              value: t.id,
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: parseHexColor(t.color),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${canonicalCode(t)} · ${t.name}'),
                ],
              ),
            ),
          ),
        ],
        onSelected: (value) async {
          final next = value == '__off__' ? null : value;
          await onPick(next);
        },
        child: MouseRegion(
          cursor: editable ? SystemMouseCursors.click : MouseCursor.defer,
          child: cell,
        ),
      );
    }

    // ── 상태 카드 (성공 + 위반 요약 통합) ──
    Widget statusCard() {
      final hasHard = totalHard > 0;
      final statusColor = hasHard ? AppColors.error : AppColors.success;
      final statusIcon = hasHard
          ? Icons.assignment_late_outlined
          : Icons.check_circle_outline;
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
                        horizontal: AppSpacing.sm,
                        vertical: 3,
                      ),
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
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                // 구분선
                Divider(height: 1, color: colorScheme.outlineVariant),
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
            onPressed: state.isPublishing ? null : () => _publish(context, ref),
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
          if (hasManualEdits.value) ...[
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: state.isPublishing || state.isGenerating
                  ? null
                  : () async {
                      final notifier = ref.read(
                        scheduleGenerationViewModelProvider(teamId).notifier,
                      );
                      final success = await notifier
                          .saveEditedPreviewAsNewVersion();
                      if (!context.mounted) return;
                      if (!success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('수정본 저장에 실패했습니다. 잠시 후 다시 시도해주세요.'),
                          ),
                        );
                        return;
                      }
                      hasManualEdits.value = false;
                      final version = ref
                          .read(scheduleGenerationViewModelProvider(teamId))
                          .valueOrNull
                          ?.generatedSchedule
                          ?.versionNo;
                      final label = version == null
                          ? '수정본을 새 버전으로 저장했습니다.'
                          : '수정본을 v$version 버전으로 저장했습니다.';
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(label)));
                    },
              icon: const Icon(Icons.save_outlined, size: 16),
              label: const Text('수정본 새 버전 저장'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
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
                                scheduleGenerationViewModelProvider(
                                  teamId,
                                ).notifier,
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
                  onPressed: () => _showPublishFeedback(
                    context,
                    ref,
                    showSuccessHeader: false,
                  ),
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        ...members.map((m) {
          final counts = memberShiftCounts[m.userId] ?? {};
          // D/E/N 각각
          final dCount = counts['D'] ?? 0;
          final eCount = counts['E'] ?? 0;
          final nCount = counts['N'] ?? 0;
          // D/E/N 외 코드도 총합에 포함
          final workTotal = counts.values.fold(0, (s, v) => s + v);
          final offCount = sortedDays.length - workTotal;

          // D·E·N 중 하나라도 있으면 색상 칩으로 표시
          final denParts = <InlineSpan>[];
          if (dCount > 0) {
            denParts.add(
              TextSpan(
                text: 'D:$dCount',
                style: TextStyle(
                  color: codeColors['D'] ?? AppColors.brandBlue,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }
          if (eCount > 0) {
            if (denParts.isNotEmpty) {
              denParts.add(const TextSpan(text: ' '));
            }
            denParts.add(
              TextSpan(
                text: 'E:$eCount',
                style: TextStyle(
                  color: codeColors['E'] ?? AppColors.brandOrange,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }
          if (nCount > 0) {
            if (denParts.isNotEmpty) {
              denParts.add(const TextSpan(text: ' '));
            }
            denParts.add(
              TextSpan(
                text: 'N:$nCount',
                style: TextStyle(
                  color: codeColors['N'] ?? colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }

          return SizedBox(
            width: memberColWidth,
            height: memberRowHeight,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    m.displayName.length > 4
                        ? m.displayName.substring(0, 4)
                        : m.displayName,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  if (denParts.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(children: denParts),
                      style: const TextStyle(fontSize: 9, height: 1),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 1),
                  Text(
                    '총:$workTotal OFF:$offCount',
                    style: TextStyle(
                      fontSize: 8,
                      color: colorScheme.onSurfaceVariant,
                      height: 1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }),
        // 합계 행 레이블
        Container(
          width: memberColWidth,
          height: summaryRowHeight,
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
          ),
          child: Center(
            child: Text(
              '합계',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
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
          // 날짜 헤더
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
          // 멤버 행
          ...members.map(
            (m) => SizedBox(
              height: memberRowHeight,
              child: Row(
                children: sortedDays.map((day) {
                  final canEdit = !state.isPublishing && !state.isGenerating;
                  final currentShiftTypeId = grid[day]?[m.userId];
                  return buildCell(
                    currentShiftTypeId,
                    editable: canEdit,
                    onPick: !canEdit
                        ? null
                        : (nextShiftTypeId) async {
                            final success = await ref
                                .read(
                                  scheduleGenerationViewModelProvider(
                                    teamId,
                                  ).notifier,
                                )
                                .updatePreviewDayAssignments(
                                  date: day,
                                  assignmentsByUserId: {
                                    m.userId: nextShiftTypeId,
                                  },
                                );
                            if (!context.mounted) return;
                            if (success) {
                              hasManualEdits.value = true;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    '근무가 수정되었습니다. 필요하면 새 버전으로 저장하세요.',
                                  ),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('근무 수정에 실패했습니다. 다시 시도해주세요.'),
                                ),
                              );
                            }
                          },
                  );
                }).toList(),
              ),
            ),
          ),
          // 일자별 합계 행
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: colorScheme.outlineVariant),
              ),
            ),
            child: Row(
              children: sortedDays.map((day) {
                final counts = dayShiftCounts[day] ?? {};
                final entries = <(String, int, Color)>[];
                for (final code in orderedCodes) {
                  final count = counts[code] ?? 0;
                  if (count > 0) {
                    entries.add((
                      code,
                      count,
                      codeColors[code] ?? AppColors.onSurfaceVariant,
                    ));
                  }
                }
                return SizedBox(
                  width: 48,
                  height: summaryRowHeight,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: entries
                        .map(
                          (e) => Text(
                            '${e.$1}:${e.$2}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: e.$3,
                              height: 1.3,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );

    // ── 웹 2-column 레이아웃 ──
    if (isWideLayout) {
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
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
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
      if (context.mounted) context.go('/teams');
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
