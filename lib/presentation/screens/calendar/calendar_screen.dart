import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/core/utils/color_utils.dart';
import 'package:moniq/data/datasources/personal_event_local_data_source.dart';
import 'package:moniq/data/models/shift_with_type.dart';
import 'package:moniq/data/providers/auth_providers.dart';
import 'package:moniq/data/providers/settings_providers.dart';
import 'package:moniq/presentation/layout/adaptive_layout.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/home_viewmodel.dart';
import 'package:moniq/presentation/widgets/calendar/moniq_calendar.dart';
import 'package:moniq/presentation/widgets/common/moniq_error_view.dart';
import 'package:moniq/presentation/widgets/common/moniq_loading_view.dart';
import 'package:table_calendar/table_calendar.dart';

import 'calendar_dialogs.dart';
import 'calendar_drawer.dart';
import 'calendar_export.dart';
import 'calendar_providers.dart';
import 'date_items_panel.dart';

// Re-export providers so external code importing calendar_screen.dart
// continues to work without changes.
export 'calendar_providers.dart';

// -- Screen --

class CalendarScreen extends HookConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendarAsync = ref.watch(homeViewModelProvider);
    final calendarStartDay = ref.watch(calendarStartDayProvider);
    final startingDay = calendarStartDay == 'sunday'
        ? StartingDayOfWeek.sunday
        : StartingDayOfWeek.monday;

    final currentUser = ref.watch(currentUserProvider);
    final userMeta = currentUser?.userMetadata;
    final displayName = userMeta?['display_name'] as String?;
    final avatarUrl = userMeta?['avatar_url'] as String?;

    Widget buildAppBarTitle() {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: (avatarUrl != null && avatarUrl.isNotEmpty)
                ? () {
                    showDialog(
                      context: context,
                      builder: (ctx) => Dialog(
                        backgroundColor: Colors.transparent,
                        child: GestureDetector(
                          onTap: () => Navigator.pop(ctx),
                          child: CircleAvatar(
                            radius: 100,
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .primaryContainer,
                            backgroundImage:
                                CachedNetworkImageProvider(avatarUrl),
                          ),
                        ),
                      ),
                    );
                  }
                : null,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.primaryContainer,
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  width: 2,
                ),
              ),
              child: avatarUrl != null && avatarUrl.isNotEmpty
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: avatarUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Icon(
                          Icons.person,
                          size: 20,
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer,
                        ),
                      ),
                    )
                  : Icon(
                      Icons.person,
                      size: 20,
                      color: Theme.of(context)
                          .colorScheme
                          .onPrimaryContainer,
                    ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ONOROFF',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.0,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
              Text(
                displayName != null && displayName.isNotEmpty
                    ? '$displayName \uB2D8\uC758 \uC77C\uC815'
                    : '\uB0B4 \uCE98\uB9B0\uB354',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
        ],
      );
    }

    return calendarAsync.when(
      loading: () => Scaffold(
        appBar: AdaptiveLayout.isWide(context)
            ? null
            : AppBar(title: buildAppBarTitle()),
        body: const MoniqLoadingView(),
      ),
      error: (e, _) => Scaffold(
        appBar: AdaptiveLayout.isWide(context)
            ? null
            : AppBar(title: buildAppBarTitle()),
        body: MoniqErrorView(
          message: '\uC77C\uC815\uC744 \uBD88\uB7EC\uC62C \uC218 \uC5C6\uC2B5\uB2C8\uB2E4',
          onRetry: () => ref.read(homeViewModelProvider.notifier).refresh(),
        ),
      ),
      data: (state) {
        final monthlyNotes =
            ref.watch(monthlyNotesProvider(state.focusedMonth));
        final monthlyEvents =
            ref.watch(monthlyEventsProvider(state.focusedMonth));
        final dateNotes = ref.watch(dateNotesProvider(state.selectedDate));
        final dateEvents = ref.watch(dateEventsProvider(state.selectedDate));

        return Scaffold(
          backgroundColor:
              Theme.of(context).colorScheme.surfaceContainerLow,
          appBar: AdaptiveLayout.isWide(context)
              ? null
              : AppBar(
                  backgroundColor:
                      Theme.of(context).colorScheme.surfaceContainerLow,
                  title: buildAppBarTitle(),
                  actions: [
                    Builder(
                      builder: (ctx) => IconButton(
                        icon: const Icon(Icons.menu),
                        onPressed: () => Scaffold.of(ctx).openEndDrawer(),
                      ),
                    ),
                  ],
                ),
          endDrawer: AdaptiveLayout.isWide(context)
              ? null
              : CalendarDrawer(
                  onImportCalendar: () => importDeviceCalendar(context, ref),
                  onExportCalendar: () => exportCalendar(context, ref, state),
                ),
          floatingActionButton: Padding(
            padding: const EdgeInsets.only(bottom: 72),
            child: FloatingActionButton.small(
              onPressed: () => showAddMenu(context, ref, state.selectedDate),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor:
                  Theme.of(context).colorScheme.onPrimary,
              elevation: 3,
              child: const Icon(Icons.add),
            ),
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.sm),

                // ── Calendar (범례는 개인 근무유형에서 동적 생성) ──
                MoniqCalendar(
                  legendItems: ref.watch(personalShiftTypesProvider)
                      .map((st) => (
                            color: parseHexColor(st.color),
                            label: st.code.toUpperCase(),
                          ))
                      .toList(),
                  focusedDay: state.focusedMonth,
                  selectedDay: state.selectedDate,
                  startingDayOfWeek: startingDay,
                  rowHeight: 80,
                  onTodayPressed: () {
                    final today = DateTime.now();
                    final todayDate =
                        DateTime(today.year, today.month, today.day);
                    ref
                        .read(homeViewModelProvider.notifier)
                        .changeMonth(todayDate);
                    ref
                        .read(homeViewModelProvider.notifier)
                        .selectDate(todayDate);
                  },
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
                    return [
                      ...state.monthlyShifts[key] ?? [],
                      ...monthlyEvents[key] ?? [],
                      ...monthlyNotes[key] ?? [],
                    ];
                  },
                  markerBuilder: (context, day, events) {
                    if (events.isEmpty) return null;
                    final dots = <Widget>[];
                    final shiftTypeNames = ref
                        .read(personalShiftTypesProvider)
                        .map((st) => st.name)
                        .toSet();
                    final overrides = ref
                            .watch(personalShiftOverridesProvider)
                            .valueOrNull ??
                        const {};
                    // 서버 근무만 dot (오버라이드 색상 적용)
                    for (final s
                        in events.whereType<ShiftWithType>().take(2)) {
                      final ov = overrides[s.shift.id];
                      final colorHex = ov?.color ?? s.shiftType.color;
                      dots.add(_shiftDot(parseHexColor(colorHex)));
                    }
                    // 개인 일정 중 근무 유형 매칭만 dot
                    for (final e in events.whereType<PersonalEvent>()) {
                      if (dots.length >= 3) break;
                      if (shiftTypeNames.contains(e.title)) {
                        final c = e.color != null
                            ? parseHexColor(e.color!)
                            : AppColors.shiftDay;
                        dots.add(_shiftDot(c));
                      }
                    }
                    if (dots.isEmpty) return null;
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: dots,
                    );
                  },
                  previewBuilder: (day) {
                    final key = DateTime(day.year, day.month, day.day);
                    final result = <CalendarPreview>[];
                    final shiftTypeNames = ref
                        .read(personalShiftTypesProvider)
                        .map((st) => st.name)
                        .toSet();

                    // Server shifts — dot으로만 표시 (previewBuilder 스킵)
                    // Personal events — 근무 유형 매칭은 스킵, 비근무만 태그
                    final evts = monthlyEvents[key];
                    if (evts != null && evts.isNotEmpty) {
                      for (final e in evts) {
                        if (result.length >= 3) break;
                        if (shiftTypeNames.contains(e.title)) continue;
                        result.add(CalendarPreview(
                          text: e.title,
                          color: e.color != null
                              ? parseHexColor(e.color!)
                              : null,
                          isWork: false,
                        ));
                      }
                    }
                    return result;
                  },
                ),

                const SizedBox(height: AppSpacing.lg),
                DateItemsPanel(
                  date: state.selectedDate,
                  shifts: state.selectedDateShifts ?? [],
                  events: dateEvents,
                  notes: dateNotes,
                  hasTeamSchedule: state.monthlyShifts.isNotEmpty,
                ),

                const SizedBox(height: 120),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Small colored dot widget for calendar markers.
  static Widget _shiftDot(Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 1.5,
            ),
          ],
        ),
      ),
    );
  }

}

