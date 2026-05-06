import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/models/shift_rule_model.dart';
import 'package:moniq/presentation/layout/adaptive_layout.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/schedule_generation_viewmodel.dart';
import 'package:moniq/presentation/viewmodels/team_detail_viewmodel.dart';
import 'package:moniq/presentation/widgets/common/moniq_app_bar.dart';
import 'package:moniq/presentation/widgets/common/moniq_bottom_sheet.dart';
import 'package:moniq/presentation/widgets/common/moniq_error_view.dart';
import 'package:moniq/presentation/widgets/common/moniq_loading_view.dart';

import 'schedule_rules_widgets.dart';

/// 스케줄 생성 시 적용되는 유동 규칙 설정 페이지.
///
/// 소프트 기피 패턴 토글 (NOOD / NOE / EOD),
/// 원티드 우선순위 reorder,
/// 숙련도 배치 고려를 설정한다.
///
/// NOD 금지·ND·NE·ED 하드 제약은 팀 설정(team_settings_screen)에 있음.
/// 나이트 전담 지정은 멤버 속성(members_screen)에 있음.
class ScheduleRulesScreen extends HookConsumerWidget {
  const ScheduleRulesScreen({
    super.key,
    required this.teamId,
  });

  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(teamDetailViewModelProvider(teamId));

    return Scaffold(
      appBar: const MoniqAppBar(title: '스케줄 생성 규칙'),
      body: detailAsync.when(
        loading: () => const MoniqLoadingView(),
        error: (e, _) => MoniqErrorView(
          message: '규칙을 불러올 수 없습니다',
          onRetry: () =>
              ref.invalidate(teamDetailViewModelProvider(teamId)),
        ),
        data: (state) => _RulesBody(
          teamId: teamId,
          rules: state.rules,
          isAdmin: state.isAdmin,
        ),
      ),
    );
  }
}

// ── 본문 ──

class _RulesBody extends ConsumerStatefulWidget {
  const _RulesBody({
    required this.teamId,
    required this.rules,
    required this.isAdmin,
  });

  final String teamId;
  final List<ShiftRuleModel> rules;
  final bool isAdmin;

  @override
  ConsumerState<_RulesBody> createState() => _RulesBodyState();
}

class _RulesBodyState extends ConsumerState<_RulesBody> {
  // ── 근무 패턴 금지 (하드) ──
  late bool _nodDisabled; // Night → Off → Day (NOD 금지)

  // ── 기피 패턴 (소프트 — 가능하면 피하지만 강제 아님) ──
  late bool _noodAvoid; // Night → Off → Off → Day
  late bool _noeAvoid; // Night → Off → Evening
  late bool _eodAvoid; // Evening → Off → Day

  // ── 스케줄링 우선순위 ──
  late List<ScheduleRulePriorityItem> _scoringPriorityOrder;

  bool _isDirty = false;
  bool _saving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  void _loadRules() {
    final ruleMap = {
      for (final r in widget.rules) r.ruleType: r.ruleValue,
    };

    _nodDisabled =
        ((ruleMap['nod_disabled'] ?? {})['enabled'] as bool?) ?? true;

    _noodAvoid =
        ((ruleMap['avoid_nood'] ?? {})['enabled'] as bool?) ?? true;
    _noeAvoid =
        ((ruleMap['avoid_noe'] ?? {})['enabled'] as bool?) ?? false;
    _eodAvoid =
        ((ruleMap['avoid_eod'] ?? {})['enabled'] as bool?) ?? false;

    // 스케줄링 우선순위 복원 (새 key: scheduling_priority_order)
    // 구버전 wanted_priority_order에서 마이그레이션 지원
    final savedOrder =
        ((ruleMap['scheduling_priority_order'] ??
                    ruleMap['wanted_priority_order'] ??
                    {})['order'] as List?);
    final defaultOrder = [
      ScheduleRulePriorityItem(key: 'wanted', label: '원티드 반영'),
      ScheduleRulePriorityItem(key: 'avoid_pattern', label: '기피패턴 처리'),
      ScheduleRulePriorityItem(key: 'preferred_shift', label: '선호근무 반영'),
      ScheduleRulePriorityItem(key: 'skill_placement', label: '숙련도 배치'),
    ];

    if (savedOrder != null && savedOrder.isNotEmpty) {
      final keyToDefault = {
        for (final d in defaultOrder) d.key: d,
      };
      _scoringPriorityOrder = savedOrder
          .whereType<String>()
          .where((k) => keyToDefault.containsKey(k))
          .map((k) => keyToDefault[k]!)
          .toList();
      for (final d in defaultOrder) {
        if (!_scoringPriorityOrder.any((p) => p.key == d.key)) {
          _scoringPriorityOrder.add(d);
        }
      }
    } else {
      _scoringPriorityOrder = defaultOrder;
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _saveError = null;
    });

    final notifier = ref.read(
      teamDetailViewModelProvider(widget.teamId).notifier,
    );

    try {
      await Future.wait([
        notifier.upsertRule(
          'nod_disabled',
          {'enabled': _nodDisabled},
        ),
        notifier.upsertRule(
          'avoid_nood',
          {'enabled': _noodAvoid},
        ),
        notifier.upsertRule(
          'avoid_noe',
          {'enabled': _noeAvoid},
        ),
        notifier.upsertRule(
          'avoid_eod',
          {'enabled': _eodAvoid},
        ),
        notifier.upsertRule(
          'scheduling_priority_order',
          {
            'order': _scoringPriorityOrder
                .map((p) => p.key)
                .toList(),
          },
        ),
      ]);

      if (mounted) {
        setState(() {
          _saving = false;
          _isDirty = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveError = '저장 중 오류가 발생했습니다: $e';
        });
      }
    }
  }

  void _markDirty() {
    if (!_isDirty) setState(() => _isDirty = true);
  }

  Future<void> _showUnsavedDialog() async {
    final leave = await showMoniqConfirmSheet(
      context: context,
      title: '저장하지 않고 나갈까요?',
      message: '변경사항이 저장되지 않아요.',
      confirmLabel: '나가기',
      destructive: true,
    );
    if (leave && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final readOnly = !widget.isAdmin;

    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _showUnsavedDialog();
      },
      child: SingleChildScrollView(
        padding: AppSpacing.screenAll,
        child: MaxWidthLayout(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 하드 패턴 금지 ──
            ScheduleRuleSectionHeader(
              title: '패턴 금지 (필수)',
              subtitle: '위반 시 해당 배정을 절대 허용하지 않습니다',
            ),
            const SizedBox(height: AppSpacing.md),
            ScheduleRuleCard(
              children: [
                ScheduleRulePatternToggleRow(
                  pattern: 'NOD',
                  description: '나이트 → 오프 → 데이 패턴 금지',
                  value: _nodDisabled,
                  isHard: true,
                  readOnly: readOnly,
                  onChanged: (v) {
                    setState(() => _nodDisabled = v);
                    _markDirty();
                  },
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.xxl),

            // ── 소프트 기피 패턴 ──
            ScheduleRuleSectionHeader(
              title: '기피 패턴 (권장)',
              subtitle: '가능하면 피하지만, 인력 부족 시 허용됩니다',
            ),
            const SizedBox(height: AppSpacing.md),
            ScheduleRuleCard(
              children: [
                ScheduleRulePatternToggleRow(
                  pattern: 'NOOD',
                  description: '나이트 → 오프 → 오프 → 데이 기피',
                  value: _noodAvoid,
                  isHard: false,
                  readOnly: readOnly,
                  onChanged: (v) {
                    setState(() => _noodAvoid = v);
                    _markDirty();
                  },
                ),
                const Divider(height: 1),
                ScheduleRulePatternToggleRow(
                  pattern: 'NOE',
                  description: '나이트 → 오프 → 이브닝 기피',
                  value: _noeAvoid,
                  isHard: false,
                  readOnly: readOnly,
                  onChanged: (v) {
                    setState(() => _noeAvoid = v);
                    _markDirty();
                  },
                ),
                const Divider(height: 1),
                ScheduleRulePatternToggleRow(
                  pattern: 'EOD',
                  description: '이브닝 → 오프 → 데이 기피',
                  value: _eodAvoid,
                  isHard: false,
                  readOnly: readOnly,
                  onChanged: (v) {
                    setState(() => _eodAvoid = v);
                    _markDirty();
                  },
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.xxl),

            // ── 스케줄링 우선순위 ──
            ScheduleRuleSectionHeader(
              title: '스케줄링 우선순위',
              subtitle: readOnly
                  ? '1번이 가장 높은 우선순위'
                  : '드래그하여 순위 조정 (1번 = 최우선)',
            ),
            const SizedBox(height: AppSpacing.md),

            if (readOnly)
              ScheduleRuleCard(
                children: [
                  ..._scoringPriorityOrder.asMap().entries.map((e) {
                    final rank = e.key + 1;
                    return ScheduleRulePriorityReadRow(
                      rank: rank,
                      label: e.value.label,
                    );
                  }),
                ],
              )
            else
              ScheduleRulePriorityReorderCard(
                items: _scoringPriorityOrder,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex -= 1;
                    final item =
                        _scoringPriorityOrder.removeAt(oldIndex);
                    _scoringPriorityOrder.insert(newIndex, item);
                  });
                  _markDirty();
                },
              ),

            const SizedBox(height: AppSpacing.xxl),

            // ── 커스텀 규칙 진입 ──
            ScheduleRuleSectionHeader(
              title: '커스텀 규칙',
              subtitle: '자연어로 팀 전용 규칙을 추가합니다',
            ),
            const SizedBox(height: AppSpacing.md),
            ScheduleRuleCard(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.rule_rounded,
                        size: 20,
                        color: Theme.of(context).colorScheme.tertiary,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          '커스텀 규칙 관리',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.push(
                          '/teams/${widget.teamId}/custom-rules',
                        ),
                        child: const Text('보기 →'),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.xxl),

            // 저장 에러
            if (_saveError != null) ...[
              SelectableText.rich(
                TextSpan(
                  text: _saveError,
                  style: TextStyle(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            // 저장 버튼
            if (widget.isAdmin)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving || !_isDirty ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : Text(_isDirty ? '저장' : '변경사항 없음'),
                ),
              ),

            if (!widget.isAdmin)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text(
                    '관리자만 설정을 수정할 수 있습니다',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),

            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _saving
                    ? null
                    : () async {
                        if (_isDirty && widget.isAdmin) await _save();
                        if (!mounted) return;
                        ref.invalidate(scheduleGenerationViewModelProvider(
                          widget.teamId,
                        ));
                        context.push(
                          '/teams/${widget.teamId}/schedule/generate',
                        );
                      },
                icon: const Icon(Icons.auto_awesome),
                label: const Text('스케줄 생성하기'),
              ),
            ),

            const SizedBox(height: AppSpacing.xxxl),
            ],
          ),
        ),
      ),
    );
  }
}
