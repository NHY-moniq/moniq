import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/core/utils/color_utils.dart';
import 'package:moniq/data/models/shift_rule_model.dart';
import 'package:moniq/data/models/shift_type_model.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/team_detail_viewmodel.dart';
import 'package:moniq/presentation/widgets/common/moniq_error_view.dart';
import 'package:moniq/presentation/widgets/common/moniq_loading_view.dart';

class RulesScreen extends HookConsumerWidget {
  const RulesScreen({super.key, required this.teamId});

  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(teamDetailViewModelProvider(teamId));

    return Scaffold(
      appBar: AppBar(title: const Text('규칙 설정')),
      body: detailAsync.when(
        loading: () => const MoniqLoadingView(),
        error: (e, _) => MoniqErrorView(
          message: '규칙 정보를 불러올 수 없습니다',
          onRetry: () => ref.invalidate(teamDetailViewModelProvider(teamId)),
        ),
        data: (state) => _RulesForm(
          teamId: teamId,
          shiftTypes: state.shiftTypes.where((t) => t.isActive).toList(),
          rules: state.rules,
          isAdmin: state.isAdmin,
        ),
      ),
    );
  }
}

class _RulesForm extends ConsumerStatefulWidget {
  const _RulesForm({
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
  ConsumerState<_RulesForm> createState() => _RulesFormState();
}

class _RulesFormState extends ConsumerState<_RulesForm> {
  // min_staffing: code → count
  late Map<String, int> _minStaffing;
  // max_staffing: code → count
  late Map<String, int> _maxStaffing;
  // constraints
  late int _maxConsecutiveWorkDays;
  late int _maxMonthlyShifts;
  late int _maxMonthlyNightShifts;
  late int _minRestAfterNight;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadFromRules();
  }

  void _loadFromRules() {
    final ruleMap = {for (final r in widget.rules) r.ruleType: r.ruleValue};

    final minStaffRaw = ruleMap['min_staffing'] ?? {};
    final maxStaffRaw = ruleMap['max_staffing'] ?? {};

    _minStaffing = {};
    _maxStaffing = {};
    for (final t in widget.shiftTypes) {
      _minStaffing[t.code] = (minStaffRaw[t.code] as num?)?.toInt() ?? 0;
      _maxStaffing[t.code] = (maxStaffRaw[t.code] as num?)?.toInt() ?? 0;
    }

    _maxConsecutiveWorkDays =
        ((ruleMap['max_consecutive_work_days'] ?? {})['days'] as num?)
                ?.toInt() ??
            5;
    _maxMonthlyShifts =
        ((ruleMap['max_monthly_shifts'] ?? {})['count'] as num?)?.toInt() ?? 0;
    _maxMonthlyNightShifts =
        ((ruleMap['max_monthly_night_shifts'] ?? {})['count'] as num?)
                ?.toInt() ??
            0;
    _minRestAfterNight =
        ((ruleMap['min_rest_after_night'] ?? {})['hours'] as num?)?.toInt() ??
            8;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final notifier =
        ref.read(teamDetailViewModelProvider(widget.teamId).notifier);

    await Future.wait([
      notifier.upsertRule('min_staffing',
          {for (final e in _minStaffing.entries) e.key: e.value}),
      notifier.upsertRule('max_staffing',
          {for (final e in _maxStaffing.entries) e.key: e.value}),
      notifier
          .upsertRule('max_consecutive_work_days', {'days': _maxConsecutiveWorkDays}),
      notifier.upsertRule('max_monthly_shifts', {'count': _maxMonthlyShifts}),
      notifier.upsertRule(
          'max_monthly_night_shifts', {'count': _maxMonthlyNightShifts}),
      notifier.upsertRule('min_rest_after_night', {'hours': _minRestAfterNight}),
    ]);

    setState(() => _saving = false);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('규칙이 저장되었습니다')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final readOnly = !widget.isAdmin;

    return SingleChildScrollView(
      padding: AppSpacing.screenAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 최소 인원
          _SectionCard(
            title: '최소 인원',
            subtitle: '근무 유형별 최소 배치 인원',
            child: Column(
              children: widget.shiftTypes
                  .where((t) => t.code != 'O')
                  .map((t) => _StaffingRow(
                        shiftType: t,
                        value: _minStaffing[t.code] ?? 0,
                        readOnly: readOnly,
                        onChanged: (v) =>
                            setState(() => _minStaffing[t.code] = v),
                      ))
                  .toList(),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // 최대 인원
          _SectionCard(
            title: '최대 인원 (선택)',
            subtitle: '0이면 제한 없음',
            child: Column(
              children: widget.shiftTypes
                  .where((t) => t.code != 'O')
                  .map((t) => _StaffingRow(
                        shiftType: t,
                        value: _maxStaffing[t.code] ?? 0,
                        readOnly: readOnly,
                        onChanged: (v) =>
                            setState(() => _maxStaffing[t.code] = v),
                      ))
                  .toList(),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // 제약 조건
          _SectionCard(
            title: '근무자 제약 조건',
            child: Column(
              children: [
                _NumberRow(
                  label: '최대 연속 근무일',
                  value: _maxConsecutiveWorkDays,
                  suffix: '일',
                  readOnly: readOnly,
                  onChanged: (v) =>
                      setState(() => _maxConsecutiveWorkDays = v),
                ),
                const Divider(height: 1),
                _NumberRow(
                  label: '월 최대 근무 횟수',
                  value: _maxMonthlyShifts,
                  suffix: '회 (0=무제한)',
                  readOnly: readOnly,
                  onChanged: (v) =>
                      setState(() => _maxMonthlyShifts = v),
                ),
                const Divider(height: 1),
                _NumberRow(
                  label: '월 최대 나이트',
                  value: _maxMonthlyNightShifts,
                  suffix: '회 (0=무제한)',
                  readOnly: readOnly,
                  onChanged: (v) =>
                      setState(() => _maxMonthlyNightShifts = v),
                ),
                const Divider(height: 1),
                _NumberRow(
                  label: '나이트 후 최소 휴식',
                  value: _minRestAfterNight,
                  suffix: '시간',
                  readOnly: readOnly,
                  onChanged: (v) =>
                      setState(() => _minRestAfterNight = v),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xxl),

          if (widget.isAdmin)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('저장'),
              ),
            ),

          if (!widget.isAdmin)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text('관리자만 규칙을 수정할 수 있습니다',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: AppColors.textSecondaryLight)),
              ),
            ),

          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    this.subtitle,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.xxs),
              Text(subtitle!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.textSecondaryLight)),
            ],
            const SizedBox(height: AppSpacing.md),
            child,
          ],
        ),
      ),
    );
  }
}

class _StaffingRow extends StatelessWidget {
  const _StaffingRow({
    required this.shiftType,
    required this.value,
    required this.readOnly,
    required this.onChanged,
  });

  final ShiftTypeModel shiftType;
  final int value;
  final bool readOnly;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: parseHexColor(shiftType.color),
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: Text(shiftType.code,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(shiftType.name)),
          _CounterWidget(
            value: value,
            readOnly: readOnly,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _NumberRow extends StatelessWidget {
  const _NumberRow({
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
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          _CounterWidget(
            value: value,
            readOnly: readOnly,
            onChanged: onChanged,
          ),
          const SizedBox(width: AppSpacing.xs),
          SizedBox(
            width: 80,
            child: Text(suffix,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondaryLight)),
          ),
        ],
      ),
    );
  }
}

class _CounterWidget extends StatelessWidget {
  const _CounterWidget({
    required this.value,
    required this.readOnly,
    required this.onChanged,
  });

  final int value;
  final bool readOnly;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.remove_circle_outline, size: 20),
          onPressed: readOnly || value <= 0
              ? null
              : () => onChanged(value - 1),
          visualDensity: VisualDensity.compact,
        ),
        SizedBox(
          width: 28,
          child: Text('$value',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 16)),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline, size: 20),
          onPressed: readOnly ? null : () => onChanged(value + 1),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}
