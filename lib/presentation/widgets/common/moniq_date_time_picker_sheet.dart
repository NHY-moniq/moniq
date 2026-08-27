import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/widgets/common/moniq_bottom_sheet.dart';

/// 날짜+시간을 **한 휠에서** 고르는 바텀시트.
///
/// [showMoniqDatePickerSheet]/[showMoniqTimePickerSheet]와 같은 골격
/// (eyebrow + 타이틀 + 선택값 요약 + 휠 + 취소/확인)을 쓰되, 휠은
/// `CupertinoDatePickerMode.dateAndTime` — 좌측 날짜 휠(요일·오늘 표기 포함)과
/// 시·분·오전/오후 휠이 한 번의 스크롤로 끝난다.
///
/// [minimumDate]를 넘기면 그 이전 값은 휠에서 아예 선택되지 않는다
/// (종료 일시가 시작보다 앞서지 못하게 하는 용도).
Future<DateTime?> showMoniqDateTimePickerSheet({
  required BuildContext context,
  required DateTime initialDateTime,
  DateTime? minimumDate,
  DateTime? maximumDate,
  String title = '일시 선택',
  String? eyebrow,
  String confirmLabel = '확인',
  String cancelLabel = '취소',
}) {
  // CupertinoDatePicker는 분 단위까지만 다루므로 초 이하를 버려
  // initial/minimum 비교가 어긋나지 않게 한다.
  DateTime normalize(DateTime d) =>
      DateTime(d.year, d.month, d.day, d.hour, d.minute);
  final min = minimumDate != null ? normalize(minimumDate) : null;
  final max = maximumDate != null ? normalize(maximumDate) : null;
  var seed = normalize(initialDateTime);
  if (min != null && seed.isBefore(min)) seed = min;
  if (max != null && seed.isAfter(max)) seed = max;

  return showMoniqBottomSheet<DateTime>(
    context: context,
    title: title,
    eyebrow: eyebrow ?? 'DATE · TIME',
    // 220px 휠 + 요약 + 버튼이라 기본 상한(0.56)으로는 하단이 잘린다.
    maxHeightFactor: 0.78,
    child: _MoniqDateTimePickerSheetBody(
      initialDateTime: seed,
      minimumDate: min,
      maximumDate: max,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
    ),
  );
}

class _MoniqDateTimePickerSheetBody extends StatefulWidget {
  const _MoniqDateTimePickerSheetBody({
    required this.initialDateTime,
    required this.minimumDate,
    required this.maximumDate,
    required this.confirmLabel,
    required this.cancelLabel,
  });

  final DateTime initialDateTime;
  final DateTime? minimumDate;
  final DateTime? maximumDate;
  final String confirmLabel;
  final String cancelLabel;

  @override
  State<_MoniqDateTimePickerSheetBody> createState() =>
      _MoniqDateTimePickerSheetBodyState();
}

class _MoniqDateTimePickerSheetBodyState
    extends State<_MoniqDateTimePickerSheetBody> {
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialDateTime;
  }

  /// 요약 필드 라벨 — 예: `8.27 (목) 오후 6:00`.
  String get _label {
    final date = DateFormat('M.d (E)').format(_selected);
    final isAm = _selected.hour < 12;
    final hour12 = switch (_selected.hour % 12) {
      0 => 12,
      final h => h,
    };
    final minute = _selected.minute.toString().padLeft(2, '0');
    return '$date ${isAm ? '오전' : '오후'} $hour12:$minute';
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
                  '선택 일시',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Text(
                  _label,
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
                  mode: CupertinoDatePickerMode.dateAndTime,
                  backgroundColor: colorScheme.surfaceContainerLowest,
                  initialDateTime: _selected,
                  minimumDate: widget.minimumDate,
                  maximumDate: widget.maximumDate,
                  onDateTimeChanged: (value) {
                    setState(() => _selected = value);
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
                    onPressed: () {
                      // 휠이 minimum 미만으로 스냅백되는 중에 확인을 눌러도
                      // 시작 이전 값이 나가지 않게 최종 clamp.
                      var result = _selected;
                      final min = widget.minimumDate;
                      if (min != null && result.isBefore(min)) result = min;
                      Navigator.pop(context, result);
                    },
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
