import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:moniq/core/utils/color_utils.dart';
import 'package:moniq/presentation/screens/team/shift_template_data.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';

/// 커스텀 근무 유형 입력 폼 (추가/수정 공용)
class CustomShiftForm extends StatefulWidget {
  const CustomShiftForm({
    super.key,
    required this.nameC,
    required this.codeC,
    required this.startC,
    required this.endC,
    required this.selectedColor,
    required this.onColorChanged,
    this.existingCodes = const {},
  });

  final TextEditingController nameC;
  final TextEditingController codeC;
  final TextEditingController startC;
  final TextEditingController endC;
  final String selectedColor;
  final ValueChanged<String> onColorChanged;
  /// 이미 사용 중인 코드 목록. 중복 감지에 사용.
  final Set<String> existingCodes;

  @override
  State<CustomShiftForm> createState() =>
      _CustomShiftFormState();
}

class _CustomShiftFormState
    extends State<CustomShiftForm> {
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  bool _codeDuplicate = false;
  bool _showCodeField = false;
  bool _userEditedCode = false;

  @override
  void initState() {
    super.initState();
    _startTime = _parseTime(widget.startC.text) ??
        const TimeOfDay(hour: 7, minute: 0);
    _endTime = _parseTime(widget.endC.text) ??
        const TimeOfDay(hour: 15, minute: 0);
    // 컨트롤러가 비어있으면 기본 시간을 채워서 저장 시 누락되지 않도록
    if (widget.startC.text.isEmpty || widget.endC.text.isEmpty) {
      _syncControllers();
    }
    // 초기값이 이미 중복인 경우 대비
    if (widget.codeC.text.isNotEmpty) {
      _codeDuplicate = _isDuplicate(widget.codeC.text);
      if (_codeDuplicate) _showCodeField = true;
    }
  }

  bool _isDuplicate(String code) =>
      code.isNotEmpty &&
      widget.existingCodes.contains(code.trim().toUpperCase());

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
    if (!_userEditedCode) {
      if (name.trim().isEmpty) {
        widget.codeC.text = '';
        setState(() => _codeDuplicate = false);
      } else {
        final first = name.trim().characters.first.toUpperCase();
        widget.codeC.text = first;
        final isDup = _isDuplicate(first);
        if (isDup) _showCodeField = true;
        setState(() => _codeDuplicate = isDup);
      }
    }
    setState(() {});
  }

  void _onCodeFieldChanged(String code) {
    _userEditedCode = code.trim().isNotEmpty;
    setState(() => _codeDuplicate = _isDuplicate(code));
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
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                use24hFormat: false,
                initialDateTime: DateTime(
                  2000, 1, 1, current.hour, current.minute,
                ),
                onDateTimeChanged: (dateTime) {
                  selected = TimeOfDay(
                    hour: dateTime.hour,
                    minute: dateTime.minute,
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
    final cs = Theme.of(context).colorScheme;
    final badgeColor = parseHexColor(widget.selectedColor);
    final code = widget.codeC.text.isEmpty ? '?' : widget.codeC.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 뱃지 + 이름 (한줄) ──
        Row(
          children: [
            // 뱃지 (중복이면 에러 색 테두리)
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _codeDuplicate
                    ? badgeColor.withValues(alpha: 0.5)
                    : badgeColor,
                borderRadius: AppRadius.borderRadiusMd,
                border: _codeDuplicate
                    ? Border.all(color: cs.error, width: 2)
                    : null,
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

            // 이름 입력
            Expanded(
              child: TextField(
                controller: widget.nameC,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: '근무 이름 입력',
                  hintStyle: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w400,
                  ),
                  border: UnderlineInputBorder(
                    borderSide: BorderSide(color: cs.outlineVariant),
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: cs.outlineVariant),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: cs.primary, width: 2),
                  ),
                  contentPadding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  isDense: true,
                ),
                onChanged: _autoCode,
              ),
            ),
          ],
        ),

        // ── 코드 중복 경고 + 직접 입력 ──
        if (_showCodeField) ...[
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 15,
                color: _codeDuplicate ? cs.error : cs.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _codeDuplicate
                      ? '코드 \'${widget.codeC.text}\'가 이미 사용 중이에요'
                      : '코드 \'${widget.codeC.text}\'로 설정됩니다',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _codeDuplicate ? cs.error : cs.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: widget.codeC,
            maxLength: 2,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: '근무 코드 직접 입력',
              counterText: '',
              errorText: _codeDuplicate ? '이미 사용 중인 코드예요. 다른 코드를 입력해주세요.' : null,
              border: const OutlineInputBorder(),
            ),
            onChanged: _onCodeFieldChanged,
          ),
        ],

        const SizedBox(height: AppSpacing.xxl),

        // ── 근무 시간 (탭하여 휠 선택) ──
        Text(
          '근무 시간',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            // 시작 시간
            Expanded(
              child: TimeTile(
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
                color: theme.colorScheme.onSurfaceVariant
                    .withValues(alpha: 0.5),
              ),
            ),

            // 종료 시간
            Expanded(
              child: TimeTile(
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
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment:
              MainAxisAlignment.spaceEvenly,
          children: presetColors.map((c) {
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
                          color: theme.colorScheme
                              .surface,
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
                    ? Icon(
                        Icons.check_rounded,
                        color: theme.colorScheme
                            .surface,
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
class TimeTile extends StatelessWidget {
  const TimeTile({
    super.key,
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
