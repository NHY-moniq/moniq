import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/models/shift_rule_model.dart';
import 'package:moniq/data/models/team_member_with_user.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/team_detail_viewmodel.dart';
import 'package:moniq/presentation/widgets/common/moniq_error_view.dart';
import 'package:moniq/presentation/widgets/common/moniq_loading_view.dart';

/// 스케줄 생성 시 적용되는 규칙 설정 페이지
/// 생성할 때마다 변경될 수 있는 규칙들
class ScheduleRulesScreen extends HookConsumerWidget {
  const ScheduleRulesScreen({
    super.key,
    required this.teamId,
  });

  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync =
        ref.watch(teamDetailViewModelProvider(teamId));

    return Scaffold(
      appBar: AppBar(title: const Text('스케줄 생성 규칙')),
      body: detailAsync.when(
        loading: () => const MoniqLoadingView(),
        error: (e, _) => MoniqErrorView(
          message: '규칙을 불러올 수 없습니다',
          onRetry: () => ref.invalidate(
            teamDetailViewModelProvider(teamId),
          ),
        ),
        data: (state) => _RulesBody(
          teamId: teamId,
          rules: state.rules,
          members: state.members,
          isAdmin: state.isAdmin,
        ),
      ),
    );
  }
}

class _RulesBody extends ConsumerStatefulWidget {
  const _RulesBody({
    required this.teamId,
    required this.rules,
    required this.members,
    required this.isAdmin,
  });

  final String teamId;
  final List<ShiftRuleModel> rules;
  final List<TeamMemberWithUser> members;
  final bool isAdmin;

  @override
  ConsumerState<_RulesBody> createState() => _RulesBodyState();
}

class _RulesBodyState extends ConsumerState<_RulesBody> {
  // NOD 불가 (Night-Off-Day 금지)
  late bool _nodDisabled;

  // 기피근무 우선순위 (높을수록 우선 반영)
  late int _avoidShiftPriority;

  // 나이트 인터벌 (나이트 근무 사이 최소 간격)
  late int _nightInterval;

  // 숙련도 고려
  late bool _considerSkillLevel;

  // 원티드(희망근무) 선정 우선순위
  late int _wantedPriority;

  // 나이트 전담 간호사 목록
  late List<String> _nightDedicatedNurseIds;

  bool _isDirty = false;
  bool _saving = false;

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
        ((ruleMap['nod_disabled'] ?? {})['enabled'] as bool?) ??
            true;
    _avoidShiftPriority =
        ((ruleMap['avoid_shift_priority'] ??
                    {})['priority'] as num?)
                ?.toInt() ??
            3;
    _nightInterval =
        ((ruleMap['night_interval'] ?? {})['days'] as num?)
                ?.toInt() ??
            2;
    _considerSkillLevel =
        ((ruleMap['consider_skill_level'] ??
                    {})['enabled'] as bool?) ??
            false;
    _wantedPriority =
        ((ruleMap['wanted_priority'] ??
                    {})['priority'] as num?)
                ?.toInt() ??
            3;
    _nightDedicatedNurseIds = List<String>.from(
      (ruleMap['night_dedicated_nurses'] ??
              {})['user_ids'] as List? ??
          [],
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final notifier = ref.read(
      teamDetailViewModelProvider(widget.teamId).notifier,
    );

    await Future.wait([
      notifier.upsertRule(
        'nod_disabled',
        {'enabled': _nodDisabled},
      ),
      notifier.upsertRule(
        'avoid_shift_priority',
        {'priority': _avoidShiftPriority},
      ),
      notifier.upsertRule(
        'night_interval',
        {'days': _nightInterval},
      ),
      notifier.upsertRule(
        'consider_skill_level',
        {'enabled': _considerSkillLevel},
      ),
      notifier.upsertRule(
        'wanted_priority',
        {'priority': _wantedPriority},
      ),
      notifier.upsertRule(
        'night_dedicated_nurses',
        {'user_ids': _nightDedicatedNurseIds},
      ),
    ]);

    setState(() {
      _saving = false;
      _isDirty = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('규칙이 저장되었습니다')),
      );
    }
  }

  void _markDirty() {
    if (!_isDirty) setState(() => _isDirty = true);
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
            // ── 근무 패턴 규칙 ──
            _SectionHeader(
              title: '근무 패턴',
              subtitle: '스케줄 생성 시 적용되는 근무 패턴 규칙',
            ),
            const SizedBox(height: AppSpacing.md),

            _RuleCard(
              children: [
                _ToggleRow(
                  label: 'NOD 불가',
                  description:
                      '나이트(N) 후 오프(O) 후 데이(D) 패턴 금지',
                  value: _nodDisabled,
                  readOnly: readOnly,
                  onChanged: (v) {
                    setState(() => _nodDisabled = v);
                    _markDirty();
                  },
                ),
                const Divider(height: 1),
                _NumberRow(
                  label: '나이트 인터벌',
                  description:
                      '나이트 근무 사이 최소 간격',
                  value: _nightInterval,
                  suffix: '일',
                  readOnly: readOnly,
                  onChanged: (v) {
                    setState(() => _nightInterval = v);
                    _markDirty();
                  },
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.xxl),

            // ── 우선순위 설정 ──
            _SectionHeader(
              title: '우선순위',
              subtitle: '생성 알고리즘에서 각 항목의 반영 우선순위',
            ),
            const SizedBox(height: AppSpacing.md),

            _RuleCard(
              children: [
                _PriorityRow(
                  label: '기피근무 우선순위',
                  description:
                      '기피 신청한 근무를 피하는 우선도',
                  value: _avoidShiftPriority,
                  readOnly: readOnly,
                  onChanged: (v) {
                    setState(() => _avoidShiftPriority = v);
                    _markDirty();
                  },
                ),
                const Divider(height: 1),
                _PriorityRow(
                  label: '희망근무 우선순위',
                  description:
                      '희망 신청한 근무를 반영하는 우선도',
                  value: _wantedPriority,
                  readOnly: readOnly,
                  onChanged: (v) {
                    setState(() => _wantedPriority = v);
                    _markDirty();
                  },
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.xxl),

            // ── 추가 옵션 ──
            _SectionHeader(
              title: '추가 옵션',
              subtitle: '스케줄 품질에 영향을 주는 추가 설정',
            ),
            const SizedBox(height: AppSpacing.md),

            _RuleCard(
              children: [
                _ToggleRow(
                  label: '숙련도 고려',
                  description:
                      '간호사 숙련도를 반영하여 균형 잡힌 배치',
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

            // ── 나이트 전담 간호사 ──
            _SectionHeader(
              title: '나이트 전담 간호사',
              subtitle:
                  '나이트 근무만 배정되는 간호사를 지정합니다',
            ),
            const SizedBox(height: AppSpacing.md),

            _NightDedicatedSection(
              members: widget.members,
              selectedIds: _nightDedicatedNurseIds,
              readOnly: readOnly,
              onChanged: (ids) {
                setState(
                    () => _nightDedicatedNurseIds = ids);
                _markDirty();
              },
            ),

            const SizedBox(height: AppSpacing.xxl),

            // 저장 버튼
            if (widget.isAdmin)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      _saving || !_isDirty ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          _isDirty ? '저장' : '변경사항 없음',
                        ),
                ),
              ),

            if (!widget.isAdmin)
              Center(
                child: Padding(
                  padding:
                      const EdgeInsets.all(AppSpacing.lg),
                  child: Text(
                    '관리자만 설정을 수정할 수 있습니다',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                ),
              ),

            const SizedBox(height: AppSpacing.xxxl),
          ],
        ),
      ),
    );
  }

  void _showUnsavedDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('저장하지 않은 변경사항'),
        content:
            const Text('변경사항을 저장하지 않고 나가시겠습니까?'),
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
}

// ── 공통 위젯들 ──

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
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            subtitle!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondaryLight,
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
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style:
                      Theme.of(context).textTheme.bodyMedium,
                ),
                if (description != null)
                  Text(
                    description!,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                          color:
                              AppColors.textSecondaryLight,
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

class _NumberRow extends StatelessWidget {
  const _NumberRow({
    required this.label,
    this.description,
    required this.value,
    required this.suffix,
    required this.readOnly,
    required this.onChanged,
  });

  final String label;
  final String? description;
  final int value;
  final String suffix;
  final bool readOnly;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style:
                      Theme.of(context).textTheme.bodyMedium,
                ),
                if (description != null)
                  Text(
                    description!,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                          color:
                              AppColors.textSecondaryLight,
                        ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.remove_circle_outline,
              size: 20,
            ),
            onPressed: readOnly || value <= 1
                ? null
                : () => onChanged(value - 1),
            visualDensity: VisualDensity.compact,
          ),
          SizedBox(
            width: 28,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.add_circle_outline,
              size: 20,
            ),
            onPressed:
                readOnly ? null : () => onChanged(value + 1),
            visualDensity: VisualDensity.compact,
          ),
          SizedBox(
            width: 24,
            child: Text(
              suffix,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(
                    color: AppColors.textSecondaryLight,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 우선순위: 1(낮음) ~ 5(높음) 슬라이더
class _PriorityRow extends StatelessWidget {
  const _PriorityRow({
    required this.label,
    this.description,
    required this.value,
    required this.readOnly,
    required this.onChanged,
  });

  final String label;
  final String? description;
  final int value;
  final bool readOnly;
  final ValueChanged<int> onChanged;

  String _priorityLabel(int v) {
    switch (v) {
      case 1:
        return '매우 낮음';
      case 2:
        return '낮음';
      case 3:
        return '보통';
      case 4:
        return '높음';
      case 5:
        return '매우 높음';
      default:
        return '보통';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.sm,
      ),
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
                    color: AppColors.textSecondaryLight,
                  ),
            ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: value.toDouble(),
                  min: 1,
                  max: 5,
                  divisions: 4,
                  label: _priorityLabel(value),
                  onChanged: readOnly
                      ? null
                      : (v) => onChanged(v.round()),
                  activeColor: AppColors.primary,
                ),
              ),
              SizedBox(
                width: 72,
                child: Text(
                  _priorityLabel(value),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 나이트 전담 간호사 선택 섹션
class _NightDedicatedSection extends StatelessWidget {
  const _NightDedicatedSection({
    required this.members,
    required this.selectedIds,
    required this.readOnly,
    required this.onChanged,
  });

  final List<TeamMemberWithUser> members;
  final List<String> selectedIds;
  final bool readOnly;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Center(
            child: Text(
              '멤버가 없습니다',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                    color: AppColors.textSecondaryLight,
                  ),
            ),
          ),
        ),
      );
    }

    return Card(
      child: Column(
        children: members.map((m) {
          final isSelected =
              selectedIds.contains(m.userId);
          return CheckboxListTile(
            value: isSelected,
            onChanged: readOnly
                ? null
                : (val) {
                    final newIds =
                        List<String>.from(selectedIds);
                    if (val == true) {
                      newIds.add(m.userId);
                    } else {
                      newIds.remove(m.userId);
                    }
                    onChanged(newIds);
                  },
            title: Text(m.displayName),
            subtitle: Text(
              m.role == 'admin' ? '관리자' : '멤버',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(
                    color: AppColors.textSecondaryLight,
                  ),
            ),
            secondary: CircleAvatar(
              radius: 18,
              backgroundColor:
                  AppColors.primary.withValues(alpha: 0.1),
              child: Text(
                m.displayName.characters.first,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
            activeColor: AppColors.primary,
            dense: true,
          );
        }).toList(),
      ),
    );
  }
}
