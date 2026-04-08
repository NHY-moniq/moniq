import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moniq/core/utils/color_utils.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/schedule_generation_viewmodel.dart';
import 'package:moniq/presentation/widgets/common/moniq_error_view.dart';
import 'package:moniq/presentation/widgets/common/moniq_loading_view.dart';

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
            return _PreviewView(teamId: teamId, state: state);
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
          // ── 단계 표시 ──
          const _StepIndicator(currentStep: 0, totalSteps: 3),
          const SizedBox(height: AppSpacing.xxl),

          // ── 기간 설정 ──
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
                  _DatePickerRow(
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
                  _DatePickerRow(
                    label: '종료일',
                    date: state.periodEnd,
                    firstDate:
                        state.periodStart ?? DateTime.now(),
                    lastDate: DateTime.now()
                        .add(const Duration(days: 365)),
                    onPicked: (picked) => notifier.setPeriod(
                      state.periodStart ?? picked,
                      picked,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xxl),

          // ── 적용 규칙 요약 ──
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
                  _TappableInfoRow(
                    icon: Icons.people,
                    label: '멤버',
                    value:
                        '${state.members.length - state.excludedMemberIds.length}명 참여',
                    onTap: state.members.isEmpty
                        ? null
                        : () => _showMembersDialog(context, ref, state, teamId),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _TappableInfoRow(
                    icon: Icons.schedule,
                    label: '근무 유형',
                    value: '${state.shiftTypes.length}개',
                    onTap: () =>
                        _showShiftTypesDialog(context, ref, state, teamId),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _TappableInfoRow(
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
                  _TappableInfoRow(
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
                    _InfoRow(
                      icon: Icons.event_note,
                      label: '수집된 희망 휴무',
                      value: '${state.wantedEntries.length}건',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _InfoRow(
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
                    _InfoRow(
                      icon: Icons.event_note,
                      label: '수집된 희망 휴무',
                      value: '${state.wantedEntries.length}건',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _InfoRow(
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

          // ── 에러 표시 ──
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

          // ── 생성 버튼 ──
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: state.isGenerating ||
                      state.members.isEmpty ||
                      state.shiftTypes.isEmpty
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

// ── 다이얼로그 헬퍼 ──

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

/// null이 포함되는 규칙은 null 반환 → 다이얼로그에서 숨김
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
    builder: (ctx) => _ViolationSheet(
      state: state,
      teamId: teamId,
    ),
  );
}

class _ViolationSheet extends ConsumerStatefulWidget {
  const _ViolationSheet({
    required this.state,
    required this.teamId,
  });
  final ScheduleGenerationState state;
  final String teamId;

  @override
  ConsumerState<_ViolationSheet> createState() => _ViolationSheetState();
}

class _ViolationSheetState extends ConsumerState<_ViolationSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // ConsumerStatefulWidget으로 ref.watch가 실제 rebuild 트리거
    final state = ref.watch(
      scheduleGenerationViewModelProvider(widget.teamId),
    ).valueOrNull ?? widget.state;
    // 하드 위반: validationWarnings 전체
    final hardWarnings = state.validationWarnings ?? [];

    final wantedPct = state.wantedTotal > 0
        ? (state.wantedSatisfied / state.wantedTotal * 100).round()
        : 100;

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      expand: false,
      builder: (ctx, scrollCtrl) => Column(
        children: [
          // 핸들
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textSecondaryLight.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '위반 리포트',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                // AI 분석 버튼
                if (!state.isAnalyzing && state.aiAnalysis == null)
                  TextButton.icon(
                    onPressed: () {
                      final teamName =
                          ''; // teamName은 state에 없으므로 빈 문자열로 처리
                      ref
                          .read(
                            scheduleGenerationViewModelProvider(widget.teamId)
                                .notifier,
                          )
                          .analyzeViolations(teamName);
                    },
                    icon: const Icon(Icons.auto_awesome, size: 16),
                    label: const Text('AI 분석'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.brandOrange,
                    ),
                  )
              ],
            ),
          ),
          // AI 분석 로딩 카드
          if (state.isAnalyzing)
            Container(
              margin: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.brandOrange.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.brandOrange.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.brandOrange,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    'AI가 근무표를 분석하고 있습니다...',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.brandOrange,
                    ),
                  ),
                ],
              ),
            ),
          // AI 분석 결과 카드
          if (state.aiAnalysis != null && !state.isAnalyzing)
            Container(
              margin: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.brandOrange.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.brandOrange.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    size: 16,
                    color: AppColors.brandOrange,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      state.aiAnalysis!,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      ref
                          .read(
                            scheduleGenerationViewModelProvider(widget.teamId)
                                .notifier,
                          )
                          .analyzeViolations('');
                    },
                    child: const Icon(
                      Icons.refresh,
                      size: 16,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
          TabBar(
            controller: _tabController,
            tabs: [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hardWarnings.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${hardWarnings.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    const Text('하드 위반'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (state.customRuleViolations.isNotEmpty ||
                        state.softViolations.values.any((v) => v.isNotEmpty))
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.brandOrange,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${state.customRuleViolations.length + state.softViolations.values.fold(0, (s, v) => s + v.length)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    const Text('소프트 요약'),
                  ],
                ),
              ),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // ── 탭 1: 하드 위반 ──
                hardWarnings.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.check_circle_outline,
                              size: 48,
                              color: AppColors.success,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              '하드 위반 없음',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: AppColors.success,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        itemCount: hardWarnings.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1),
                        itemBuilder: (_, i) => ListTile(
                          dense: true,
                          leading: const Icon(
                            Icons.warning_amber_rounded,
                            color: AppColors.error,
                            size: 20,
                          ),
                          title: Text(
                            hardWarnings[i],
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ),

                // ── 탭 2: 소프트 요약 ──
                _SoftSummaryTab(state: state, wantedPct: wantedPct),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────
// 위반 리포트 진입 배너 (항상 표시)
// ────────────────────────────────────────

class _ViolationSummaryBanner extends StatelessWidget {
  const _ViolationSummaryBanner({
    required this.state,
    required this.onTap,
  });

  final ScheduleGenerationState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hardCount = (state.validationWarnings ?? []).length;
    final customViolCount = state.customRuleViolations.length;
    final hasIssue = hardCount > 0 || customViolCount > 0;

    // 소프트 기피 패턴 총 위반 수
    final softPatternTotal =
        state.softViolations.values.fold(0, (s, v) => s + v.length);

    final wantedPct = state.wantedTotal > 0
        ? (state.wantedSatisfied / state.wantedTotal * 100).round()
        : 100;

    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        color: hasIssue
            ? AppColors.error.withValues(alpha: 0.06)
            : AppColors.success.withValues(alpha: 0.06),
        child: Row(
          children: [
            Icon(
              hasIssue ? Icons.assignment_late_outlined : Icons.assignment_turned_in_outlined,
              size: 20,
              color: hasIssue ? AppColors.error : AppColors.success,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  if (hardCount > 0)
                    _BannerChip(
                      label: '하드 위반 ${hardCount}건',
                      color: AppColors.error,
                    ),
                  if (customViolCount > 0)
                    _BannerChip(
                      label: '커스텀 룰 위반 ${customViolCount}건',
                      color: AppColors.error,
                    ),
                  if (softPatternTotal > 0)
                    _BannerChip(
                      label: '기피패턴 ${softPatternTotal}회',
                      color: AppColors.brandOrange,
                    ),
                  if (state.wantedTotal > 0)
                    _BannerChip(
                      label: '원티드 ${wantedPct}%',
                      color: wantedPct >= 80
                          ? AppColors.success
                          : AppColors.brandOrange,
                    ),
                  if (!hasIssue && softPatternTotal == 0 && state.wantedTotal == 0)
                    Text(
                      '위반 없음',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '리포트',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondaryLight,
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: AppColors.textSecondaryLight,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BannerChip extends StatelessWidget {
  const _BannerChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    );
  }
}

// ────────────────────────────────────────
// 소프트 요약 탭
// ────────────────────────────────────────

class _SoftSummaryTab extends StatelessWidget {
  const _SoftSummaryTab({
    required this.state,
    required this.wantedPct,
  });

  final ScheduleGenerationState state;
  final int wantedPct;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final softViol = state.softViolations;
    final hasSoftPattern = softViol.isNotEmpty &&
        softViol.values.any((v) => v.isNotEmpty);
    final customViols = state.customRuleViolations;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        // ── 원티드 반영률 ──
        if (state.wantedTotal > 0) ...[
          _SummaryCard(
            icon: Icons.favorite_outline,
            iconColor: AppColors.brandOrange,
            title: '원티드 반영률',
            value: '$wantedPct%',
            subtitle:
                '${state.wantedSatisfied}건 반영 / 전체 ${state.wantedTotal}건',
            valueColor:
                wantedPct >= 80 ? AppColors.success : AppColors.brandOrange,
          ),
          if (state.wantedUnsatisfied.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.brandOrange.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.brandOrange.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '미반영 원티드',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.brandOrange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...state.wantedUnsatisfied.map(
                    (item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          const Icon(Icons.event_busy_outlined,
                              size: 14, color: AppColors.brandOrange),
                          const SizedBox(width: 6),
                          Text(item,
                              style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
        ],

        // ── 기피 패턴 위반 ──
        if (hasSoftPattern) ...[
          Text(
            '기피패턴 위반',
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...{
            'NOD': ('NOD (나이트→오프→데이)', softViol['NOD']),
            'NOOD': ('NOOD (나이트→오프×2→데이)', softViol['NOOD']),
            'NOE': ('NOE (나이트→오프→이브닝)', softViol['NOE']),
            'EOD': ('EOD (이브닝→오프→데이)', softViol['EOD']),
          }.entries.where((e) => (e.value.$2?.isNotEmpty ?? false)).map((e) {
            final label = e.value.$1;
            final items = e.value.$2!;
            return _PatternGroup(label: label, items: items);
          }),
          const SizedBox(height: AppSpacing.sm),
        ],

        // ── 커스텀 룰 위반 ──
        if (customViols.isNotEmpty) ...[
          Text(
            '커스텀 룰 위반',
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.15)),
            ),
            child: Column(
              children: customViols
                  .map(
                    (v) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.error_outline,
                              size: 15, color: AppColors.error),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(v,
                                style: theme.textTheme.bodySmall),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],

        // ── 모두 양호 ──
        if (state.wantedTotal == 0 && !hasSoftPattern && customViols.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xxl),
              child: Column(
                children: [
                  const Icon(Icons.check_circle_outline,
                      size: 40, color: AppColors.success),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    '소프트 위반 없음',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _PatternGroup extends StatelessWidget {
  const _PatternGroup({required this.label, required this.items});
  final String label;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.brandOrange.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: AppColors.brandOrange.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  size: 15, color: AppColors.brandOrange),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ),
              Text(
                '${items.length}회',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.brandOrange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(left: 21, top: 2),
              child: Text('• $item',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondaryLight,
                  )),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.valueColor,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final String subtitle;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: iconColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondaryLight,
                    )),
                Text(subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondaryLight,
                    )),
              ],
            ),
          ),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              color: valueColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────
// Step 2: 미리보기 & 발행
// ────────────────────────────────────────

class _PreviewView extends HookConsumerWidget {
  const _PreviewView({
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
        // ── 단계 표시 ──
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: const _StepIndicator(currentStep: 1, totalSteps: 3),
        ),

        // ── 생성 성공 배너 ──
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

        // ── 위반 리포트 진입 배너 (항상 표시) ──
        _ViolationSummaryBanner(
          state: state,
          onTap: () => _showViolationSheet(context, ref, state, teamId),
        ),

        // ── 경고 + 그리드 (스크롤 영역) ──
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

                // ── 캘린더 표 미리보기 ──
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

        // ── 하단 버튼 ──
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
                // 피드백 버튼 (발행 전 — 피드백 폼만 표시)
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
      builder: (ctx) => _PublishSuccessSheet(
        teamId: teamId,
        ref: ref,
        showSuccessHeader: showSuccessHeader,
        onClose: () => Navigator.pop(ctx),
      ),
    );
  }
}

// ────────────────────────────────────────
// Step 3: 발행 완료 피드백 바텀시트
// ────────────────────────────────────────

class _PublishSuccessSheet extends StatefulWidget {
  const _PublishSuccessSheet({
    required this.onClose,
    required this.teamId,
    required this.ref,
    this.showSuccessHeader = true,
  });

  final VoidCallback onClose;
  final String teamId;
  final WidgetRef ref;
  final bool showSuccessHeader;

  @override
  State<_PublishSuccessSheet> createState() => _PublishSuccessSheetState();
}

class _PublishSuccessSheetState extends State<_PublishSuccessSheet> {
  int _overallRating = 0; // 0 = 미선택
  // ruleRatings: 1=좋음, -1=아쉬움, 0=미평가
  final Map<String, int> _ruleRatings = {
    'wanted': 0,
    'avoid_pattern': 0,
    'skill_balance': 0,
  };
  bool _isSaving = false;
  bool _saved = false;

  static const _ruleLabels = {
    'wanted': '원티드 반영',
    'avoid_pattern': '기피패턴 처리',
    'skill_balance': '숙련도 배치',
  };

  Future<void> _save() async {
    if (_overallRating == 0) return;
    setState(() => _isSaving = true);
    try {
      final ratings = Map<String, int>.from(_ruleRatings)
        ..removeWhere((_, v) => v == 0);
      await widget.ref
          .read(
            scheduleGenerationViewModelProvider(widget.teamId).notifier,
          )
          .saveFeedback(
            overallRating: _overallRating,
            ruleRatings: ratings,
          );
      setState(() {
        _isSaving = false;
        _saved = true;
      });
    } catch (_) {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: AppSpacing.xxl,
          right: AppSpacing.xxl,
          top: AppSpacing.xxl,
          bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.showSuccessHeader) ...[
              // ── 단계 표시 ──
              const _StepIndicator(currentStep: 2, totalSteps: 3),
              const SizedBox(height: AppSpacing.xxl),

              // ── 완료 아이콘 ──
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: AppColors.successLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  size: 48,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              Text(
                '스케줄이 발행되었습니다',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '팀 멤버에게 알림이 전송됩니다.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondaryLight,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: AppSpacing.xxl),
              const Divider(),
              const SizedBox(height: AppSpacing.md),
            ] else ...[
              // 핸들
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.textSecondaryLight.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                '근무표 피드백',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '피드백은 다음 달 스케줄 생성에 반영됩니다',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],

            // ── 피드백 섹션 ──
            if (_saved)
              Column(
                children: [
                  const Icon(Icons.favorite, color: AppColors.brandOrange, size: 32),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '피드백 감사합니다!',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.brandOrange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '다음 달 근무표 생성에 반영됩니다.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              )
            else ...[
              Text(
                '이번 근무표는 어떠셨나요?',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '피드백은 다음 달 스케줄 생성에 반영됩니다',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // 별점
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final star = i + 1;
                  return GestureDetector(
                    onTap: () => setState(() => _overallRating = star),
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        star <= _overallRating
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 36,
                        color: star <= _overallRating
                            ? AppColors.brandOrange
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: AppSpacing.lg),

              // 항목별 좋음/아쉬움
              ..._ruleLabels.entries.map((entry) {
                final current = _ruleRatings[entry.key] ?? 0;
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.value,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      _RatingToggle(
                        value: current,
                        onChanged: (v) => setState(
                          () => _ruleRatings[entry.key] = v,
                        ),
                      ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: AppSpacing.lg),

              // 저장 버튼
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      (_overallRating == 0 || _isSaving) ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('피드백 저장'),
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: widget.onClose,
                child: const Text('닫기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RatingToggle extends StatelessWidget {
  const _RatingToggle({required this.value, required this.onChanged});
  final int value; // -1, 0, 1
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ToggleChip(
          label: '좋아요',
          icon: Icons.thumb_up_outlined,
          selected: value == 1,
          selectedColor: AppColors.success,
          onTap: () => onChanged(value == 1 ? 0 : 1),
        ),
        const SizedBox(width: AppSpacing.sm),
        _ToggleChip(
          label: '아쉬워요',
          icon: Icons.thumb_down_outlined,
          selected: value == -1,
          selectedColor: AppColors.error,
          onTap: () => onChanged(value == -1 ? 0 : -1),
        ),
      ],
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? selectedColor.withValues(alpha: 0.1)
              : Colors.transparent,
          border: Border.all(
            color: selected
                ? selectedColor
                : AppColors.textSecondaryLight.withValues(alpha: 0.3),
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected
                  ? selectedColor
                  : AppColors.textSecondaryLight,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: selected
                    ? selectedColor
                    : AppColors.textSecondaryLight,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────
// 공통 위젯
// ────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({
    required this.currentStep,
    required this.totalSteps,
  });

  final int currentStep;
  final int totalSteps;

  static const _labels = ['설정', '미리보기', '완료'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: List.generate(totalSteps * 2 - 1, (i) {
        if (i.isOdd) {
          // 연결선
          final stepIdx = i ~/ 2;
          final isDone = stepIdx < currentStep;
          return Expanded(
            child: Container(
              height: 2,
              color: isDone
                  ? AppColors.primary
                  : AppColors.outlineVariant,
            ),
          );
        }

        final stepIdx = i ~/ 2;
        final isDone = stepIdx < currentStep;
        final isCurrent = stepIdx == currentStep;

        return Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isCurrent
                    ? AppColors.primary
                    : isDone
                        ? AppColors.success
                        : AppColors.outlineVariant,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: isDone
                    ? const Icon(
                        Icons.check,
                        size: 16,
                        color: Colors.white,
                      )
                    : Text(
                        '${stepIdx + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isCurrent
                              ? AppColors.onPrimary
                              : AppColors.textSecondaryLight,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              _labels[stepIdx],
              style: theme.textTheme.labelSmall?.copyWith(
                color: isCurrent
                    ? AppColors.primary
                    : AppColors.textSecondaryLight,
                fontWeight: isCurrent
                    ? FontWeight.w600
                    : FontWeight.normal,
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _DatePickerRow extends StatelessWidget {
  const _DatePickerRow({
    required this.label,
    this.date,
    required this.firstDate,
    required this.lastDate,
    required this.onPicked,
  });

  final String label;
  final DateTime? date;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<DateTime> onPicked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = DateFormat('yyyy년 MM월 dd일');

    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? firstDate,
          firstDate: firstDate,
          lastDate: lastDate,
        );
        if (picked != null) onPicked(picked);
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Row(
            children: [
              Text(
                date != null ? fmt.format(date!) : '선택',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              const Icon(
                Icons.calendar_today,
                size: 18,
                color: AppColors.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: AppSpacing.sm),
        Text(label, style: theme.textTheme.bodyMedium),
        const Spacer(),
        Text(
          value,
          style: theme.textTheme.bodyMedium
              ?.copyWith(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

class _TappableInfoRow extends StatelessWidget {
  const _TappableInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondaryLight),
          const SizedBox(width: AppSpacing.sm),
          Text(label, style: theme.textTheme.bodyMedium),
          const Spacer(),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color:
                  onTap != null ? AppColors.primary : null,
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: AppSpacing.xs),
            const Icon(
              Icons.chevron_right,
              size: 16,
              color: AppColors.primary,
            ),
          ],
        ],
      ),
    );
  }
}
