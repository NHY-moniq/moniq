import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moniq/core/utils/color_utils.dart';
import 'package:moniq/data/models/custom_rule_model.dart';
import 'package:moniq/data/models/shift_type_model.dart';
import 'package:moniq/data/models/shift_rule_model.dart';
import 'package:moniq/data/models/team_member_with_user.dart';
import 'package:moniq/presentation/layout/adaptive_layout.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/schedule_generation_viewmodel.dart';
import 'package:moniq/presentation/widgets/common/moniq_app_bar.dart';
import 'package:moniq/presentation/widgets/common/moniq_bottom_sheet.dart';
import 'package:moniq/presentation/widgets/common/moniq_error_view.dart';
import 'package:moniq/presentation/widgets/common/moniq_loading_view.dart';

import '../wanted/wanted_request_widgets.dart';
import 'widgets/schedule_common_widgets.dart';
import 'widgets/schedule_preview_widgets.dart';

/// 스케줄 생성 4단계 플로우
///
/// Step 1 — 생성 규칙 설정
/// Step 2 — 기간·규칙 요약 확인 + 생성 실행
/// Step 3 — 미리보기 (날짜별 그룹)
/// Step 4 — 발행 완료 (피드백 바텀시트)
class ScheduleGenerationScreen extends HookConsumerWidget {
  const ScheduleGenerationScreen({super.key, required this.teamId});

  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrapping = useState(true);

    // 화면 진입 시마다 항상 fresh state로 시작
    useEffect(() {
      bootstrapping.value = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          final _ = await ref.refresh(
            scheduleGenerationViewModelProvider(teamId).future,
          );
        } finally {
          if (context.mounted) {
            bootstrapping.value = false;
          }
        }
      });
      return null;
    }, [teamId]);

    final stateAsync = ref.watch(scheduleGenerationViewModelProvider(teamId));

    return Scaffold(
      appBar: MoniqAppBar(
        title: '스케줄 생성',
        trailing: MoniqAppBarAction(
          icon: Icons.history_rounded,
          onTap: () => context.push('/teams/$teamId/schedule/history'),
        ),
      ),
      body: bootstrapping.value
          ? const MoniqLoadingView()
          : stateAsync.when(
              skipLoadingOnRefresh: false,
              skipLoadingOnReload: false,
              loading: () => const MoniqLoadingView(),
              error: (e, _) => MoniqErrorView(
                message: '정보를 불러올 수 없습니다',
                onRetry: () =>
                    ref.invalidate(scheduleGenerationViewModelProvider(teamId)),
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
// Step 2: 기간 설정 & 생성
// ────────────────────────────────────────

class _SetupView extends HookConsumerWidget {
  const _SetupView({required this.teamId, required this.state});

  final String teamId;
  final ScheduleGenerationState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final notifier = ref.read(
      scheduleGenerationViewModelProvider(teamId).notifier,
    );
    final defaultShiftTypes = _defaultShiftTypes(state.shiftTypes);
    final hasDefaultShiftTypes = defaultShiftTypes.isNotEmpty;

    return SingleChildScrollView(
      padding: AppSpacing.screenAll,
      child: MaxWidthLayout(
        maxWidth: 640,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // -- 단계 표시 --
            const ScheduleStepIndicator(currentStep: 1, totalSteps: 4),
            const SizedBox(height: AppSpacing.xl),

            // -- 기간 설정 --
            Text(
              '생성 기간',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
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
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      onPicked: (picked) =>
                          notifier.setPeriod(picked, state.periodEnd ?? picked),
                    ),
                    const Divider(height: AppSpacing.xxl),
                    ScheduleDatePickerRow(
                      label: '종료일',
                      date: state.periodEnd,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
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
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.error,
                          ),
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
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
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
                          : () =>
                                _showMembersDialog(context, ref, state, teamId),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ScheduleTappableInfoRow(
                      icon: Icons.schedule,
                      label: '근무 유형',
                      value: '${defaultShiftTypes.length}개',
                      onTap: () => _showShiftTypesDialog(context, state),
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
                          : state.customRules.where((r) => r.isActive).isEmpty
                          ? '${state.customRules.length}개 (모두 비활성)'
                          : '${state.customRules.where((r) => r.isActive).length}개 적용 중',
                      onTap: state.customRules.isEmpty
                          ? null
                          : () => _showCustomRulesDialog(context, state),
                    ),
                    if (hasDefaultShiftTypes) ...[
                      const Divider(height: AppSpacing.xxl),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: defaultShiftTypes
                            .map(
                              (t) => Chip(
                                avatar: CircleAvatar(
                                  backgroundColor: parseHexColor(t.color),
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

            // 원티드 현황
            if (state.wantedEntries.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xxl),
              Text(
                '원티드 현황',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _showWantedDetailSheet(context, state),
                child: Card(
                  color: colorScheme.primary.withValues(alpha: 0.05),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ScheduleInfoRow(
                                    icon: Icons.event_note,
                                    label: '수집된 원티드',
                                    value: '${state.wantedEntries.length}건',
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  ScheduleInfoRow(
                                    icon: Icons.people,
                                    label: '입력 인원',
                                    value:
                                        '${state.wantedEntries.map((e) => e.userId).toSet().length}명',
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              color: colorScheme.primary.withValues(alpha: 0.6),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          '생성 시 원티드가 자동 반영됩니다',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
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
                  style: TextStyle(color: colorScheme.error),
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.xxxl),

            // -- 생성 버튼 --
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed:
                    state.isGenerating ||
                        state.members.isEmpty ||
                        !hasDefaultShiftTypes ||
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
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(state.isGenerating ? '생성 중...' : '스케줄 생성'),
              ),
            ),

            if (state.members.isEmpty || !hasDefaultShiftTypes) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                state.members.isEmpty ? '멤버를 먼저 추가해주세요' : '기본 근무 유형을 먼저 설정해주세요',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.error,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// -- 다이얼로그 헬퍼 --

void _showShiftTypesDialog(
  BuildContext context,
  ScheduleGenerationState state,
) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;
  final defaultShiftTypes = _defaultShiftTypes(state.shiftTypes);

  showMoniqBottomSheet<void>(
    context: context,
    title: '근무 유형 (${defaultShiftTypes.length}개)',
    eyebrow: 'SHIFT TYPES',
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
            borderRadius: AppRadius.borderRadiusMd,
          ),
          child: Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  defaultShiftTypes.isEmpty
                      ? '기본 근무 유형이 없습니다'
                      : '총 ${defaultShiftTypes.length}개 기본 근무 유형이 반영됩니다',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (defaultShiftTypes.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
            alignment: Alignment.center,
            child: Text(
              '설정된 기본 근무 유형이 없어요',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        if (defaultShiftTypes.isNotEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 420),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: defaultShiftTypes.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, i) {
                final t = defaultShiftTypes[i];
                final color = parseHexColor(t.color);

                return _ShiftTypeOverviewTile(
                  name: t.name,
                  code: t.code,
                  color: color,
                  timeText: _formatShiftTypeTimeText(t.startTime, t.endTime),
                  badgeLabel: '기본',
                );
              },
            ),
          ),
      ],
    ),
  );
}

const _defaultShiftTypeCodes = {'D', 'E', 'N', 'ED'};

List<ShiftTypeModel> _defaultShiftTypes(List<ShiftTypeModel> shiftTypes) {
  return shiftTypes
      .where(
        (t) => _defaultShiftTypeCodes.contains(t.code.trim().toUpperCase()),
      )
      .toList();
}

class _ShiftTypeOverviewTile extends StatelessWidget {
  const _ShiftTypeOverviewTile({
    required this.name,
    required this.code,
    required this.color,
    required this.timeText,
    required this.badgeLabel,
  });

  final String name;
  final String code;
  final Color color;
  final String timeText;
  final String badgeLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: AppRadius.borderRadiusMd,
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: AppRadius.borderRadiusMd,
            ),
            alignment: Alignment.center,
            child: Text(
              code,
              style: TextStyle(
                color: colorScheme.surface,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  timeText,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xxs,
            ),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: AppRadius.borderRadiusFull,
            ),
            child: Text(
              badgeLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatShiftTypeTimeText(String? startTime, String? endTime) {
  final start = _formatClock(startTime);
  final end = _formatClock(endTime);
  if (start.isEmpty && end.isEmpty) return '시간 미설정';
  if (start.isEmpty) return '~ $end';
  if (end.isEmpty) return '$start ~';
  return '$start ~ $end';
}

String _formatClock(String? time) {
  if (time == null || time.trim().isEmpty) return '';
  final parts = time.trim().split(':');
  if (parts.length < 2) return '';
  final hour = parts[0].padLeft(2, '0');
  final minute = parts[1].padLeft(2, '0');
  return '$hour:$minute';
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
  final theme = Theme.of(context);
  final colorScheme = Theme.of(context).colorScheme;

  showMoniqBottomSheet<void>(
    context: context,
    title: '멤버 (${state.members.length}명)',
    eyebrow: 'MEMBERS',
    child: StatefulBuilder(
      builder: (sheetCtx, setLocal) {
        // 최신 state는 ref에서 읽음 (토글 즉시 반영)
        final current =
            ref.read(scheduleGenerationViewModelProvider(teamId)).valueOrNull ??
            state;
        final excluded = current.excludedMemberIds;
        final activeCount = current.members.length - excluded.length;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.45,
                ),
                borderRadius: AppRadius.borderRadiusMd,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.groups_rounded,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '$activeCount명 참여 · ${excluded.length}명 제외',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: ListView.separated(
                shrinkWrap: true,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.sm),
                itemCount: current.members.length,
                itemBuilder: (_, i) {
                  final m = current.members[i];
                  final isExcluded = excluded.contains(m.userId);
                  return _MemberSwitchTile(
                    member: m,
                    isExcluded: isExcluded,
                    onToggle: () {
                      ref
                          .read(
                            scheduleGenerationViewModelProvider(
                              teamId,
                            ).notifier,
                          )
                          .toggleMemberExclusion(m.userId);
                      setLocal(() {}); // 시트 내 즉시 갱신
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                context
                    .push('/teams/$teamId/members')
                    .then(
                      (_) => ref.invalidate(
                        scheduleGenerationViewModelProvider(teamId),
                      ),
                    );
              },
              child: const Text('멤버 설정'),
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
  'wanted': '원티드 반영',
  'avoid_pattern': '기피패턴 처리',
  'preferred_shift': '선호근무 반영',
  'skill_placement': '숙련도 배치',
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
  'wanted_p1_limit': '1순위 최대 신청',
  'wanted_p2_limit': '2순위 최대 신청',
  'wanted_priority_order': '원티드 우선순위',
  'scheduling_priority_order': '우선순위',
  'consider_skill_level': '숙련도 배치',
};

const _ruleCategorySpecs = <_RuleCategorySpec>[
  _RuleCategorySpec(
    key: 'staffing',
    title: '인력 설정',
    icon: Icons.groups_rounded,
    ruleTypes: {'min_staffing', 'max_staffing'},
  ),
  _RuleCategorySpec(
    key: 'workload',
    title: '근무량 제한',
    icon: Icons.calendar_month_rounded,
    ruleTypes: {'max_monthly_shifts', 'max_monthly_night_shifts'},
  ),
  _RuleCategorySpec(
    key: 'required',
    title: '필수 규칙',
    icon: Icons.rule_rounded,
    ruleTypes: {
      'max_consecutive_work_days',
      'max_consecutive_night_shifts',
      'min_weekly_off_days',
    },
  ),
  _RuleCategorySpec(
    key: 'blocked_pattern',
    title: '금지 패턴',
    icon: Icons.block_rounded,
    ruleTypes: {
      'no_night_then_day',
      'no_night_then_evening',
      'no_evening_then_day',
      'nod_disabled',
    },
  ),
  _RuleCategorySpec(
    key: 'avoid_pattern',
    title: '기피 패턴',
    icon: Icons.tune_rounded,
    ruleTypes: {'avoid_nood', 'avoid_noe', 'avoid_eod'},
  ),
  _RuleCategorySpec(
    key: 'scheduling',
    title: '스케줄링 우선순위',
    icon: Icons.auto_graph_rounded,
    ruleTypes: {'scheduling_priority_order', 'consider_skill_level'},
  ),
];

const _otherRuleCategorySpec = _RuleCategorySpec(
  key: 'other',
  title: '기타 규칙',
  icon: Icons.rule_folder_rounded,
  ruleTypes: <String>{},
);

class _RuleCategorySpec {
  const _RuleCategorySpec({
    required this.key,
    required this.title,
    required this.icon,
    required this.ruleTypes,
  });

  final String key;
  final String title;
  final IconData icon;
  final Set<String> ruleTypes;
}

class _AppliedRuleSummary {
  const _AppliedRuleSummary({required this.title, required this.icon});

  final String title;
  final IconData icon;
}

class _RuleSummaryGroup {
  const _RuleSummaryGroup({required this.spec, required this.rules});

  final _RuleCategorySpec spec;
  final List<_AppliedRuleSummary> rules;
}

/// null이 포함되는 규칙은 null 반환 -> 다이얼로그에서 숨김
String? _ruleValueSummary(
  String ruleType,
  Map<String, dynamic> rv, {
  Map<String, ShiftTypeModel> shiftTypeLookup = const {},
}) {
  switch (ruleType) {
    case 'max_consecutive_work_days':
      final days = rv['days'];
      if (days == null) return null;
      return '최대 연속 근무: $days일';
    case 'max_monthly_shifts':
      final count = rv['count'];
      if (count == null) return null;
      return '월 최대 근무: $count회';
    case 'max_monthly_night_shifts':
      final count = rv['count'];
      if (count == null) return null;
      return '월 최대 야간: $count회';
    case 'max_consecutive_night_shifts':
      // team_settings에서 {'days': value}로 저장됨
      final days = rv['days'];
      if (days == null) return null;
      return '최대 연속 야간: $days일';
    case 'min_weekly_off_days':
      final days = rv['days'];
      if (days == null) return null;
      return '주 최소 오프: $days일';
    case 'wanted_p1_limit':
    case 'wanted_p2_limit':
      return null;
    case 'min_staffing':
    case 'max_staffing':
      return _staffingRuleValueSummary(
        ruleType,
        rv,
        shiftTypeLookup: shiftTypeLookup,
      );
    case 'wanted_priority_order':
      return null;
    case 'scheduling_priority_order':
      final order = rv['order'] as List?;
      if (order == null || order.isEmpty) return null;
      return '${_ruleTypeLabels[ruleType]}: '
          '${order.map((k) => _priorityKeyLabels[k] ?? k).join(' > ')}';
    default:
      final enabled = rv['enabled'];
      if (enabled == null) return null;
      return '${_ruleTypeLabels[ruleType] ?? ruleType}: '
          '${enabled == true ? '활성화' : '비활성화'}';
  }
}

Map<String, ShiftTypeModel> _buildShiftTypeLookup(
  List<ShiftTypeModel> shiftTypes,
) {
  final lookup = <String, ShiftTypeModel>{};
  for (final type in shiftTypes) {
    lookup[type.id] = type;
    lookup[type.code] = type;
    lookup[type.code.toUpperCase()] = type;
  }
  return lookup;
}

String _shiftTypeSummaryLabel(String key, ShiftTypeModel? type) {
  final code = type?.code.trim();
  if (code != null && code.isNotEmpty) return code.toUpperCase();
  final name = type?.name.trim();
  if (name != null && name.isNotEmpty) return name;
  return key;
}

String? _staffingRuleValueSummary(
  String ruleType,
  Map<String, dynamic> rv, {
  required Map<String, ShiftTypeModel> shiftTypeLookup,
}) {
  final counts = rv['counts'] is Map ? rv['counts'] as Map : rv;
  final entries =
      counts.entries
          .map((entry) {
            final key = entry.key.toString();
            final count = entry.value is num ? (entry.value as num).toInt() : 0;
            final shiftType =
                shiftTypeLookup[key] ?? shiftTypeLookup[key.toUpperCase()];
            return (key: key, count: count, shiftType: shiftType);
          })
          .where((entry) => entry.count > 0)
          .toList()
        ..sort((a, b) {
          final orderA = a.shiftType?.displayOrder ?? 999;
          final orderB = b.shiftType?.displayOrder ?? 999;
          if (orderA != orderB) return orderA.compareTo(orderB);
          return _shiftTypeSummaryLabel(
            a.key,
            a.shiftType,
          ).compareTo(_shiftTypeSummaryLabel(b.key, b.shiftType));
        });

  if (entries.isEmpty) return null;
  final detail = entries
      .map((entry) {
        final label = _shiftTypeSummaryLabel(entry.key, entry.shiftType);
        return '$label ${entry.count}명';
      })
      .join(' · ');
  return '${_ruleTypeLabels[ruleType]}: $detail';
}

_RuleCategorySpec _ruleCategorySpecFor(String ruleType) {
  for (final spec in _ruleCategorySpecs) {
    if (spec.ruleTypes.contains(ruleType)) return spec;
  }
  return _otherRuleCategorySpec;
}

List<_RuleSummaryGroup> _buildRuleSummaryGroups(
  List<ShiftRuleModel> rules,
  Map<String, ShiftTypeModel> shiftTypeLookup,
) {
  final grouped = <String, List<_AppliedRuleSummary>>{};
  final specsByKey = <String, _RuleCategorySpec>{
    for (final spec in _ruleCategorySpecs) spec.key: spec,
    _otherRuleCategorySpec.key: _otherRuleCategorySpec,
  };

  for (final rule in rules) {
    final summary = _ruleValueSummary(
      rule.ruleType,
      rule.ruleValue,
      shiftTypeLookup: shiftTypeLookup,
    );
    if (summary == null) continue;
    final spec = _ruleCategorySpecFor(rule.ruleType);
    grouped
        .putIfAbsent(spec.key, () => [])
        .add(
          _AppliedRuleSummary(
            title: summary,
            icon: _ruleTypeIcon(rule.ruleType),
          ),
        );
  }

  return [
    for (final spec in [..._ruleCategorySpecs, _otherRuleCategorySpec])
      if ((grouped[spec.key] ?? const <_AppliedRuleSummary>[]).isNotEmpty)
        _RuleSummaryGroup(
          spec: specsByKey[spec.key]!,
          rules: grouped[spec.key]!,
        ),
  ];
}

void _showRulesDialog(BuildContext context, ScheduleGenerationState state) {
  final shiftTypeLookup = _buildShiftTypeLookup(state.shiftTypes);
  // null 요약인 규칙은 숨김
  final visibleRules = state.rules
      .where(
        (r) =>
            _ruleValueSummary(
              r.ruleType,
              r.ruleValue,
              shiftTypeLookup: shiftTypeLookup,
            ) !=
            null,
      )
      .toList();
  final ruleGroups = _buildRuleSummaryGroups(visibleRules, shiftTypeLookup);
  final expandedGroupKeys = ruleGroups.map((g) => g.spec.key).toSet();

  showMoniqBottomSheet<void>(
    context: context,
    title: '적용 규칙 (${visibleRules.length}개)',
    eyebrow: 'RULES',
    child: visibleRules.isEmpty
        ? const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Text('설정된 규칙이 없어요'),
          )
        : StatefulBuilder(
            builder: (ctx, setSheetState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 520),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: ruleGroups.length,
                      itemBuilder: (_, index) {
                        final group = ruleGroups[index];
                        final isExpanded = expandedGroupKeys.contains(
                          group.spec.key,
                        );
                        return _RuleCategoryCard(
                          group: group,
                          isExpanded: isExpanded,
                          onToggle: () {
                            setSheetState(() {
                              if (isExpanded) {
                                expandedGroupKeys.remove(group.spec.key);
                              } else {
                                expandedGroupKeys.add(group.spec.key);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
  );
}

void _showCustomRulesDialog(
  BuildContext context,
  ScheduleGenerationState state,
) {
  final theme = Theme.of(context);
  final colorScheme = Theme.of(context).colorScheme;
  final active = state.customRules.where((r) => r.isActive).toList();
  final inactive = state.customRules.where((r) => !r.isActive).toList();
  final all = [...active, ...inactive];

  showMoniqBottomSheet<void>(
    context: context,
    title: '커스텀 규칙 (${active.length}개 적용 중)',
    eyebrow: 'CUSTOM RULES',
    child: all.isEmpty
        ? const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Text('등록된 커스텀 규칙이 없어요'),
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.45,
                  ),
                  borderRadius: AppRadius.borderRadiusMd,
                ),
                child: Text(
                  '${all.length}개 중 ${active.length}개 적용 · ${inactive.length}개 비활성',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 420),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: all.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, i) {
                    final rule = all[i];
                    return _CustomRuleSummaryTile(rule: rule);
                  },
                ),
              ),
            ],
          ),
  );
}

void _showWantedDetailSheet(
  BuildContext context,
  ScheduleGenerationState state,
) {
  final nameMap = {for (final m in state.members) m.userId: m.displayName};
  final shiftTypeMap = {for (final t in state.shiftTypes) t.id: t};

  final grouped = <String, List<_WantedEntryRow>>{};
  for (final e in state.wantedEntries) {
    grouped
        .putIfAbsent(e.userId, () => [])
        .add(
          _WantedEntryRow(
            date: e.wantedDate,
            priority: e.priority,
            shiftTypeId: e.shiftTypeId,
            reason: e.reason,
          ),
        );
  }
  for (final entries in grouped.values) {
    entries.sort((a, b) => a.date.compareTo(b.date));
  }

  final sortedUserIds = grouped.keys.toList()
    ..sort((a, b) => (nameMap[a] ?? a).compareTo(nameMap[b] ?? b));
  final expandedUserIds = sortedUserIds.toSet();

  showMoniqBottomSheet<void>(
    context: context,
    title: '원티드 현황',
    eyebrow: 'WANTED',
    child: StatefulBuilder(
      builder: (ctx, setSheetState) {
        final theme = Theme.of(ctx);
        final colorScheme = theme.colorScheme;
        final dateFormat = DateFormat('MM.dd');

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${state.wantedEntries.length}건 · ${grouped.length}명',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 520),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: sortedUserIds.length,
                itemBuilder: (_, i) {
                  final uid = sortedUserIds[i];
                  final name = nameMap[uid] ?? uid;
                  final entries = grouped[uid]!;
                  final isExpanded = expandedUserIds.contains(uid);

                  return Card(
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            onTap: () {
                              setSheetState(() {
                                if (isExpanded) {
                                  expandedUserIds.remove(uid);
                                } else {
                                  expandedUserIds.add(uid);
                                }
                              });
                            },
                            borderRadius: AppRadius.borderRadiusSm,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.xxs,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: colorScheme.primary.withValues(
                                        alpha: 0.1,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.person,
                                      color: colorScheme.primary,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                  Text(
                                    '${entries.length}건',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  Icon(
                                    isExpanded
                                        ? Icons.keyboard_arrow_up_rounded
                                        : Icons.keyboard_arrow_down_rounded,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          AnimatedCrossFade(
                            duration: const Duration(milliseconds: 180),
                            crossFadeState: isExpanded
                                ? CrossFadeState.showFirst
                                : CrossFadeState.showSecond,
                            firstChild: Padding(
                              padding: const EdgeInsets.only(
                                top: AppSpacing.md,
                              ),
                              child: Wrap(
                                spacing: AppSpacing.xs,
                                runSpacing: AppSpacing.xs,
                                children: entries.map((e) {
                                  final shiftType = e.shiftTypeId != null
                                      ? shiftTypeMap[e.shiftTypeId]
                                      : null;
                                  final Color chipColor;
                                  final String avatarLabel;
                                  if (shiftType != null) {
                                    chipColor = parseHexColor(shiftType.color);
                                    avatarLabel = shiftType.code;
                                  } else {
                                    chipColor = AppColors.shiftOff;
                                    avatarLabel = 'O';
                                  }
                                  final hasReason =
                                      e.reason != null && e.reason!.isNotEmpty;
                                  final chip = WantedEntryPill(
                                    color: chipColor,
                                    avatarLabel: avatarLabel,
                                    label: Text(
                                      '${dateFormat.format(e.date)} · '
                                      '${e.priority}순위',
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  );
                                  if (!hasReason) return chip;
                                  return WantedReasonChip(
                                    chip: chip,
                                    reason: e.reason!,
                                  );
                                }).toList(),
                              ),
                            ),
                            secondChild: const SizedBox.shrink(),
                            alignment: Alignment.topLeft,
                            sizeCurve: Curves.easeOutCubic,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    ),
  );
}

// ────────────────────────────────────────
// 멤버 바텀시트 — 개별 멤버 타일
// ────────────────────────────────────────

class _MemberSwitchTile extends StatelessWidget {
  const _MemberSwitchTile({
    required this.member,
    required this.isExcluded,
    required this.onToggle,
  });

  final TeamMemberWithUser member;
  final bool isExcluded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final skillLabel = _skillDisplayLabel(member.member.skillLevel);
    final m = member.member;
    final avatarText = member.displayName.isNotEmpty
        ? member.displayName[0].toUpperCase()
        : '?';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggle,
        borderRadius: AppRadius.borderRadiusMd,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: AppRadius.borderRadiusMd,
            border: Border.all(
              color: isExcluded
                  ? colorScheme.outlineVariant
                  : colorScheme.primary.withValues(alpha: 0.24),
            ),
            color: isExcluded
                ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.25)
                : colorScheme.surface,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: colorScheme.primary.withValues(alpha: 0.14),
                backgroundImage: member.user.avatarUrl != null
                    ? NetworkImage(member.user.avatarUrl!)
                    : null,
                child: member.user.avatarUrl == null
                    ? Text(
                        avatarText,
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            member.displayName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: isExcluded
                                  ? colorScheme.onSurfaceVariant
                                  : colorScheme.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (skillLabel != null)
                          _MemberTag(
                            label: skillLabel,
                            backgroundColor:
                                colorScheme.surfaceContainerHighest,
                            foregroundColor: colorScheme.onSurfaceVariant,
                          ),
                        if (m.nightDedicated)
                          const _MemberTag(
                            label: '나이트전담',
                            backgroundColor: Color(
                              0xFFB3E5FC,
                            ), // tertiaryContainer
                            foregroundColor: Color(0xFF2196F3), // shiftNight
                          ),
                        if (m.nightExempt)
                          const _MemberTag(
                            label: '나이트제외',
                            backgroundColor: Color(0xFFFFE5C2),
                            foregroundColor: Color(0xFFB65F00),
                          ),
                        if (m.dayOnly)
                          const _MemberTag(
                            label: '데이전용',
                            backgroundColor: Color(
                              0xFFFFECB3,
                            ), // primaryContainer
                            foregroundColor: Color(
                              0xFF5B4B00,
                            ), // onPrimaryContainer
                          ),
                        for (final code in m.preferredShifts)
                          _PreferredShiftChip(code: code),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Transform.scale(
                scale: 0.84,
                child: Switch.adaptive(
                  value: !isExcluded,
                  onChanged: (_) => onToggle(),
                  activeTrackColor: colorScheme.primary,
                  activeThumbColor: colorScheme.surface,
                  inactiveTrackColor: colorScheme.outlineVariant.withValues(
                    alpha: 0.9,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RuleSummaryTile extends StatelessWidget {
  const _RuleSummaryTile({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: AppRadius.borderRadiusMd,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.13),
              borderRadius: AppRadius.borderRadiusSm,
            ),
            child: Icon(icon, size: 18, color: colorScheme.primary),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RuleSummaryList extends StatelessWidget {
  const _RuleSummaryList({required this.rules});

  final List<_AppliedRuleSummary> rules;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < rules.length; index++)
          Padding(
            padding: EdgeInsets.only(top: index == 0 ? 0 : AppSpacing.sm),
            child: _RuleSummaryTile(
              title: rules[index].title,
              icon: rules[index].icon,
            ),
          ),
      ],
    );
  }
}

class _RuleCategoryCard extends StatelessWidget {
  const _RuleCategoryCard({
    required this.group,
    required this.isExpanded,
    required this.onToggle,
  });

  final _RuleSummaryGroup group;
  final bool isExpanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: AppRadius.borderRadiusSm,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.sm,
                horizontal: AppSpacing.xs,
              ),
              child: Row(
                children: [
                  Icon(group.spec.icon, color: colorScheme.primary, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      group.spec.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    '${group.rules.length}개',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState: isExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: _RuleSummaryList(rules: group.rules),
            ),
            secondChild: const SizedBox.shrink(),
            alignment: Alignment.topLeft,
            sizeCurve: Curves.easeOutCubic,
          ),
        ],
      ),
    );
  }
}

class _CustomRuleSummaryTile extends StatelessWidget {
  const _CustomRuleSummaryTile({required this.rule});

  final CustomRuleModel rule;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final priorityColor = rule.priority == 'hard'
        ? colorScheme.error
        : colorScheme.secondary;

    return Opacity(
      opacity: rule.isActive ? 1 : 0.6,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: rule.isActive
              ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.32)
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
          borderRadius: AppRadius.borderRadiusMd,
          border: Border.all(
            color: rule.isActive
                ? priorityColor.withValues(alpha: 0.3)
                : colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              rule.isActive
                  ? Icons.check_circle_rounded
                  : Icons.pause_circle_outline_rounded,
              size: 20,
              color: rule.isActive ? priorityColor : colorScheme.outline,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rule.originalText,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: rule.isActive
                          ? colorScheme.onSurface
                          : colorScheme.onSurfaceVariant,
                      decoration: rule.isActive
                          ? null
                          : TextDecoration.lineThrough,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      _MemberTag(
                        label: rule.priority == 'hard' ? '하드' : '소프트',
                        backgroundColor: priorityColor.withValues(alpha: 0.15),
                        foregroundColor: priorityColor,
                      ),
                      _MemberTag(
                        label: _customRuleTypeLabel(rule.ruleType),
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        foregroundColor: colorScheme.onSurfaceVariant,
                      ),
                      if (!rule.isActive)
                        _MemberTag(
                          label: '비활성',
                          backgroundColor: colorScheme.surfaceContainerHighest,
                          foregroundColor: colorScheme.outline,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _ruleTypeIcon(String type) {
  switch (type) {
    case 'min_staffing':
      return Icons.group_add_rounded;
    case 'max_staffing':
      return Icons.groups_rounded;
    case 'max_consecutive_work_days':
      return Icons.calendar_view_week_rounded;
    case 'max_monthly_shifts':
      return Icons.calendar_month_rounded;
    case 'max_monthly_night_shifts':
      return Icons.nightlight_round;
    case 'max_consecutive_night_shifts':
      return Icons.bedtime_rounded;
    case 'min_weekly_off_days':
      return Icons.event_available_rounded;
    case 'scheduling_priority_order':
      return Icons.priority_high_rounded;
    default:
      return Icons.rule_folder_rounded;
  }
}

class _MemberTag extends StatelessWidget {
  const _MemberTag({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: foregroundColor,
        ),
      ),
    );
  }
}

class _PreferredShiftChip extends StatelessWidget {
  const _PreferredShiftChip({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final String label;

    switch (code) {
      case 'D':
        bg = AppColors.shiftDay.withValues(alpha: 0.15);
        fg = AppColors.shiftDay.withValues(alpha: 0.9);
        label = '데이';
      case 'E':
        bg = AppColors.shiftEvening.withValues(alpha: 0.15);
        fg = AppColors.shiftEvening.withValues(alpha: 0.9);
        label = '이브닝';
      case 'N':
        bg = AppColors.shiftNight.withValues(alpha: 0.15);
        fg = AppColors.shiftNight.withValues(alpha: 0.9);
        label = '나이트';
      default:
        bg = Colors.grey.withValues(alpha: 0.15);
        fg = Colors.grey;
        label = code;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

class _WantedEntryRow {
  _WantedEntryRow({
    required this.date,
    required this.priority,
    this.shiftTypeId,
    this.reason,
  });
  final DateTime date;
  final int priority;
  final String? shiftTypeId;
  final String? reason;
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
