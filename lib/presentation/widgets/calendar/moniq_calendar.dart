import 'package:flutter/material.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:table_calendar/table_calendar.dart';

/// 캘린더 미리보기 데이터
class CalendarPreview {
  const CalendarPreview({required this.text, this.color});
  final String text;
  final Color? color;
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
  /// 날짜별 미리보기 리스트를 반환 (최대 2개 표시)
  final List<CalendarPreview> Function(DateTime day)? previewBuilder;
  final double rowHeight;

  @override
  Widget build(BuildContext context) {
    return TableCalendar<dynamic>(
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
      headerStyle: HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        titleTextStyle: Theme.of(context).textTheme.titleMedium!.copyWith(
              fontWeight: FontWeight.w600,
            ),
        leftChevronIcon: const Icon(Icons.chevron_left, size: 28),
        rightChevronIcon: const Icon(Icons.chevron_right, size: 28),
        headerPadding: const EdgeInsets.symmetric(vertical: 8),
      ),
      daysOfWeekHeight: 20,
      daysOfWeekStyle: DaysOfWeekStyle(
        weekdayStyle: Theme.of(context).textTheme.bodySmall!.copyWith(
              color: AppColors.textSecondaryLight,
              fontWeight: FontWeight.w500,
            ),
        weekendStyle: Theme.of(context).textTheme.bodySmall!.copyWith(
              color: AppColors.error.withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
            ),
      ),
      calendarStyle: CalendarStyle(
        outsideDaysVisible: false,
        cellMargin: const EdgeInsets.all(1),
        markersMaxCount: 0,
      ),
      calendarBuilders: CalendarBuilders<dynamic>(
        dowBuilder: (context, day) {
          final text = _dowLabel(day.weekday);
          Color color;
          if (day.weekday == DateTime.sunday) {
            color = AppColors.error.withValues(alpha: 0.7);
          } else if (day.weekday == DateTime.saturday) {
            color = AppColors.brandBlue;
          } else {
            color = AppColors.textSecondaryLight;
          }
          return Center(
            child: Text(text,
                style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      color: color, fontWeight: FontWeight.w500)),
          );
        },
        defaultBuilder: (context, day, focusedDay) =>
            _buildCell(context, day, false, false),
        todayBuilder: (context, day, focusedDay) =>
            _buildCell(context, day, true, false),
        selectedBuilder: (context, day, focusedDay) =>
            _buildCell(context, day, false, true),
      ),
    );
  }

  Widget _buildCell(
      BuildContext context, DateTime day, bool isToday, bool isSelected) {
    final theme = Theme.of(context);
    final events = eventLoader?.call(day) ?? [];
    final previews = previewBuilder?.call(day) ?? [];
    final hasEvents = events.isNotEmpty;

    Color textColor;
    if (isSelected) {
      textColor = Colors.white;
    } else if (isToday) {
      textColor = AppColors.primary;
    } else if (day.weekday == DateTime.sunday) {
      textColor = AppColors.error.withValues(alpha: 0.7);
    } else if (day.weekday == DateTime.saturday) {
      textColor = AppColors.brandBlue;
    } else {
      textColor = theme.textTheme.bodyMedium?.color ?? Colors.black;
    }

    Widget? markers;
    if (hasEvents && markerBuilder != null && previews.isEmpty) {
      markers = markerBuilder!(context, day, events);
    }

    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary
                  : isToday
                      ? AppColors.primary.withValues(alpha: 0.2)
                      : null,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${day.day}',
                style: TextStyle(
                  color: textColor,
                  fontWeight:
                      (isToday || isSelected) ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          // 미리보기 태그들 (최대 2개)
          if (previews.isNotEmpty)
            ...previews.take(2).map((preview) => Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 48),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 2, vertical: 0.5),
                    decoration: BoxDecoration(
                      color: preview.color?.withValues(alpha: 0.2) ??
                          AppColors.textSecondaryLight.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      preview.text,
                      style: TextStyle(
                        fontSize: 7,
                        color: preview.color ?? AppColors.textSecondaryLight,
                        fontWeight: FontWeight.w600,
                        height: 1.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ))
          else if (markers != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: markers,
            ),
        ],
      ),
    );
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
