part of 'announcement_screen.dart';

// ══════════════════════════════════════════════
// 공용 위젯들 (팀 관리 + 홈탭 공유)
// ══════════════════════════════════════════════

/// 팀 공지사항 화면 상단의 바텀시트 필터 셀렉터 바.
class _AnnouncementFilterBar extends StatelessWidget {
  const _AnnouncementFilterBar({
    required this.filter,
    required this.onTap,
  });

  final _AnnouncementFilter filter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label =
        filter == _AnnouncementFilter.pinned ? '고정된 공지만' : '전체 공지';
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.sm,
        AppSpacing.xxl,
        AppSpacing.xs,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: AnnouncementFilterChip(
          label: label,
          onTap: onTap,
        ),
      ),
    );
  }
}

/// 공지사항 리스트 타일 (공용)
///
/// 본문 미리보기 대신 작성자(아바타+이름)와 댓글 수를 노출한다.
/// 작성자/댓글 수는 [AnnouncementModel]에 조인·집계로 함께 담겨 오므로
/// 추가 조회 없이 모델에서 바로 읽는다.
class AnnouncementListTile extends StatelessWidget {
  const AnnouncementListTile({
    super.key,
    required this.announcement,
    this.teamName,
    required this.onTap,
    this.isPinnedLocally = false,
    this.onTogglePin,
  });

  final AnnouncementModel announcement;
  final String? teamName;
  final VoidCallback onTap;
  final bool isPinnedLocally;
  final VoidCallback? onTogglePin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dateFormat = DateFormat('MM.dd');
    final isDark = theme.brightness == Brightness.dark;

    final title = announcement.title;
    final createdAt = announcement.createdAt;
    final author = AnnouncementAuthorInfo.fromAnnouncement(announcement);
    final commentCount = announcement.commentCount;

    return Material(
      color: isDark
          ? colorScheme.surfaceContainer
          : colorScheme.surfaceContainerLowest,
      borderRadius: AppRadius.borderRadiusLg,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.borderRadiusLg,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _AuthorAvatar(
                avatarUrl: author.avatarUrl,
                displayName: author.displayName,
                radius: 20,
                primary: colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          author.displayName,
                          style: theme.textTheme.labelMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        if (teamName != null) ...[
                          const SizedBox(width: AppSpacing.xs),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: colorScheme.primary
                                  .withValues(alpha: 0.1),
                              borderRadius: AppRadius.borderRadiusSm,
                            ),
                            child: Text(
                              teamName!,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        if (createdAt != null)
                          Text(
                            dateFormat.format(createdAt),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        const SizedBox(width: AppSpacing.xxs),
                        Icon(Icons.chevron_right,
                            size: 16, color: colorScheme.outline),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        if (isPinnedLocally) ...[
                          Icon(Icons.push_pin,
                              size: 13, color: AppColors.brandOrange),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            title,
                            style: theme.textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _CommentCountBadge(count: commentCount),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 공지 카드용 작성자 아바타 (이니셜 폴백 포함).
class _AuthorAvatar extends StatelessWidget {
  const _AuthorAvatar({
    required this.avatarUrl,
    required this.displayName,
    required this.radius,
    required this.primary,
  });

  final String? avatarUrl;
  final String displayName;
  final double radius;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    final initial =
        displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(avatarUrl!),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: primary.withValues(alpha: 0.15),
      child: Text(
        initial,
        style: TextStyle(
          fontSize: radius * 0.8,
          fontWeight: FontWeight.w700,
          color: primary,
        ),
      ),
    );
  }
}

/// 카드에 표시하는 댓글 수 뱃지.
class _CommentCountBadge extends StatelessWidget {
  const _CommentCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final label = '$count';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.mode_comment_outlined,
          size: 12,
          color: cs.onSurfaceVariant,
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: AppTypography.captionSmall.copyWith(
            fontWeight: FontWeight.w700,
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

