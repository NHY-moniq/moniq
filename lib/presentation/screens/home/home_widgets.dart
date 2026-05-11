import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moniq/core/utils/time_utils.dart';
import 'package:moniq/data/models/shift_type_model.dart';
import 'package:moniq/data/models/user_model.dart';
import 'package:moniq/data/providers/announcement_providers.dart';
import 'package:moniq/data/providers/handover_providers.dart';
import 'package:moniq/presentation/screens/handover/handover_modal.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/theme/shift_theme.dart';
import 'package:moniq/presentation/viewmodels/home_viewmodel.dart';
import 'package:moniq/presentation/viewmodels/team_viewmodel.dart';

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

// ════════════════════════════════════════════════
// On-Shift Team Card (overlapping avatars)
// ════════════════════════════════════════════════

class OnShiftTeamCard extends ConsumerWidget {
  const OnShiftTeamCard({super.key, required this.shiftTheme});

  final ShiftThemeData shiftTheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    // 지금 시간 기준 근무자 (본인 shift 무관)
    final dataAsync = ref.watch(onShiftTeamDataProvider);
    final data = dataAsync.valueOrNull;
    final coworkersAsync = dataAsync.whenData((d) => d.currentCoworkers);
    final coworkers = data?.currentCoworkers ?? const [];
    final visible = coworkers.take(3).toList();
    final overflow = coworkers.length - visible.length;
    final currentType = data?.currentType;

    String? shiftChip;
    if (currentType != null) {
      final s = formatTimeString(currentType.startTime);
      final e = formatTimeString(currentType.endTime);
      if (s.isNotEmpty && e.isNotEmpty) {
        shiftChip = '${currentType.name} · $s–$e';
      } else {
        shiftChip = currentType.name;
      }
    }

    return GestureDetector(
      onTap: () => _showOnShiftModal(context, ref, shiftTheme),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        decoration: BoxDecoration(
          color: shiftTheme.primary.withValues(alpha: isDark ? 0.18 : 0.08),
          borderRadius: AppRadius.borderRadiusLg,
          border: Border.all(
            color:
                shiftTheme.primary.withValues(alpha: isDark ? 0.40 : 0.15),
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
              'ON-SHIFT NOW',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                color: colorScheme.outline,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (shiftChip != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: shiftTheme.primary.withValues(alpha: 0.15),
                  borderRadius: AppRadius.borderRadiusFull,
                ),
                child: Text(
                  shiftChip,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: shiftTheme.accentText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              )
            else
              Text(
                '쉬는 시간',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 40,
              child: _buildContent(
                context,
                colorScheme,
                coworkersAsync,
                visible,
                overflow,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ColorScheme colorScheme,
    AsyncValue<List<UserModel>> coworkersAsync,
    List<UserModel> visible,
    int overflow,
  ) {
    if (coworkersAsync.isLoading && visible.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: colorScheme.outline,
          ),
        ),
      );
    }

    if (visible.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text(
          '지금 근무 중인 사람 없음',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (int i = 0; i < visible.length; i++)
          Positioned(
            left: i * 26.0,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.surfaceContainerHigh,
                border: Border.all(
                  color: shiftTheme.background,
                  width: 3,
                ),
              ),
              child: ClipOval(
                child: (visible[i].avatarUrl != null &&
                        visible[i].avatarUrl!.isNotEmpty)
                    ? CachedNetworkImage(
                        imageUrl: visible[i].avatarUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Icon(
                          Icons.person,
                          size: 18,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      )
                    : Icon(
                        Icons.person,
                        size: 18,
                        color: colorScheme.onSurfaceVariant,
                      ),
              ),
            ),
          ),
        if (overflow > 0)
          Positioned(
            left: visible.length * 26.0,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.surface,
                border: Border.all(
                  color: shiftTheme.background,
                  width: 3,
                ),
              ),
              child: Center(
                child: Text(
                  '+$overflow',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.outline,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ════════════════════════════════════════════════
// On-Shift Team Modal (current / next coworkers)
// ════════════════════════════════════════════════

Future<void> _showOnShiftModal(
  BuildContext context,
  WidgetRef ref,
  ShiftThemeData shiftTheme,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _OnShiftTeamModal(shiftTheme: shiftTheme),
  );
}

class _OnShiftTeamModal extends ConsumerWidget {
  const _OnShiftTeamModal({required this.shiftTheme});

  final ShiftThemeData shiftTheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final dataAsync = ref.watch(onShiftTeamDataProvider);

    final maxHeight = MediaQuery.of(context).size.height * 0.85;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xxl,
            AppSpacing.lg,
            AppSpacing.xxl,
            AppSpacing.xxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'ON SHIFT NOW',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              dataAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.xxl),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                error: (_, __) => Padding(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  child: Text(
                    '근무자 정보를 불러오지 못했어요',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ),
                data: (data) => _ModalBody(
                  data: data,
                  shiftTheme: shiftTheme,
                ),
              ),
              // 랜덤 뽑기 섹션 — 현재+다음 시프트 사람들 중 1명
              dataAsync.maybeWhen(
                data: (d) {
                  final pool = [
                    ...d.currentCoworkers,
                    ...d.nextCoworkers,
                  ];
                  if (pool.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.lg),
                    child: _LotterySection(
                      users: pool,
                      shiftTheme: shiftTheme,
                    ),
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LotterySection extends StatefulWidget {
  const _LotterySection({required this.users, required this.shiftTheme});

  final List<UserModel> users;
  final ShiftThemeData shiftTheme;

  @override
  State<_LotterySection> createState() => _LotterySectionState();
}

class _LotterySectionState extends State<_LotterySection> {
  UserModel? _winner;
  final _random = Random();

  void _pick() {
    if (widget.users.isEmpty) return;
    setState(() {
      // 같은 사람이 연속 안 뽑히도록 가능하면 다른 사람으로
      if (widget.users.length == 1) {
        _winner = widget.users.first;
        return;
      }
      UserModel next;
      do {
        next = widget.users[_random.nextInt(widget.users.length)];
      } while (next.id == _winner?.id);
      _winner = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = widget.shiftTheme.accentText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(color: cs.outlineVariant.withValues(alpha: 0.4), height: 1),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Icon(Icons.casino_outlined, size: 16, color: accent),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'RANDOM PICK',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: accent,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: _winner == null
              ? Container(
                  key: const ValueKey('placeholder'),
                  padding:
                      const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '뽑기 버튼을 누르면 1명을 무작위로 골라요',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                )
              : Container(
                  key: ValueKey(_winner!.id),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.10),
                    borderRadius: AppRadius.borderRadiusMd,
                    border:
                        Border.all(color: accent.withValues(alpha: 0.30)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: cs.surfaceContainerHigh,
                        ),
                        clipBehavior: Clip.antiAlias,
                        alignment: Alignment.center,
                        child: (_winner!.avatarUrl != null &&
                                _winner!.avatarUrl!.isNotEmpty)
                            ? CachedNetworkImage(
                                imageUrl: _winner!.avatarUrl!,
                                fit: BoxFit.cover,
                                width: 36,
                                height: 36,
                              )
                            : Text(
                                (_winner!.displayName?.isNotEmpty == true
                                        ? _winner!.displayName!
                                        : '?')
                                    .characters
                                    .first
                                    .toUpperCase(),
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: cs.onSurface,
                                ),
                              ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '🎉 당첨!',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: accent,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _winner!.displayName ?? '이름 없음',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: cs.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 44,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: cs.surface,
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.borderRadiusFull,
              ),
            ),
            onPressed: _pick,
            icon: const Icon(Icons.shuffle_rounded, size: 18),
            label: Text(_winner == null ? '뽑기' : '다시 뽑기'),
          ),
        ),
      ],
    );
  }
}

class _ModalBody extends StatelessWidget {
  const _ModalBody({required this.data, required this.shiftTheme});

  final OnShiftTeamData data;
  final ShiftThemeData shiftTheme;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final currentLabel = data.currentType == null
        ? '현재 근무'
        : '${data.currentType!.name} ${_timeRange(data.currentType!)}';
    final nextLabel = data.nextType == null
        ? '다음 근무 없음'
        : '${data.nextType!.name} ${_timeRange(data.nextType!)}';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _CoworkerColumn(
            eyebrow: '지금 시간',
            title: currentLabel,
            users: data.currentCoworkers,
            emptyText: '혼자 근무해요',
            accentColor: shiftTheme.accentText,
            cs: cs,
          ),
        ),
        Container(
          width: 1,
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          color: cs.outlineVariant.withValues(alpha: 0.4),
        ),
        Expanded(
          child: _CoworkerColumn(
            eyebrow: '다음 시간',
            title: nextLabel,
            users: data.nextCoworkers,
            emptyText: data.nextType == null ? '예정된 다음 근무 없음' : '아직 비어있어요',
            accentColor: cs.onSurfaceVariant,
            cs: cs,
          ),
        ),
      ],
    );
  }

  String _timeRange(ShiftTypeModel t) {
    final s = (t.startTime ?? '').padRight(5).substring(0, 5);
    final e = (t.endTime ?? '').padRight(5).substring(0, 5);
    if (s.trim().isEmpty || e.trim().isEmpty) return '';
    return '$s–$e';
  }
}

class _CoworkerColumn extends StatelessWidget {
  const _CoworkerColumn({
    required this.eyebrow,
    required this.title,
    required this.users,
    required this.emptyText,
    required this.accentColor,
    required this.cs,
  });

  final String eyebrow;
  final String title;
  final List<UserModel> users;
  final String emptyText;
  final Color accentColor;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          eyebrow,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
            color: cs.outline,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: accentColor,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.md),
        if (users.isEmpty)
          Text(
            emptyText,
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurfaceVariant,
            ),
          )
        else
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: users.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, i) => _CoworkerRow(user: users[i], cs: cs),
            ),
          ),
      ],
    );
  }
}

class _CoworkerRow extends StatelessWidget {
  const _CoworkerRow({required this.user, required this.cs});

  final UserModel user;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final url = user.avatarUrl;
    final initial = (user.displayName?.isNotEmpty == true
            ? user.displayName!
            : '?')
        .characters
        .first
        .toUpperCase();

    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: cs.surfaceContainerHigh,
          ),
          clipBehavior: Clip.antiAlias,
          alignment: Alignment.center,
          child: (url != null && url.isNotEmpty)
              ? CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  width: 32,
                  height: 32,
                  errorWidget: (_, __, ___) => Text(
                    initial,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                    ),
                  ),
                )
              : Text(
                  initial,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                  ),
                ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            user.displayName ?? '이름 없음',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════
// Announcement Card
// ════════════════════════════════════════════════

class AnnouncementCard extends ConsumerWidget {
  const AnnouncementCard({super.key, required this.shiftTheme});

  final ShiftThemeData shiftTheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final announcementsAsync = ref.watch(filteredAnnouncementsProvider);
    final teamsAsync = ref.watch(teamViewModelProvider);
    final selectedTeamId =
        ref.watch(selectedAnnouncementTeamFilterProvider);

    final teams = teamsAsync.valueOrNull ?? const [];
    final selectedTeam = selectedTeamId == null
        ? null
        : teams.where((t) => t.id == selectedTeamId).firstOrNull;
    final filterLabel =
        selectedTeam?.name ?? (teams.length > 1 ? '전체' : null);

    // 로딩 중이거나 에러면 기본 카드 표시
    if (announcementsAsync.isLoading || announcementsAsync.hasError) {
      return _buildDefaultCard(context, ref, teams, filterLabel);
    }

    final items = announcementsAsync.valueOrNull ?? [];

    // 데이터 로드 완료 후 공지가 없으면 기본 카드
    if (items.isEmpty) {
      return _buildDefaultCard(context, ref, teams, filterLabel);
    }

    final latest = items.first;

    final subtitle = latest.announcement.title;
    final isDark = Theme.of(context).colorScheme.brightness == Brightness.dark;

    final dateText = latest.announcement.createdAt != null
        ? DateFormat('MM.dd').format(latest.announcement.createdAt!)
        : null;

    return GestureDetector(
      onTap: () => context.push('/announcements'),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: shiftTheme.primary.withValues(alpha: isDark ? 0.18 : 0.06),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: shiftTheme.primary.withValues(alpha: 0.15),
                    borderRadius: AppRadius.borderRadiusSm,
                  ),
                  child: Icon(
                    Icons.campaign_outlined,
                    size: 16,
                    color: shiftTheme.accentText,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '팀 공지사항',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const Spacer(),
                if (filterLabel != null)
                  _TeamFilterChip(
                    label: filterLabel,
                    accent: shiftTheme.accentText,
                    teams: teams,
                    selectedTeamId: selectedTeamId,
                    onSelect: (id) => ref
                        .read(selectedAnnouncementTeamFilterProvider.notifier)
                        .state = id,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '[${latest.teamName}]',
                        style: TextStyle(
                          fontSize: 11,
                          color: shiftTheme.accentText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (dateText != null) ...[
                  Text(
                    dateText,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                ],
                Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultCard(
    BuildContext context,
    WidgetRef ref,
    List<dynamic> teams,
    String? filterLabel,
  ) {
    final isDark = Theme.of(context).colorScheme.brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => context.push('/announcements'),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: shiftTheme.primary.withValues(alpha: isDark ? 0.18 : 0.06),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: shiftTheme.primary.withValues(alpha: 0.15),
                    borderRadius: AppRadius.borderRadiusSm,
                  ),
                  child: Icon(
                    Icons.campaign_outlined,
                    size: 16,
                    color: shiftTheme.accentText,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '팀 공지사항',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const Spacer(),
                if (filterLabel != null)
                  _TeamFilterChip(
                    label: filterLabel,
                    accent: shiftTheme.accentText,
                    teams: teams.cast(),
                    selectedTeamId:
                        ref.watch(selectedAnnouncementTeamFilterProvider),
                    onSelect: (id) => ref
                        .read(selectedAnnouncementTeamFilterProvider.notifier)
                        .state = id,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '아직 공지사항이 없습니다',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamFilterChip extends StatelessWidget {
  const _TeamFilterChip({
    required this.label,
    required this.accent,
    required this.teams,
    required this.selectedTeamId,
    required this.onSelect,
  });

  final String label;
  final Color accent;
  final List<dynamic> teams;
  final String? selectedTeamId;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String?>(
      tooltip: '팀 필터',
      position: PopupMenuPosition.under,
      onSelected: onSelect,
      itemBuilder: (ctx) => [
        CheckedPopupMenuItem<String?>(
          value: null,
          checked: selectedTeamId == null,
          child: const Text('전체'),
        ),
        for (final t in teams)
          CheckedPopupMenuItem<String?>(
            value: t.id as String,
            checked: selectedTeamId == t.id,
            child: Text(t.name as String),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.10),
          borderRadius: AppRadius.borderRadiusFull,
          border: Border.all(
            color: accent.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.expand_more_rounded,
              size: 14,
              color: accent,
            ),
          ],
        ),
      ),
    );
  }
}
