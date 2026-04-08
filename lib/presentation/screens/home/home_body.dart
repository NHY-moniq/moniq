import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/models/shift_with_type.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/theme/shift_theme.dart';
import 'package:moniq/presentation/screens/calendar/calendar_providers.dart';
import 'package:moniq/presentation/screens/home/active_shift_card.dart';
import 'package:moniq/presentation/screens/home/home_widgets.dart';

// ════════════════════════════════════════════════
// Home Body
// ════════════════════════════════════════════════

class HomeBody extends ConsumerWidget {
  const HomeBody({
    super.key,
    required this.displayName,
    required this.monthlyShifts,
    required this.shiftTheme,
  });

  final String? displayName;
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
    final startTime =
        hasServerShift ? firstShift.shiftType.startTime : matchedShiftType?.startTime;
    final endTime =
        hasServerShift ? firstShift.shiftType.endTime : matchedShiftType?.endTime;
    final teamName = hasServerShift ? firstShift.teamName : null;

    // Subtitle
    final subtitle = hasShift
        ? teamName != null
            ? '$teamName에서 근무 중이에요'
            : '오늘도 파이팅!'
        : '오늘은 쉬는 날이에요';

    return Padding(
      padding: AppSpacing.screenHorizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.sm),

          // Welcome
          Text(
            'Hello, ${displayName ?? 'there'}!',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),

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

          // Stats row: Weekly Hours + On-Shift Team
          Row(
            children: [
              Expanded(child: WeeklyHoursCard(shiftTheme: shiftTheme)),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: OnShiftTeamCard(shiftTheme: shiftTheme)),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Title
          Text(
            'Your Schedule',
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
