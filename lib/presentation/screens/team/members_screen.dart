import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/models/team_member_with_user.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/team_detail_viewmodel.dart';
import 'package:moniq/presentation/widgets/common/moniq_error_view.dart';
import 'package:moniq/presentation/widgets/common/moniq_loading_view.dart';

class MembersScreen extends HookConsumerWidget {
  const MembersScreen({super.key, required this.teamId});

  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(teamDetailViewModelProvider(teamId));

    return Scaffold(
      appBar: AppBar(
        title: detailAsync.whenOrNull(
              data: (s) => Text('멤버 관리 (${s.members.length})'),
            ) ??
            const Text('멤버 관리'),
      ),
      body: detailAsync.when(
        loading: () => const MoniqLoadingView(),
        error: (e, _) => MoniqErrorView(
          message: '멤버 정보를 불러올 수 없습니다',
          onRetry: () => ref.invalidate(teamDetailViewModelProvider(teamId)),
        ),
        data: (state) => Column(
          children: [
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                itemCount: state.members.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final m = state.members[index];
                  final isSelf = m.userId == state.currentUserId;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          AppColors.primary.withValues(alpha: 0.1),
                      backgroundImage: m.user.avatarUrl != null
                          ? NetworkImage(m.user.avatarUrl!)
                          : null,
                      child: m.user.avatarUrl == null
                          ? Text(
                              m.displayName.isNotEmpty
                                  ? m.displayName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600),
                            )
                          : null,
                    ),
                    title: Row(
                      children: [
                        Flexible(child: Text(m.displayName)),
                        if (isSelf) ...[
                          const SizedBox(width: AppSpacing.xs),
                          Text('(나)',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                      color: AppColors.textSecondaryLight)),
                        ],
                      ],
                    ),
                    subtitle: Text(m.user.email),
                    trailing: _RoleBadge(role: m.role),
                    onTap: state.isAdmin && !isSelf
                        ? () => _showMemberActions(context, ref, state, m)
                        : null,
                  );
                },
              ),
            ),
            // 초대 코드 공유
            if (state.team.inviteCode != null)
              SafeArea(
                child: Padding(
                  padding: AppSpacing.screenAll,
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.share),
                      label: Text('초대 코드 공유: ${state.team.inviteCode}'),
                      onPressed: () {
                        Clipboard.setData(
                            ClipboardData(text: state.team.inviteCode!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('초대 코드가 복사되었습니다')),
                        );
                      },
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showMemberActions(BuildContext context, WidgetRef ref,
      TeamDetailState state, TeamMemberWithUser m) {
    final newRole = m.role == 'admin' ? 'member' : 'admin';
    final adminCount = state.members.where((x) => x.role == 'admin').length;
    final canDemote = !(m.role == 'admin' && adminCount <= 1);

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: Text(
                  newRole == 'admin' ? '관리자로 변경' : '일반 멤버로 변경'),
              enabled: newRole == 'admin' || canDemote,
              onTap: () async {
                Navigator.pop(ctx);
                await ref
                    .read(teamDetailViewModelProvider(teamId).notifier)
                    .updateMemberRole(m.userId, newRole);
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_remove, color: AppColors.error),
              title: const Text('멤버 제거',
                  style: TextStyle(color: AppColors.error)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmRemove(context, ref, m);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmRemove(
      BuildContext context, WidgetRef ref, TeamMemberWithUser m) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('멤버 제거'),
        content: Text('${m.displayName}님을 팀에서 제거하시겠습니까?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(teamDetailViewModelProvider(teamId).notifier)
                  .removeMember(m.userId);
            },
            child:
                const Text('제거', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    final isAdmin = role == 'admin';
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
      decoration: BoxDecoration(
        color: isAdmin
            ? AppColors.primary.withValues(alpha: 0.1)
            : AppColors.textSecondaryLight.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isAdmin ? '관리자' : '멤버',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: isAdmin ? AppColors.primary : AppColors.textSecondaryLight,
        ),
      ),
    );
  }
}
