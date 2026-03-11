import 'package:flutter/material.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:table_calendar/table_calendar.dart';

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
  });

  final DateTime focusedDay;
  final DateTime selectedDay;
  final void Function(DateTime selectedDay, DateTime focusedDay) onDaySelected;
  final void Function(DateTime focusedDay) onPageChanged;
  final List<dynamic> Function(DateTime day)? eventLoader;
  final CalendarFormat calendarFormat;
  final void Function(CalendarFormat)? onFormatChanged;
  final Widget? Function(BuildContext, DateTime, List<dynamic>)? markerBuilder;

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
      availableCalendarFormats: const {
        CalendarFormat.month: '월',
        CalendarFormat.week: '주',
      },
      eventLoader: eventLoader,
      startingDayOfWeek: StartingDayOfWeek.monday,
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
        todayDecoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.2),
          shape: BoxShape.circle,
        ),
        todayTextStyle: TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
        selectedDecoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
        selectedTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        weekendTextStyle: TextStyle(
          color: AppColors.error.withValues(alpha: 0.7),
        ),
        markersMaxCount: 3,
        markersAlignment: Alignment.bottomCenter,
        markerMargin: const EdgeInsets.symmetric(horizontal: 0.5),
      ),
      calendarBuilders: CalendarBuilders<dynamic>(
        markerBuilder: markerBuilder,
      ),
    );
  }
}
