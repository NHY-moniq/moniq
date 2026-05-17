import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/core/utils/time_utils.dart';
import 'package:moniq/data/models/shift_with_type.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/theme/shift_theme.dart';
import 'package:moniq/presentation/screens/calendar/calendar_providers.dart';
import 'package:moniq/presentation/screens/home/active_shift_card.dart';
import 'package:moniq/presentation/screens/home/home_widgets.dart';
import 'package:moniq/presentation/viewmodels/team_viewmodel.dart';

// ════════════════════════════════════════════════
// Home Body
// ════════════════════════════════════════════════

class HomeBody extends ConsumerWidget {
  const HomeBody({
    super.key,
    required this.monthlyShifts,
    required this.shiftTheme,
  });

  final Map<DateTime, List<ShiftWithType>> monthlyShifts;
  final ShiftThemeData shiftTheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);

    // Server shift
    final todayShifts = monthlyShifts[todayKey];
    final firstShift =
        todayShifts != null && todayShifts.isNotEmpty ? todayShifts.first : null;

    // Personal calendar fallback (safe if SharedPreferences not ready)
    List<dynamic> personalEvents = [];
    List<dynamic> personalShiftTypes = [];
    Set<String> shiftTypeNames = {};
    try {
      personalEvents = ref.watch(dateEventsProvider(todayKey));
      personalShiftTypes = ref.watch(personalShiftTypesProvider);
      shiftTypeNames = personalShiftTypes.map((st) => st.name as String).toSet();
    } catch (_) {
      // SharedPreferences not yet initialized
    }

    // Resolve shift info
    final hasServerShift = firstShift != null;
    final personalShiftEvent = !hasServerShift
        ? personalEvents
            .where((e) => shiftTypeNames.contains(e.title))
            .firstOrNull
        : null;
    final matchedShiftType = personalShiftEvent != null
        ? personalShiftTypes
            .where((st) => st.name == personalShiftEvent.title)
            .firstOrNull
        : null;

    final hasShift = hasServerShift || matchedShiftType != null;
    final shiftName = hasServerShift
        ? firstShift.shiftType.name
        : matchedShiftType?.name ?? 'Off';
    final rawStart =
        hasServerShift ? firstShift.shiftType.startTime : matchedShiftType?.startTime;
    final rawEnd =
        hasServerShift ? firstShift.shiftType.endTime : matchedShiftType?.endTime;
    final startTime = rawStart == null ? null : formatTimeString(rawStart);
    final endTime = rawEnd == null ? null : formatTimeString(rawEnd);

    // 서버 shift는 teamId만 가지고 있어 팀 목록에서 이름을 조회.
    // 개인 캘린더 기반(=서버 shift 없음) 항목은 팀이 없는 사적 일정이라 null.
    String? teamName;
    if (hasServerShift) {
      final teams = ref.watch(teamViewModelProvider).valueOrNull ?? const [];
      teamName = teams
          .where((t) => t.id == firstShift.shift.teamId)
          .map((t) => t.name)
          .firstOrNull;
    }

    return Padding(
      padding: AppSpacing.screenHorizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.md),

          // Active Shift Card
          ActiveShiftCard(
            shiftTheme: shiftTheme,
            shiftName: shiftName,
            startTime: startTime,
            endTime: endTime,
            teamName: teamName,
            hasShift: hasShift,
          ),
          const SizedBox(height: AppSpacing.lg),

          // 좌(Next Off + Handover) / 우(On-Shift NOW) — 좌측 합 == 우측 높이
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Expanded(child: NextOffCard(shiftTheme: shiftTheme)),
                      const SizedBox(height: AppSpacing.md),
                      Expanded(child: TodayEventsCard(shiftTheme: shiftTheme)),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: OnShiftTeamCard(shiftTheme: shiftTheme)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Title
          Text(
            '팀 소식',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: shiftTheme.accentText,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Announcement
          AnnouncementCard(shiftTheme: shiftTheme),
        ],
      ),
    );
  }
}
