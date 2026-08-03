import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/widgets/common/moniq_bottom_sheet.dart';

/// 시간 선택 바텀시트.
///
/// [showMoniqDatePickerSheet]와 같은 골격(eyebrow + 타이틀 + 선택값 요약 +
/// 휠 + 취소/확인 버튼)을 써서, 날짜와 시간 선택이 한 벌로 읽히게 한다.
/// 기존엔 시간만 네이티브 Cupertino 시트를 그대로 띄워 톤이 어긋났다.
Future<TimeOfDay?> showMoniqTimePickerSheet({
  required BuildContext context,
  required TimeOfDay initialTime,
  String title = '시간 선택',
  String? eyebrow,
  String confirmLabel = '확인',
  String cancelLabel = '취소',
  bool use24hFormat = false,
}) {
  return showMoniqBottomSheet<TimeOfDay>(
    context: context,
    title: title,
    eyebrow: eyebrow ?? 'TIME',
    // 220px 휠 + 요약 + 버튼이라 기본 상한(0.56)으로는 하단이 잘린다.
    maxHeightFactor: 0.78,
    child: _MoniqTimePickerSheetBody(
      initialTime: initialTime,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      use24hFormat: use24hFormat,
    ),
  );
}

class _MoniqTimePickerSheetBody extends StatefulWidget {
  const _MoniqTimePickerSheetBody({
    required this.initialTime,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.use24hFormat,
  });

  final TimeOfDay initialTime;
  final String confirmLabel;
  final String cancelLabel;
  final bool use24hFormat;

  @override
  State<_MoniqTimePickerSheetBody> createState() =>
      _MoniqTimePickerSheetBodyState();
}

class _MoniqTimePickerSheetBodyState extends State<_MoniqTimePickerSheetBody> {
  late TimeOfDay _selectedTime;

  @override
  void initState() {
    super.initState();
    _selectedTime = widget.initialTime;
  }

  /// 요약 필드에 보여줄 문자열. 24시간제면 `22:00`, 아니면 `오후 10:00`.
  String get _timeLabel {
    final minute = _selectedTime.minute.toString().padLeft(2, '0');
    if (widget.use24hFormat) {
      return '${_selectedTime.hour.toString().padLeft(2, '0')}:$minute';
    }
    final isAm = _selectedTime.hour < 12;
    final hour12 = switch (_selectedTime.hour % 12) {
      0 => 12,
      final h => h,
    };
    return '${isAm ? '오전' : '오후'} ${hour12.toString().padLeft(2, '0')}:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // 글자 크기를 키운 기기에서는 상한을 올려도 넘칠 수 있어 스크롤로 받는다.
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLowest,
              borderRadius: AppRadius.borderRadiusMd,
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Row(
              children: [
                Text(
                  '선택 시간',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Text(
                  _timeLabel,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: AppRadius.borderRadiusMd,
            child: Container(
              height: 220,
              color: colorScheme.surfaceContainerLowest,
              child: CupertinoTheme(
                data: CupertinoThemeData(
                  brightness: theme.brightness,
                  primaryColor: colorScheme.primary,
                ),
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  use24hFormat: widget.use24hFormat,
                  backgroundColor: colorScheme.surfaceContainerLowest,
                  // 날짜는 의미 없고 시/분만 쓰므로 고정 기준일을 둔다.
                  initialDateTime: DateTime(
                    2000,
                    1,
                    1,
                    _selectedTime.hour,
                    _selectedTime.minute,
                  ),
                  onDateTimeChanged: (value) {
                    setState(() {
                      _selectedTime = TimeOfDay(
                        hour: value.hour,
                        minute: value.minute,
                      );
                    });
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.borderRadiusFull,
                      ),
                      side: BorderSide(color: colorScheme.outlineVariant),
                    ),
                    child: Text(widget.cancelLabel),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, _selectedTime),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.borderRadiusFull,
                      ),
                    ),
                    child: Text(widget.confirmLabel),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
