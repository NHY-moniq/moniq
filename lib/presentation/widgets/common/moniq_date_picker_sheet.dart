import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/widgets/common/moniq_bottom_sheet.dart';

Future<DateTime?> showMoniqDatePickerSheet({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String title = '날짜 선택',
  String? eyebrow,
  String confirmLabel = '확인',
  String cancelLabel = '취소',
}) {
  DateTime normalize(DateTime d) => DateTime(d.year, d.month, d.day);
  final minDate = normalize(firstDate);
  final maxDate = normalize(lastDate);
  var seed = normalize(initialDate);
  if (seed.isBefore(minDate)) seed = minDate;
  if (seed.isAfter(maxDate)) seed = maxDate;

  return showMoniqBottomSheet<DateTime>(
    context: context,
    title: title,
    eyebrow: eyebrow ?? 'DATE',
    child: _MoniqDatePickerSheetBody(
      initialDate: seed,
      minDate: minDate,
      maxDate: maxDate,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
    ),
  );
}

class _MoniqDatePickerSheetBody extends StatefulWidget {
  const _MoniqDatePickerSheetBody({
    required this.initialDate,
    required this.minDate,
    required this.maxDate,
    required this.confirmLabel,
    required this.cancelLabel,
  });

  final DateTime initialDate;
  final DateTime minDate;
  final DateTime maxDate;
  final String confirmLabel;
  final String cancelLabel;

  @override
  State<_MoniqDatePickerSheetBody> createState() =>
      _MoniqDatePickerSheetBodyState();
}

class _MoniqDatePickerSheetBodyState extends State<_MoniqDatePickerSheetBody> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dateLabel = DateFormat('yyyy.MM.dd (E)').format(_selectedDate);

    return Column(
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
                '선택 날짜',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                dateLabel,
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
                mode: CupertinoDatePickerMode.date,
                backgroundColor: colorScheme.surfaceContainerLowest,
                initialDateTime: _selectedDate,
                minimumDate: widget.minDate,
                maximumDate: widget.maxDate,
                onDateTimeChanged: (value) {
                  setState(() {
                    _selectedDate = DateTime(
                      value.year,
                      value.month,
                      value.day,
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
                  onPressed: () => Navigator.pop(context, _selectedDate),
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
    );
  }
}
