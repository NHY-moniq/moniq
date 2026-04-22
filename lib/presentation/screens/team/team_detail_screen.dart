import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/team_detail_viewmodel.dart';
import 'package:moniq/presentation/widgets/common/moniq_error_view.dart';
import 'package:moniq/presentation/widgets/common/moniq_loading_view.dart';

import 'team_detail_dialogs.dart';
import 'team_detail_widgets.dart';

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
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_back,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
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
              TeamDetailHeroSection(
                name: state.team.name,
                description: state.team.description,
                icon: state.team.icon,
                inviteCode: state.team.inviteCode,
                isAdmin: state.isAdmin,
                onEdit: () => showEditTeamSheet(
                  context: context,
                  ref: ref,
                  teamId: teamId,
                  state: state,
                ),
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
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withValues(alpha: 0.6),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Management menu cards
              TeamDetailBubbleMenuCard(
                icon: Icons.people_outline,
                iconColor: Theme.of(context).colorScheme.tertiary,
                title: '멤버 관리',
                subtitle: '${state.members.length}명 등록됨',
                onTap: () => context.push('/teams/$teamId/members'),
              ),
              const SizedBox(height: AppSpacing.md),
              TeamDetailBubbleMenuCard(
                icon: Icons.settings_outlined,
                iconColor: Theme.of(context).colorScheme.secondary,
                title: '팀 상세 설정',
                subtitle: '근무 유형 · 고정 규칙',
                onTap: () => context.push('/teams/$teamId/settings'),
              ),
              const SizedBox(height: AppSpacing.md),
              Opacity(
                opacity: state.isAdmin ? 1.0 : 0.5,
                child: TeamDetailBubbleMenuCard(
                  icon: Icons.auto_awesome_outlined,
                  iconColor: Theme.of(context).colorScheme.primary,
                  title: '스케줄 생성',
                  subtitle: state.isAdmin
                      ? '생성 규칙 설정'
                      : '팀 관리자만 사용 가능',
                  onTap: () {
                    if (state.isAdmin) {
                      context.push('/teams/$teamId/schedule-rules');
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('팀 관리자만 사용 가능한 기능입니다.'),
                        ),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.xxxl),

              // Section header - 근무표 관리
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Text(
                  '근무표 관리',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.0,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withValues(alpha: 0.6),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              Opacity(
                opacity: state.isAdmin ? 1.0 : 0.5,
                child: TeamDetailBubbleMenuCard(
                  icon: Icons.event_note_outlined,
                  iconColor: AppColors.brandOrange,
                  title: '원티드 수집',
                  subtitle: state.isAdmin
                      ? '근무표 생성 전 팀원 원티드 수집'
                      : '팀 관리자만 사용 가능',
                  onTap: () {
                    if (state.isAdmin) {
                      context.push(
                        '/teams/$teamId/wanted?teamName=${Uri.encodeComponent(state.team.name)}',
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('팀 관리자만 사용 가능한 기능입니다.'),
                        ),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TeamDetailBubbleMenuCard(
                icon: Icons.edit_calendar_outlined,
                iconColor: Theme.of(context).colorScheme.secondary,
                title: '원티드 입력',
                subtitle: '내 원티드 날짜 입력하기',
                onTap: () =>
                    context.push('/teams/$teamId/wanted/entry'),
              ),
              const SizedBox(height: AppSpacing.md),
              TeamDetailBubbleMenuCard(
                icon: Icons.swap_horiz_outlined,
                iconColor: Theme.of(context).colorScheme.tertiary,
                title: '교환/변경 요청',
                subtitle: '근무 교환 및 변경 요청 관리',
                onTap: () =>
                    context.push('/teams/$teamId/requests'),
              ),

              const SizedBox(height: AppSpacing.xxxl),
              const Divider(),
              const SizedBox(height: AppSpacing.lg),

              // Leave / Delete
              TeamDetailBubbleMenuCard(
                icon: Icons.exit_to_app,
                iconColor: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant,
                title: '팀 나가기',
                onTap: () => showConfirmLeaveDialog(
                  context: context,
                  ref: ref,
                  teamId: teamId,
                  state: state,
                ),
              ),
              if (state.isAdmin) ...[
                const SizedBox(height: AppSpacing.md),
                TeamDetailBubbleMenuCard(
                  icon: Icons.delete_outline,
                  iconColor: Theme.of(context).colorScheme.error,
                  title: '팀 삭제',
                  titleColor: Theme.of(context).colorScheme.error,
                  onTap: () => showConfirmDeleteDialog(
                    context: context,
                    ref: ref,
                    teamId: teamId,
                    state: state,
                  ),
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
}
