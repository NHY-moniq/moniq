import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/core/utils/color_utils.dart';
import 'package:moniq/core/utils/time_utils.dart';
import 'package:moniq/data/models/shift_rule_model.dart';
import 'package:moniq/data/models/shift_type_model.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
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
            _SectionHeader(
              title: '근무 유형',
              subtitle: '팀에서 사용하는 근무 유형을 관리합니다',
            ),
            const SizedBox(height: AppSpacing.sm),
            _ShiftTypesList(
              shiftTypes: widget.shiftTypes,
              isAdmin: widget.isAdmin,
              teamId: widget.teamId,
            ),

            const SizedBox(height: AppSpacing.xxxl),

            // ── 고정 규칙 섹션 ──
            _SectionHeader(
              title: '고정 규칙',
              subtitle:
                  '병원에서 정해진 필수 규칙입니다. '
                  '한번 설정하면 거의 변하지 않습니다.',
            ),
            const SizedBox(height: AppSpacing.md),

            // 숫자 규칙들
            _RuleCard(
              children: [
                _NumberRuleRow(
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
                _NumberRuleRow(
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
                _NumberRuleRow(
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
            _RuleCard(
              children: [
                _ToggleRuleRow(
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
                _ToggleRuleRow(
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
                _ToggleRuleRow(
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

class _NumberRuleRow extends StatelessWidget {
  const _NumberRuleRow({
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
                    color: AppColors.textSecondaryLight,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleRuleRow extends StatelessWidget {
  const _ToggleRuleRow({
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

// ── 근무 유형 섹션 ──

/// 기본 근무 유형 템플릿
class _ShiftTemplate {
  const _ShiftTemplate({
    required this.name,
    required this.code,
    required this.color,
    required this.startTime,
    required this.endTime,
    required this.description,
    required this.icon,
  });

  final String name;
  final String code;
  final String color;
  final String startTime;
  final String endTime;
  final String description;
  final IconData icon;
}

const _defaultTemplates = [
  _ShiftTemplate(
    name: '데이',
    code: 'D',
    color: '#F0C040',
    startTime: '07:00:00',
    endTime: '15:00:00',
    description: '오전 7시 ~ 오후 3시',
    icon: Icons.wb_sunny_rounded,
  ),
  _ShiftTemplate(
    name: '이브닝',
    code: 'E',
    color: '#E8923A',
    startTime: '14:00:00',
    endTime: '22:00:00',
    description: '오후 2시 ~ 밤 10시',
    icon: Icons.wb_twilight_rounded,
  ),
  _ShiftTemplate(
    name: '나이트',
    code: 'N',
    color: '#5A8BB5',
    startTime: '21:00:00',
    endTime: '08:00:00',
    description: '밤 9시 ~ 오전 8시',
    icon: Icons.nightlight_round,
  ),
];

const _presetColors = [
  '#F0C040',
  '#E8923A',
  '#5A8BB5',
  '#A0AEC0',
  '#48BB78',
  '#ED64A6',
  '#9F7AEA',
  '#ED8936',
];

class _ShiftTypesList extends ConsumerWidget {
  const _ShiftTypesList({
    required this.shiftTypes,
    required this.isAdmin,
    required this.teamId,
  });

  final List<ShiftTypeModel> shiftTypes;
  final bool isAdmin;
  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (shiftTypes.isEmpty && isAdmin) {
      return _EmptyShiftTypesView(
        teamId: teamId,
      );
    }

    if (shiftTypes.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Center(
            child: Text(
              '등록된 근무 유형이 없습니다',
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

    return Column(
      children: [
        ...shiftTypes.map((t) => _ShiftTypeCard(
              shiftType: t,
              isAdmin: isAdmin,
              teamId: teamId,
            )),
        if (isAdmin) ...[
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showAddSheet(context, ref),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('근무 유형 추가'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(
                  color: AppColors.primary,
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.borderRadiusMd,
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.md,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _showAddSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      builder: (ctx) => _ShiftTypeAddSheet(
        teamId: teamId,
        existingCodes: shiftTypes.map((t) => t.code).toSet(),
      ),
    );
  }
}

/// 빈 상태: 기본 근무 유형 템플릿 카드 3개
class _EmptyShiftTypesView extends ConsumerStatefulWidget {
  const _EmptyShiftTypesView({required this.teamId});

  final String teamId;

  @override
  ConsumerState<_EmptyShiftTypesView> createState() =>
      _EmptyShiftTypesViewState();
}

class _EmptyShiftTypesViewState
    extends ConsumerState<_EmptyShiftTypesView> {
  bool _loading = false;

  Future<void> _addAllDefaults() async {
    setState(() => _loading = true);
    final notifier = ref.read(
      teamDetailViewModelProvider(widget.teamId).notifier,
    );

    for (var i = 0; i < _defaultTemplates.length; i++) {
      final t = _defaultTemplates[i];
      await notifier.createShiftType(
        name: t.name,
        code: t.code,
        startTime: t.startTime,
        endTime: t.endTime,
        color: t.color,
      );
    }
    if (mounted) setState(() => _loading = false);
  }

  void _showTemplateEditSheet(
      BuildContext context, _ShiftTemplate template) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      builder: (ctx) => _ShiftTypeCreateFromTemplateSheet(
        teamId: widget.teamId,
        template: template,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Text(
          '기본 근무 유형을 추가해보세요',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondaryLight,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // 3개 템플릿 카드 (탭하면 편집 후 추가)
        Row(
          children: _defaultTemplates
              .map(
                (t) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                    ),
                    child: _ShiftTemplateCard(
                      template: t,
                      onTap: () =>
                          _showTemplateEditSheet(
                              context, t),
                    ),
                  ),
                ),
              )
              .toList(),
        ),

        const SizedBox(height: AppSpacing.xl),

        // 한번에 추가 버튼
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _loading ? null : _addAllDefaults,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(
                    Icons.auto_awesome_rounded,
                    size: 20,
                  ),
            label: Text(
              _loading ? '추가 중...' : '기본 3개 한번에 추가',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.md,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.borderRadiusMd,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 템플릿 미리보기 카드 (통통 튀는 애니메이션 아이콘)
class _ShiftTemplateCard extends StatelessWidget {
  const _ShiftTemplateCard({
    required this.template,
    required this.onTap,
  });

  final _ShiftTemplate template;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = parseHexColor(template.color);

    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.borderRadiusLg,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.lg,
            horizontal: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: AppRadius.borderRadiusLg,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withValues(alpha: 0.15),
                color.withValues(alpha: 0.05),
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 애니메이션 아이콘
              _BouncyShiftIcon(
                icon: template.icon,
                color: color,
                code: template.code,
              ),
              const SizedBox(height: AppSpacing.sm),

              // 이름
              Text(
                template.name,
                style:
                    theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),

              // 시간
              Text(
                template.description,
                style:
                    theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondaryLight,
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: AppSpacing.xs),

              // 탭 힌트
              Text(
                '탭하여 편집',
                style:
                    theme.textTheme.labelSmall?.copyWith(
                  color: color.withValues(alpha: 0.6),
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 템플릿 기반 생성 시트 (편집 가능)
class _ShiftTypeCreateFromTemplateSheet
    extends ConsumerStatefulWidget {
  const _ShiftTypeCreateFromTemplateSheet({
    required this.teamId,
    required this.template,
  });

  final String teamId;
  final _ShiftTemplate template;

  @override
  ConsumerState<_ShiftTypeCreateFromTemplateSheet>
      createState() =>
          _ShiftTypeCreateFromTemplateSheetState();
}

class _ShiftTypeCreateFromTemplateSheetState
    extends ConsumerState<
        _ShiftTypeCreateFromTemplateSheet> {
  late final TextEditingController _nameC;
  late final TextEditingController _codeC;
  late final TextEditingController _startC;
  late final TextEditingController _endC;
  late String _selectedColor;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final t = widget.template;
    _nameC = TextEditingController(text: t.name);
    _codeC = TextEditingController(text: t.code);
    _startC = TextEditingController(
      text: formatTimeString(t.startTime),
    );
    _endC = TextEditingController(
      text: formatTimeString(t.endTime),
    );
    _selectedColor = t.color;
  }

  @override
  void dispose() {
    _nameC.dispose();
    _codeC.dispose();
    _startC.dispose();
    _endC.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameC.text.trim();
    final code = _codeC.text.trim();
    if (name.isEmpty || code.isEmpty) return;

    setState(() => _saving = true);
    await ref
        .read(teamDetailViewModelProvider(widget.teamId)
            .notifier)
        .createShiftType(
          name: name,
          code: code,
          startTime: _startC.text.trim().isNotEmpty
              ? '${_startC.text.trim()}:00'
              : null,
          endTime: _endC.text.trim().isNotEmpty
              ? '${_endC.text.trim()}:00'
              : null,
          color: _selectedColor,
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = parseHexColor(widget.template.color);

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.xl,
        bottom:
            MediaQuery.of(context).viewInsets.bottom +
                AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 핸들
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderLight,
                borderRadius:
                    AppRadius.borderRadiusFull,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // 타이틀 + 아이콘
          Row(
            children: [
              _BouncyShiftIcon(
                icon: widget.template.icon,
                color: color,
                code: widget.template.code,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.template.name} 근무 추가',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '기본값이 입력되어 있어요. 수정 후 추가하세요.',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(
                        color:
                            AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),

          _CustomShiftForm(
            nameC: _nameC,
            codeC: _codeC,
            startC: _startC,
            endC: _endC,
            selectedColor: _selectedColor,
            onColorChanged: (c) =>
                setState(() => _selectedColor = c),
          ),
          const SizedBox(height: AppSpacing.xl),

          FilledButton(
            onPressed: _saving ? null : _create,
            style: FilledButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.md,
              ),
            ),
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('추가'),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}

/// 통통 튀는 아이콘 애니메이션
class _BouncyShiftIcon extends StatefulWidget {
  const _BouncyShiftIcon({
    required this.icon,
    required this.color,
    required this.code,
  });

  final IconData icon;
  final Color color;
  final String code;

  @override
  State<_BouncyShiftIcon> createState() =>
      _BouncyShiftIconState();
}

class _BouncyShiftIconState extends State<_BouncyShiftIcon>
    with TickerProviderStateMixin {
  late final AnimationController _bounceController;
  late final AnimationController _glowController;
  late final Animation<double> _bounceAnim;
  late final Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();

    // 바운스: 위아래로 통통
    _bounceController = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: widget.code == 'D'
            ? 1200
            : widget.code == 'E'
                ? 1500
                : 1800,
      ),
    )..repeat(reverse: true);

    _bounceAnim = Tween<double>(begin: 0, end: -8).animate(
      CurvedAnimation(
        parent: _bounceController,
        curve: Curves.easeInOut,
      ),
    );

    // 글로우: 빛나는 효과
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _glowAnim = Tween<double>(begin: 0.3, end: 0.8)
        .animate(CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(
          [_bounceController, _glowController]),
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _bounceAnim.value),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color
                  .withValues(alpha: 0.2),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(
                    alpha: _glowAnim.value,
                  ),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: _buildIcon(),
          ),
        );
      },
    );
  }

  Widget _buildIcon() {
    // 각 근무 유형별 다른 아이콘 스타일
    if (widget.code == 'D') {
      return _buildSunIcon();
    } else if (widget.code == 'E') {
      return _buildSunsetIcon();
    } else {
      return _buildMoonIcon();
    }
  }

  Widget _buildSunIcon() {
    return AnimatedBuilder(
      animation: _bounceController,
      builder: (context, _) {
        final rotation =
            _bounceController.value * 0.3;
        return Transform.rotate(
          angle: rotation,
          child: Icon(
            Icons.wb_sunny_rounded,
            size: 30,
            color: widget.color,
          ),
        );
      },
    );
  }

  Widget _buildSunsetIcon() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(
          Icons.wb_twilight_rounded,
          size: 30,
          color: widget.color,
        ),
        // 작은 반짝이
        AnimatedBuilder(
          animation: _glowController,
          builder: (context, _) {
            return Positioned(
              top: 10,
              right: 10,
              child: Opacity(
                opacity: _glowAnim.value,
                child: Icon(
                  Icons.auto_awesome,
                  size: 12,
                  color: widget.color
                      .withValues(alpha: 0.6),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMoonIcon() {
    return AnimatedBuilder(
      animation: _bounceController,
      builder: (context, _) {
        // 살짝 기울기 변화
        final tilt =
            (_bounceController.value - 0.5) * 0.2;
        return Transform.rotate(
          angle: tilt,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.nightlight_round,
                size: 28,
                color: widget.color,
              ),
              // 별 반짝임
              Positioned(
                top: 8,
                left: 10,
                child: Opacity(
                  opacity: (1 - _bounceController.value)
                      .clamp(0.2, 1.0),
                  child: const Icon(
                    Icons.star_rounded,
                    size: 10,
                    color: Color(0xFFFFD700),
                  ),
                ),
              ),
              Positioned(
                bottom: 10,
                right: 8,
                child: Opacity(
                  opacity: _bounceController.value
                      .clamp(0.2, 1.0),
                  child: const Icon(
                    Icons.star_rounded,
                    size: 8,
                    color: Color(0xFFFFD700),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 기존 근무 유형 카드 (등록된 상태)
class _ShiftTypeCard extends ConsumerWidget {
  const _ShiftTypeCard({
    required this.shiftType,
    required this.isAdmin,
    required this.teamId,
  });

  final ShiftTypeModel shiftType;
  final bool isAdmin;
  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final color = parseHexColor(shiftType.color);
    final timeText = _buildTimeText(shiftType);

    return Padding(
      padding: const EdgeInsets.only(
        bottom: AppSpacing.sm,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isAdmin
              ? () => _showEditSheet(context, ref)
              : null,
          borderRadius: AppRadius.borderRadiusMd,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: AppRadius.borderRadiusMd,
              border: Border.all(
                color: shiftType.isActive
                    ? color.withValues(alpha: 0.3)
                    : AppColors.borderLight,
              ),
              color: shiftType.isActive
                  ? color.withValues(alpha: 0.06)
                  : Colors.grey.withValues(alpha: 0.04),
            ),
            child: Row(
              children: [
                // 코드 뱃지
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: shiftType.isActive
                        ? color
                        : AppColors.textSecondaryLight,
                    borderRadius:
                        AppRadius.borderRadiusMd,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    shiftType.code,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),

                // 이름 + 시간
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        shiftType.name,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: shiftType.isActive
                              ? null
                              : AppColors
                                  .textSecondaryLight,
                          decoration: shiftType.isActive
                              ? null
                              : TextDecoration
                                  .lineThrough,
                        ),
                      ),
                      if (timeText.isNotEmpty)
                        Text(
                          timeText,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(
                            color: AppColors
                                .textSecondaryLight,
                          ),
                        ),
                    ],
                  ),
                ),

                // 활성/비활성 토글
                if (isAdmin)
                  Switch.adaptive(
                    value: shiftType.isActive,
                    onChanged: (val) => ref
                        .read(
                          teamDetailViewModelProvider(
                            teamId,
                          ).notifier,
                        )
                        .toggleShiftTypeActive(
                          shiftType.id,
                          val,
                        ),
                    activeColor: color,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditSheet(
      BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      builder: (ctx) => _ShiftTypeEditSheet(
        teamId: teamId,
        existing: shiftType,
      ),
    );
  }

  String _buildTimeText(ShiftTypeModel t) {
    if (t.startTime == null && t.endTime == null) {
      return '';
    }
    final start = t.startTime != null
        ? formatTimeString(t.startTime!)
        : '';
    final end = t.endTime != null
        ? formatTimeString(t.endTime!)
        : '';
    if (start.isEmpty && end.isEmpty) return '';
    return '$start ~ $end';
  }
}

/// 근무 유형 추가 바텀시트 (템플릿 or 커스텀)
class _ShiftTypeAddSheet extends ConsumerStatefulWidget {
  const _ShiftTypeAddSheet({
    required this.teamId,
    required this.existingCodes,
  });

  final String teamId;
  final Set<String> existingCodes;

  @override
  ConsumerState<_ShiftTypeAddSheet> createState() =>
      _ShiftTypeAddSheetState();
}

class _ShiftTypeAddSheetState
    extends ConsumerState<_ShiftTypeAddSheet> {
  bool _isCustom = false;

  // 커스텀 입력용
  final _nameC = TextEditingController();
  final _codeC = TextEditingController();
  final _startC = TextEditingController();
  final _endC = TextEditingController();
  String _selectedColor = _presetColors[0];
  bool _saving = false;

  @override
  void dispose() {
    _nameC.dispose();
    _codeC.dispose();
    _startC.dispose();
    _endC.dispose();
    super.dispose();
  }

  Future<void> _addTemplate(_ShiftTemplate t) async {
    setState(() => _saving = true);
    await ref
        .read(teamDetailViewModelProvider(widget.teamId)
            .notifier)
        .createShiftType(
          name: t.name,
          code: t.code,
          startTime: t.startTime,
          endTime: t.endTime,
          color: t.color,
        );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _addCustom() async {
    final name = _nameC.text.trim();
    final code = _codeC.text.trim();
    if (name.isEmpty || code.isEmpty) return;

    setState(() => _saving = true);
    await ref
        .read(teamDetailViewModelProvider(widget.teamId)
            .notifier)
        .createShiftType(
          name: name,
          code: code,
          startTime: _startC.text.trim().isNotEmpty
              ? '${_startC.text.trim()}:00'
              : null,
          endTime: _endC.text.trim().isNotEmpty
              ? '${_endC.text.trim()}:00'
              : null,
          color: _selectedColor,
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.xl,
        bottom:
            MediaQuery.of(context).viewInsets.bottom +
                AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 핸들
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderLight,
                borderRadius:
                    AppRadius.borderRadiusFull,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          Text(
            '근무 유형 추가',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          if (!_isCustom) ...[
            // 템플릿 선택
            ...(_defaultTemplates
                .where((t) => !widget.existingCodes
                    .contains(t.code))
                .map((t) => _TemplateTile(
                      template: t,
                      loading: _saving,
                      onTap: () => _addTemplate(t),
                    ))),

            if (_defaultTemplates.every((t) =>
                widget.existingCodes
                    .contains(t.code)))
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.lg,
                ),
                child: Text(
                  '기본 유형이 모두 추가되었습니다',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(
                    color: AppColors.textSecondaryLight,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

            const SizedBox(height: AppSpacing.md),
            const Divider(),
            const SizedBox(height: AppSpacing.sm),

            // 커스텀 만들기 버튼
            TextButton.icon(
              onPressed: () =>
                  setState(() => _isCustom = true),
              icon: const Icon(
                Icons.edit_rounded,
                size: 18,
              ),
              label: const Text('직접 만들기'),
              style: TextButton.styleFrom(
                foregroundColor:
                    AppColors.textSecondaryLight,
              ),
            ),
          ] else ...[
            // 커스텀 입력 폼
            _CustomShiftForm(
              nameC: _nameC,
              codeC: _codeC,
              startC: _startC,
              endC: _endC,
              selectedColor: _selectedColor,
              onColorChanged: (c) =>
                  setState(() => _selectedColor = c),
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(
                        () => _isCustom = false),
                    child: const Text('뒤로'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed:
                        _saving ? null : _addCustom,
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          AppColors.primary,
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('추가'),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}

/// 템플릿 선택 타일 (애니메이션 아이콘 포함)
class _TemplateTile extends StatelessWidget {
  const _TemplateTile({
    required this.template,
    required this.loading,
    required this.onTap,
  });

  final _ShiftTemplate template;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = parseHexColor(template.color);

    return Padding(
      padding: const EdgeInsets.only(
        bottom: AppSpacing.sm,
      ),
      child: Material(
        color: color.withValues(alpha: 0.08),
        borderRadius: AppRadius.borderRadiusMd,
        child: InkWell(
          onTap: loading ? null : onTap,
          borderRadius: AppRadius.borderRadiusMd,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                // 애니메이션 아이콘
                _BouncyShiftIcon(
                  icon: template.icon,
                  color: color,
                  code: template.code,
                ),
                const SizedBox(width: AppSpacing.lg),

                // 정보
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding:
                                const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.xxs,
                            ),
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: AppRadius
                                  .borderRadiusSm,
                            ),
                            child: Text(
                              template.code,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight:
                                    FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(
                            width: AppSpacing.sm,
                          ),
                          Text(
                            template.name,
                            style: theme
                                .textTheme.titleSmall
                                ?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: AppSpacing.xxs,
                      ),
                      Text(
                        template.description,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(
                          color: AppColors
                              .textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),

                Icon(
                  Icons.add_circle_rounded,
                  color: color,
                  size: 28,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 근무 유형 수정 바텀시트
class _ShiftTypeEditSheet
    extends ConsumerStatefulWidget {
  const _ShiftTypeEditSheet({
    required this.teamId,
    required this.existing,
  });

  final String teamId;
  final ShiftTypeModel existing;

  @override
  ConsumerState<_ShiftTypeEditSheet> createState() =>
      _ShiftTypeEditSheetState();
}

class _ShiftTypeEditSheetState
    extends ConsumerState<_ShiftTypeEditSheet> {
  late final TextEditingController _nameC;
  late final TextEditingController _codeC;
  late final TextEditingController _startC;
  late final TextEditingController _endC;
  late String _selectedColor;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameC = TextEditingController(
        text: widget.existing.name);
    _codeC = TextEditingController(
        text: widget.existing.code);
    _startC = TextEditingController(
      text: widget.existing.startTime != null
          ? formatTimeString(
              widget.existing.startTime!)
          : '',
    );
    _endC = TextEditingController(
      text: widget.existing.endTime != null
          ? formatTimeString(widget.existing.endTime!)
          : '',
    );
    _selectedColor = widget.existing.color;
  }

  @override
  void dispose() {
    _nameC.dispose();
    _codeC.dispose();
    _startC.dispose();
    _endC.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameC.text.trim();
    final code = _codeC.text.trim();
    if (name.isEmpty || code.isEmpty) return;

    setState(() => _saving = true);
    await ref
        .read(teamDetailViewModelProvider(widget.teamId)
            .notifier)
        .updateShiftType(
          widget.existing.id,
          name: name,
          code: code,
          startTime: _startC.text.trim().isNotEmpty
              ? '${_startC.text.trim()}:00'
              : null,
          endTime: _endC.text.trim().isNotEmpty
              ? '${_endC.text.trim()}:00'
              : null,
          color: _selectedColor,
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.xl,
        bottom:
            MediaQuery.of(context).viewInsets.bottom +
                AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderLight,
                borderRadius:
                    AppRadius.borderRadiusFull,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            '근무 유형 수정',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _CustomShiftForm(
            nameC: _nameC,
            codeC: _codeC,
            startC: _startC,
            endC: _endC,
            selectedColor: _selectedColor,
            onColorChanged: (c) =>
                setState(() => _selectedColor = c),
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.md,
              ),
            ),
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('저장'),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}

/// 커스텀 근무 유형 입력 폼 (추가/수정 공용)
class _CustomShiftForm extends StatefulWidget {
  const _CustomShiftForm({
    required this.nameC,
    required this.codeC,
    required this.startC,
    required this.endC,
    required this.selectedColor,
    required this.onColorChanged,
  });

  final TextEditingController nameC;
  final TextEditingController codeC;
  final TextEditingController startC;
  final TextEditingController endC;
  final String selectedColor;
  final ValueChanged<String> onColorChanged;

  @override
  State<_CustomShiftForm> createState() =>
      _CustomShiftFormState();
}

class _CustomShiftFormState
    extends State<_CustomShiftForm> {
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;

  @override
  void initState() {
    super.initState();
    _startTime = _parseTime(widget.startC.text) ??
        const TimeOfDay(hour: 7, minute: 0);
    _endTime = _parseTime(widget.endC.text) ??
        const TimeOfDay(hour: 15, minute: 0);
  }

  TimeOfDay? _parseTime(String text) {
    final t = text.trim();
    if (t.isEmpty) return null;
    final parts = t.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  void _syncControllers() {
    widget.startC.text =
        '${_startTime.hour.toString().padLeft(2, '0')}:'
        '${_startTime.minute.toString().padLeft(2, '0')}';
    widget.endC.text =
        '${_endTime.hour.toString().padLeft(2, '0')}:'
        '${_endTime.minute.toString().padLeft(2, '0')}';
  }

  void _autoCode(String name) {
    if (name.trim().isEmpty) {
      widget.codeC.text = '';
    } else {
      // 첫 글자를 코드로 (영문이면 대문자, 한글이면 그대로)
      final first = name.trim().characters.first;
      widget.codeC.text = first.toUpperCase();
    }
    setState(() {});
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _periodLabel(TimeOfDay t) {
    if (t.hour < 6) return '새벽';
    if (t.hour < 12) return '오전';
    if (t.hour < 18) return '오후';
    return '밤';
  }

  void _showTimePicker({
    required bool isStart,
  }) {
    final current = isStart ? _startTime : _endTime;
    var selected = current;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      builder: (ctx) => SizedBox(
        height: 280,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isStart ? '시작 시간' : '종료 시간',
                    style: Theme.of(ctx)
                        .textTheme
                        .titleSmall
                        ?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        if (isStart) {
                          _startTime = selected;
                        } else {
                          _endTime = selected;
                        }
                        _syncControllers();
                      });
                      Navigator.pop(ctx);
                    },
                    child: const Text('완료'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: CupertinoTimerPicker(
                mode: CupertinoTimerPickerMode.hm,
                initialTimerDuration: Duration(
                  hours: current.hour,
                  minutes: current.minute,
                ),
                onTimerDurationChanged: (d) {
                  selected = TimeOfDay(
                    hour: d.inHours % 24,
                    minute: d.inMinutes % 60,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final badgeColor =
        parseHexColor(widget.selectedColor);
    final code = widget.codeC.text.isEmpty
        ? '?'
        : widget.codeC.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 뱃지 + 이름 (한줄) ──
        Row(
          children: [
            // 뱃지
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius:
                    AppRadius.borderRadiusMd,
              ),
              alignment: Alignment.center,
              child: Text(
                code,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),

            // 이름 입력 (underline only)
            Expanded(
              child: TextField(
                controller: widget.nameC,
                style: theme.textTheme.titleMedium
                    ?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                decoration: const InputDecoration(
                  hintText: '근무 이름 입력',
                  hintStyle: TextStyle(
                    color: AppColors.textSecondaryLight,
                    fontWeight: FontWeight.w400,
                  ),
                  border: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: AppColors.borderLight,
                    ),
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: AppColors.borderLight,
                    ),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: AppColors.primary,
                      width: 2,
                    ),
                  ),
                  contentPadding: EdgeInsets.only(
                    bottom: AppSpacing.xs,
                  ),
                  isDense: true,
                ),
                onChanged: _autoCode,
              ),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.xxl),

        // ── 근무 시간 (탭하여 휠 선택) ──
        Text(
          '근무 시간',
          style: theme.textTheme.labelMedium?.copyWith(
            color: AppColors.textSecondaryLight,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            // 시작 시간
            Expanded(
              child: _TimeTile(
                label: _periodLabel(_startTime),
                time: _formatTime(_startTime),
                color: badgeColor,
                onTap: () =>
                    _showTimePicker(isStart: true),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
              ),
              child: Icon(
                Icons.arrow_forward_rounded,
                size: 18,
                color: AppColors.textSecondaryLight
                    .withValues(alpha: 0.5),
              ),
            ),

            // 종료 시간
            Expanded(
              child: _TimeTile(
                label: _periodLabel(_endTime),
                time: _formatTime(_endTime),
                color: badgeColor,
                onTap: () =>
                    _showTimePicker(isStart: false),
              ),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.xxl),

        // ── 색상 선택 ──
        Text(
          '색상',
          style: theme.textTheme.labelMedium?.copyWith(
            color: AppColors.textSecondaryLight,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment:
              MainAxisAlignment.spaceEvenly,
          children: _presetColors.map((c) {
            final isSelected =
                c == widget.selectedColor;
            final color = parseHexColor(c);
            return GestureDetector(
              onTap: () => widget.onColorChanged(c),
              child: AnimatedContainer(
                duration: const Duration(
                  milliseconds: 150,
                ),
                width: isSelected ? 32 : 28,
                height: isSelected ? 32 : 28,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: isSelected
                      ? Border.all(
                          color: Colors.white,
                          width: 2.5,
                        )
                      : null,
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: color.withValues(
                              alpha: 0.5,
                            ),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 16,
                      )
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// 시간 선택 타일 (탭하면 휠 피커 열림)
class _TimeTile extends StatelessWidget {
  const _TimeTile({
    required this.label,
    required this.time,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String time;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: AppSpacing.lg,
        ),
        decoration: BoxDecoration(
          borderRadius: AppRadius.borderRadiusMd,
          border: Border.all(
            color: color.withValues(alpha: 0.25),
          ),
          color: color.withValues(alpha: 0.05),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              time,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

