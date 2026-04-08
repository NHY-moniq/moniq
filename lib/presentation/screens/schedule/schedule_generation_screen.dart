import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/core/utils/color_utils.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/schedule_generation_viewmodel.dart';
import 'package:moniq/presentation/widgets/common/moniq_error_view.dart';
import 'package:moniq/presentation/widgets/common/moniq_loading_view.dart';

import 'widgets/schedule_common_widgets.dart';
import 'widgets/schedule_preview_widgets.dart';

/// 스케줄 생성 3단계 플로우
///
/// Step 1 — 기간·요약 확인 + 생성 실행
/// Step 2 — 미리보기 (날짜별 그룹)
/// Step 3 — 발행 완료 (피드백 바텀시트)
class ScheduleGenerationScreen extends HookConsumerWidget {
  const ScheduleGenerationScreen({
    super.key,
    required this.teamId,
  });

  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 화면 진입 시마다 항상 fresh state로 시작
    // addPostFrameCallback으로 미뤄야 HookState.initState 에러 방지
    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.invalidate(scheduleGenerationViewModelProvider(teamId));
      });
      return null;
    }, const []);

    final stateAsync =
        ref.watch(scheduleGenerationViewModelProvider(teamId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('스케줄 생성'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: '이전 버전',
            onPressed: () =>
                context.push('/teams/$teamId/schedule/history'),
          ),
        ],
      ),
      body: stateAsync.when(
        loading: () => const MoniqLoadingView(),
        error: (e, _) => MoniqErrorView(
          message: '정보를 불러올 수 없습니다',
          onRetry: () => ref.invalidate(
            scheduleGenerationViewModelProvider(teamId),
          ),
        ),
        data: (state) {
          if (state.generatedSchedule != null &&
              state.previewShifts != null) {
            return PreviewView(teamId: teamId, state: state);
          }
          return _SetupView(teamId: teamId, state: state);
        },
      ),
    );
  }
}

// ────────────────────────────────────────
// Step 1: 설정 & 생성
// ────────────────────────────────────────

class _SetupView extends HookConsumerWidget {
  const _SetupView({required this.teamId, required this.state});

  final String teamId;
  final ScheduleGenerationState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final notifier = ref.read(
      scheduleGenerationViewModelProvider(teamId).notifier,
    );

    return SingleChildScrollView(
      padding: AppSpacing.screenAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // -- 단계 표시 --
          const ScheduleStepIndicator(currentStep: 0, totalSteps: 3),
          const SizedBox(height: AppSpacing.xxl),

          // -- 기간 설정 --
          Text(
            '생성 기간',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.md),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  ScheduleDatePickerRow(
                    label: '시작일',
                    date: state.periodStart,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now()
                        .add(const Duration(days: 365)),
                    onPicked: (picked) => notifier.setPeriod(
                      picked,
                      state.periodEnd ?? picked,
                    ),
                  ),
                  const Divider(height: AppSpacing.xxl),
                  ScheduleDatePickerRow(
                    label: '종료일',
                    date: state.periodEnd,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now()
                        .add(const Duration(days: 365)),
                    onPicked: (picked) => notifier.setPeriod(
                      state.periodStart ?? picked,
                      picked,
                    ),
                  ),
                  if (state.periodStart != null &&
                      state.periodEnd != null &&
                      state.periodEnd!.isBefore(state.periodStart!)) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '시작 일자가 마감 일자 이후입니다',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppColors.error),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xxl),

          // -- 적용 규칙 요약 --
          Text(
            '적용 규칙 요약',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.md),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ScheduleTappableInfoRow(
                    icon: Icons.people,
                    label: '멤버',
                    value:
                        '${state.members.length - state.excludedMemberIds.length}명 참여',
                    onTap: state.members.isEmpty
                        ? null
                        : () => _showMembersDialog(context, ref, state, teamId),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ScheduleTappableInfoRow(
                    icon: Icons.schedule,
                    label: '근무 유형',
                    value: '${state.shiftTypes.length}개',
                    onTap: () =>
                        _showShiftTypesDialog(context, ref, state, teamId),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ScheduleTappableInfoRow(
                    icon: Icons.rule,
                    label: '규칙',
                    value: state.rules.isEmpty
                        ? '기본 규칙 적용'
                        : '${state.rules.length}개 규칙',
                    onTap: state.rules.isEmpty
                        ? null
                        : () => _showRulesDialog(context, state),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ScheduleTappableInfoRow(
                    icon: Icons.tune_rounded,
                    label: '커스텀 규칙',
                    value: state.customRules.isEmpty
                        ? '없음'
                        : state.customRules
                                .where((r) => r.isActive)
                                .isEmpty
                        ? '${state.customRules.length}개 (모두 비활성)'
                        : '${state.customRules.where((r) => r.isActive).length}개 적용 중',
                    onTap: state.customRules.isEmpty
                        ? null
                        : () => _showCustomRulesDialog(context, state),
                  ),
                  if (state.shiftTypes.isNotEmpty) ...[
                    const Divider(height: AppSpacing.xxl),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: state.shiftTypes
                          .map(
                            (t) => Chip(
                              avatar: CircleAvatar(
                                backgroundColor:
                                    parseHexColor(t.color),
                                radius: 8,
                              ),
                              label: Text(t.name),
                              visualDensity: VisualDensity.compact,
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // 희망 휴무 현황
          if (state.wantedEntries.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xxl),
            Text('희망 휴무 현황',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: AppSpacing.md),
            Card(
              color: AppColors.primary.withValues(alpha: 0.05),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ScheduleInfoRow(
                      icon: Icons.event_note,
                      label: '수집된 희망 휴무',
                      value: '${state.wantedEntries.length}건',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ScheduleInfoRow(
                      icon: Icons.people,
                      label: '입력 인원',
                      value:
                          '${state.wantedEntries.map((e) => e.userId).toSet().length}명',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '생성 시 희망 휴무일이 자동 반영됩니다',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          if (state.error != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Card(
              color: AppColors.primary.withValues(alpha: 0.05),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ScheduleInfoRow(
                      icon: Icons.event_note,
                      label: '수집된 희망 휴무',
                      value: '${state.wantedEntries.length}건',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ScheduleInfoRow(
                      icon: Icons.people,
                      label: '입력 인원',
                      value:
                          '${state.wantedEntries.map((e) => e.userId).toSet().length}명',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '생성 시 희망 휴무일이 자동 반영됩니다',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // -- 에러 표시 --
          if (state.error != null) ...[
            const SizedBox(height: AppSpacing.lg),
            SelectableText.rich(
              TextSpan(
                text: state.error,
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.xxxl),

          // -- 생성 버튼 --
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: state.isGenerating ||
                      state.members.isEmpty ||
                      state.shiftTypes.isEmpty ||
                      state.periodStart == null ||
                      state.periodEnd == null ||
                      state.periodEnd!.isBefore(state.periodStart!)
                  ? null
                  : () => ref
                      .read(
                        scheduleGenerationViewModelProvider(
                          teamId,
                        ).notifier,
                      )
                      .generate(),
              icon: state.isGenerating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(
                state.isGenerating ? '생성 중...' : '스케줄 생성',
              ),
            ),
          ),

          if (state.members.isEmpty || state.shiftTypes.isEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              state.members.isEmpty
                  ? '멤버를 먼저 추가해주세요'
                  : '근무 유형을 먼저 설정해주세요',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.error),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

// -- 다이얼로그 헬퍼 --

void _showShiftTypesDialog(
  BuildContext context,
  WidgetRef ref,
  ScheduleGenerationState state,
  String teamId,
) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('근무 유형 (${state.shiftTypes.length}개)'),
      content: SizedBox(
        width: double.maxFinite,
        child: state.shiftTypes.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('설정된 근무 유형이 없습니다'),
              )
            : ListView.builder(
                shrinkWrap: true,
                itemCount: state.shiftTypes.length,
                itemBuilder: (_, i) {
                  final t = state.shiftTypes[i];
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 10,
                      backgroundColor: parseHexColor(t.color),
                    ),
                    title: Text(t.name),
                    subtitle: Text(t.code),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            context
                .push('/teams/$teamId/shift-types')
                .then((_) => ref.invalidate(
                      scheduleGenerationViewModelProvider(teamId),
                    ));
          },
          child: const Text('근무 유형 설정'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('닫기'),
        ),
      ],
    ),
  );
}

String? _skillDisplayLabel(String? skillLevel) {
  switch (skillLevel) {
    case 'junior':
      return '신규';
    case 'mid':
      return '중간';
    case 'senior':
      return '올드';
    default:
      return null;
  }
}

void _showMembersDialog(
  BuildContext context,
  WidgetRef ref,
  ScheduleGenerationState state,
  String teamId,
) {
  showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        // 최신 state는 ref에서 읽음 (토글 즉시 반영)
        final current = ref.read(
          scheduleGenerationViewModelProvider(teamId),
        ).valueOrNull ?? state;
        final excluded = current.excludedMemberIds;
        final activeCount = current.members.length - excluded.length;

        return AlertDialog(
          title: Row(
            children: [
              Expanded(child: Text('멤버 (${current.members.length}명)')),
              Text(
                '$activeCount명 참여',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondaryLight,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: current.members.length,
              itemBuilder: (_, i) {
                final m = current.members[i];
                final isExcluded = excluded.contains(m.userId);
                final skillLabel = _skillDisplayLabel(m.member.skillLevel);
                return SwitchListTile.adaptive(
                  dense: true,
                  value: !isExcluded,
                  onChanged: (_) {
                    ref
                        .read(
                          scheduleGenerationViewModelProvider(teamId).notifier,
                        )
                        .toggleMemberExclusion(m.userId);
                    setState(() {}); // 다이얼로그 내 즉시 갱신
                  },
                  title: Text(
                    m.displayName,
                    style: TextStyle(
                      color: isExcluded
                          ? AppColors.textSecondaryLight
                          : null,
                    ),
                  ),
                  subtitle: skillLabel != null
                      ? Text(
                          skillLabel,
                          style: TextStyle(
                            fontSize: 11,
                            color: isExcluded
                                ? AppColors.textSecondaryLight
                                : AppColors.textSecondaryLight,
                          ),
                        )
                      : null,
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('확인'),
            ),
          ],
        );
      },
    ),
  );
}

const _priorityKeyLabels = <String, String>{
  'annual_leave': '연차/법정휴가',
  'night_dedicated': '나이트전담 우선',
  'fairness_rest': '휴무배려',
  'fairness_equal': '균등배분',
};

const _ruleTypeLabels = <String, String>{
  'min_staffing': '최소 인원',
  'max_staffing': '최대 인원',
  'max_consecutive_work_days': '최대 연속 근무',
  'max_monthly_shifts': '월 최대 근무',
  'max_monthly_night_shifts': '월 최대 야간',
  'max_consecutive_night_shifts': '최대 연속 야간',
  'min_weekly_off_days': '주 최소 오프',
  'no_night_then_day': 'ND 금지',
  'no_night_then_evening': 'NE 금지',
  'no_evening_then_day': 'ED 금지',
  'nod_disabled': 'NOD 금지',
  'avoid_nood': 'NOOD 기피',
  'avoid_noe': 'NOE 기피',
  'avoid_eod': 'EOD 기피',
  'wanted_priority_order': '원티드 우선순위',
  'consider_skill_level': '숙련도 배치',
};

/// null이 포함되는 규칙은 null 반환 -> 다이얼로그에서 숨김
String? _ruleValueSummary(String ruleType, Map<String, dynamic> rv) {
  switch (ruleType) {
    case 'max_consecutive_work_days':
      final days = rv['days'];
      if (days == null) return null;
      return '최대 연속 근무: ${days}일';
    case 'max_monthly_shifts':
      final count = rv['count'];
      if (count == null) return null;
      return '월 최대 근무: ${count}회';
    case 'max_monthly_night_shifts':
      final count = rv['count'];
      if (count == null) return null;
      return '월 최대 야간: ${count}회';
    case 'max_consecutive_night_shifts':
      // team_settings에서 {'days': value}로 저장됨
      final days = rv['days'];
      if (days == null) return null;
      return '최대 연속 야간: ${days}일';
    case 'min_weekly_off_days':
      final days = rv['days'];
      if (days == null) return null;
      return '주 최소 오프: ${days}일';
    case 'min_staffing':
    case 'max_staffing':
      // {'counts': {shiftTypeId: count}}
      final counts = rv['counts'] as Map?;
      if (counts == null || counts.isEmpty) return null;
      final total = counts.values
          .whereType<num>()
          .fold<int>(0, (s, v) => s + v.toInt());
      if (total == 0) return null;
      return '${_ruleTypeLabels[ruleType]}: 합계 ${total}명';
    case 'wanted_priority_order':
      final order = rv['order'] as List?;
      if (order == null || order.isEmpty) return null;
      return order
          .map((k) => _priorityKeyLabels[k] ?? k)
          .join(' > ');
    default:
      final enabled = rv['enabled'];
      if (enabled == null) return null;
      return enabled == true ? '활성화' : '비활성화';
  }
}

void _showRulesDialog(
  BuildContext context,
  ScheduleGenerationState state,
) {
  // null 요약인 규칙은 숨김
  final visibleRules = state.rules
      .where(
        (r) => _ruleValueSummary(r.ruleType, r.ruleValue) != null,
      )
      .toList();

  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('적용 규칙 (${visibleRules.length}개)'),
      content: SizedBox(
        width: double.maxFinite,
        child: visibleRules.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('설정된 규칙이 없습니다'),
              )
            : ListView.builder(
                shrinkWrap: true,
                itemCount: visibleRules.length,
                itemBuilder: (_, i) {
                  final rule = visibleRules[i];
                  final label =
                      _ruleTypeLabels[rule.ruleType] ?? rule.ruleType;
                  final summary = _ruleValueSummary(
                    rule.ruleType,
                    rule.ruleValue,
                  )!;
                  return ListTile(
                    dense: true,
                    title: Text(label),
                    subtitle: Text(summary),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('닫기'),
        ),
      ],
    ),
  );
}

void _showCustomRulesDialog(
  BuildContext context,
  ScheduleGenerationState state,
) {
  final active = state.customRules.where((r) => r.isActive).toList();
  final inactive =
      state.customRules.where((r) => !r.isActive).toList();
  final all = [...active, ...inactive];

  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('커스텀 규칙 (${active.length}개 적용 중)'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: all.length,
          itemBuilder: (_, i) {
            final rule = all[i];
            return ListTile(
              dense: true,
              leading: Icon(
                rule.isActive
                    ? Icons.check_circle_outline_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 18,
                color: rule.isActive
                    ? (rule.priority == 'hard'
                        ? AppColors.error
                        : AppColors.secondary)
                    : AppColors.outline,
              ),
              title: Text(
                rule.originalText,
                style: TextStyle(
                  color: rule.isActive ? null : AppColors.outline,
                  decoration: rule.isActive
                      ? null
                      : TextDecoration.lineThrough,
                ),
              ),
              subtitle: Text(
                '${rule.priority == 'hard' ? '하드' : '소프트'} · ${_customRuleTypeLabel(rule.ruleType)}',
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('닫기'),
        ),
      ],
    ),
  );
}

String _customRuleTypeLabel(String type) {
  switch (type) {
    case 'member_shift_ban':
      return '근무 금지';
    case 'anti_pair':
      return '동시 배정 금지';
    case 'require_pair':
      return '함께 배정';
    case 'date_off':
      return '날짜 오프';
    case 'post_night_off':
      return '나이트 후 오프';
    case 'skill_condition':
      return '숙련도 조건';
    default:
      return '자유형';
  }
}
