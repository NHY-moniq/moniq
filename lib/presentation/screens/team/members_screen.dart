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

List<TeamMemberWithUser> _sortedMembers(
  List<TeamMemberWithUser> members,
  String currentUserId,
) {
  final me = members.where((m) => m.userId == currentUserId).toList();
  final others = members.where((m) => m.userId != currentUserId).toList();
  return [...me, ...others];
}

String _normalizeMemberSearchText(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');

bool _matchesMemberName(TeamMemberWithUser member, String query) {
  final normalizedQuery = _normalizeMemberSearchText(query);
  if (normalizedQuery.isEmpty) return true;
  return _normalizeMemberSearchText(
    member.displayName,
  ).contains(normalizedQuery);
}

List<TeamMemberWithUser> _filteredSortedMembers(
  List<TeamMemberWithUser> members,
  String currentUserId,
  String nameQuery,
) {
  return _sortedMembers(
    members,
    currentUserId,
  ).where((member) => _matchesMemberName(member, nameQuery)).toList();
}

class MembersScreen extends ConsumerStatefulWidget {
  const MembersScreen({super.key, required this.teamId});

  final String teamId;

  @override
  ConsumerState<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends ConsumerState<MembersScreen> {
  TeamMemberWithUser? _selectedMember;
  final _searchController = TextEditingController();
  String _nameQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
                  searchController: _searchController,
                  nameQuery: _nameQuery,
                  onSearchChanged: _updateNameQuery,
                  onClearSearch: _clearNameQuery,
                  onSelectMember: (m) => setState(() => _selectedMember = m),
                )
              : _MobileLayout(
                  teamId: widget.teamId,
                  state: state,
                  searchController: _searchController,
                  nameQuery: _nameQuery,
                  onSearchChanged: _updateNameQuery,
                  onClearSearch: _clearNameQuery,
                  onTapMember: (m) => _showMemberSheet(context, ref, state, m),
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
      clipBehavior: Clip.antiAlias,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.42),
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

  void _updateNameQuery(String value) {
    setState(() {
      _nameQuery = value;
      if (_selectedMember != null &&
          !_matchesMemberName(_selectedMember!, value)) {
        _selectedMember = null;
      }
    });
  }

  void _clearNameQuery() {
    _searchController.clear();
    _updateNameQuery('');
  }
}

class _MemberSearchFilter extends StatelessWidget {
  const _MemberSearchFilter({
    required this.controller,
    required this.query,
    required this.totalCount,
    required this.resultCount,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String query;
  final int totalCount;
  final int resultCount;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasQuery = query.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                '필터: 이름',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                hasQuery ? '$resultCount/$totalCount명' : '전체 $totalCount명',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: hasQuery
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: controller,
            onChanged: onChanged,
            textCapitalization: TextCapitalization.none,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: '이름으로 검색',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: hasQuery
                  ? IconButton(
                      onPressed: onClear,
                      icon: const Icon(Icons.close_rounded),
                    )
                  : null,
              isDense: true,
              filled: true,
              fillColor: colorScheme.surfaceContainerLow,
              border: OutlineInputBorder(
                borderRadius: AppRadius.borderRadiusFull,
                borderSide: BorderSide(color: colorScheme.outlineVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppRadius.borderRadiusFull,
                borderSide: BorderSide(color: colorScheme.outlineVariant),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppRadius.borderRadiusFull,
                borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoMemberSearchResult extends StatelessWidget {
  const _NoMemberSearchResult({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_search_rounded,
              size: 44,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.36),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '검색 결과가 없습니다',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '"${query.trim()}" 이름과 일치하는 멤버가 없어요',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
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
    required this.searchController,
    required this.nameQuery,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onTapMember,
  });

  final String teamId;
  final TeamDetailState state;
  final TextEditingController searchController;
  final String nameQuery;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final ValueChanged<TeamMemberWithUser> onTapMember;

  @override
  Widget build(BuildContext context) {
    final sorted = _filteredSortedMembers(
      state.members,
      state.currentUserId,
      nameQuery,
    );

    return Column(
      children: [
        _MemberSearchFilter(
          controller: searchController,
          query: nameQuery,
          totalCount: state.members.length,
          resultCount: sorted.length,
          onChanged: onSearchChanged,
          onClear: onClearSearch,
        ),
        Expanded(
          child: sorted.isEmpty
              ? _NoMemberSearchResult(query: nameQuery)
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  itemCount: sorted.length,
                  separatorBuilder: (_, __) => const SizedBox.shrink(),
                  itemBuilder: (_, i) {
                    final m = sorted[i];
                    return MemberTile(
                      member: m,
                      isSelf: m.userId == state.currentUserId,
                      isAdmin: state.isAdmin,
                      onTap: (state.isAdmin || m.userId == state.currentUserId)
                          ? () => onTapMember(m)
                          : null,
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
    required this.searchController,
    required this.nameQuery,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onSelectMember,
  });

  final String teamId;
  final TeamDetailState state;
  final TeamMemberWithUser? selectedMember;
  final TextEditingController searchController;
  final String nameQuery;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final ValueChanged<TeamMemberWithUser?> onSelectMember;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final sorted = _filteredSortedMembers(
      state.members,
      state.currentUserId,
      nameQuery,
    );

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
              _MemberSearchFilter(
                controller: searchController,
                query: nameQuery,
                totalCount: state.members.length,
                resultCount: sorted.length,
                onChanged: onSearchChanged,
                onClear: onClearSearch,
              ),
              Expanded(
                child: sorted.isEmpty
                    ? _NoMemberSearchResult(query: nameQuery)
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm,
                        ),
                        itemCount: sorted.length,
                        separatorBuilder: (_, __) => const SizedBox.shrink(),
                        itemBuilder: (_, i) {
                          final m = sorted[i];
                          final isSelected = selectedMember?.userId == m.userId;
                          return _SelectableMemberTile(
                            member: m,
                            isSelf: m.userId == state.currentUserId,
                            isAdmin: state.isAdmin,
                            isSelected: isSelected,
                            onTap:
                                (state.isAdmin ||
                                    m.userId == state.currentUserId)
                                ? () => onSelectMember(isSelected ? null : m)
                                : null,
                          );
                        },
                      ),
              ),
              if (state.team.inviteCode != null)
                MemberInviteCodeBar(inviteCode: state.team.inviteCode!),
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
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.3,
                        ),
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
      color: isSelected ? colorScheme.primary.withValues(alpha: 0.08) : null,
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
        color: colorScheme.surfaceContainerLow,
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
