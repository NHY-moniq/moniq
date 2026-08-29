import 'package:flutter/material.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/theme/shift_theme.dart';

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
    final colorScheme = Theme.of(context).colorScheme;
    // 활성 pill은 면 요소 — 오프면 파스텔(ShiftFillColors.fill),
    // 다른 시프트는 fill == primary라 기존과 동일.
    final fills = Theme.of(context).extension<ShiftFillColors>();
    final fill = fills?.fill ?? colorScheme.primary;
    final onFill = fills?.onFill ?? colorScheme.onPrimary;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: CalendarViewMode.values.map((mode) {
            final isSelected = mode == currentMode;
            final label = mode == CalendarViewMode.month ? '월' : '주';
            return GestureDetector(
              onTap: () => onChanged(mode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? fill : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: fill.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? onFill
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
