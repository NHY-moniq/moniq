part of 'wanted_day_off_screen.dart';

class _ActiveBanner extends StatelessWidget {
  const _ActiveBanner({
    required this.displayRequest,
    required this.daysLeft,
    required this.isNightView,
  });

  final WantedRequestModel displayRequest;
  final int? daysLeft;
  final bool isNightView;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dateFormat = DateFormat('yyyy.MM.dd');
    final bannerColor = (daysLeft != null && daysLeft! <= 3)
        ? AppColors.brandOrange
        : colorScheme.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.lg,
        AppSpacing.xxl,
        AppSpacing.xxl,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상단 Row: 수집 중 pill + D-N pill
          Row(
            children: [
              const _EntryStatusPill(
                label: '수집 중',
                color: AppColors.brandOrange,
                icon: Icons.circle,
              ),
              const Spacer(),
              if (daysLeft != null)
                _EntryStatusPill(
                  label: daysLeft == 0 ? 'D-Day' : 'D-$daysLeft',
                  color: bannerColor,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // 타이틀
          Text(
            isNightView ? '나이트 전담을 신청해주세요' : '원티드를 입력해주세요',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          // 근무 기간
          Text(
            '${dateFormat.format(displayRequest.periodStart)} ~ '
            '${dateFormat.format(displayRequest.periodEnd)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          // 마감 칩
          if (displayRequest.deadline != null) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _EntryMetricChip(
                  icon: Icons.event_available_rounded,
                  label: '마감 ${dateFormat.format(displayRequest.deadline!)}',
                  color: (daysLeft != null && daysLeft! <= 3)
                      ? AppColors.brandOrange
                      : null,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─── _DayOffSel ────────────────────────────────────────────────────────────────

class _DayOffSel {
  const _DayOffSel({required this.priority, this.reason, this.shiftTypeId});
  final int priority;
  final String? reason;
  final String? shiftTypeId; // null = OFF

  @override
  bool operator ==(Object other) =>
      other is _DayOffSel &&
      other.priority == priority &&
      other.reason == reason &&
      other.shiftTypeId == shiftTypeId;

  @override
  int get hashCode => Object.hash(priority, reason, shiftTypeId);
}

// ─── _MultiDateCalendar ────────────────────────────────────────────────────────

class _MultiDateCalendar extends StatefulWidget {
  const _MultiDateCalendar({
    required this.periodStart,
    required this.periodEnd,
    required this.selectedDates,
    required this.shiftTypes,
    required this.existingDates,
    required this.onToggle,
  });

  final DateTime periodStart;
  final DateTime periodEnd;
  final Map<DateTime, _DayOffSel> selectedDates;
  final List<ShiftTypeModel> shiftTypes;
  final Set<DateTime> existingDates;
  final ValueChanged<DateTime> onToggle;

  @override
  State<_MultiDateCalendar> createState() => _MultiDateCalendarState();
}

class _MultiDateCalendarState extends State<_MultiDateCalendar> {
  late DateTime _currentMonth;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(widget.periodStart.year, widget.periodStart.month);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dayLabels = ['월', '화', '수', '목', '금', '토', '일'];
    final typeMap = {for (final t in widget.shiftTypes) t.id: t};

    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final startWeekday = firstDay.weekday;

    final days = <DateTime?>[];
    for (int i = 1; i < startWeekday; i++) {
      days.add(null);
    }
    for (int d = 1; d <= lastDay.day; d++) {
      days.add(DateTime(_currentMonth.year, _currentMonth.month, d));
    }

    return Column(
      children: [
        // 월 네비게이션
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () {
                final prev = DateTime(
                  _currentMonth.year,
                  _currentMonth.month - 1,
                );
                final periodMonth = DateTime(
                  widget.periodStart.year,
                  widget.periodStart.month,
                );
                if (!prev.isBefore(periodMonth)) {
                  setState(() => _currentMonth = prev);
                }
              },
            ),
            Text(
              DateFormat('yyyy년 MM월').format(_currentMonth),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () {
                final next = DateTime(
                  _currentMonth.year,
                  _currentMonth.month + 1,
                );
                final periodEndMonth = DateTime(
                  widget.periodEnd.year,
                  widget.periodEnd.month,
                );
                if (!next.isAfter(
                  DateTime(periodEndMonth.year, periodEndMonth.month + 1),
                )) {
                  setState(() => _currentMonth = next);
                }
              },
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),

        // 요일 헤더
        Row(
          children: dayLabels.map((label) {
            final isWeekend = label == '토' || label == '일';
            return Expanded(
              child: Center(
                child: Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isWeekend
                        ? colorScheme.error.withValues(alpha: 0.6)
                        : colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.sm),

        // P1-5: 날짜 그리드 childAspectRatio 0.85
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 0.85,
            ),
            itemCount: days.length,
            itemBuilder: (context, index) {
              final day = days[index];
              if (day == null) return const SizedBox();

              final isInPeriod =
                  !day.isBefore(widget.periodStart) &&
                  !day.isAfter(widget.periodEnd);
              final sel = widget.selectedDates[day];
              final isSelected = sel != null;
              final isExisting = widget.existingDates.contains(day);

              // Cell color: OFF/교육 = gray, D/E/N = shift color
              Color selColor;
              if (sel != null) {
                if (sel.shiftTypeId == null) {
                  selColor = AppColors.shiftOff;
                } else {
                  final t = typeMap[sel.shiftTypeId];
                  selColor = t != null
                      ? parseHexColor(t.color)
                      : colorScheme.primary;
                }
              } else {
                selColor = colorScheme.primary;
              }

              // 우선순위 배지(좌상단) + 근무 유형 배지(우상단) + 사유 배지(우하단)
              final String? priorityBadge = isSelected
                  ? '${sel.priority}'
                  : null;
              final String? typeBadge = isSelected
                  ? (sel.shiftTypeId == null
                        ? (sel.reason == '#필수교육' ? '교' : 'O')
                        : (typeMap[sel.shiftTypeId]?.code ?? '?'))
                  : null;
              final String? reasonBadge =
                  (isSelected && sel.shiftTypeId == null)
                  ? (sel.reason == '#생리휴가'
                        ? '생휴'
                        : sel.reason == '#연차'
                        ? '연차'
                        : null)
                  : null;

              // P1-5: 기간 외 셀 opacity 처리
              Widget cellWidget = Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? selColor
                      : isExisting
                      ? colorScheme.onSurfaceVariant.withValues(alpha: 0.15)
                      : null,
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                  border: isInPeriod && !isSelected && !isExisting
                      ? Border.all(color: colorScheme.outlineVariant)
                      : null,
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Text(
                        '${day.day}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isSelected
                              ? Colors.white
                              : isExisting
                              ? colorScheme.onSurfaceVariant
                              : isInPeriod
                              ? null
                              : colorScheme.onSurface.withValues(alpha: 0.25),
                          fontWeight: isSelected ? FontWeight.w700 : null,
                        ),
                      ),
                    ),
                    if (priorityBadge != null)
                      Positioned(
                        top: 2,
                        left: 2,
                        child: Text(
                          priorityBadge,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    if (typeBadge != null)
                      Positioned(
                        top: 2,
                        right: 2,
                        child: Text(
                          typeBadge,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    if (reasonBadge != null)
                      Positioned(
                        bottom: 2,
                        right: 2,
                        child: Text(
                          reasonBadge,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 7,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              );

              return GestureDetector(
                onTap: isInPeriod && !isExisting
                    ? () => widget.onToggle(day)
                    : null,
                child: isInPeriod
                    ? cellWidget
                    : Opacity(opacity: 0.35, child: cellWidget),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── _EntryMetricChip ──────────────────────────────────────────────────────────

class _EntryMetricChip extends StatelessWidget {
  const _EntryMetricChip({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final resolvedColor = color ?? colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: AppRadius.borderRadiusFull,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: resolvedColor),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: resolvedColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryStatusPill extends StatelessWidget {
  const _EntryStatusPill({required this.label, required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: AppRadius.borderRadiusFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: color),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── _ShiftCodeBadge (P0-2) ───────────────────────────────────────────────────

class _ShiftCodeBadge extends StatelessWidget {
  const _ShiftCodeBadge({required this.code, required this.color});

  final String code;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        code,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
          height: 1,
        ),
      ),
    );
  }
}

// ─── _WantedTypeSelector (P1-2) ───────────────────────────────────────────────

class _TypeItem {
  const _TypeItem({
    required this.id,
    required this.label,
    required this.code,
    required this.color,
  });

  final String? id; // null = 오프
  final String label;
  final String code;
  final Color color;
}

class _WantedTypeSelector extends StatelessWidget {
  const _WantedTypeSelector({
    required this.items,
    required this.selectedId,
    required this.onSelected,
  });

  final List<_TypeItem> items;
  final String? selectedId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final tiles = items.map((item) {
      final isSelected = selectedId == item.id;
      return GestureDetector(
        onTap: () => onSelected(item.id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 68,
          height: 60,
          decoration: BoxDecoration(
            color: isSelected
                ? item.color.withValues(alpha: 0.15)
                : colorScheme.surfaceContainerHigh,
            border: Border.all(
              color: isSelected ? item.color : colorScheme.outlineVariant,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ShiftCodeBadge(code: item.code, color: item.color),
              const SizedBox(height: 4),
              Text(
                item.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                  color: isSelected ? item.color : colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      );
    }).toList();

    if (items.length >= 5) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (int i = 0; i < tiles.length; i++) ...[
              tiles[i],
              if (i < tiles.length - 1) const SizedBox(width: AppSpacing.sm),
            ],
          ],
        ),
      );
    }

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: tiles,
    );
  }
}

// ─── _OffReasonChip (P1-4) ────────────────────────────────────────────────────

class _OffReasonChip extends StatelessWidget {
  const _OffReasonChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primary.withValues(alpha: 0.12)
              : colorScheme.surfaceContainerHigh,
          border: Border.all(
            color: selected ? colorScheme.primary : colorScheme.outlineVariant,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            color: selected
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
