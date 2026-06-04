
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moniq/data/providers/announcement_providers.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/theme/shift_theme.dart';
import 'package:moniq/presentation/viewmodels/team_viewmodel.dart';
import 'package:moniq/presentation/widgets/announcement/announcement_filter_sheet.dart';

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
                  '공지사항',
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
                  '공지사항',
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

  /// "전체"(teamId == null)와 취소(null 반환)를 구분하기 위한 sentinel.
  static const _allValue = '__all__';

  Future<void> _openTeamSheet(BuildContext context) async {
    final options = <AnnouncementFilterOption<String>>[
      const AnnouncementFilterOption(
        value: _allValue,
        label: '전체',
        icon: Icons.groups_outlined,
      ),
      for (final t in teams)
        AnnouncementFilterOption(
          value: t.id as String,
          label: t.name as String,
          icon: Icons.campaign_outlined,
        ),
    ];

    final picked = await showAnnouncementFilterSheet<String>(
      context: context,
      title: '팀 선택',
      selectedValue: selectedTeamId ?? _allValue,
      options: options,
    );
    if (picked == null) return;
    onSelect(picked.value == _allValue ? null : picked.value);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openTeamSheet(context),
        borderRadius: AppRadius.borderRadiusFull,
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
      ),
    );
  }
}
