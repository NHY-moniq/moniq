import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/models/team_member_with_user.dart';
import 'package:moniq/presentation/screens/team/members_dialogs.dart';
import 'package:moniq/presentation/screens/team/members_widgets.dart';
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
          onRetry: () =>
              ref.invalidate(teamDetailViewModelProvider(teamId)),
        ),
        data: (state) => Column(
          children: [
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.sm,
                ),
                itemCount: state.members.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1),
                itemBuilder: (context, index) {
                  final m = state.members[index];
                  final isSelf =
                      m.userId == state.currentUserId;

                  return MemberTile(
                    member: m,
                    isSelf: isSelf,
                    isAdmin: state.isAdmin,
                    onTap: state.isAdmin && !isSelf
                        ? () => _showMemberSheet(
                              context,
                              ref,
                              state,
                              m,
                            )
                        : null,
                  );
                },
              ),
            ),
            if (state.team.inviteCode != null)
              MemberInviteCodeBar(
                inviteCode: state.team.inviteCode!,
              ),
          ],
        ),
      ),
    );
  }

  void _showMemberSheet(
    BuildContext context,
    WidgetRef ref,
    TeamDetailState state,
    TeamMemberWithUser m,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => MemberEditSheet(
          teamId: teamId,
          member: m,
          state: state,
          scrollController: scrollController,
        ),
      ),
    );
  }
}
