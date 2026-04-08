import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/models/shift_with_type.dart';
import 'package:moniq/data/providers/auth_providers.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/theme/shift_theme.dart';
import 'package:moniq/presentation/screens/calendar/calendar_providers.dart';
import 'package:moniq/presentation/viewmodels/home_viewmodel.dart';
import 'package:moniq/presentation/widgets/common/character_blob.dart';
import 'package:moniq/presentation/widgets/common/moniq_error_view.dart';
import 'package:moniq/presentation/widgets/common/moniq_loading_view.dart';
import 'package:moniq/presentation/screens/home/home_widgets.dart';

// ── Screen ──

class HomeScreen extends HookConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendarAsync = ref.watch(homeViewModelProvider);
    final shiftTheme = ref.watch(todayShiftThemeProvider);

    final currentUser = ref.watch(currentUserProvider);
    final userMeta = currentUser?.userMetadata;
    final displayName = userMeta?['display_name'] as String?;
    final avatarUrl = userMeta?['avatar_url'] as String?;

    Widget buildAppBar() {
      return AppBar(
        backgroundColor: shiftTheme.background,
        surfaceTintColor: Colors.transparent,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: (avatarUrl != null && avatarUrl.isNotEmpty)
                  ? () => _showAvatarDialog(context, avatarUrl)
                  : null,
              child: _Avatar(
                url: avatarUrl,
                ringColor: shiftTheme.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              'OnorOff',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: shiftTheme.primary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.notifications_outlined,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            onPressed: () {},
          ),
          const SizedBox(width: 4),
        ],
      );
    }

    return calendarAsync.when(
      loading: () => Scaffold(
        backgroundColor: shiftTheme.background,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: buildAppBar(),
        ),
        body: const MoniqLoadingView(),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: shiftTheme.background,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: buildAppBar(),
        ),
        body: MoniqErrorView(
          message: '일정을 불러올 수 없습니다',
          onRetry: () => ref.read(homeViewModelProvider.notifier).refresh(),
        ),
      ),
      data: (state) {
        return Scaffold(
          backgroundColor: shiftTheme.background,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(kToolbarHeight),
            child: buildAppBar(),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HomeBody(
                  displayName: displayName,
                  monthlyShifts: state.monthlyShifts,
                  shiftTheme: shiftTheme,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAvatarDialog(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: GestureDetector(
          onTap: () => Navigator.pop(ctx),
          child: CircleAvatar(
            radius: 100,
            backgroundColor:
                Theme.of(context).colorScheme.primaryContainer,
            backgroundImage: CachedNetworkImageProvider(url),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════
// Avatar
// ════════════════════════════════════════════════

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.ringColor});

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
// Home Body
// ════════════════════════════════════════════════

class _HomeBody extends ConsumerWidget {
  const _HomeBody({
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

    // Subtitle — 팀 이름 포함
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
          _ActiveShiftCard(
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

// ════════════════════════════════════════════════
// Active Shift Card (full-width with character)
// ════════════════════════════════════════════════

class _ActiveShiftCard extends StatelessWidget {
  const _ActiveShiftCard({
    required this.shiftTheme,
    required this.shiftName,
    required this.startTime,
    required this.endTime,
    required this.teamName,
    required this.hasShift,
  });

  final ShiftThemeData shiftTheme;
  final String shiftName;
  final String? startTime;
  final String? endTime;
  final String? teamName;
  final bool hasShift;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.hardEdge,
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 280),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            shiftTheme.cardColor,
            shiftTheme.cardColor.withValues(alpha: 0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Stack(
        children: [
          // Decorative blur circle (top-right)
          Positioned(
            top: -48,
            right: -48,
            child: Container(
              width: 192,
              height: 192,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: shiftTheme.primary.withValues(alpha: 0.15),
              ),
            ),
          ),

          // Character PNG or CharacterBlob fallback
          Positioned(
            right: -16,
            bottom: -16,
            child: Transform.rotate(
              angle: 0.21,
              child: Opacity(
                opacity: 0.25,
                child: shiftTheme.characterAsset.isNotEmpty
                    ? Image.asset(
                        shiftTheme.characterAsset,
                        width: 200,
                        height: 200,
                        fit: BoxFit.contain,
                      )
                    : CharacterBlob(
                        type: CharacterType.grey,
                        size: 160,
                        showEyes: true,
                        sleeping: true,
                      ),
              ),
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Glass badge
                _GlassBadge(
                  label: hasShift ? 'Active Shift' : 'No Shift',
                  showPulse: hasShift,
                  textColor: shiftTheme.onPrimary,
                ),
                const SizedBox(height: 20),

                // Shift name
                Text(
                  shiftTheme.displayName,
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: shiftTheme.onPrimary,
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),

                // Time
                if (hasShift && startTime != null && endTime != null)
                  Text(
                    '$startTime — $endTime',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: shiftTheme.onPrimary.withValues(alpha: 0.8),
                    ),
                  ),
                const SizedBox(height: 16),

                // Location / Team chips
                if (hasShift)
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      _GlassChip(
                        icon: Icons.group,
                        label: teamName ?? '개인 일정',
                        textColor: shiftTheme.onPrimary,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════
// Glass Badge
// ════════════════════════════════════════════════

class _GlassBadge extends StatelessWidget {
  const _GlassBadge({
    required this.label,
    required this.showPulse,
    required this.textColor,
  });

  final String label;
  final bool showPulse;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadius.borderRadiusFull,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.3),
            borderRadius: AppRadius.borderRadiusFull,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: textColor,
                  shape: BoxShape.circle,
                  boxShadow: showPulse
                      ? [
                          BoxShadow(
                            color: textColor.withValues(alpha: 0.6),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════
// Glass Chip
// ════════════════════════════════════════════════

class _GlassChip extends StatelessWidget {
  const _GlassChip({
    required this.icon,
    required this.label,
    required this.textColor,
  });

  final IconData icon;
  final String label;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadius.borderRadiusFull,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.3),
            borderRadius: AppRadius.borderRadiusFull,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: textColor),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
