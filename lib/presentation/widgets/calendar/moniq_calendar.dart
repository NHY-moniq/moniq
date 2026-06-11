import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/theme/app_typography.dart';
import 'package:moniq/presentation/widgets/calendar/view_mode_toggle.dart';
import 'package:moniq/presentation/widgets/common/moniq_bottom_sheet.dart';
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

class MoniqCalendar extends StatefulWidget {
  const MoniqCalendar({
    super.key,
    required this.focusedDay,
    required this.selectedDay,
    required this.onDaySelected,
    required this.onPageChanged,
    this.onDayLongPressed,
    this.eventLoader,
    this.calendarFormat = CalendarFormat.month,
    this.onFormatChanged,
    this.markerBuilder,
    this.cornerBadgeBuilder,
    this.startingDayOfWeek = StartingDayOfWeek.monday,
    this.previewBuilder,
    this.rowHeight = 58,
    this.onTodayPressed,
    this.legendItems,
    this.viewMode,
    this.onViewModeChanged,
  });

  final DateTime focusedDay;
  final DateTime selectedDay;
  final void Function(DateTime selectedDay, DateTime focusedDay) onDaySelected;
  final void Function(DateTime focusedDay) onPageChanged;

  /// 날짜를 길게 누르면 호출 (선택과 별개 제스처).
  final void Function(DateTime day, DateTime focusedDay)? onDayLongPressed;
  final List<dynamic> Function(DateTime day)? eventLoader;
  final CalendarFormat calendarFormat;
  final void Function(CalendarFormat)? onFormatChanged;
  final Widget? Function(BuildContext, DateTime, List<dynamic>)? markerBuilder;
  final Widget? Function(BuildContext, DateTime)? cornerBadgeBuilder;
  final StartingDayOfWeek startingDayOfWeek;
  final List<CalendarPreview> Function(DateTime day)? previewBuilder;
  final double rowHeight;
  final VoidCallback? onTodayPressed;

  /// 범례 항목 (null이면 기본 DAY/EVENING/NIGHT/OFF)
  final List<({Color color, String label})>? legendItems;

  /// 헤더 우측에 월/주 segmented pill을 표시하려면 함께 전달.
  /// 둘 다 null이면 토글이 표시되지 않는다.
  final CalendarViewMode? viewMode;
  final ValueChanged<CalendarViewMode>? onViewModeChanged;

  @override
  State<MoniqCalendar> createState() => _MoniqCalendarState();
}

class _MoniqCalendarState extends State<MoniqCalendar> {
  // TableCalendar 내부 PageController — 화살표 버튼이 이 컨트롤러로 직접
  // 페이지를 넘겨, 외부 focusedDay 변경에 의한 재애니메이션/이중 onPageChanged
  // (좌우 클릭 시 캘린더가 혼자 움직이던 버그)를 방지한다.
  PageController? _pageController;

  // 기존 build/헬퍼 코드를 한 줄도 바꾸지 않고 쓰기 위한 prop forwarding getter.
  DateTime get focusedDay => widget.focusedDay;
  DateTime get selectedDay => widget.selectedDay;
  void Function(DateTime, DateTime) get onDaySelected => widget.onDaySelected;
  void Function(DateTime) get onPageChanged => widget.onPageChanged;
  void Function(DateTime, DateTime)? get onDayLongPressed =>
      widget.onDayLongPressed;
  List<dynamic> Function(DateTime)? get eventLoader => widget.eventLoader;
  CalendarFormat get calendarFormat => widget.calendarFormat;
  void Function(CalendarFormat)? get onFormatChanged => widget.onFormatChanged;
  Widget? Function(BuildContext, DateTime, List<dynamic>)? get markerBuilder =>
      widget.markerBuilder;
  Widget? Function(BuildContext, DateTime)? get cornerBadgeBuilder =>
      widget.cornerBadgeBuilder;
  StartingDayOfWeek get startingDayOfWeek => widget.startingDayOfWeek;
  List<CalendarPreview> Function(DateTime)? get previewBuilder =>
      widget.previewBuilder;
  double get rowHeight => widget.rowHeight;
  VoidCallback? get onTodayPressed => widget.onTodayPressed;
  List<({Color color, String label})>? get legendItems => widget.legendItems;
  CalendarViewMode? get viewMode => widget.viewMode;
  ValueChanged<CalendarViewMode>? get onViewModeChanged =>
      widget.onViewModeChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: AppSpacing.screenHorizontal,
      child: Column(
        children: [
          // Header OUTSIDE the card
          _buildExternalHeader(context),
          const SizedBox(height: AppSpacing.md),

          // Calendar card — 팀 관리 페이지(MoniqCard)와 동일한 표면 톤으로 통일.
          // Scaffold 배경(surfaceContainerLow) 위에 카드가 한 단계 대비되는 표면으로
          // 떠 보이도록: 라이트=흰색(surfaceContainerLowest), 다크=surfaceContainer + soft shadow.
          Container(
            decoration: BoxDecoration(
              color: isDark ? cs.surfaceContainer : cs.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: [
                BoxShadow(
                  color: cs.shadow.withValues(alpha: isDark ? 0.3 : 0.04),
                  blurRadius: 12,
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
              onDayLongPressed: onDayLongPressed,
              onPageChanged: onPageChanged,
              onCalendarCreated: (controller) => _pageController = controller,
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
                  color: Theme.of(
                    context,
                  ).colorScheme.error.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                  letterSpacing: 1.2,
                ),
              ),
              calendarStyle: const CalendarStyle(
                outsideDaysVisible: true,
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
                // 이전달·다음달 미리보기 — 날짜 숫자만 회색으로 표시
                outsideBuilder: (context, day, focusedDay) =>
                    _buildOutsideCell(context, day),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExternalHeader(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    // 월 모드: 현재 달인지. 주 모드: focused가 속한 주 안에 오늘이 있는지.
    final showsToday = viewMode == CalendarViewMode.week
        ? _isSameWeek(focusedDay, now, startingDayOfWeek)
        : focusedDay.year == now.year && focusedDay.month == now.month;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1줄: 년월 (displayMedium) + 우측 컨트롤 라인
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _showYearMonthPicker(context, focusedDay),
                child: Text(
                  '${focusedDay.year}년 ${focusedDay.month}월',
                  style: AppTypography.displayMedium.copyWith(
                    color: cs.onSurface,
                  ),
                ),
              ),
            ),
            if (!showsToday && onTodayPressed != null) ...[
              _HeaderPill(
                onTap: onTodayPressed!,
                child: Icon(
                  Icons.today_outlined,
                  size: 16,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(width: 6),
            ],
            _HeaderPill(
              onTap: () {
                // 페이지 컨트롤러로 직접 한 페이지 이동(주/월 모두 동일).
                // 이동이 끝나면 TableCalendar의 onPageChanged가 단 한 번 발화한다.
                final pc = _pageController;
                if (pc != null && pc.hasClients) {
                  pc.previousPage(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                  );
                } else {
                  final prev = viewMode == CalendarViewMode.week
                      ? focusedDay.subtract(const Duration(days: 7))
                      : DateTime(focusedDay.year, focusedDay.month - 1, 1);
                  onPageChanged(prev);
                }
              },
              child: Icon(Icons.chevron_left, size: 18, color: cs.onSurface),
            ),
            const SizedBox(width: 6),
            _HeaderPill(
              onTap: () {
                final pc = _pageController;
                if (pc != null && pc.hasClients) {
                  pc.nextPage(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                  );
                } else {
                  final next = viewMode == CalendarViewMode.week
                      ? focusedDay.add(const Duration(days: 7))
                      : DateTime(focusedDay.year, focusedDay.month + 1, 1);
                  onPageChanged(next);
                }
              },
              child: Icon(Icons.chevron_right, size: 18, color: cs.onSurface),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        // 2줄: 범례 + 월/주 segmented pill
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Wrap(
                spacing: 10,
                runSpacing: 4,
                children: (legendItems ?? _defaultLegendItems)
                    .map((item) => _legendDot(context, item.color, item.label))
                    .toList(),
              ),
            ),
            if (viewMode != null && onViewModeChanged != null)
              _ViewModeSegmentedPill(
                mode: viewMode!,
                onChanged: onViewModeChanged!,
              ),
          ],
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

  Widget _legendDot(BuildContext context, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  /// 이전달·다음달 날짜 — 숫자만 흐린 회색으로 미리보기 표시 (근무/일정은 숨김).
  Widget _buildOutsideCell(BuildContext context, DateTime day) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      height: rowHeight,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: 8,
            child: Text(
              '${day.day}',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.28),
                fontWeight: FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCell(
    BuildContext context,
    DateTime day,
    bool isToday,
    bool isSelected,
  ) {
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
    final cornerBadge = cornerBadgeBuilder?.call(context, day);

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

          // Today — 일반 날짜 텍스트와 동일한 vertical 영역(top=4..28)
          // 안에 들어가는 작은 blob. 미리보기가 밀리지 않도록 사이즈를 줄임.
          if (isToday)
            Positioned(
              top: 4,
              child: SizedBox(
                width: 24,
                height: 24,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(24, 24),
                      painter: _BlobPainter(todayColor),
                    ),
                    Text(
                      '${day.day}',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
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
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ),

          if (cornerBadge != null)
            Positioned(top: 3, right: 5, child: cornerBadge),

          // 마커/미리보기 시작 y — today/non-today 동일 (밀림 방지)
          if (markers != null) Positioned(top: 30, child: markers),

          // Preview tags below dots — 셀 가로 폭 가득 채움
          if (previews.isNotEmpty)
            Positioned(
              top: markers != null ? 42 : 30,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: previews
                    .take(2)
                    .map(
                      (p) => Padding(
                        padding: const EdgeInsets.only(bottom: 1),
                        child: _buildTag(context, p),
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTag(BuildContext context, CalendarPreview preview) {
    final cs = Theme.of(context).colorScheme;
    final color = preview.color ?? cs.onSurfaceVariant;

    if (preview.isWork) {
      // 근무: 셀 가로 폭을 가득 채우는 컬러 박스 (D/E/N/O 단문자).
      // 테두리 없이 fill alpha만 적용.
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          preview.text,
          style: TextStyle(
            fontSize: 9,
            color: color,
            fontWeight: FontWeight.w800,
            height: 1.1,
            letterSpacing: 0.2,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      );
    }

    // 개인 일정: 배경 없는 plain 텍스트 — 셀 가운데 정렬,
    // 사용자가 추가 시 지정한 색상으로 텍스트 채색 (없으면 onSurface)
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0.5),
      child: Text(
        preview.text,
        style: TextStyle(
          fontSize: 9,
          color: preview.color ?? cs.onSurface,
          fontWeight: FontWeight.w600,
          height: 1.1,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      ),
    );
  }

  void _showYearMonthPicker(BuildContext context, DateTime day) async {
    DateTime selected = DateTime(day.year, day.month);

    final result = await showMoniqBottomSheet<DateTime>(
      context: context,
      title: '연월 선택',
      child: Builder(
        builder: (ctx) {
          final cs = Theme.of(ctx).colorScheme;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 216,
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.monthYear,
                  initialDateTime: selected,
                  onDateTimeChanged: (d) {
                    selected = DateTime(d.year, d.month);
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.borderRadiusFull,
                  ),
                ),
                onPressed: () => Navigator.pop(
                  ctx,
                  DateTime(selected.year, selected.month, 1),
                ),
                child: Text(
                  '이동',
                  style: AppTypography.labelLarge.copyWith(
                    color: cs.onPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    if (result != null) {
      onPageChanged(result);
      onDaySelected(result, result);
    }
  }

  /// [a]와 [b]가 같은 주에 속하는지 — [startingDayOfWeek]를 기준으로 계산.
  static bool _isSameWeek(
    DateTime a,
    DateTime b,
    StartingDayOfWeek startingDayOfWeek,
  ) {
    final startWeekday = switch (startingDayOfWeek) {
      StartingDayOfWeek.sunday => DateTime.sunday,
      StartingDayOfWeek.monday => DateTime.monday,
      _ => DateTime.monday,
    };
    DateTime startOfWeek(DateTime d) {
      final daysFromStart = (d.weekday - startWeekday) % 7;
      final base = DateTime(d.year, d.month, d.day);
      return base.subtract(Duration(days: daysFromStart));
    }

    return startOfWeek(a) == startOfWeek(b);
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

class _BlobPainter extends CustomPainter {
  const _BlobPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.50, h * 0.03)
      ..cubicTo(w * 0.80, h * 0.00, w * 1.02, h * 0.22, w * 0.98, h * 0.52)
      ..cubicTo(w * 0.94, h * 0.82, w * 0.72, h * 1.00, w * 0.46, h * 0.98)
      ..cubicTo(w * 0.20, h * 0.96, w * 0.00, h * 0.78, h * 0.02, h * 0.50)
      ..cubicTo(w * 0.04, h * 0.22, w * 0.22, h * 0.06, w * 0.50, h * 0.03)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_BlobPainter old) => old.color != color;
}

/// 헤더 우측 원형 pill 버튼 (chevron / today / 등).
class _HeaderPill extends StatelessWidget {
  const _HeaderPill({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHigh,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(padding: const EdgeInsets.all(7), child: child),
      ),
    );
  }
}

/// 헤더 우측 월/주 segmented pill 토글.
class _ViewModeSegmentedPill extends StatelessWidget {
  const _ViewModeSegmentedPill({required this.mode, required this.onChanged});

  final CalendarViewMode mode;
  final ValueChanged<CalendarViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: CalendarViewMode.values.map((m) {
          final selected = m == mode;
          final label = m == CalendarViewMode.month ? '월' : '주';
          return GestureDetector(
            onTap: () => onChanged(m),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: selected ? cs.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: selected ? cs.onPrimary : cs.onSurfaceVariant,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
