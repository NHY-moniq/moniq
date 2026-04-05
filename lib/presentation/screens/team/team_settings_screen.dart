import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/models/shift_rule_model.dart';
import 'package:moniq/data/models/shift_type_model.dart';
import 'package:moniq/presentation/screens/team/shift_types_list_widgets.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/team_detail_viewmodel.dart';
import 'package:moniq/presentation/widgets/common/moniq_error_view.dart';
import 'package:moniq/presentation/widgets/common/moniq_loading_view.dart';

class TeamSettingsScreen extends HookConsumerWidget {
  const TeamSettingsScreen({
    super.key,
    required this.teamId,
  });

  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync =
        ref.watch(teamDetailViewModelProvider(teamId));

    return Scaffold(
      appBar: AppBar(title: const Text('팀 상세 설정')),
      body: detailAsync.when(
        loading: () => const MoniqLoadingView(),
        error: (e, _) => MoniqErrorView(
          message: '설정을 불러올 수 없습니다',
          onRetry: () => ref.invalidate(
            teamDetailViewModelProvider(teamId),
          ),
        ),
        data: (state) => _SettingsBody(
          teamId: teamId,
          shiftTypes: state.shiftTypes,
          rules: state.rules,
          isAdmin: state.isAdmin,
        ),
      ),
    );
  }
}

class _SettingsBody extends ConsumerStatefulWidget {
  const _SettingsBody({
    required this.teamId,
    required this.shiftTypes,
    required this.rules,
    required this.isAdmin,
  });

  final String teamId;
  final List<ShiftTypeModel> shiftTypes;
  final List<ShiftRuleModel> rules;
  final bool isAdmin;

  @override
  ConsumerState<_SettingsBody> createState() =>
      _SettingsBodyState();
}

class _SettingsBodyState extends ConsumerState<_SettingsBody> {
  late int _maxConsecutiveWorkDays;
  late int _maxConsecutiveNightShifts;
  late int _minWeeklyOffDays;
  late bool _noNightThenDay;
  late bool _noNightThenEvening;
  late bool _noEveningThenDay;

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

    _maxConsecutiveWorkDays =
        ((ruleMap['max_consecutive_work_days'] ??
                    {})['days'] as num?)
                ?.toInt() ??
            5;
    _maxConsecutiveNightShifts =
        ((ruleMap['max_consecutive_night_shifts'] ??
                    {})['days'] as num?)
                ?.toInt() ??
            5;
    _minWeeklyOffDays =
        ((ruleMap['min_weekly_off_days'] ??
                    {})['days'] as num?)
                ?.toInt() ??
            2;
    _noNightThenDay =
        ((ruleMap['no_night_then_day'] ??
                {})['enabled'] as bool?) ??
            true;
    _noNightThenEvening =
        ((ruleMap['no_night_then_evening'] ??
                {})['enabled'] as bool?) ??
            true;
    _noEveningThenDay =
        ((ruleMap['no_evening_then_day'] ??
                {})['enabled'] as bool?) ??
            true;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final notifier = ref.read(
      teamDetailViewModelProvider(widget.teamId).notifier,
    );

    await Future.wait([
      notifier.upsertRule(
        'max_consecutive_work_days',
        {'days': _maxConsecutiveWorkDays},
      ),
      notifier.upsertRule(
        'max_consecutive_night_shifts',
        {'days': _maxConsecutiveNightShifts},
      ),
      notifier.upsertRule(
        'min_weekly_off_days',
        {'days': _minWeeklyOffDays},
      ),
      notifier.upsertRule(
        'no_night_then_day',
        {'enabled': _noNightThenDay},
      ),
      notifier.upsertRule(
        'no_night_then_evening',
        {'enabled': _noNightThenEvening},
      ),
      notifier.upsertRule(
        'no_evening_then_day',
        {'enabled': _noEveningThenDay},
      ),
    ]);

    setState(() {
      _saving = false;
      _isDirty = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('설정이 저장되었습니다')),
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
            // ── 근무 유형 섹션 ──
            SectionHeader(
              title: '근무 유형',
              subtitle: '팀에서 사용하는 근무 유형을 관리합니다',
            ),
            const SizedBox(height: AppSpacing.sm),
            ShiftTypesList(
              shiftTypes: widget.shiftTypes,
              isAdmin: widget.isAdmin,
              teamId: widget.teamId,
            ),

            const SizedBox(height: AppSpacing.xxxl),

            // ── 고정 규칙 섹션 ──
            SectionHeader(
              title: '고정 규칙',
              subtitle:
                  '병원에서 정해진 필수 규칙입니다. '
                  '한번 설정하면 거의 변하지 않습니다.',
            ),
            const SizedBox(height: AppSpacing.md),

            // 숫자 규칙들
            RuleCard(
              children: [
                NumberRuleRow(
                  label: '최대 연속 근무일 수',
                  value: _maxConsecutiveWorkDays,
                  suffix: '일',
                  readOnly: readOnly,
                  onChanged: (v) {
                    setState(
                      () => _maxConsecutiveWorkDays = v,
                    );
                    _markDirty();
                  },
                ),
                const Divider(height: 1),
                NumberRuleRow(
                  label: '최대 연속 야간(N) 근무 수',
                  value: _maxConsecutiveNightShifts,
                  suffix: '일',
                  readOnly: readOnly,
                  onChanged: (v) {
                    setState(
                      () => _maxConsecutiveNightShifts = v,
                    );
                    _markDirty();
                  },
                ),
                const Divider(height: 1),
                NumberRuleRow(
                  label: '주당 최소 휴무 일수',
                  value: _minWeeklyOffDays,
                  suffix: '일',
                  readOnly: readOnly,
                  onChanged: (v) {
                    setState(
                      () => _minWeeklyOffDays = v,
                    );
                    _markDirty();
                  },
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),

            // 금지 패턴 규칙들
            RuleCard(
              children: [
                ToggleRuleRow(
                  label: '야간→주간 금지 (N→D)',
                  description:
                      '야간 근무 다음날 주간 근무 불가',
                  value: _noNightThenDay,
                  readOnly: readOnly,
                  onChanged: (v) {
                    setState(() => _noNightThenDay = v);
                    _markDirty();
                  },
                ),
                const Divider(height: 1),
                ToggleRuleRow(
                  label: '야간→저녁 금지 (N→E)',
                  description:
                      '야간 근무 다음날 저녁 근무 불가',
                  value: _noNightThenEvening,
                  readOnly: readOnly,
                  onChanged: (v) {
                    setState(
                      () => _noNightThenEvening = v,
                    );
                    _markDirty();
                  },
                ),
                const Divider(height: 1),
                ToggleRuleRow(
                  label: '저녁→주간 금지 (E→D)',
                  description:
                      '저녁 근무 다음날 주간 근무 불가',
                  value: _noEveningThenDay,
                  readOnly: readOnly,
                  onChanged: (v) {
                    setState(
                      () => _noEveningThenDay = v,
                    );
                    _markDirty();
                  },
                ),
              ],
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
                      color: theme.colorScheme.onSurfaceVariant,
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

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
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
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class RuleCard extends StatelessWidget {
  const RuleCard({super.key, required this.children});

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

class NumberRuleRow extends StatelessWidget {
  const NumberRuleRow({
    super.key,
    required this.label,
    required this.value,
    required this.suffix,
    required this.readOnly,
    required this.onChanged,
  });

  final String label;
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
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
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
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class ToggleRuleRow extends StatelessWidget {
  const ToggleRuleRow({
    super.key,
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
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                  ),
              ],
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
