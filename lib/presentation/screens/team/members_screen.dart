import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/models/team_member_with_user.dart';
import 'package:moniq/presentation/layout/adaptive_layout.dart';
import 'package:moniq/presentation/screens/team/members_dialogs.dart';
import 'package:moniq/presentation/screens/team/members_widgets.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/team_detail_viewmodel.dart';
import 'package:moniq/presentation/widgets/common/moniq_app_bar.dart';
import 'package:moniq/presentation/widgets/common/moniq_error_view.dart';
import 'package:moniq/presentation/widgets/common/moniq_loading_view.dart';

class MembersScreen extends ConsumerStatefulWidget {
  const MembersScreen({super.key, required this.teamId});

  final String teamId;

  @override
  ConsumerState<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends ConsumerState<MembersScreen> {
  TeamMemberWithUser? _selectedMember;

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(teamDetailViewModelProvider(widget.teamId));
    final isWide = AdaptiveLayout.isWide(context);

    final membersTitle = detailAsync.maybeWhen(
      data: (s) => '멤버 관리 (${s.members.length}명)',
      orElse: () => '멤버 관리',
    );

    return Scaffold(
      appBar: MoniqAppBar(title: membersTitle),
      body: detailAsync.when(
        loading: () => const MoniqLoadingView(),
        error: (e, _) => MoniqErrorView(
          message: '멤버 정보를 불러올 수 없습니다',
          onRetry: () =>
              ref.invalidate(teamDetailViewModelProvider(widget.teamId)),
        ),
        data: (state) {
          // 선택된 멤버가 목록에서 제거된 경우 초기화
          if (_selectedMember != null &&
              !state.members.any((m) => m.userId == _selectedMember!.userId)) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => setState(() => _selectedMember = null),
            );
          }

          return isWide
              ? _WebLayout(
                  teamId: widget.teamId,
                  state: state,
                  selectedMember: _selectedMember,
                  onSelectMember: (m) => setState(() => _selectedMember = m),
                )
              : _MobileLayout(
                  teamId: widget.teamId,
                  state: state,
                  onTapMember: (m) =>
                      _showMemberSheet(context, ref, state, m),
                );
        },
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
          teamId: widget.teamId,
          member: m,
          state: state,
          isSelf: m.userId == state.currentUserId,
          scrollController: scrollController,
        ),
      ),
    );
  }
}

// ────────────────────────────────────────
// 모바일 레이아웃 (기존)
// ────────────────────────────────────────

class _MobileLayout extends StatelessWidget {
  const _MobileLayout({
    required this.teamId,
    required this.state,
    required this.onTapMember,
  });

  final String teamId;
  final TeamDetailState state;
  final ValueChanged<TeamMemberWithUser> onTapMember;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            itemCount: state.members.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final m = state.members[i];
              return MemberTile(
                member: m,
                isSelf: m.userId == state.currentUserId,
                isAdmin: state.isAdmin,
                onTap: state.isAdmin ? () => onTapMember(m) : null,
              );
            },
          ),
        ),
        if (state.team.inviteCode != null)
          MemberInviteCodeBar(inviteCode: state.team.inviteCode!),
      ],
    );
  }
}

// ────────────────────────────────────────
// 웹 2-column 레이아웃
// ────────────────────────────────────────

class _WebLayout extends StatelessWidget {
  const _WebLayout({
    required this.teamId,
    required this.state,
    required this.selectedMember,
    required this.onSelectMember,
  });

  final String teamId;
  final TeamDetailState state;
  final TeamMemberWithUser? selectedMember;
  final ValueChanged<TeamMemberWithUser?> onSelectMember;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 왼쪽: 멤버 목록 ──
        Container(
          width: 380,
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(color: colorScheme.outlineVariant, width: 1),
            ),
          ),
          child: Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm),
                  itemCount: state.members.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final m = state.members[i];
                    final isSelected =
                        selectedMember?.userId == m.userId;
                    return _SelectableMemberTile(
                      member: m,
                      isSelf: m.userId == state.currentUserId,
                      isAdmin: state.isAdmin,
                      isSelected: isSelected,
                      onTap: state.isAdmin
                          ? () => onSelectMember(
                                isSelected ? null : m,
                              )
                          : null,
                    );
                  },
                ),
              ),
              if (state.team.inviteCode != null)
                MemberInviteCodeBar(
                    inviteCode: state.team.inviteCode!),
            ],
          ),
        ),

        // ── 오른쪽: 편집 패널 ──
        Expanded(
          child: selectedMember == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.person_outline_rounded,
                        size: 48,
                        color: colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        '멤버를 선택하면 상세 정보가 표시됩니다',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                )
              : _MemberSidePanel(
                  key: ValueKey(selectedMember!.userId),
                  teamId: teamId,
                  member: selectedMember!,
                  state: state,
                ),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────
// 선택 가능한 멤버 타일 (웹 전용)
// ────────────────────────────────────────

class _SelectableMemberTile extends StatelessWidget {
  const _SelectableMemberTile({
    required this.member,
    required this.isSelf,
    required this.isAdmin,
    required this.isSelected,
    this.onTap,
  });

  final TeamMemberWithUser member;
  final bool isSelf;
  final bool isAdmin;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      color: isSelected
          ? colorScheme.primary.withValues(alpha: 0.08)
          : null,
      child: MemberTile(
        member: member,
        isSelf: isSelf,
        isAdmin: isAdmin,
        onTap: onTap,
      ),
    );
  }
}

// ────────────────────────────────────────
// 웹 전용 사이드 편집 패널
// ────────────────────────────────────────

class _MemberSidePanel extends StatelessWidget {
  const _MemberSidePanel({
    super.key,
    required this.teamId,
    required this.member,
    required this.state,
  });

  final String teamId;
  final TeamMemberWithUser member;
  final TeamDetailState state;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: MemberEditSheet(
          teamId: teamId,
          member: member,
          state: state,
          isSelf: member.userId == state.currentUserId,
        ),
      ),
    );
  }
}
