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
    final skillLabel = _skillLabel(member.member.skillLevel);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
        backgroundImage: member.user.avatarUrl != null
            ? NetworkImage(member.user.avatarUrl!)
            : null,
        child: member.user.avatarUrl == null
            ? Text(
                member.displayName.isNotEmpty
                    ? member.displayName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              )
            : null,
      ),
      title: Row(
        children: [
          Flexible(child: Text(member.displayName)),
          if (isSelf) ...[
            const SizedBox(width: AppSpacing.xs),
            Text(
              '(나)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondaryLight,
              ),
            ),
          ],
        ],
      ),
      subtitle: Row(
        children: [
          Flexible(child: Text(member.user.email)),
          if (skillLabel != null) ...[
            const SizedBox(width: AppSpacing.xs),
            MemberSkillChip(
              label: skillLabel,
              skillLevel: member.member.skillLevel,
            ),
          ],
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MemberRoleBadge(role: member.role),
          if (isAdmin && !isSelf)
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: AppColors.textSecondaryLight,
            ),
        ],
      ),
      onTap: onTap,
    );
  }

  String? _skillLabel(String? skillLevel) {
    switch (skillLevel) {
      case 'junior':
        return '신규';
      case 'mid':
        return '중간';
      case 'senior':
        return '올드';
      default:
        return null;
    }
  }
}

// ── 역할 배지 ──

class MemberRoleBadge extends StatelessWidget {
  const MemberRoleBadge({super.key, required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    final isAdmin = role == 'admin';
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: isAdmin
            ? Theme.of(context)
                .colorScheme
                .primary
                .withValues(alpha: 0.1)
            : Theme.of(context)
                .colorScheme
                .onSurfaceVariant
                .withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isAdmin ? '관리자' : '멤버',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: isAdmin
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

// ── 스킬 칩 ──

class MemberSkillChip extends StatelessWidget {
  const MemberSkillChip({
    super.key,
    required this.label,
    required this.skillLevel,
  });

  final String label;
  final String? skillLevel;

  Color get _color {
    switch (skillLevel) {
      case 'junior':
        return AppColors.shiftDay;
      case 'mid':
        return AppColors.shiftEvening;
      case 'senior':
        return AppColors.shiftNight;
      default:
        return AppColors.tertiary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 1,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('초대 코드가 복사되었습니다'),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
