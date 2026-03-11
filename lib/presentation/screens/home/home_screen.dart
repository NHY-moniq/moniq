import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/core/utils/color_utils.dart';
import 'package:moniq/data/models/shift_with_type.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/home_viewmodel.dart';
import 'package:moniq/presentation/widgets/calendar/moniq_calendar.dart';
import 'package:moniq/presentation/widgets/calendar/shift_detail_panel.dart';
import 'package:moniq/presentation/widgets/calendar/shift_marker.dart';
import 'package:moniq/presentation/widgets/calendar/today_card.dart';
import 'package:moniq/presentation/widgets/common/moniq_error_view.dart';
import 'package:moniq/presentation/widgets/common/moniq_loading_view.dart';

class HomeScreen extends HookConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendarAsync = ref.watch(homeViewModelProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('내 일정')),
      body: calendarAsync.when(
        loading: () => const MoniqLoadingView(),
        error: (e, _) => MoniqErrorView(
          message: '일정을 불러올 수 없습니다',
          onRetry: () => ref.read(homeViewModelProvider.notifier).refresh(),
        ),
        data: (state) {
          final today = DateTime.now();
          final todayKey =
              DateTime(today.year, today.month, today.day);
          final todayShifts = state.monthlyShifts[todayKey];
          final firstTodayShift =
              todayShifts != null && todayShifts.isNotEmpty
                  ? todayShifts.first
                  : null;

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MoniqCalendar(
                  focusedDay: state.focusedMonth,
                  selectedDay: state.selectedDate,
                  onDaySelected: (selected, focused) {
                    ref
                        .read(homeViewModelProvider.notifier)
                        .selectDate(selected);
                  },
                  onPageChanged: (focused) {
                    ref
                        .read(homeViewModelProvider.notifier)
                        .changeMonth(focused);
                  },
                  eventLoader: (day) {
                    final key = DateTime(day.year, day.month, day.day);
                    return state.monthlyShifts[key] ?? [];
                  },
                  markerBuilder: (context, day, events) {
                    if (events.isEmpty) return null;
                    final shifts = events.cast<ShiftWithType>();
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: shifts
                          .take(3)
                          .map(
                            (s) => ShiftMarker(
                              color: parseHexColor(s.shiftType.color),
                            ),
                          )
                          .toList(),
                    );
                  },
                ),

                // Today card
                if (firstTodayShift != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Padding(
                    padding: AppSpacing.screenHorizontal,
                    child: TodayCard(
                      shiftTypeName: firstTodayShift.shiftType.name,
                      shiftTypeCode: firstTodayShift.shiftType.code,
                      shiftColor:
                          parseHexColor(firstTodayShift.shiftType.color),
                      startTime: firstTodayShift.shiftType.startTime,
                      endTime: firstTodayShift.shiftType.endTime,
                      teamName: firstTodayShift.teamName,
                    ),
                  ),
                ],

                // Selected date detail
                if (state.selectedDateShifts != null &&
                    state.selectedDateShifts!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  ShiftDetailPanel(
                    date: state.selectedDate,
                    shifts: state.selectedDateShifts!,
                  ),
                ],

                const SizedBox(height: AppSpacing.xxxl),
              ],
            ),
          );
        },
      ),
    );
  }
}
