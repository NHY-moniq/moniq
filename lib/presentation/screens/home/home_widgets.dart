
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/core/utils/time_utils.dart';
import 'package:moniq/data/datasources/personal_event_local_data_source.dart';
import 'package:moniq/data/providers/handover_providers.dart';
import 'package:moniq/presentation/screens/calendar/calendar_providers.dart';
import 'package:moniq/presentation/screens/handover/handover_modal.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/theme/shift_theme.dart';
import 'package:moniq/presentation/viewmodels/home_viewmodel.dart';
export 'home_on_shift_widgets.dart';
export 'home_announcement_card.dart';

// ════════════════════════════════════════════════
// Home Avatar
// ════════════════════════════════════════════════

class HomeAvatar extends StatelessWidget {
  const HomeAvatar({super.key, required this.url, required this.ringColor});

  final String? url;
  final Color ringColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).colorScheme.primaryContainer,
        border: Border.all(color: ringColor, width: 2),
      ),
      child: url != null && url!.isNotEmpty
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: url!,
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
    );
  }
}

// ════════════════════════════════════════════════
// Next Off Card — 다음 휴무까지 카운트다운
// ════════════════════════════════════════════════

class NextOffCard extends ConsumerWidget {
  const NextOffCard({super.key, required this.shiftTheme});

  final ShiftThemeData shiftTheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    final homeState = ref.watch(homeViewModelProvider);

    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);
    final shifts = homeState.maybeWhen(
      data: (s) => s.monthlyShifts,
      orElse: () => const <DateTime, List<dynamic>>{},
    );

    DateTime? nextOff;
    for (int i = 1; i <= 60; i++) {
      final d = todayKey.add(Duration(days: i));
      final list = shifts[d];
      // schedule에 일이 없거나(=빈 리스트/없음) OFF만 있으면 휴무로 간주
      final hasWork = list != null &&
          list.any(
            (s) => (s.shiftType.code as String).toUpperCase() != 'OFF',
          );
      if (!hasWork) {
        nextOff = d;
        break;
      }
    }

    final daysAway = nextOff?.difference(todayKey).inDays;
    final isLoading = homeState.isLoading;

    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: shiftTheme.primary.withValues(alpha: isDark ? 0.18 : 0.08),
        borderRadius: AppRadius.borderRadiusLg,
        border: Border.all(
          color: shiftTheme.primary.withValues(alpha: isDark ? 0.40 : 0.12),
        ),
        boxShadow: isDark
            ? const []
            : [
                BoxShadow(
                  color: shiftTheme.primary.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: shiftTheme.primary.withValues(alpha: 0.18),
              borderRadius: AppRadius.borderRadiusSm,
            ),
            child: Icon(
              Icons.beach_access_rounded,
              size: 16,
              color: shiftTheme.accentText,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'NEXT OFF',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.3,
                    color: colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 1),
                if (isLoading)
                  Text(
                    '--',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: shiftTheme.accentText,
                    ),
                  )
                else if (nextOff == null)
                  Text(
                    '예정 없음',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  )
                else
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: daysAway == 0 ? 'TODAY' : 'D-$daysAway',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: shiftTheme.accentText,
                          ),
                        ),
                        TextSpan(
                          text:
                              '  ${nextOff.month}.${nextOff.day.toString().padLeft(2, '0')}(${_weekdayKo(nextOff.weekday)})',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _weekdayKo(int w) {
    const names = ['월', '화', '수', '목', '금', '토', '일'];
    return names[(w - 1) % 7];
  }
}

// ════════════════════════════════════════════════
// Handover Card — 오늘의 인계 메모 카운트 + 최신 1줄
// ════════════════════════════════════════════════

class HandoverCard extends ConsumerWidget {
  const HandoverCard({super.key, required this.shiftTheme});

  final ShiftThemeData shiftTheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final listAsync = ref.watch(todayHandoversProvider);
    final items = listAsync.valueOrNull ?? const [];
    final count = items.length;
    final latest = items.isNotEmpty ? items.last.handover.body : null;

    return GestureDetector(
      onTap: () => showHandoverModal(
        context: context,
        shiftTheme: shiftTheme,
      ),
      child: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: shiftTheme.primary.withValues(alpha: isDark ? 0.18 : 0.08),
          borderRadius: AppRadius.borderRadiusLg,
          border: Border.all(
            color:
                shiftTheme.primary.withValues(alpha: isDark ? 0.40 : 0.12),
          ),
          boxShadow: isDark
              ? const []
              : [
                  BoxShadow(
                    color: shiftTheme.primary.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: shiftTheme.primary.withValues(alpha: 0.18),
                borderRadius: AppRadius.borderRadiusSm,
              ),
              child: Icon(
                Icons.sticky_note_2_outlined,
                size: 16,
                color: shiftTheme.accentText,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        '인수인계',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        '$count개',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: shiftTheme.accentText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    latest ?? '아직 메모 없음',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════
// Today Events Card — 오늘 개인 일정 간략 표시
// ════════════════════════════════════════════════

class TodayEventsCard extends ConsumerWidget {
  const TodayEventsCard({super.key, required this.shiftTheme});

  final ShiftThemeData shiftTheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    final now = DateTime.now();
    final todayKey = DateTime(now.year, now.month, now.day);

    // 개인 캘린더(SharedPreferences)는 초기화 전 접근 시 throw 가능 → 가드.
    List<PersonalEvent> events = const [];
    Set<String> shiftTypeNames = const {};
    try {
      events = ref.watch(dateEventsProvider(todayKey));
      shiftTypeNames = ref
          .watch(personalShiftTypesProvider)
          .map((st) => st.name)
          .toSet();
    } catch (_) {
      // 초기화 전 — 빈 상태로 표시
    }

    // 개인 시프트(=근무 카드에서 이미 표현됨)는 일정에서 제외
    final dayEvents =
        events.where((e) => !shiftTypeNames.contains(e.title)).toList();
    final count = dayEvents.length;
    final preview = dayEvents.firstOrNull;

    return GestureDetector(
      onTap: () => context.go('/calendar'),
      child: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: shiftTheme.primary.withValues(alpha: isDark ? 0.18 : 0.08),
          borderRadius: AppRadius.borderRadiusLg,
          border: Border.all(
            color:
                shiftTheme.primary.withValues(alpha: isDark ? 0.40 : 0.12),
          ),
          boxShadow: isDark
              ? const []
              : [
                  BoxShadow(
                    color: shiftTheme.primary.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: shiftTheme.primary.withValues(alpha: 0.18),
                borderRadius: AppRadius.borderRadiusSm,
              ),
              child: Icon(
                Icons.event_note_outlined,
                size: 16,
                color: shiftTheme.accentText,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'TODAY',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.3,
                      color: cs.outline,
                    ),
                  ),
                  const SizedBox(height: 1),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: count > 0 ? '$count개' : '일정 없음',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: shiftTheme.accentText,
                          ),
                        ),
                        if (preview != null)
                          TextSpan(
                            text: '  ${_formatPreview(preview)}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatPreview(PersonalEvent? e) {
    if (e == null) return '일정 없음';
    final t = e.startTime;
    if (t == null || t.isEmpty) return e.title;
    return '$t ${e.title}';
  }
}

// ════════════════════════════════════════════════
// Weekly Hours Card (사용 안 함 — 통계 화면으로 이동 예정)
// ════════════════════════════════════════════════

class WeeklyHoursCard extends ConsumerWidget {
  const WeeklyHoursCard({super.key, required this.shiftTheme});

  final ShiftThemeData shiftTheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    final homeState = ref.watch(homeViewModelProvider);

    final hours = homeState.maybeWhen(
      data: (state) => monthlyWorkedHours(state.monthlyShifts, state.focusedMonth),
      orElse: () => 0.0,
    );
    final valueText = homeState.isLoading ? '--' : hours.toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        color: shiftTheme.primary.withValues(alpha: isDark ? 0.18 : 0.08),
        borderRadius: AppRadius.borderRadiusLg,
        border: Border.all(
          color: shiftTheme.primary.withValues(alpha: isDark ? 0.40 : 0.12),
        ),
        boxShadow: isDark
            ? const []
            : [
                BoxShadow(
                  color: shiftTheme.primary.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MONTHLY HOURS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: colorScheme.outline,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$valueText ',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: shiftTheme.accentText,
                    ),
                  ),
                  TextSpan(
                    text: 'hrs',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

