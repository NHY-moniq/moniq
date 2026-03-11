import 'package:flutter/material.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';

enum CalendarViewMode { month, week }

class ViewModeToggle extends StatelessWidget {
  const ViewModeToggle({
    super.key,
    required this.currentMode,
    required this.onChanged,
  });

  final CalendarViewMode currentMode;
  final ValueChanged<CalendarViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: SegmentedButton<CalendarViewMode>(
        segments: const [
          ButtonSegment(
            value: CalendarViewMode.month,
            label: Text('월'),
          ),
          ButtonSegment(
            value: CalendarViewMode.week,
            label: Text('주'),
          ),
        ],
        selected: {currentMode},
        onSelectionChanged: (set) => onChanged(set.first),
        style: SegmentedButton.styleFrom(
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}
