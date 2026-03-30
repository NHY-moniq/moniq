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
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: GestureDetector(
            onTap: () {
              if (Navigator.of(context).canPop()) {
                context.pop();
              } else {
                context.go('/teams');
              }
            },
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_back,
                color: AppColors.onSurface.withValues(alpha: 0.6),
                size: 20,
              ),
            ),
          ),
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
              // Hero profile section
              _TeamHeroSection(
                name: state.team.name,
                description: state.team.description,
                icon: state.team.icon,
                inviteCode: state.team.inviteCode,
                isAdmin: state.isAdmin,
                onEdit: () => _showEditSheet(context, ref, state),
              ),

              const SizedBox(height: AppSpacing.xxxl),

              // Section header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Text(
                  '팀 관리',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.0,
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Management menu cards
              _BubbleMenuCard(
                icon: Icons.people_outline,
                iconColor: AppColors.tertiary,
                title: '멤버 관리',
                subtitle: '${state.members.length}명 등록됨',
                onTap: () => context.push('/teams/$teamId/members'),
              ),
              const SizedBox(height: AppSpacing.md),
              _BubbleMenuCard(
                icon: Icons.settings_outlined,
                iconColor: AppColors.secondary,
                title: '팀 상세 설정',
                subtitle: '근무 유형 · 고정 규칙',
                onTap: () => context.push('/teams/$teamId/settings'),
              ),
              const SizedBox(height: AppSpacing.md),
              _BubbleMenuCard(
                icon: Icons.auto_awesome_outlined,
                iconColor: AppColors.primary,
                title: '스케줄 생성',
                subtitle: '생성 규칙 설정',
                onTap: () =>
                    context.push('/teams/$teamId/schedule-rules'),
              ),

              const SizedBox(height: AppSpacing.xxxl),
              const Divider(),
              const SizedBox(height: AppSpacing.lg),

              // Leave / Delete
              _BubbleMenuCard(
                icon: Icons.exit_to_app,
                iconColor: AppColors.onSurfaceVariant,
                title: '팀 나가기',
                onTap: () => _confirmLeave(context, ref, state),
              ),
              if (state.isAdmin) ...[
                const SizedBox(height: AppSpacing.md),
                _BubbleMenuCard(
                  icon: Icons.delete_outline,
                  iconColor: AppColors.error,
                  title: '팀 삭제',
                  titleColor: AppColors.error,
                  onTap: () => _confirmDelete(context, ref, state),
                ),
              ],

              // Bottom padding for floating nav
              const SizedBox(height: 100),
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
          left: AppSpacing.xxl,
          right: AppSpacing.xxl,
          top: AppSpacing.xxl,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('팀 정보 수정',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    )),
            const SizedBox(height: AppSpacing.xxl),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(hintText: '팀 이름'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: descController,
              decoration: const InputDecoration(hintText: '설명 (선택)'),
              maxLines: 2,
            ),
            const SizedBox(height: AppSpacing.xxl),
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

/// Hero-style team profile section matching design HTML
class _TeamHeroSection extends StatelessWidget {
  const _TeamHeroSection({
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.huge,
        horizontal: AppSpacing.xxl,
      ),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer.withValues(alpha: 0.3),
        borderRadius: AppRadius.borderRadiusXl,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Column(
        children: [
          // Avatar with gradient ring
          Stack(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.secondary],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(color: Colors.white, width: 4),
                ),
                child: ClipOval(
                  child: TeamProfileAvatar(icon: icon, radius: 46),
                ),
              ),
              if (isAdmin)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onTap: onEdit,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.edit,
                        size: 16,
                        color: AppColors.secondary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),

          // Team name
          Text(
            name,
            style: theme.textTheme.headlineLarge,
            textAlign: TextAlign.center,
          ),
          if (description != null && description!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              description!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],

          // Invite code pill
          if (inviteCode != null) ...[
            const SizedBox(height: AppSpacing.xxl),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: inviteCode!));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('초대 코드가 복사되었습니다')),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xxl,
                  vertical: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.6),
                  borderRadius: AppRadius.borderRadiusFull,
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.link,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      inviteCode!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: AppColors.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Icon(Icons.copy,
                        size: 14, color: AppColors.primary),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Bubbly menu card matching design HTML
class _BubbleMenuCard extends StatelessWidget {
  const _BubbleMenuCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.titleColor,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: AppRadius.borderRadiusLg,
          border: Border.all(color: Colors.transparent, width: 2),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chevron_right,
                color: iconColor.withValues(alpha: 0.6),
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
