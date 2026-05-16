import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/core/utils/color_utils.dart';
import 'package:moniq/core/utils/time_utils.dart';
import 'package:moniq/data/models/shift_type_model.dart';
import 'package:moniq/presentation/screens/team/custom_shift_form.dart';
import 'package:moniq/presentation/screens/team/shift_template_data.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/team_detail_viewmodel.dart';
import 'package:moniq/presentation/widgets/common/moniq_bottom_sheet.dart';

const _protectedDefaultCodes = {'D', 'E', 'N', 'ED'};

bool _isProtectedDefaultShiftType(ShiftTypeModel shiftType) =>
    _protectedDefaultCodes.contains(shiftType.code.trim().toUpperCase());

/// 기존 근무 유형 카드 (등록된 상태)
class ShiftTypeCard extends ConsumerWidget {
  const ShiftTypeCard({
    super.key,
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
    final isProtectedDefault = _isProtectedDefaultShiftType(shiftType);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isAdmin ? () => _showEditSheet(context, ref) : null,
          borderRadius: AppRadius.borderRadiusMd,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              borderRadius: AppRadius.borderRadiusMd,
              border: Border.all(
                color: shiftType.isActive
                    ? color.withValues(alpha: 0.3)
                    : Theme.of(context).colorScheme.outlineVariant,
              ),
              color: shiftType.isActive
                  ? color.withValues(alpha: 0.06)
                  : Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.04),
            ),
            child: Row(
              children: [
                // 코드 뱃지
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: shiftType.isActive
                        ? color
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    borderRadius: AppRadius.borderRadiusMd,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    shiftType.code,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.surface,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),

                // 이름 + 시간
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shiftType.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: shiftType.isActive
                              ? null
                              : theme.colorScheme.onSurfaceVariant,
                          decoration: shiftType.isActive
                              ? null
                              : TextDecoration.lineThrough,
                        ),
                      ),
                      if (timeText.isNotEmpty)
                        Text(
                          timeText,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),

                if (isProtectedDefault)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: AppRadius.borderRadiusFull,
                    ),
                    child: Text(
                      '기본',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),

                // 삭제 버튼
                if (isAdmin && !isProtectedDefault)
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    tooltip: '삭제',
                    onPressed: () => _confirmDelete(context, ref),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    if (_isProtectedDefaultShiftType(shiftType)) {
      await showMoniqInfoSheet(
        context: context,
        title: '삭제 불가',
        message: '데이/이브닝/나이트/교육 기본 근무 유형은 삭제할 수 없습니다.',
      );
      return;
    }

    final confirmed = await showMoniqConfirmSheet(
      context: context,
      title: '근무 유형 삭제',
      message: '"${shiftType.name}" 근무 유형을 삭제하시겠습니까?\n배정된 근무가 있으면 삭제할 수 없습니다.',
      confirmLabel: '삭제',
      destructive: true,
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref
          .read(teamDetailViewModelProvider(teamId).notifier)
          .deleteShiftType(shiftType.id);
    } catch (e) {
      if (!context.mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  void _showEditSheet(BuildContext context, WidgetRef ref) {
    showMoniqBottomSheet<void>(
      context: context,
      title: '근무 유형 수정',
      eyebrow: 'SHIFT TYPE',
      child: ShiftTypeEditSheet(teamId: teamId, existing: shiftType),
    );
  }

  String _buildTimeText(ShiftTypeModel t) {
    if (t.startTime == null && t.endTime == null) {
      return '';
    }
    final start = t.startTime != null ? formatTimeString(t.startTime!) : '';
    final end = t.endTime != null ? formatTimeString(t.endTime!) : '';
    if (start.isEmpty && end.isEmpty) return '';
    return '$start ~ $end';
  }
}

/// 근무 유형 추가 바텀시트 (커스텀 폼)
class ShiftTypeAddSheet extends ConsumerStatefulWidget {
  const ShiftTypeAddSheet({
    super.key,
    required this.teamId,
    required this.existingCodes,
  });

  final String teamId;
  final Set<String> existingCodes;

  @override
  ConsumerState<ShiftTypeAddSheet> createState() => _ShiftTypeAddSheetState();
}

class _ShiftTypeAddSheetState extends ConsumerState<ShiftTypeAddSheet> {
  final _nameC = TextEditingController();
  final _codeC = TextEditingController();
  final _startC = TextEditingController();
  final _endC = TextEditingController();
  String _selectedColor = presetColors[0];
  bool _saving = false;

  @override
  void dispose() {
    _nameC.dispose();
    _codeC.dispose();
    _startC.dispose();
    _endC.dispose();
    super.dispose();
  }

  Future<void> _addCustom() async {
    final name = _nameC.text.trim();
    final code = _codeC.text.trim();
    if (name.isEmpty || code.isEmpty) return;

    setState(() => _saving = true);
    await ref
        .read(teamDetailViewModelProvider(widget.teamId).notifier)
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
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.sm,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CustomShiftForm(
            nameC: _nameC,
            codeC: _codeC,
            startC: _startC,
            endC: _endC,
            selectedColor: _selectedColor,
            onColorChanged: (c) => setState(() => _selectedColor = c),
            existingCodes: widget.existingCodes,
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            onPressed: _saving ? null : _addCustom,
            style: FilledButton.styleFrom(backgroundColor: cs.primary),
            child: _saving
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: cs.onPrimary,
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

/// 근무 유형 수정 바텀시트
class ShiftTypeEditSheet extends ConsumerStatefulWidget {
  const ShiftTypeEditSheet({
    super.key,
    required this.teamId,
    required this.existing,
  });

  final String teamId;
  final ShiftTypeModel existing;

  @override
  ConsumerState<ShiftTypeEditSheet> createState() => _ShiftTypeEditSheetState();
}

class _ShiftTypeEditSheetState extends ConsumerState<ShiftTypeEditSheet> {
  late final TextEditingController _nameC;
  late final TextEditingController _codeC;
  late final TextEditingController _startC;
  late final TextEditingController _endC;
  late String _selectedColor;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameC = TextEditingController(text: widget.existing.name);
    _codeC = TextEditingController(text: widget.existing.code);
    _startC = TextEditingController(
      text: widget.existing.startTime != null
          ? formatTimeString(widget.existing.startTime!)
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
        .read(teamDetailViewModelProvider(widget.teamId).notifier)
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
    // 현재 수정 중인 유형 제외한 다른 유형들의 코드 (중복 감지용)
    final otherCodes =
        ref
            .watch(teamDetailViewModelProvider(widget.teamId))
            .valueOrNull
            ?.shiftTypes
            .where((t) => t.id != widget.existing.id)
            .map((t) => t.code.toUpperCase())
            .toSet() ??
        {};

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        top: AppSpacing.xs,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.sm,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CustomShiftForm(
            nameC: _nameC,
            codeC: _codeC,
            startC: _startC,
            endC: _endC,
            selectedColor: _selectedColor,
            onColorChanged: (c) => setState(() => _selectedColor = c),
            existingCodes: otherCodes,
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            ),
            child: _saving
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  )
                : const Text('저장'),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
      ),
    );
  }
}
