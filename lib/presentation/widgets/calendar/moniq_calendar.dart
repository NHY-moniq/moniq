import 'package:flutter/material.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:table_calendar/table_calendar.dart';

/// 캘린더 미리보기 데이터
class CalendarPreview {
  const CalendarPreview({required this.text, this.color, this.isWork = false});
  final String text;
  final Color? color;
  /// 근무 일정이면 true, 개인 일정이면 false
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
      headerStyle: const HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        leftChevronIcon: Icon(Icons.chevron_left, size: 28),
        rightChevronIcon: Icon(Icons.chevron_right, size: 28),
        headerPadding: EdgeInsets.symmetric(vertical: 8),
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
        headerTitleBuilder: (context, day) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _showYearMonthPicker(context, day),
          child: Center(
            child: Text(
              '${day.year}년 ${day.month}월',
              style: Theme.of(context).textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ),
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

    // 태그 위젯 생성
    Widget buildTag(CalendarPreview preview) {
      return Container(
        constraints: BoxConstraints(maxWidth: preview.isWork ? 52 : 44),
        padding: EdgeInsets.symmetric(
          horizontal: preview.isWork ? 3 : 2,
          vertical: preview.isWork ? 1.5 : 0.5,
        ),
        decoration: BoxDecoration(
          color: preview.isWork
              ? (preview.color?.withValues(alpha: 0.3) ?? AppColors.textSecondaryLight.withValues(alpha: 0.2))
              : (preview.color?.withValues(alpha: 0.12) ?? AppColors.textSecondaryLight.withValues(alpha: 0.1)),
          borderRadius: BorderRadius.circular(preview.isWork ? 4 : 3),
          border: preview.isWork
              ? Border.all(
                  color: preview.color?.withValues(alpha: 0.5) ?? Colors.transparent,
                  width: 0.8,
                )
              : null,
        ),
        child: Text(
          preview.text,
          style: TextStyle(
            fontSize: preview.isWork ? 8.5 : 6.5,
            color: preview.isWork
                ? (preview.color ?? AppColors.textSecondaryLight)
                : (preview.color?.withValues(alpha: 0.7) ?? AppColors.textSecondaryLight),
            fontWeight: preview.isWork ? FontWeight.w800 : FontWeight.w500,
            height: 1.1,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: rowHeight,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // 날짜 숫자 — 항상 고정 위치
          Positioned(
            top: 8,
            child: Container(
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
          ),
          // 미리보기 태그 영역 — 날짜 아래 고정 위치
          if (previews.isNotEmpty)
            Positioned(
              top: 38,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: previews.take(3).map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 1),
                  child: buildTag(p),
                )).toList(),
              ),
            )
          else if (markers != null)
            Positioned(
              top: 40,
              child: markers,
            ),
        ],
      ),
    );
  }

  void _showYearMonthPicker(BuildContext context, DateTime day) async {
    final theme = Theme.of(context);
    final style = theme.textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w600);
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
                // 연도 선택
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => setDialogState(() => selectedYear--),
                    ),
                    Text('$selectedYear년', style: style),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => setDialogState(() => selectedYear++),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // 월 그리드 (Wrap 사용 — GridView 대신)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: List.generate(12, (i) {
                    final m = i + 1;
                    final isSelected = m == selectedMonth;
                    return InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => setDialogState(() => selectedMonth = m),
                      child: Container(
                        width: 56,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : null,
                          borderRadius: BorderRadius.circular(8),
                          border: isSelected
                              ? Border.all(color: AppColors.primary, width: 1.5)
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$m월',
                          style: style.copyWith(
                            color: isSelected ? Colors.white : null,
                            fontSize: 14,
                          ),
                        ),
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
              onPressed: () => Navigator.pop(ctx, DateTime(selectedYear, selectedMonth, 1)),
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
