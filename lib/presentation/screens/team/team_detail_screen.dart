import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/core/utils/team_icon_utils.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/team_calendar_viewmodel.dart';
import 'package:moniq/presentation/viewmodels/team_detail_viewmodel.dart';
import 'package:moniq/presentation/viewmodels/team_viewmodel.dart';
import 'package:moniq/presentation/widgets/common/moniq_error_view.dart';
import 'package:moniq/presentation/widgets/common/moniq_loading_view.dart';

class TeamDetailScreen extends HookConsumerWidget {
  const TeamDetailScreen({super.key, required this.teamId});

  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(teamDetailViewModelProvider(teamId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              context.pop();
            } else {
              context.go('/teams');
            }
          },
        ),
        title: const Text('팀 관리'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list_outlined),
            tooltip: '팀 목록',
            onPressed: () => context.push('/teams/list'),
          ),
        ],
      ),
      body: detailAsync.when(
        loading: () => const MoniqLoadingView(),
        error: (e, _) => MoniqErrorView(
          message: '팀 정보를 불러올 수 없습니다',
          onRetry: () => ref.invalidate(teamDetailViewModelProvider(teamId)),
        ),
        data: (state) => SingleChildScrollView(
          padding: AppSpacing.screenAll,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 팀 프로필 카드
              _TeamProfileCard(
                name: state.team.name,
                description: state.team.description,
                icon: state.team.icon,
                inviteCode: state.team.inviteCode,
                isAdmin: state.isAdmin,
                onEdit: () => _showEditSheet(context, ref, state),
              ),

              const SizedBox(height: AppSpacing.xxl),

              // 메뉴 리스트
              _MenuTile(
                icon: Icons.people_outline,
                title: '멤버 관리',
                subtitle: '${state.members.length}명',
                onTap: () => context.push('/teams/$teamId/members'),
              ),
              _MenuTile(
                icon: Icons.settings_outlined,
                title: '팀 상세 설정',
                subtitle: '근무 유형 · 고정 규칙',
                onTap: () =>
                    context.push('/teams/$teamId/settings'),
              ),
              _MenuTile(
                icon: Icons.auto_awesome_outlined,
                title: '스케줄 생성',
                subtitle: '생성 규칙 설정',
                onTap: () => context.push(
                    '/teams/$teamId/schedule-rules'),
              ),

              const SizedBox(height: AppSpacing.xxl),
              const Divider(),
              const SizedBox(height: AppSpacing.md),

              // 팀 나가기 (모든 멤버)
              _MenuTile(
                icon: Icons.exit_to_app,
                title: '팀 나가기',
                color: AppColors.textSecondaryLight,
                onTap: () => _confirmLeave(context, ref, state),
              ),

              // 팀 삭제 (관리자 전용)
              if (state.isAdmin)
                _MenuTile(
                  icon: Icons.delete_outline,
                  title: '팀 삭제',
                  color: AppColors.error,
                  onTap: () => _confirmDelete(context, ref, state),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmLeave(
    BuildContext context,
    WidgetRef ref,
    TeamDetailState state,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('팀 나가기'),
        content: Text('${state.team.name} 팀에서 나가시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref
                    .read(teamDetailViewModelProvider(teamId).notifier)
                    .leaveTeam();
                ref.invalidate(teamViewModelProvider);
                ref.invalidate(favoriteTeamProvider);
                if (context.mounted) context.go('/teams');
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('팀 나가기에 실패했습니다: $e')),
                  );
                }
              }
            },
            child: const Text(
              '나가기',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    TeamDetailState state,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('팀 삭제'),
        content: Text(
          '${state.team.name} 팀을 삭제하시겠습니까?\n'
          '모든 멤버가 더 이상 이 팀에 접근할 수 없습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref
                    .read(teamDetailViewModelProvider(teamId).notifier)
                    .deleteTeam();
                ref.invalidate(teamViewModelProvider);
                ref.invalidate(favoriteTeamProvider);
                if (context.mounted) context.go('/teams');
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('팀 삭제에 실패했습니다: $e')),
                  );
                }
              }
            },
            child: const Text(
              '삭제',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditSheet(
      BuildContext context, WidgetRef ref, TeamDetailState state) {
    final nameController = TextEditingController(text: state.team.name);
    final descController =
        TextEditingController(text: state.team.description ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.lg,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('팀 정보 수정',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    )),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: '팀 이름'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: '설명 (선택)'),
              maxLines: 2,
            ),
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton(
              onPressed: () async {
                await ref
                    .read(teamDetailViewModelProvider(teamId).notifier)
                    .updateTeam(
                      name: nameController.text.trim(),
                      description: descController.text.trim(),
                    );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamProfileCard extends StatelessWidget {
  const _TeamProfileCard({
    required this.name,
    this.description,
    this.icon,
    this.inviteCode,
    required this.isAdmin,
    required this.onEdit,
  });

  final String name;
  final String? description;
  final String? icon;
  final String? inviteCode;
  final bool isAdmin;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                TeamProfileAvatar(icon: icon, radius: 28),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      if (description != null && description!.isNotEmpty)
                        Text(description!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondaryLight)),
                    ],
                  ),
                ),
                if (isAdmin)
                  IconButton(
                      icon: const Icon(Icons.edit_outlined), onPressed: onEdit),
              ],
            ),
            if (inviteCode != null) ...[
              const SizedBox(height: AppSpacing.md),
              const Divider(),
              const SizedBox(height: AppSpacing.sm),
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: inviteCode!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('초대 코드가 복사되었습니다')),
                  );
                },
                child: Row(
                  children: [
                    const Icon(Icons.link, size: 18, color: AppColors.primary),
                    const SizedBox(width: AppSpacing.sm),
                    Text('초대 코드: $inviteCode',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: AppColors.primary)),
                    const SizedBox(width: AppSpacing.xs),
                    const Icon(Icons.copy, size: 14, color: AppColors.primary),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title,
          style: TextStyle(color: color)),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

