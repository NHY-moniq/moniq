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

    return ListTile(
      leading: CircleAvatar(
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
                  fontWeight: FontWeight.w600,
                ),
              )
            : null,
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              member.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
                color: colorScheme.primary.withValues(alpha: 0.16),
                borderRadius: AppRadius.borderRadiusFull,
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.32),
                ),
              ),
              child: Text(
                '(나)',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Row(
        children: [
          Flexible(
            child: Text(
              member.user.email,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (workAttributeTags.isNotEmpty)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(width: AppSpacing.xxs),
                for (var i = 0; i < workAttributeTags.length; i++) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.xxs),
                  workAttributeTags[i],
                ],
              ],
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MemberRoleBadge(role: member.role),
          if (onTap != null)
            Icon(
              Icons.chevron_right,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
        ],
      ),
      onTap: onTap,
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
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: isAdmin
            ? colorScheme.primary.withValues(alpha: 0.1)
            : colorScheme.onSurfaceVariant.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        isAdmin ? '관리자' : '멤버',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w500,
          color: isAdmin ? colorScheme.primary : colorScheme.onSurfaceVariant,
        ),
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
    return SafeArea(
      child: Padding(
        padding: AppSpacing.screenAll,
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.share),
            label: Text('초대 코드 공유: $inviteCode'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: inviteCode));
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('초대 코드가 복사되었습니다')));
            },
          ),
        ),
      ),
    );
  }
}
