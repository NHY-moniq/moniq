import 'package:flutter/material.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:table_calendar/table_calendar.dart';

// Shift colors are mode-invariant, kept from AppColors.
// All other colors use Theme.of(context).colorScheme.

/// 캘린더 미리보기 데이터
class CalendarPreview {
  const CalendarPreview({required this.text, this.color, this.isWork = false});
  final String text;
  final Color? color;
  final bool isWork;
}

class MoniqCalendar extends StatelessWidget {
  const MoniqCalendar({
    super.key,
    required this.focusedDay,
    required this.selectedDay,
    required this.onDaySelected,
    required this.onPageChanged,
    this.eventLoader,
    this.calendarFormat = CalendarFormat.month,
    this.onFormatChanged,
    this.markerBuilder,
    this.startingDayOfWeek = StartingDayOfWeek.monday,
    this.previewBuilder,
    this.rowHeight = 52,
    this.onTodayPressed,
    this.legendItems,
  });

  final DateTime focusedDay;
  final DateTime selectedDay;
  final void Function(DateTime selectedDay, DateTime focusedDay) onDaySelected;
  final void Function(DateTime focusedDay) onPageChanged;
  final List<dynamic> Function(DateTime day)? eventLoader;
  final CalendarFormat calendarFormat;
  final void Function(CalendarFormat)? onFormatChanged;
  final Widget? Function(BuildContext, DateTime, List<dynamic>)? markerBuilder;
  final StartingDayOfWeek startingDayOfWeek;
  final List<CalendarPreview> Function(DateTime day)? previewBuilder;
  final double rowHeight;
  final VoidCallback? onTodayPressed;
  /// 범례 항목 (null이면 기본 DAY/EVENING/NIGHT/OFF)
  final List<({Color color, String label})>? legendItems;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppSpacing.screenHorizontal,
      child: Column(
        children: [
          // Header OUTSIDE the card
          _buildExternalHeader(context),
          const SizedBox(height: AppSpacing.md),

          // Calendar card
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context)
                      .colorScheme
                      .shadow
                      .withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.only(bottom: 8, top: 8),
            child: TableCalendar<dynamic>(
              locale: 'ko_KR',
              firstDay: DateTime(2020, 1, 1),
              lastDay: DateTime(2030, 12, 31),
              focusedDay: focusedDay,
              selectedDayPredicate: (day) => isSameDay(selectedDay, day),
              onDaySelected: onDaySelected,
              onPageChanged: onPageChanged,
              calendarFormat: calendarFormat,
              availableGestures: AvailableGestures.horizontalSwipe,
              onFormatChanged: onFormatChanged,
              rowHeight: rowHeight,
              availableCalendarFormats: const {
                CalendarFormat.month: '월',
                CalendarFormat.week: '주',
              },
              eventLoader: eventLoader,
              startingDayOfWeek: startingDayOfWeek,
              headerVisible: false,
          daysOfWeekHeight: 28,
          daysOfWeekStyle: DaysOfWeekStyle(
            weekdayStyle: Theme.of(context).textTheme.bodySmall!.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                  letterSpacing: 1.2,
                ),
            weekendStyle: Theme.of(context).textTheme.bodySmall!.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .error
                      .withValues(alpha: 0.7),
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                  letterSpacing: 1.2,
                ),
          ),
          calendarStyle: const CalendarStyle(
            outsideDaysVisible: false,
            cellMargin: EdgeInsets.all(1),
            markersMaxCount: 0,
          ),
          calendarBuilders: CalendarBuilders<dynamic>(
            dowBuilder: (context, day) {
              final cs = Theme.of(context).colorScheme;
              final text = _dowLabel(day.weekday).toUpperCase();
              Color color;
              if (day.weekday == DateTime.sunday) {
                color = cs.error.withValues(alpha: 0.7);
              } else if (day.weekday == DateTime.saturday) {
                color = cs.tertiary;
              } else {
                color = cs.onSurfaceVariant;
              }
              return Center(
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                        letterSpacing: 1.2,
                      ),
                ),
              );
            },
            defaultBuilder: (context, day, focusedDay) =>
                _buildCell(context, day, false, false),
            todayBuilder: (context, day, focusedDay) =>
                _buildCell(context, day, true, false),
            selectedBuilder: (context, day, focusedDay) =>
                _buildCell(context, day, false, true),
            ),
          ),
          ),
        ],
      ),
    );
  }

  Widget _buildExternalHeader(BuildContext context) {
    final now = DateTime.now();
    final isCurrentMonth =
        focusedDay.year == now.year && focusedDay.month == now.month;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 년월 + 화살표
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _showYearMonthPicker(context, focusedDay),
                child: Text(
                  '${focusedDay.year}년 ${focusedDay.month}월',
                  style: Theme.of(context).textTheme.titleLarge!.copyWith(
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                      ),
                ),
              ),
            ),
            if (!isCurrentMonth && onTodayPressed != null)
              GestureDetector(
                onTap: onTodayPressed,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Theme.of(context)
                        .colorScheme
                        .onPrimaryContainer,
                  ),
                ),
              ),
            GestureDetector(
              onTap: () {
                final prev =
                    DateTime(focusedDay.year, focusedDay.month - 1, 1);
                onPageChanged(prev);
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHigh,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.chevron_left, size: 18),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                final next =
                    DateTime(focusedDay.year, focusedDay.month + 1, 1);
                onPageChanged(next);
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHigh,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.chevron_right, size: 18),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // 범례
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: (legendItems ?? _defaultLegendItems)
              .map((item) => _legendDot(context, item.color, item.label))
              .toList(),
        ),
      ],
    );
  }

  static const _defaultLegendItems = [
    (color: AppColors.shiftDay, label: 'DAY'),
    (color: AppColors.shiftEvening, label: 'EVENING'),
    (color: AppColors.shiftNight, label: 'NIGHT'),
    (color: AppColors.shiftOff, label: 'OFF'),
  ];

  Widget _legendDot(
    BuildContext context,
    Color color,
    String label,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: Theme.of(context)
                .colorScheme
                .onSurfaceVariant,
          ),
        ),
      ],
    );
  }


  Widget _buildCell(
      BuildContext context, DateTime day, bool isToday, bool isSelected) {
    final cs = Theme.of(context).colorScheme;
    final events = eventLoader?.call(day) ?? [];
    final previews = previewBuilder?.call(day) ?? [];

    Color textColor;
    if (isToday) {
      textColor = cs.onPrimary;
    } else if (isSelected) {
      textColor = cs.primary;
    } else if (day.weekday == DateTime.sunday) {
      textColor = cs.error.withValues(alpha: 0.7);
    } else if (day.weekday == DateTime.saturday) {
      textColor = cs.tertiary;
    } else {
      textColor = cs.onSurface;
    }

    // Today blob color from first work preview
    Color todayColor = cs.primary;
    if (isToday && previews.isNotEmpty) {
      final firstWork = previews.where((p) => p.isWork).firstOrNull;
      if (firstWork?.color != null) {
        todayColor = firstWork!.color!;
      }
    }

    // Build marker dots
    Widget? markers;
    if (events.isNotEmpty && markerBuilder != null) {
      markers = markerBuilder!(context, day, events);
    }

    return SizedBox(
      width: double.infinity,
      height: rowHeight,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // Selected day — full cell background highlight
          if (isSelected && !isToday)
            Positioned.fill(
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: cs.primary.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
              ),
            ),

          // Today — PNG blob + centered number
          if (isToday)
            Positioned(
              top: -2,
              child: SizedBox(
                width: 36,
                height: 36,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Image.asset(
                      'assets/images/today.png',
                      width: 36,
                      height: 36,
                      fit: BoxFit.contain,
                      color: todayColor,
                      colorBlendMode: BlendMode.srcIn,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '${day.day}',
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Date number (non-today)
          if (!isToday)
            Positioned(
              top: 8,
              child: Text(
                '${day.day}',
                style: TextStyle(
                  color: textColor,
                  fontWeight: isSelected
                      ? FontWeight.w800
                      : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ),

          // Color dots below date
          if (markers != null)
            Positioned(
              top: 30,
              child: markers,
            ),

          // Preview tags below dots
          if (previews.isNotEmpty)
            Positioned(
              top: markers != null ? 42 : 30,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: previews
                    .take(2)
                    .map((p) => Padding(
                          padding: const EdgeInsets.only(
                            bottom: 1,
                          ),
                          child: _buildTag(context, p),
                        ))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTag(BuildContext context, CalendarPreview preview) {
    final tagColor = preview.color ??
        Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1.5),
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: tagColor.withValues(alpha: preview.isWork ? 0.25 : 0.12),
        borderRadius: BorderRadius.circular(4),
        border: preview.isWork
            ? Border.all(
                color: tagColor.withValues(alpha: 0.4),
                width: 0.8,
              )
            : null,
      ),
      child: Text(
        preview.text,
        style: TextStyle(
          fontSize: 8,
          color: tagColor,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      ),
    );
  }

  void _showYearMonthPicker(BuildContext context, DateTime day) async {
    final theme = Theme.of(context);
    final style =
        theme.textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w600);
    int selectedYear = day.year;
    int selectedMonth = day.month;

    final result = await showDialog<DateTime>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('연월 선택', textAlign: TextAlign.center),
          contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          content: SizedBox(
            width: 280,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () =>
                          setDialogState(() => selectedYear--),
                    ),
                    Text('$selectedYear년', style: style),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () =>
                          setDialogState(() => selectedYear++),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: List.generate(12, (i) {
                    final m = i + 1;
                    final isSel = m == selectedMonth;
                    return InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () =>
                          setDialogState(() => selectedMonth = m),
                      child: Builder(
                        builder: (innerCtx) {
                          final dcs =
                              Theme.of(innerCtx).colorScheme;
                          return Container(
                            width: 56,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isSel
                                  ? dcs.primary
                                  : null,
                              borderRadius:
                                  BorderRadius.circular(8),
                              border: isSel
                                  ? Border.all(
                                      color: dcs.primary,
                                      width: 1.5,
                                    )
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '$m월',
                              style: style.copyWith(
                                color: isSel
                                    ? dcs.onPrimary
                                    : null,
                                fontSize: 14,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(
                  ctx, DateTime(selectedYear, selectedMonth, 1)),
              child: const Text('이동'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      onPageChanged(result);
      onDaySelected(result, result);
    }
  }

  static String _dowLabel(int weekday) {
    const labels = {
      DateTime.monday: '월',
      DateTime.tuesday: '화',
      DateTime.wednesday: '수',
      DateTime.thursday: '목',
      DateTime.friday: '금',
      DateTime.saturday: '토',
      DateTime.sunday: '일',
    };
    return labels[weekday] ?? '';
  }
}

