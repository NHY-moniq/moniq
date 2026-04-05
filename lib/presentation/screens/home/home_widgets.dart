import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/models/roster_entry.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/theme/shift_theme.dart';
import 'package:moniq/presentation/viewmodels/home_viewmodel.dart';

// ═════════════════════════════════════════���══════
// Weekly Hours Card
// ════════════════════════════════════════════════

class WeeklyHoursCard extends StatelessWidget {
  const WeeklyHoursCard({super.key, required this.shiftTheme});

  final ShiftThemeData shiftTheme;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        color: shiftTheme.primary.withValues(alpha: 0.08),
        borderRadius: AppRadius.borderRadiusLg,
        border: Border.all(
          color: shiftTheme.primary.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WEEKLY HOURS',
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
                    text: '32.5 ',
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
// On-Shift Team Card (real data)
// ════════════════════════════════════════════════

class OnShiftTeamCard extends ConsumerWidget {
  const OnShiftTeamCard({super.key, required this.shiftTheme});

  final ShiftThemeData shiftTheme;

  static const _maxAvatars = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final rosterAsync = ref.watch(todayTeamRosterProvider);

    final info = rosterAsync.valueOrNull;
    final workers = info?.workers ?? [];
    final overflow = workers.length > _maxAvatars
        ? workers.length - _maxAvatars
        : 0;

    return GestureDetector(
      onTap: info != null && workers.isNotEmpty
          ? () => _showRosterSheet(context, info)
          : null,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        decoration: BoxDecoration(
          color: shiftTheme.primary.withValues(alpha: 0.08),
          borderRadius: AppRadius.borderRadiusLg,
          border: Border.all(
            color: shiftTheme.primary.withValues(alpha: 0.15),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'ON-SHIFT TEAM',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      color: colorScheme.outline,
                    ),
                  ),
                ),
                if (workers.isNotEmpty)
                  Text(
                    '${workers.length}명',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: shiftTheme.accentText,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            if (workers.isEmpty)
              _EmptyState(colorScheme: colorScheme)
            else
              SizedBox(
                height: 40,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (int i = 0;
                        i < workers.length && i < _maxAvatars;
                        i++)
                      Positioned(
                        left: i * 26.0,
                        child: _MemberAvatar(
                          avatarUrl: workers[i].user.avatarUrl,
                          name: workers[i].user.displayName,
                          borderColor: shiftTheme.background,
                          colorScheme: colorScheme,
                        ),
                      ),
                    if (overflow > 0)
                      Positioned(
                        left: _maxAvatars * 26.0,
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
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showRosterSheet(BuildContext context, OnShiftTeamInfo info) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _RosterBottomSheet(info: info),
    );
  }
}

// ════════════════════════════════════════════════
// Member Avatar
// ════════════════════════════════════════════════

class _MemberAvatar extends StatelessWidget {
  const _MemberAvatar({
    required this.avatarUrl,
    required this.name,
    required this.borderColor,
    required this.colorScheme,
  });

  final String? avatarUrl;
  final String? name;
  final Color borderColor;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colorScheme.surfaceContainerHigh,
        border: Border.all(color: borderColor, width: 3),
      ),
      child: ClipOval(
        child: avatarUrl != null && avatarUrl!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: avatarUrl!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _FallbackIcon(
                  name: name,
                  colorScheme: colorScheme,
                ),
              )
            : _FallbackIcon(name: name, colorScheme: colorScheme),
      ),
    );
  }
}

class _FallbackIcon extends StatelessWidget {
  const _FallbackIcon({required this.name, required this.colorScheme});

  final String? name;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    if (name != null && name!.isNotEmpty) {
      return Center(
        child: Text(
          name!.characters.first,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return Icon(
      Icons.person,
      size: 18,
      color: colorScheme.onSurfaceVariant,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Center(
        child: Text(
          '오늘 팀 근무 없음',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════
// Roster Bottom Sheet
// ════════════════════════════════════════════════

class _RosterBottomSheet extends StatelessWidget {
  const _RosterBottomSheet({required this.info});

  final OnShiftTeamInfo info;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (ctx, scrollController) => Column(
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: AppRadius.borderRadiusFull,
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '오늘의 근무 팀원',
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (info.teamName != null)
                        Text(
                          info.teamName!,
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Roster list grouped by shift type
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xxl,
                vertical: AppSpacing.lg,
              ),
              itemCount: info.allRoster.length,
              itemBuilder: (ctx, index) {
                final entry = info.allRoster[index];
                return _RosterSection(
                  entry: entry,
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RosterSection extends StatelessWidget {
  const _RosterSection({
    required this.entry,
    required this.colorScheme,
    required this.textTheme,
  });

  final RosterEntry entry;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final color = _parseShiftColor(entry.shiftType.color);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Shift type header
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                entry.shiftType.name,
                style: textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              if (entry.shiftType.startTime != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '${entry.shiftType.startTime} – ${entry.shiftType.endTime}',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const Spacer(),
              Text(
                '${entry.workers.length}명',
                style: textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Workers
          ...entry.workers.map(
            (worker) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: [
                  _MemberAvatar(
                    avatarUrl: worker.user.avatarUrl,
                    name: worker.user.displayName,
                    borderColor: colorScheme.surface,
                    colorScheme: colorScheme,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      worker.user.displayName ?? worker.user.email,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (worker.note != null && worker.note!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHigh,
                        borderRadius: AppRadius.borderRadiusFull,
                      ),
                      child: Text(
                        worker.note!,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
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

  Color _parseShiftColor(String? hex) {
    if (hex == null || hex.isEmpty) return colorScheme.primary;
    final cleaned = hex.replaceAll('#', '');
    if (cleaned.length == 6) {
      return Color(int.parse('FF$cleaned', radix: 16));
    }
    return colorScheme.primary;
  }
}

// ════════════════════════════════════════════════
// Announcement Card
// ════════════════════════════════════════════════

class AnnouncementCard extends StatelessWidget {
  const AnnouncementCard({super.key, required this.shiftTheme});

  final ShiftThemeData shiftTheme;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: shiftTheme.primary.withValues(alpha: 0.06),
        borderRadius: AppRadius.borderRadiusLg,
        border: Border.all(
          color: shiftTheme.primary.withValues(alpha: 0.12),
        ),
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
              color: shiftTheme.primary,
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
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: colorScheme.outline,
          ),
        ],
      ),
    );
  }
}
