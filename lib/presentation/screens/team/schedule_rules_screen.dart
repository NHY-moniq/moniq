import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/models/shift_rule_model.dart';
import 'package:moniq/data/models/team_member_with_user.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/schedule_generation_viewmodel.dart';
import 'package:moniq/presentation/viewmodels/team_detail_viewmodel.dart';
import 'package:moniq/presentation/widgets/common/moniq_error_view.dart';
import 'package:moniq/presentation/widgets/common/moniq_loading_view.dart';

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
      appBar: AppBar(title: const Text('스케줄 생성 규칙')),
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

// ── 우선순위 항목 모델 ──

class _PriorityItem {
  _PriorityItem({required this.key, required this.label});

  final String key;
  final String label;
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

  // ── 원티드 우선순위 ──
  late List<_PriorityItem> _wantedPriorityOrder;

  // ── 숙련도 배치 고려 ──
  late bool _considerSkillLevel;

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

    _considerSkillLevel =
        ((ruleMap['consider_skill_level'] ?? {})['enabled'] as bool?) ??
            false;

    // 원티드 우선순위 복원
    final savedOrder =
        (ruleMap['wanted_priority_order'] ?? {})['order'] as List?;
    final defaultOrder = [
      _PriorityItem(key: 'annual_leave', label: '연차 / 법정휴가'),
      _PriorityItem(key: 'night_dedicated', label: '나이트전담 우선'),
      _PriorityItem(key: 'fairness_rest', label: '휴무배려'),
      _PriorityItem(key: 'fairness_equal', label: '균등배분'),
    ];

    if (savedOrder != null && savedOrder.isNotEmpty) {
      final keyToDefault = {
        for (final d in defaultOrder) d.key: d,
      };
      _wantedPriorityOrder = savedOrder
          .whereType<String>()
          .where((k) => keyToDefault.containsKey(k))
          .map((k) => keyToDefault[k]!)
          .toList();
      for (final d in defaultOrder) {
        if (!_wantedPriorityOrder.any((p) => p.key == d.key)) {
          _wantedPriorityOrder.add(d);
        }
      }
    } else {
      _wantedPriorityOrder = defaultOrder;
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
          'consider_skill_level',
          {'enabled': _considerSkillLevel},
        ),
        notifier.upsertRule(
          'wanted_priority_order',
          {
            'order': _wantedPriorityOrder
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

  void _showUnsavedDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('저장하지 않은 변경사항'),
        content: const Text('변경사항을 저장하지 않고 나가시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('나가기'),
          ),
        ],
      ),
    );
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 하드 패턴 금지 ──
            _SectionHeader(
              title: '패턴 금지 (필수)',
              subtitle: '위반 시 해당 배정을 절대 허용하지 않습니다',
            ),
            const SizedBox(height: AppSpacing.md),
            _RuleCard(
              children: [
                _PatternToggleRow(
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
            _SectionHeader(
              title: '기피 패턴 (권장)',
              subtitle: '가능하면 피하지만, 인력 부족 시 허용됩니다',
            ),
            const SizedBox(height: AppSpacing.md),
            _RuleCard(
              children: [
                _PatternToggleRow(
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
                _PatternToggleRow(
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
                _PatternToggleRow(
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

            // ── 원티드 우선순위 ──
            _SectionHeader(
              title: '원티드 반영 우선순위',
              subtitle: readOnly
                  ? '1번이 가장 높은 우선순위'
                  : '드래그하여 순위 조정 (1번 = 최우선)',
            ),
            const SizedBox(height: AppSpacing.md),

            if (readOnly)
              _RuleCard(
                children: [
                  ..._wantedPriorityOrder.asMap().entries.map((e) {
                    final rank = e.key + 1;
                    return _PriorityReadRow(
                      rank: rank,
                      label: e.value.label,
                    );
                  }),
                ],
              )
            else
              _PriorityReorderCard(
                items: _wantedPriorityOrder,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex -= 1;
                    final item =
                        _wantedPriorityOrder.removeAt(oldIndex);
                    _wantedPriorityOrder.insert(newIndex, item);
                  });
                  _markDirty();
                },
              ),

            const SizedBox(height: AppSpacing.xxl),

            // ── 추가 옵션 ──
            _SectionHeader(
              title: '추가 옵션',
              subtitle: '스케줄 품질에 영향을 주는 설정',
            ),
            const SizedBox(height: AppSpacing.md),
            _RuleCard(
              children: [
                _ToggleRow(
                  label: '숙련도 균형 배치',
                  description: '각 근무에 연차별 멤버가 균형 있게 배치',
                  value: _considerSkillLevel,
                  readOnly: readOnly,
                  onChanged: (v) {
                    setState(() => _considerSkillLevel = v);
                    _markDirty();
                  },
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.xxl),

            // ── 커스텀 규칙 진입 ──
            _SectionHeader(
              title: '커스텀 규칙',
              subtitle: '자연어로 팀 전용 규칙을 추가합니다',
            ),
            const SizedBox(height: AppSpacing.md),
            _RuleCard(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.rule_rounded,
                        size: 20,
                        color: AppColors.tertiary,
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
                  style: const TextStyle(color: AppColors.error),
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
    );
  }
}

// ── 공통 위젯 ──

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.subtitle,
  });

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            subtitle!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _RuleCard extends StatelessWidget {
  const _RuleCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Column(children: children),
      ),
    );
  }
}

class _PatternToggleRow extends StatelessWidget {
  const _PatternToggleRow({
    required this.pattern,
    required this.description,
    required this.value,
    required this.isHard,
    required this.readOnly,
    required this.onChanged,
  });

  final String pattern;
  final String description;
  final bool value;
  final bool isHard;
  final bool readOnly;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = isHard ? AppColors.error : AppColors.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xxs,
            ),
            decoration: BoxDecoration(
              color: value
                  ? activeColor.withValues(alpha: 0.12)
                  : AppColors.textSecondaryLight
                      .withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              pattern,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: value
                    ? activeColor
                    : AppColors.textSecondaryLight,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondaryLight,
              ),
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: readOnly ? null : onChanged,
            activeColor: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    this.description,
    required this.value,
    required this.readOnly,
    required this.onChanged,
  });

  final String label;
  final String? description;
  final bool value;
  final bool readOnly;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (description != null)
                  Text(
                    description!,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: readOnly ? null : onChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

// ── 우선순위 reorder 카드 ──

class _PriorityReorderCard extends StatelessWidget {
  const _PriorityReorderCard({
    required this.items,
    required this.onReorder,
  });

  final List<_PriorityItem> items;
  final ReorderCallback onReorder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        itemCount: items.length,
        onReorder: onReorder,
        proxyDecorator: (child, index, animation) => Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          child: child,
        ),
        itemBuilder: (context, index) {
          final item = items[index];
          final rank = index + 1;
          return ListTile(
            key: ValueKey(item.key),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
            ),
            leading: _RankBadge(rank: rank),
            title: Text(
              item.label,
              style: theme.textTheme.bodyMedium,
            ),
            trailing: ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(
                  Icons.menu,
                  color: AppColors.textSecondaryLight,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PriorityReadRow extends StatelessWidget {
  const _PriorityReadRow({
    required this.rank,
    required this.label,
  });

  final int rank;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          _RankBadge(rank: rank),
          const SizedBox(width: AppSpacing.md),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) {
    final isTop = rank == 1;
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isTop
            ? AppColors.primary.withValues(alpha: 0.15)
            : AppColors.surfaceContainer,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$rank',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: isTop
              ? AppColors.primary
              : AppColors.textSecondaryLight,
        ),
      ),
    );
  }
}
