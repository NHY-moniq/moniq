import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/core/utils/time_utils.dart';
import 'package:moniq/data/models/user_model.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/theme/shift_theme.dart';
import 'package:moniq/presentation/widgets/common/moniq_bottom_sheet.dart';
import 'package:moniq/presentation/viewmodels/home_viewmodel.dart';

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
      onTap: () => _showOnShiftModal(context, shiftTheme),
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

// 공통 헬퍼(showMoniqBottomSheet)로 띄워 바텀시트 동안 하단 dock이 자동으로 숨겨진다.
Future<void> _showOnShiftModal(
  BuildContext context,
  ShiftThemeData shiftTheme,
) {
  return showMoniqBottomSheet<void>(
    context: context,
    child: SingleChildScrollView(
      child: _OnShiftContent(shiftTheme: shiftTheme),
    ),
  );
}

/// ON SHIFT NOW 본문 — 헤더(+랜덤픽 버튼), 당첨 배너, 근무자 컬럼.
/// 랜덤픽은 별도 섹션 대신 헤더 옆 컴팩트 버튼으로 배치한다.
class _OnShiftContent extends ConsumerStatefulWidget {
  const _OnShiftContent({required this.shiftTheme});

  final ShiftThemeData shiftTheme;

  @override
  ConsumerState<_OnShiftContent> createState() => _OnShiftContentState();
}

class _OnShiftContentState extends ConsumerState<_OnShiftContent> {
  UserModel? _winner;
  final _random = Random();

  void _pick(List<UserModel> pool) {
    if (pool.isEmpty) return;
    setState(() {
      // 같은 사람이 연속 안 뽑히도록 가능하면 다른 사람으로
      if (pool.length == 1) {
        _winner = pool.first;
        return;
      }
      UserModel next;
      do {
        next = pool[_random.nextInt(pool.length)];
      } while (next.id == _winner?.id);
      _winner = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = widget.shiftTheme.accentText;
    final dataAsync = ref.watch(onShiftTeamDataProvider);
    final data = dataAsync.valueOrNull;
    // 랜덤픽은 지금 시간 근무자(현재 시프트)만 대상
    final pool = data?.currentCoworkers ?? const <UserModel>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'ON SHIFT NOW',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: cs.onSurface,
                ),
              ),
            ),
            if (pool.isNotEmpty)
              _LotteryButton(
                accent: accent,
                foreground: cs.surface,
                hasWinner: _winner != null,
                onPressed: () => _pick(pool),
              ),
          ],
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: _winner == null
              ? const SizedBox.shrink()
              : Padding(
                  key: ValueKey(_winner!.id),
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: _LotteryResultBanner(
                    winner: _winner!,
                    accent: accent,
                    cs: cs,
                  ),
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
          data: (d) => _ModalBody(data: d, shiftTheme: widget.shiftTheme),
        ),
      ],
    );
  }
}

/// 헤더 옆에 놓이는 컴팩트 랜덤픽 버튼.
class _LotteryButton extends StatelessWidget {
  const _LotteryButton({
    required this.accent,
    required this.foreground,
    required this.hasWinner,
    required this.onPressed,
  });

  final Color accent;
  final Color foreground;
  final bool hasWinner;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: foreground,
        minimumSize: const Size(0, 32),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 0,
        ),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.borderRadiusFull,
        ),
      ),
      onPressed: onPressed,
      icon: const Icon(Icons.casino_outlined, size: 15),
      label: Text(hasWinner ? '다시' : '랜덤픽'),
    );
  }
}

/// 랜덤픽 당첨자를 한 줄로 보여주는 배너.
class _LotteryResultBanner extends StatelessWidget {
  const _LotteryResultBanner({
    required this.winner,
    required this.accent,
    required this.cs,
  });

  final UserModel winner;
  final Color accent;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final name = winner.displayName?.isNotEmpty == true
        ? winner.displayName!
        : '이름 없음';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: AppRadius.borderRadiusMd,
        border: Border.all(color: accent.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.surfaceContainerHigh,
            ),
            clipBehavior: Clip.antiAlias,
            alignment: Alignment.center,
            child: (winner.avatarUrl != null && winner.avatarUrl!.isNotEmpty)
                ? CachedNetworkImage(
                    imageUrl: winner.avatarUrl!,
                    fit: BoxFit.cover,
                    width: 28,
                    height: 28,
                  )
                : Text(
                    name.characters.first.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                    ),
                  ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '🎉 당첨',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: cs.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
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
    final currentLabel =
        data.currentType == null ? '현재 근무' : data.currentType!.name;
    final nextLabel =
        data.nextType == null ? '다음 근무 없음' : data.nextType!.name;

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

