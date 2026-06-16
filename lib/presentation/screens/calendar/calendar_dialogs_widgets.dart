part of 'calendar_dialogs.dart';

class _EventAllDayCheckbox extends StatelessWidget {
  const _EventAllDayCheckbox({required this.selected, required this.onChanged});

  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!selected),
        borderRadius: AppRadius.borderRadiusMd,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: selected ? cs.primary : cs.surface,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: selected
                        ? cs.primary
                        : cs.outlineVariant.withValues(alpha: 0.9),
                    width: 1.4,
                  ),
                ),
                alignment: Alignment.center,
                child: selected
                    ? Icon(Icons.check_rounded, size: 15, color: cs.onPrimary)
                    : null,
              ),
              const SizedBox(height: 4),
              Text(
                '종일',
                maxLines: 1,
                style: textTheme.labelSmall?.copyWith(
                  color: selected ? cs.primary : cs.onSurfaceVariant,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 시작/종료 시간 버튼 — 약속잡기 시트의 `_AppointmentTimeButton`과 동일 스펙.
class _EventTimeButton extends StatelessWidget {
  const _EventTimeButton({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.borderRadiusMd,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: AppRadius.borderRadiusMd,
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.62),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 13,
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: cs.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 색상 chip — 선택 시 흰색 inner ring + primary 2px outer outline로 강조.
class _ColorChip extends StatelessWidget {
  const _ColorChip({
    required this.hex,
    required this.isSelected,
    required this.onTap,
  });

  final String hex;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = parseHexColor(hex);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          // Outer primary ring when selected
          border: isSelected ? Border.all(color: cs.primary, width: 2) : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        padding: EdgeInsets.all(isSelected ? 3 : 0),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            // Inner white ring for the double-ring effect
            border: isSelected ? Border.all(color: cs.surface, width: 2) : null,
          ),
        ),
      ),
    );
  }
}

/// 반복 선택 — 다른 입력과 동일한 fill bg + radius로 통일.
class _RecurrenceField extends StatelessWidget {
  const _RecurrenceField({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String value;
  final List<(String, String)> options;
  final ValueChanged<String> onChanged;

  /// 각 옵션 값에 매핑되는 아이콘 — 빈도의 의미를 시각적으로 보조.
  IconData _iconFor(String val) {
    switch (val) {
      case 'none':
        return Icons.do_disturb_alt_outlined;
      case 'daily':
        return Icons.today_outlined;
      case 'weekly':
        return Icons.calendar_view_week_rounded;
      case 'biweekly':
        return Icons.event_repeat_rounded;
      case 'monthly':
        return Icons.calendar_month_outlined;
      case 'yearly':
        return Icons.cake_outlined;
      default:
        return Icons.repeat_rounded;
    }
  }

  String _labelFor(String val) {
    return options
        .firstWhere((o) => o.$1 == val, orElse: () => options.first)
        .$2;
  }

  Future<void> _openPicker(BuildContext context) async {
    final selected = await showMoniqBottomSheet<String>(
      context: context,
      title: '일정 반복',
      eyebrow: 'RECURRENCE',
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final opt in options) ...[
              _RecurrenceOptionTile(
                icon: _iconFor(opt.$1),
                label: opt.$2,
                selected: opt.$1 == value,
                onTap: () =>
                    Navigator.of(context, rootNavigator: true).pop(opt.$1),
              ),
              const SizedBox(height: 6),
            ],
          ],
        ),
      ),
    );
    if (selected != null && selected != value) onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.xs,
            bottom: AppSpacing.xs,
          ),
          child: Text(
            '반복',
            style: tt.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Material(
          color: cs.surfaceContainerHigh,
          borderRadius: AppRadius.borderRadiusLg,
          child: InkWell(
            borderRadius: AppRadius.borderRadiusLg,
            onTap: () => _openPicker(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: [
                  Icon(_iconFor(value), size: 20, color: cs.onSurfaceVariant),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      _labelFor(value),
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(Icons.expand_more_rounded, color: cs.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 반복 선택 바텀시트의 옵션 행 — 아이콘 + 라벨 + 선택 체크.
class _RecurrenceOptionTile extends StatelessWidget {
  const _RecurrenceOptionTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bg = selected
        ? cs.primary.withValues(alpha: 0.10)
        : cs.surfaceContainerHigh;
    final fg = selected ? cs.primary : cs.onSurface;
    return Material(
      color: bg,
      borderRadius: AppRadius.borderRadiusLg,
      child: InkWell(
        borderRadius: AppRadius.borderRadiusLg,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? cs.primary.withValues(alpha: 0.18)
                      : cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: selected ? cs.primary : cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: fg,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
              if (selected)
                Icon(Icons.check_rounded, size: 20, color: cs.primary),
            ],
          ),
        ),
      ),
    );
  }
}

/// 개인 캘린더 — 연/월 선택 후 해당 월의 **근무 일정(팀에서 가져온 근무)** 만
/// 일괄 삭제하는 바텀시트. 직접 추가한 개인 일정/메모는 보존된다.
/// 제목 있는 공용 바텀시트(showMoniqBottomSheet)로 통일한다.
void showDeletePersonalScheduleSheet({
  required BuildContext context,
  required WidgetRef ref,
}) {
  final now = DateTime.now();
  DateTime selectedDate = DateTime(now.year, now.month);

  showMoniqBottomSheet<void>(
    context: context,
    title: '근무 삭제',
    eyebrow: 'DELETE',
    child: StatefulBuilder(
      builder: (ctx, setSheetState) {
        final cs = Theme.of(ctx).colorScheme;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 180,
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.monthYear,
                initialDateTime: selectedDate,
                onDateTimeChanged: (d) {
                  setSheetState(() {
                    selectedDate = DateTime(d.year, d.month);
                  });
                },
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: cs.error,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.borderRadiusFull,
                ),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                final year = selectedDate.year;
                final month = selectedDate.month;

                final confirm = await showMoniqDestructiveConfirm(
                  context: context,
                  title: '근무 일정을 삭제할까요?',
                  message: '$year년 $month월의 근무 일정이 개인 캘린더에서 제거됩니다.\n'
                      '팀 근무표 원본과 직접 추가한 개인 일정/메모는 유지됩니다.',
                );
                if (!confirm) return;

                try {
                  // 팀 데이터는 보존하고 개인 캘린더에서만 그 달 근무/OFF를 숨긴다.
                  await ref
                      .read(personalHiddenShiftsDataSourceProvider)
                      .hideMonth(year, month);

                  // 캐시 무효화 — 홈 캘린더가 숨김을 반영하도록
                  ref.read(eventRefreshProvider.notifier).state++;
                  ref.invalidate(monthlyEventsProvider);
                  ref.invalidate(dateEventsProvider);
                  ref.invalidate(homeViewModelProvider);

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '$year년 $month월 근무를 개인 캘린더에서 제거했습니다',
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
                  }
                }
              },
              child: Text(
                '근무 삭제',
                style: TextStyle(
                  color: cs.onError,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}
