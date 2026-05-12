import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/core/utils/color_utils.dart';
import 'package:moniq/data/datasources/personal_shift_type_local_data_source.dart';
import 'package:moniq/data/models/shift_with_type.dart';
import 'package:moniq/data/providers/auth_providers.dart';
import 'package:moniq/data/providers/settings_providers.dart';
import 'package:moniq/presentation/layout/adaptive_layout.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/home_viewmodel.dart';
import 'package:moniq/presentation/widgets/calendar/moniq_calendar.dart';
import 'package:moniq/presentation/widgets/common/moniq_app_bar.dart';
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


    final calendarTitle = displayName != null && displayName.isNotEmpty
        ? '$displayName 님의 일정'
        : '내 캘린더';

    Widget buildAvatarLeading() {
      return GestureDetector(
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
      );
    }

    return calendarAsync.when(
      loading: () => Scaffold(
        appBar: MoniqAppBar(
          title: calendarTitle,
          eyebrow: 'ONOROFF',
          showBack: false,
          leading: buildAvatarLeading(),
        ),
        body: const MoniqLoadingView(),
      ),
      error: (e, _) => Scaffold(
        appBar: MoniqAppBar(
          title: calendarTitle,
          eyebrow: 'ONOROFF',
          showBack: false,
          leading: buildAvatarLeading(),
        ),
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
          appBar: MoniqAppBar(
                  title: calendarTitle,
                  eyebrow: 'ONOROFF',
                  showBack: false,
                  leading: buildAvatarLeading(),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MoniqAppBarAction(
                        icon: Icons.ios_share_outlined,
                        onTap: () => exportCalendar(context, ref, state),
                      ),
                      // 팀 캘린더와 동일한 휴지통 — 월별 개인 일정/메모 일괄 삭제
                      MoniqAppBarAction(
                        icon: Icons.delete_outline_rounded,
                        tint: AppColors.error,
                        onTap: () => showDeletePersonalScheduleSheet(
                          context: context,
                          ref: ref,
                        ),
                      ),
                      if (!AdaptiveLayout.isWide(context))
                        Builder(
                          builder: (ctx) => MoniqAppBarAction(
                            icon: Icons.menu_rounded,
                            onTap: () => Scaffold.of(ctx).openEndDrawer(),
                          ),
                        ),
                    ],
                  ),
                ),
          endDrawer: AdaptiveLayout.isWide(context)
              ? null
              : CalendarDrawer(
                  onImportCalendar: () => importDeviceCalendar(context, ref),
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
          body: RefreshIndicator(
            onRefresh: () async {
              await ref.read(homeViewModelProvider.notifier).refresh();
              // 개인 일정/노트/오버라이드 등도 함께 갱신
              ref.read(eventRefreshProvider.notifier).state++;
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppSpacing.sm),

                // ── Calendar (근무 범례/프리뷰 제거됨) ──
                MoniqCalendar(
                  legendItems: const [],
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
                    final hideTeamShifts =
                        ref.watch(hideTeamShiftsInPersonalProvider);
                    return [
                      // 팀 로스터 근무: 설정에 따라 숨김 가능
                      if (!hideTeamShifts)
                        ...state.monthlyShifts[key] ?? [],
                      ...monthlyEvents[key] ?? [],
                      ...monthlyNotes[key] ?? [],
                    ];
                  },
                  // dots/markers는 사용하지 않음 — 근무는 previewBuilder의
                  // 컬러 박스(D/E/N/O)로, 개인 일정은 plain 텍스트로 표시.
                  markerBuilder: (context, day, events) => null,
                  previewBuilder: (day) {
                    final key = DateTime(day.year, day.month, day.day);
                    final result = <CalendarPreview>[];
                    final personalShiftTypes =
                        ref.read(personalShiftTypesProvider);
                    final shiftTypeByName = {
                      for (final st in personalShiftTypes) st.name: st,
                    };
                    final overrides = ref
                            .watch(personalShiftOverridesProvider)
                            .valueOrNull ??
                        const {};
                    final seenWorkLabels = <String>{};

                    String labelOf(String name, String code) {
                      final personalType = shiftTypeByName[name];
                      if (personalType != null) {
                        return displayShiftLabel(
                            personalType, personalShiftTypes);
                      }
                      final c = code.toUpperCase();
                      if (c == 'OFF') return 'O';
                      if (c.isEmpty) {
                        return name.isEmpty ? '?' : name[0].toUpperCase();
                      }
                      return c.length > 1 ? c[0] : c;
                    }

                    // 1) 서버 근무: 컬러 박스로 단문자 표시
                    //    "팀 근무 숨기기" 토글이 ON이면 서버 근무는 스킵
                    final hideTeamShiftsPv =
                        ref.watch(hideTeamShiftsInPersonalProvider);
                    final dayShifts = hideTeamShiftsPv
                        ? const <ShiftWithType>[]
                        : (state.monthlyShifts[key] ?? const []);
                    for (final s in dayShifts) {
                      final label =
                          labelOf(s.shiftType.name, s.shiftType.code);
                      if (!seenWorkLabels.add(label)) continue;
                      final ov = overrides[s.shift.id];
                      final colorHex = ov?.color ?? s.shiftType.color;
                      result.add(CalendarPreview(
                        text: label,
                        color: parseHexColor(colorHex),
                        isWork: true,
                      ));
                    }
                    // 2) 개인 일정: 근무 매칭이면 컬러 박스(중복 제거), 아니면 plain
                    final evts = monthlyEvents[key];
                    if (evts != null && evts.isNotEmpty) {
                      for (final e in evts) {
                        if (result.length >= 3) break;
                        final matchedType = shiftTypeByName[e.title];
                        if (matchedType != null) {
                          final label = displayShiftLabel(
                              matchedType, personalShiftTypes);
                          if (!seenWorkLabels.add(label)) continue;
                          final colorHex = e.color ?? matchedType.color;
                          result.add(CalendarPreview(
                            text: label,
                            color: parseHexColor(colorHex),
                            isWork: true,
                          ));
                        } else {
                          result.add(CalendarPreview(
                            text: e.title,
                            color: e.color != null
                                ? parseHexColor(e.color!)
                                : null,
                            isWork: false,
                          ));
                        }
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
          ),
        );
      },
    );
  }

}

