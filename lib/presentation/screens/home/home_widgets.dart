import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moniq/core/utils/time_utils.dart';
import 'package:moniq/data/models/user_model.dart';
import 'package:moniq/data/providers/announcement_providers.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/theme/shift_theme.dart';
import 'package:moniq/presentation/viewmodels/home_viewmodel.dart';

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
// Weekly Hours Card
// ════════════════════════════════════════════════

class WeeklyHoursCard extends ConsumerWidget {
  const WeeklyHoursCard({super.key, required this.shiftTheme});

  final ShiftThemeData shiftTheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final homeState = ref.watch(homeViewModelProvider);

    final hours = homeState.maybeWhen(
      data: (state) => monthlyWorkedHours(state.monthlyShifts, state.focusedMonth),
      orElse: () => 0.0,
    );
    final valueText = homeState.isLoading ? '--' : hours.toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        color: shiftTheme.primary.withValues(alpha: 0.08),
        borderRadius: AppRadius.borderRadiusLg,
        border: Border.all(
          color: shiftTheme.primary.withValues(alpha: 0.12),
        ),
        boxShadow: [
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
    final coworkersAsync = ref.watch(todayCoworkersProvider);
    final coworkers = coworkersAsync.valueOrNull ?? const [];
    final visible = coworkers.take(3).toList();
    final overflow = coworkers.length - visible.length;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        color: shiftTheme.primary.withValues(alpha: 0.08),
        borderRadius: AppRadius.borderRadiusLg,
        border: Border.all(
          color: shiftTheme.primary.withValues(alpha: 0.15),
        ),
        boxShadow: [
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
            'ON-SHIFT TEAM',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: colorScheme.outline,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
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
          '혼자 근무해요',
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
// Announcement Card
// ════════════════════════════════════════════════

class AnnouncementCard extends ConsumerWidget {
  const AnnouncementCard({super.key, required this.shiftTheme});

  final ShiftThemeData shiftTheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final announcementsAsync = ref.watch(myAnnouncementsProvider);

    // 로딩 중이거나 에러면 기본 카드 표시
    if (announcementsAsync.isLoading || announcementsAsync.hasError) {
      return _buildDefaultCard(context);
    }

    final items = announcementsAsync.valueOrNull ?? [];

    // 데이터 로드 완료 후 공지가 없으면 기본 카드
    if (items.isEmpty) return _buildDefaultCard(context);

    final latest = items.first;

    final subtitle = latest.announcement.title;
    final teamLabel = '[${latest.teamName}]';

    final dateText = latest.announcement.createdAt != null
        ? DateFormat('MM.dd').format(latest.announcement.createdAt!)
        : null;

    return GestureDetector(
      onTap: () => context.push('/announcements'),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: shiftTheme.primary.withValues(alpha: 0.06),
          borderRadius: AppRadius.borderRadiusLg,
          border: Border.all(
            color: shiftTheme.primary.withValues(alpha: 0.12),
          ),
          boxShadow: [
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
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: shiftTheme.primary.withValues(alpha: 0.15),
                borderRadius: AppRadius.borderRadiusMd,
              ),
              child: Icon(
                Icons.campaign_outlined,
                size: 20,
                color: shiftTheme.accentText,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '팀 공지사항',
                        style:
                            Theme.of(context).textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                      ...[
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          teamLabel,
                          style: TextStyle(
                            fontSize: 11,
                            color: shiftTheme.accentText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (dateText != null) ...[
              Text(
                dateText,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant,
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
      ),
    );
  }

  Widget _buildDefaultCard(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/announcements'),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: shiftTheme.primary.withValues(alpha: 0.06),
          borderRadius: AppRadius.borderRadiusLg,
          border: Border.all(
            color: shiftTheme.primary.withValues(alpha: 0.12),
          ),
          boxShadow: [
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
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: shiftTheme.primary.withValues(alpha: 0.15),
                borderRadius: AppRadius.borderRadiusMd,
              ),
              child: Icon(
                Icons.campaign_outlined,
                size: 20,
                color: shiftTheme.accentText,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '팀 공지사항',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '아직 공지사항이 없습니다',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Theme.of(context).colorScheme.outline,
            ),
          ],
        ),
      ),
    );
  }
}
