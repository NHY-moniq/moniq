import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/core/utils/color_utils.dart';
import 'package:moniq/data/datasources/personal_event_remote_data_source.dart'
    show kPersonalTeamImportMarker;
import 'package:moniq/data/datasources/personal_shift_type_local_data_source.dart';
import 'package:moniq/data/models/shift_with_type.dart';
import 'package:moniq/data/providers/auth_providers.dart';
import 'package:moniq/data/providers/settings_providers.dart';
import 'package:moniq/presentation/layout/adaptive_layout.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/home_viewmodel.dart';
import 'package:moniq/presentation/widgets/calendar/moniq_calendar.dart';
import 'package:moniq/presentation/widgets/calendar/view_mode_toggle.dart';
import 'package:moniq/presentation/widgets/common/moniq_app_bar.dart';
import 'package:moniq/presentation/widgets/common/moniq_error_view.dart';
import 'package:moniq/presentation/widgets/common/moniq_loading_view.dart';
import 'package:table_calendar/table_calendar.dart';

import 'calendar_dialogs.dart';
import 'calendar_drawer.dart';
import 'calendar_export.dart';
import 'calendar_providers.dart';
import 'package:moniq/presentation/router/bottom_sheet_visibility_provider.dart';
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

    // 더블탭 감지용 — 마지막 탭한 날짜 + 시각.
    final lastTap = useState<({DateTime day, int at})?>(null);
    final scrollCtrl = useScrollController();

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
          eyebrow: 'OnorOff',
          showBack: false,
          leading: buildAvatarLeading(),
        ),
        body: const MoniqLoadingView(),
      ),
      error: (e, _) => Scaffold(
        appBar: MoniqAppBar(
          title: calendarTitle,
          eyebrow: 'OnorOff',
          showBack: false,
          leading: buildAvatarLeading(),
        ),
        body: MoniqErrorView(
          message: '\uC77C\uC815\uC744 \uBD88\uB7EC\uC62C \uC218 \uC5C6\uC2B5\uB2C8\uB2E4',
          onRetry: () => ref.read(homeViewModelProvider.notifier).refresh(),
        ),
      ),
      data: (state) {
        final monthlyEvents =
            ref.watch(monthlyEventsProvider(state.focusedMonth));
        final monthlyNotes =
            ref.watch(monthlyNotesProvider(state.focusedMonth));
        final dateNotes = ref.watch(dateNotesProvider(state.selectedDate));
        final dateEvents =
            ref.watch(dateEventsProvider(state.selectedDate));

        return Scaffold(
          backgroundColor:
              Theme.of(context).colorScheme.surfaceContainerLow,
          appBar: MoniqAppBar(
                  title: calendarTitle,
                  eyebrow: 'OnorOff',
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
          // 햄버거 드로어가 열리면 하단 dock을 숨긴다 (바텀시트와 동일 처리).
          onEndDrawerChanged: (isOpened) {
            final notifier =
                ref.read(bottomSheetCountProvider.notifier);
            if (isOpened) {
              notifier.increment();
            } else {
              notifier.decrement();
            }
          },
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
              controller: scrollCtrl,
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppSpacing.sm),

                // ── Calendar (근무 범례/프리뷰 제거됨) ──
                MoniqCalendar(
                  legendItems: const [],
                  viewMode: state.viewMode,
                  onViewModeChanged: (_) => ref
                      .read(homeViewModelProvider.notifier)
                      .toggleViewMode(),
                  calendarFormat: state.viewMode == CalendarViewMode.month
                      ? CalendarFormat.month
                      : CalendarFormat.week,
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
                    final nowMs = DateTime.now().millisecondsSinceEpoch;
                    final last = lastTap.value;
                    final sameDay = last != null &&
                        last.day.year == selected.year &&
                        last.day.month == selected.month &&
                        last.day.day == selected.day;
                    final isDouble =
                        sameDay && (nowMs - last!.at) < 350;
                    if (isDouble) {
                      // 두 번째 빠른 탭 → 펼치기/닫기 토글
                      final cur = ref.read(dateExpandedProvider);
                      final next = !cur;
                      ref.read(dateExpandedProvider.notifier).state = next;
                      lastTap.value = null;
                      // 토글 직후 한 프레임 뒤 스크롤 — 펼치면 맨 아래(카드들),
                      // 접으면 맨 위(캘린더)로 부드럽게 이동.
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!scrollCtrl.hasClients) return;
                        final target = next
                            ? scrollCtrl.position.maxScrollExtent
                            : 0.0;
                        scrollCtrl.animateTo(
                          target,
                          duration: const Duration(milliseconds: 320),
                          curve: Curves.easeOutCubic,
                        );
                      });
                    } else {
                      lastTap.value = (day: selected, at: nowMs);
                      ref
                          .read(homeViewModelProvider.notifier)
                          .selectDate(selected);
                    }
                  },
                  onDayLongPressed: (day, focused) {
                    // 날짜를 길게 누르면 해당 날짜를 선택하고 근무 일정 추가 시트를 연다.
                    // (더블탭은 일정 패널 펼치기/접기로 유지)
                    ref.read(homeViewModelProvider.notifier).selectDate(day);
                    showAddMenu(context, ref, day);
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
                    // 즐겨찾기 팀이 있으면 그 팀의 근무 유형을 우선 사용(없으면 개인).
                    // 로딩 중(valueOrNull == null)이면 개인 유형으로 graceful fallback.
                    final teamTypes = ref
                        .watch(favoriteTeamShiftTypesProvider)
                        .valueOrNull;
                    final personalShiftTypes =
                        (teamTypes != null && teamTypes.isNotEmpty)
                            ? teamTypes.map(personalTypeFromTeam).toList()
                            : ref.read(personalShiftTypesProvider);
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
                        // 사용자가 지정한 코드 우선, 없으면 파생 라벨.
                        final typeCode =
                            personalType.code.trim().toUpperCase();
                        return typeCode.isEmpty
                            ? displayShiftLabel(
                                personalType, personalShiftTypes)
                            : typeCode;
                      }
                      final c = code.toUpperCase();
                      if (c == 'OFF') return 'O';
                      if (c.isEmpty) {
                        return name.isEmpty ? '?' : name[0].toUpperCase();
                      }
                      // 근무 코드 전체를 그대로 노출 (예: 'Dw' → 'Dw').
                      return code;
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
                    // 2) 개인 일정: 근무 매칭이면 컬러 박스(중복 제거), 아니면 plain.
                    //    team-import 마커가 있는 이벤트는 근무 박스로 강제 표시.
                    final evts = monthlyEvents[key];
                    if (evts != null && evts.isNotEmpty) {
                      for (final e in evts) {
                        if (result.length >= 3) break;
                        final matchedType = shiftTypeByName[e.title];
                        final isTeamImport = e.description
                                ?.startsWith(kPersonalTeamImportMarker) ==
                            true;
                        if (matchedType != null) {
                          // 사용자가 지정한 코드 우선, 없으면 파생 라벨.
                          final matchedCode =
                              matchedType.code.trim().toUpperCase();
                          final label = matchedCode.isEmpty
                              ? displayShiftLabel(
                                  matchedType, personalShiftTypes)
                              : matchedCode;
                          if (!seenWorkLabels.add(label)) continue;
                          final colorHex = e.color ?? matchedType.color;
                          result.add(CalendarPreview(
                            text: label,
                            color: parseHexColor(colorHex),
                            isWork: true,
                          ));
                        } else if (isTeamImport) {
                          // 팀에서 가져온 근무는 정식 근무 라벨로 처리 (텍스트 박스)
                          final label = labelOf(e.title, '');
                          if (!seenWorkLabels.add(label)) continue;
                          result.add(CalendarPreview(
                            text: label,
                            color: e.color != null
                                ? parseHexColor(e.color!)
                                : AppColors.shiftOff,
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
                    // 3) 월 단위 OFF: 해당 월에 (서버 근무 OR team-import 일정) 이
                    //    한 건이라도 있을 때만 — 이 날에 work 라벨이 없으면 OFF 추가.
                    //    (서버/일정 처리 후 평가해야 team-import 근무가 있는 날에
                    //     OFF가 잘못 추가되지 않는다.)
                    final monthHasAnyTeamSource = !hideTeamShiftsPv &&
                        (state.monthlyShifts.isNotEmpty ||
                            monthlyEvents.values.any((evts) => evts.any((e) =>
                                e.description
                                        ?.startsWith(kPersonalTeamImportMarker) ==
                                    true)));
                    final isInFocusedMonth =
                        key.year == state.focusedMonth.year &&
                            key.month == state.focusedMonth.month;
                    final hasAnyWork = result.any((p) => p.isWork);
                    if (monthHasAnyTeamSource &&
                        isInFocusedMonth &&
                        !hasAnyWork) {
                      seenWorkLabels.add('O');
                      result.insert(
                        0,
                        const CalendarPreview(
                          text: 'O',
                          color: AppColors.shiftOff,
                          isWork: true,
                        ),
                      );
                    }
                    return result;
                  },
                ),

                const SizedBox(height: AppSpacing.lg),
                // 펼친 상태에서 패널 빈 영역을 더블탭하면 접기.
                // (스크롤이 내려가 캘린더 셀까지 닿기 어려운 상황 보완)
                GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onDoubleTap: () {
                    final cur = ref.read(dateExpandedProvider);
                    if (!cur) return; // 이미 접혀있으면 무시
                    ref.read(dateExpandedProvider.notifier).state = false;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!scrollCtrl.hasClients) return;
                      scrollCtrl.animateTo(
                        0,
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeOutCubic,
                      );
                    });
                  },
                  child: DateItemsPanel(
                    date: state.selectedDate,
                    shifts: state.selectedDateShifts ?? [],
                    events: dateEvents,
                    notes: dateNotes,
                    // 캘린더 셀의 OFF 표시와 같은 로직: focused month에 팀 근무 또는
                    // team-import 일정이 1건이라도 있고, 선택된 날도 focused month이며
                    // 그 날 본인 근무가 없으면 OFF로 간주.
                    hasTeamSchedule: () {
                      final isInFocusedMonth = state.selectedDate.year ==
                              state.focusedMonth.year &&
                          state.selectedDate.month ==
                              state.focusedMonth.month;
                      if (!isInFocusedMonth) return false;
                      final monthHasTeamSource =
                          state.monthlyShifts.isNotEmpty ||
                              monthlyEvents.values.any((evts) => evts.any(
                                  (e) =>
                                      e.description?.startsWith(
                                          kPersonalTeamImportMarker) ==
                                      true));
                      return monthHasTeamSource;
                    }(),
                  ),
                ),

                const SizedBox(height: 140),
              ],
            ),
            ),
          ),
        );
      },
    );
  }

}

