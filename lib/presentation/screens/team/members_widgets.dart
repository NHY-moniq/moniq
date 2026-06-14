import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moniq/data/models/team_member_with_user.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';

// ── 멤버 타일 ──

class MemberTile extends StatelessWidget {
  const MemberTile({
    super.key,
    required this.member,
    required this.isSelf,
    required this.isAdmin,
    this.onTap,
  });

  final TeamMemberWithUser member;
  final bool isSelf;
  final bool isAdmin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final m = member.member;
    // 다크모드 호환: 고정 파스텔 색 대신 accent 색의 반투명 배경 + accent 글자색.
    final isDark = colorScheme.brightness == Brightness.dark;
    final workAttributeTags = <Widget>[
      if (m.nightDedicated)
        MemberInfoTag(
          label: '나이트전담',
          backgroundColor:
              AppColors.shiftNight.withValues(alpha: isDark ? 0.24 : 0.18),
          foregroundColor: AppColors.shiftNight,
        ),
      if (m.nightExempt)
        MemberInfoTag(
          label: '나이트제외',
          backgroundColor:
              AppColors.brandOrange.withValues(alpha: isDark ? 0.24 : 0.18),
          foregroundColor: AppColors.brandOrange,
        ),
      if (m.dayOnly)
        MemberInfoTag(
          label: '데이전용',
          backgroundColor:
              AppColors.shiftDay.withValues(alpha: isDark ? 0.28 : 0.22),
          foregroundColor: isDark ? AppColors.shiftDay : const Color(0xFF8A6D00),
        ),
    ];

    // 아바타 — 은은한 링으로 입체감.
    final avatar = Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: CircleAvatar(
        radius: 22,
        backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
        backgroundImage: member.user.avatarUrl != null
            ? NetworkImage(member.user.avatarUrl!)
            : null,
        child: member.user.avatarUrl == null
            ? Text(
                member.displayName.isNotEmpty
                    ? member.displayName[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              )
            : null,
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      child: Material(
        color: colorScheme.surfaceContainerLow,
        borderRadius: AppRadius.borderRadiusLg,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.borderRadiusLg,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: AppRadius.borderRadiusLg,
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.6),
              ),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm + 2,
            ),
            child: Row(
              children: [
                avatar,
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              member.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                          if (isSelf) ...[
                            const SizedBox(width: AppSpacing.xs),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: AppSpacing.xxs,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primary
                                    .withValues(alpha: 0.16),
                                borderRadius: AppRadius.borderRadiusFull,
                                border: Border.all(
                                  color: colorScheme.primary
                                      .withValues(alpha: 0.32),
                                ),
                              ),
                              child: Text(
                                '나',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              member.user.email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          if (workAttributeTags.isNotEmpty)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(width: AppSpacing.xxs),
                                for (var i = 0;
                                    i < workAttributeTags.length;
                                    i++) ...[
                                  if (i > 0)
                                    const SizedBox(width: AppSpacing.xxs),
                                  workAttributeTags[i],
                                ],
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                MemberRoleBadge(role: member.role),
                if (onTap != null) ...[
                  const SizedBox(width: 2),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── 역할 배지 ──

class MemberRoleBadge extends StatelessWidget {
  const MemberRoleBadge({super.key, required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isAdmin = role == 'admin';
    final fg = isAdmin ? colorScheme.primary : colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: AppSpacing.xxs + 1,
      ),
      decoration: BoxDecoration(
        color: isAdmin
            ? colorScheme.primary.withValues(alpha: 0.14)
            : colorScheme.onSurfaceVariant.withValues(alpha: 0.1),
        borderRadius: AppRadius.borderRadiusFull,
        border: Border.all(color: fg.withValues(alpha: isAdmin ? 0.3 : 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isAdmin) ...[
            Icon(Icons.shield_rounded, size: 11, color: fg),
            const SizedBox(width: 3),
          ],
          Text(
            isAdmin ? '관리자' : '멤버',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

class MemberInfoTag extends StatelessWidget {
  const MemberInfoTag({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontSize: 10,
          color: foregroundColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ── 초대 코드 바 ──

class MemberInviteCodeBar extends StatelessWidget {
  const MemberInviteCodeBar({super.key, required this.inviteCode});

  final String inviteCode;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: AppSpacing.screenAll,
        child: Material(
          color: cs.primaryContainer.withValues(alpha: 0.5),
          borderRadius: AppRadius.borderRadiusFull,
          child: InkWell(
            borderRadius: AppRadius.borderRadiusFull,
            onTap: () {
              Clipboard.setData(ClipboardData(text: inviteCode));
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('초대 코드가 복사되었습니다')));
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                borderRadius: AppRadius.borderRadiusFull,
                border: Border.all(
                  color: cs.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.share_rounded, size: 18, color: cs.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '초대 코드 공유',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  // 코드 자체는 모노스페이스 느낌의 칩으로 또렷하게.
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: 0.7),
                      borderRadius: AppRadius.borderRadiusSm,
                    ),
                    child: Text(
                      inviteCode,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: cs.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
