import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moniq/core/utils/color_utils.dart';
import 'package:moniq/data/datasources/push_service.dart';
import 'package:moniq/data/models/shift_type_model.dart';
import 'package:moniq/data/models/team_member_with_user.dart';
import 'package:moniq/data/models/wanted_request_model.dart';
import 'package:moniq/data/providers/shift_providers.dart';
import 'package:moniq/data/providers/team_providers.dart';
import 'package:moniq/presentation/layout/adaptive_layout.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/wanted_viewmodel.dart';
import 'package:moniq/presentation/widgets/common/moniq_bottom_sheet.dart';
import 'package:moniq/presentation/widgets/common/moniq_date_picker_sheet.dart';

final _requestWidgetsShiftTypesProvider = FutureProvider.autoDispose
    .family<List<ShiftTypeModel>, String>(
      (ref, teamId) => ref.watch(shiftRepositoryProvider).getShiftTypes(teamId),
    );

final _requestWidgetsTeamMembersProvider = FutureProvider.autoDispose
    .family<List<TeamMemberWithUser>, String>(
      (ref, teamId) =>
          ref.watch(teamRepositoryProvider).getTeamMembersWithUsers(teamId),
    );

/// 새 수집 요청 생성 폼
class WantedRequestCreateView extends StatefulWidget {
  const WantedRequestCreateView({
    super.key,
    required this.teamId,
    required this.teamName,
  });

  final String teamId;
  final String teamName;

  @override
  State<WantedRequestCreateView> createState() =>
      _WantedRequestCreateViewState();
}

class _WantedRequestCreateViewState extends State<WantedRequestCreateView> {
  DateTime? _periodStart;
  DateTime? _periodEnd;
  DateTime? _deadline;

  String? get _periodRangeError {
    if (_periodStart == null || _periodEnd == null) return null;
    if (_periodEnd!.isBefore(_periodStart!)) {
      return '시작 일자가 마감 일자 이후입니다';
    }
    return null;
  }

  bool get _hasValidationError => _periodRangeError != null;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _periodStart = DateTime(now.year, now.month + 1, 1);
    _periodEnd = DateTime(now.year, now.month + 2, 0);
    _deadline = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 7));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final dateFormat = DateFormat('yyyy년 MM월 dd일');

    return SingleChildScrollView(
      padding: AppSpacing.screenAll,
      child: MaxWidthLayout(
        maxWidth: 640,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 안내 카드
            Card(
              color: colorScheme.primary.withValues(alpha: 0.08),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: colorScheme.primary),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        '근무표 생성 전 팀원들의 원티드를 수집합니다.\n요청을 생성하면 팀원들에게 알림이 발송됩니다.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),

            // 근무 생성 예정 기간
            Text(
              '근무 생성 예정 기간',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  children: [
                    WantedRequestDatePickerRow(
                      label: '시작일',
                      date: _periodStart,
                      dateFormat: dateFormat,
                      onTap: () async {
                        final picked = await showMoniqDatePickerSheet(
                          context: context,
                          initialDate: _periodStart ?? DateTime.now(),
                          title: '시작일 선택',
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );
                        if (picked != null) {
                          setState(() => _periodStart = picked);
                        }
                      },
                    ),
                    const Divider(height: AppSpacing.xxl),
                    WantedRequestDatePickerRow(
                      label: '종료일',
                      date: _periodEnd,
                      dateFormat: dateFormat,
                      onTap: () async {
                        final picked = await showMoniqDatePickerSheet(
                          context: context,
                          initialDate:
                              _periodEnd ??
                              (_periodStart ?? DateTime.now()).add(
                                const Duration(days: 30),
                              ),
                          title: '종료일 선택',
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );
                        if (picked != null) {
                          setState(() => _periodEnd = picked);
                        }
                      },
                    ),
                    if (_periodRangeError != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _periodRangeError!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),

            // 입력 마감일
            Text(
              '입력 마감일',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '마감일 이후 또는 수집 마감 시 팀원 입력이 자동 차단됩니다',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: WantedRequestDatePickerRow(
                  label: '마감일',
                  date: _deadline,
                  dateFormat: dateFormat,
                  onTap: () async {
                    final picked = await showMoniqDatePickerSheet(
                      context: context,
                      initialDate: _deadline ?? DateTime.now(),
                      title: '마감일 선택',
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setState(() => _deadline = picked);
                    }
                  },
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.xxxl),

            // 생성 버튼
            SizedBox(
              width: double.infinity,
              child: Consumer(
                builder: (context, ref, _) {
                  final stateAsync = ref.watch(
                    wantedAdminViewModelProvider(widget.teamId),
                  );
                  final isCreating =
                      stateAsync.valueOrNull?.isCreating ?? false;

                  return ElevatedButton.icon(
                    onPressed:
                        isCreating ||
                            _periodStart == null ||
                            _periodEnd == null ||
                            _hasValidationError
                        ? null
                        : () async {
                            final notifier = ref.read(
                              wantedAdminViewModelProvider(
                                widget.teamId,
                              ).notifier,
                            );
                            var allOk = true;
                            for (final type in WantedType.values) {
                              final ok = await notifier.createWantedRequest(
                                periodStart: _periodStart!,
                                periodEnd: _periodEnd!,
                                deadline: _deadline,
                                teamName: widget.teamName,
                                wantedType: type.value,
                              );
                              if (!ok) allOk = false;
                            }
                            if (allOk && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    '전체 수집 유형 요청이 생성되고 알림이 발송되었습니다',
                                  ),
                                ),
                              );
                            }
                          },
                    icon: isCreating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    label: Text(isCreating ? '생성 중...' : '원티드 수집 생성'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 활성 수집 요청 현황
class WantedRequestActiveView extends HookConsumerWidget {
  const WantedRequestActiveView({
    super.key,
    required this.teamId,
    required this.teamName,
    required this.state,
  });

  final String teamId;
  final String teamName;
  final WantedAdminState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final dateFormat = DateFormat('MM.dd');
    final request = state.activeRequest;
    if (request == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final isNight = request.wantedType == 'night_dedicated';

    // 근무 유형 맵
    final shiftTypesAsync = ref.watch(
      _requestWidgetsShiftTypesProvider(teamId),
    );
    final shiftTypeMap = {
      for (final t in (shiftTypesAsync.valueOrNull ?? [])) t.id: t,
    };
    final membersAsync = ref.watch(_requestWidgetsTeamMembersProvider(teamId));
    final teamMembers =
        membersAsync.valueOrNull ?? const <TeamMemberWithUser>[];

    // 팀원별 엔트리 그루핑
    final groupedByUser = <String, WantedRequestUserEntryGroup>{};
    for (final ew in state.allEntries) {
      final uid = ew.entry.userId;
      groupedByUser.putIfAbsent(
        uid,
        () => WantedRequestUserEntryGroup(
          userId: uid,
          displayName: ew.displayName,
          items: [],
        ),
      );
      groupedByUser[uid]!.items.add(
        WantedEntryDisplayItem(
          date: ew.entry.wantedDate,
          priority: ew.entry.priority,
          shiftTypeId: ew.entry.shiftTypeId,
          reason: ew.entry.reason,
        ),
      );
    }
    for (final group in groupedByUser.values) {
      group.items.sort((a, b) => a.date.compareTo(b.date));
    }
    final userGroups = groupedByUser.values.toList();
    final activeGroupSeed = userGroups.map((g) => g.userId).join(',');
    final expandedActiveUserIds = useState<Set<String>>({});
    useEffect(() {
      expandedActiveUserIds.value = {};
      return null;
    }, [activeGroupSeed, isNight]);
    final respondedUserIds = groupedByUser.keys.toSet();
    final totalMemberCount = teamMembers.length;
    final respondedCount = userGroups.length;
    final missingMembers =
        teamMembers
            .where((member) => !respondedUserIds.contains(member.userId))
            .toList()
          ..sort((a, b) => a.displayName.compareTo(b.displayName));
    final responseLabel = totalMemberCount > 0
        ? '$totalMemberCount명 중 $respondedCount명 응답'
        : '$respondedCount명 응답';

    // 엔트리 칩 빌더 (shiftTypeId 기반: null=오프/회색, non-null=근무 유형 색)
    Widget entryChip(WantedEntryDisplayItem item) {
      final Color chipColor;
      final String avatarLabel;
      if (item.shiftTypeId != null) {
        final st = shiftTypeMap[item.shiftTypeId];
        chipColor = st != null ? parseHexColor(st.color) : colorScheme.primary;
        avatarLabel = st?.code ?? '?';
      } else {
        chipColor = AppColors.shiftOff;
        avatarLabel = 'O';
      }
      final chip = WantedEntryPill(
        color: chipColor,
        avatarLabel: avatarLabel,
        label: Text(
          '${dateFormat.format(item.date)} · ${item.priority}순위',
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      );
      final hasReason = item.reason != null && item.reason!.isNotEmpty;
      if (!hasReason) return chip;
      return WantedReasonChip(chip: chip, reason: item.reason!);
    }

    // D-day 텍스트 계산
    String dDayText() {
      if (request.deadline == null) return '';
      final now = DateTime.now();
      final deadline = request.deadline!;
      final today = DateTime(now.year, now.month, now.day);
      final deadlineDay = DateTime(deadline.year, deadline.month, deadline.day);
      final days = deadlineDay.difference(today).inDays;
      if (days > 0) return 'D-$days';
      if (days == 0) return 'D-Day';
      return '마감일 지남';
    }

    Color daysLeftColor(DateTime deadline) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final deadlineDay = DateTime(deadline.year, deadline.month, deadline.day);
      final days = deadlineDay.difference(today).inDays;
      if (days < 0) return colorScheme.error;
      if (days <= 3) return AppColors.brandOrange;
      return colorScheme.onSurfaceVariant;
    }

    Future<void> showMissingMembersSheet() async {
      await showMoniqBottomSheet<void>(
        context: context,
        title: '미응답자',
        eyebrow: 'WANTED',
        child: _WantedMissingMembersSheet(
          teamId: teamId,
          teamName: teamName,
          request: request,
          missingMembers: missingMembers,
        ),
      );
    }

    // 타입 전환 칩: 나이트 전담과 원티드가 모두 있을 때만 표시
    final hasNight = state.activeRequests.any(
      (r) => r.wantedType == 'night_dedicated',
    );
    final hasNonNight = state.activeRequests.any(
      (r) => r.wantedType != 'night_dedicated',
    );
    Widget typeChips() => (hasNight && hasNonNight)
        ? Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Center(
              child: WantedModeTabs(
                isNight: isNight,
                onWanted: () => ref
                    .read(wantedAdminViewModelProvider(teamId).notifier)
                    .selectType('day_off'),
                onNight: () => ref
                    .read(wantedAdminViewModelProvider(teamId).notifier)
                    .selectType('night_dedicated'),
              ),
            ),
          )
        : const SizedBox.shrink();

    // 상태 배너 (공통)
    Widget statusBanner() => Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.lg,
        AppSpacing.xxl,
        AppSpacing.xxl,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _WantedStatusPill(
                label: '수집 중',
                color: AppColors.brandOrange,
                icon: Icons.circle,
              ),
              const Spacer(),
              if (request.deadline != null)
                _WantedStatusPill(
                  label: dDayText(),
                  color: daysLeftColor(request.deadline!),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            isNight ? '나이트 전담 수집 진행 중' : '원티드 수집 진행 중',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${DateFormat('yyyy.MM.dd').format(request.periodStart)} ~ '
            '${DateFormat('yyyy.MM.dd').format(request.periodEnd)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              if (request.deadline != null)
                _WantedMetricChip(
                  icon: Icons.event_available_rounded,
                  label:
                      '마감 ${DateFormat('yyyy.MM.dd').format(request.deadline!)}',
                ),
              _WantedMetricChip(
                icon: Icons.groups_rounded,
                label: responseLabel,
                color: colorScheme.primary,
                onTap: showMissingMembersSheet,
              ),
              _WantedMetricChip(
                icon: Icons.checklist_rounded,
                label: '${state.allEntries.length}건',
                color: AppColors.brandOrange,
              ),
            ],
          ),
        ],
      ),
    );

    Widget closeRequestButton() => SizedBox(
      width: double.infinity,
      child: FilledButton.tonalIcon(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.errorContainer,
          foregroundColor: colorScheme.onErrorContainer,
        ),
        onPressed: () async {
          final confirm = await showMoniqConfirmSheet(
            context: context,
            title: '수집 마감',
            message: '원티드 수집을 마감하시겠습니까?',
            confirmLabel: '마감',
            destructive: true,
          );
          if (confirm == true) {
            await ref
                .read(wantedAdminViewModelProvider(teamId).notifier)
                .closeRequest();
          }
        },
        icon: const Icon(Icons.check_circle_outline),
        label: const Text('수집 마감'),
      ),
    );

    // 하단 버튼 (공통)
    Widget bottomButtons() => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: closeRequestButton(),
      ),
    );

    // ── 웹: 2-column (좌: 상태+버튼, 우: DataTable) ──
    if (AdaptiveLayout.isWide(context)) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 왼쪽: 상태 + 버튼
          Container(
            width: 320,
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: colorScheme.outlineVariant, width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                statusBanner(),
                typeChips(),
                const Spacer(),
                bottomButtons(),
              ],
            ),
          ),
          // 오른쪽: 나이트 전담 선택 or 응답 목록
          Expanded(
            child: isNight
                ? _NightDedicatedSelector(
                    teamId: teamId,
                    entries: state.allEntries,
                    isActive: true,
                  )
                : state.allEntries.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.hourglass_empty,
                          size: 48,
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.3,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          '아직 입력된 원티드가 없습니다',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      children: userGroups.map((group) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 100,
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    top: AppSpacing.xs,
                                  ),
                                  child: Text(
                                    group.displayName,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Wrap(
                                  spacing: AppSpacing.xs,
                                  runSpacing: AppSpacing.xs,
                                  children: group.items.map(entryChip).toList(),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: AppSpacing.xs,
                                  left: AppSpacing.sm,
                                ),
                                child: Text(
                                  '${group.items.length}건',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ],
      );
    }

    // ── 모바일 레이아웃 ──
    return Column(
      children: [
        statusBanner(),
        typeChips(),

        // 나이트 전담 탭: 선택 UI
        if (isNight)
          Expanded(
            child: _NightDedicatedSelector(
              teamId: teamId,
              entries: state.allEntries,
              isActive: true,
              footerButton: closeRequestButton(),
            ),
          )
        else
          // 엔트리 목록 (RefreshIndicator로 새로고침 가능)
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref
                  .read(wantedAdminViewModelProvider(teamId).notifier)
                  .refresh(),
              child: state.allEntries.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.4,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.hourglass_empty,
                                  size: 48,
                                  color: colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.3),
                                ),
                                const SizedBox(height: AppSpacing.md),
                                Text(
                                  '아직 입력된 원티드가 없습니다',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  '아래로 당겨 새로고침',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: AppSpacing.screenAll,
                      itemCount: userGroups.length,
                      itemBuilder: (context, index) {
                        final group = userGroups[index];
                        final isExpanded = expandedActiveUserIds.value.contains(
                          group.userId,
                        );

                        final initial = group.displayName.isNotEmpty
                            ? group.displayName[0].toUpperCase()
                            : '?';
                        return Card(
                          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                          elevation: 0,
                          color: colorScheme.surfaceContainerLow,
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.borderRadiusMd,
                            side: BorderSide(color: colorScheme.outlineVariant),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceContainerHighest
                                        .withValues(alpha: 0.5),
                                    borderRadius: AppRadius.borderRadiusMd,
                                  ),
                                  child: InkWell(
                                    borderRadius: AppRadius.borderRadiusMd,
                                    onTap: () {
                                      final next = Set<String>.from(
                                        expandedActiveUserIds.value,
                                      );
                                      if (isExpanded) {
                                        next.remove(group.userId);
                                      } else {
                                        next.add(group.userId);
                                      }
                                      expandedActiveUserIds.value = next;
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(
                                        AppSpacing.sm,
                                      ),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 17,
                                            backgroundColor: colorScheme.primary
                                                .withValues(alpha: 0.14),
                                            child: Text(
                                              initial,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w900,
                                                color: colorScheme.primary,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: AppSpacing.sm),
                                          Expanded(
                                            child: Text(
                                              group.displayName,
                                              style: theme.textTheme.titleSmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                            ),
                                          ),
                                          Text(
                                            '${group.items.length}건',
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color: colorScheme.primary,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                          ),
                                          const SizedBox(width: AppSpacing.xs),
                                          Icon(
                                            isExpanded
                                                ? Icons.keyboard_arrow_up
                                                : Icons.keyboard_arrow_down,
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                AnimatedCrossFade(
                                  firstChild: const SizedBox.shrink(),
                                  secondChild: Padding(
                                    padding: const EdgeInsets.only(
                                      top: AppSpacing.sm,
                                    ),
                                    child: Wrap(
                                      spacing: AppSpacing.xs,
                                      runSpacing: AppSpacing.xs,
                                      children: group.items
                                          .map(entryChip)
                                          .toList(),
                                    ),
                                  ),
                                  crossFadeState: isExpanded
                                      ? CrossFadeState.showSecond
                                      : CrossFadeState.showFirst,
                                  duration: const Duration(milliseconds: 180),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),

        if (!isNight) bottomButtons(),
      ],
    );
  }
}

/// 마감된 수집 결과 보기 (활성 요청 없고 마감된 내역 있을 때)
class WantedRequestClosedView extends HookConsumerWidget {
  const WantedRequestClosedView({
    super.key,
    required this.teamId,
    required this.teamName,
    required this.state,
  });

  final String teamId;
  final String teamName;
  final WantedAdminState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dateFormat = DateFormat('MM.dd');
    final request = state.lastClosedRequest;
    if (request == null) return const SizedBox.shrink();

    final isNight = request.wantedType == 'night_dedicated';
    final hasNight = state.lastClosedRequests.any(
      (r) => r.wantedType == 'night_dedicated',
    );
    final hasNonNight = state.lastClosedRequests.any(
      (r) => r.wantedType != 'night_dedicated',
    );
    final shiftTypesAsync = ref.watch(
      _requestWidgetsShiftTypesProvider(teamId),
    );
    final shiftTypeMap = {
      for (final t in (shiftTypesAsync.valueOrNull ?? [])) t.id: t,
    };

    // 팀원별 엔트리 그루핑
    final groupedByUser = <String, WantedRequestUserEntryGroup>{};
    for (final ew in state.lastClosedEntries) {
      final uid = ew.entry.userId;
      groupedByUser.putIfAbsent(
        uid,
        () => WantedRequestUserEntryGroup(
          userId: uid,
          displayName: ew.displayName,
          items: [],
        ),
      );
      groupedByUser[uid]!.items.add(
        WantedEntryDisplayItem(
          date: ew.entry.wantedDate,
          priority: ew.entry.priority,
          shiftTypeId: ew.entry.shiftTypeId,
          reason: ew.entry.reason,
        ),
      );
    }
    for (final g in groupedByUser.values) {
      g.items.sort((a, b) => a.date.compareTo(b.date));
    }
    final userGroups = groupedByUser.values.toList();
    final closedGroupSeed = userGroups.map((g) => g.userId).join(',');
    final expandedClosedUserIds = useState<Set<String>>(
      userGroups.map((g) => g.userId).toSet(),
    );
    useEffect(() {
      expandedClosedUserIds.value = userGroups.map((g) => g.userId).toSet();
      return null;
    }, [closedGroupSeed, isNight]);

    // 엔트리 칩 빌더
    Widget entryChip(WantedEntryDisplayItem item) {
      final Color chipColor;
      final String avatarLabel;
      if (!isNight) {
        final st = item.shiftTypeId != null
            ? shiftTypeMap[item.shiftTypeId]
            : null;
        chipColor = st != null ? parseHexColor(st.color) : AppColors.shiftOff;
        avatarLabel = st?.code ?? 'O';
      } else {
        chipColor = item.priority == 1
            ? AppColors.error
            : item.priority == 2
            ? AppColors.brandOrange
            : AppColors.success;
        avatarLabel = '${item.priority}';
      }
      final chip = WantedEntryPill(
        color: chipColor,
        avatarLabel: avatarLabel,
        label: Text(
          !isNight
              ? '${DateFormat('MM.dd').format(item.date)} · ${item.priority}순위'
              : DateFormat('MM.dd').format(item.date),
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      );
      final hasReason = item.reason != null && item.reason!.isNotEmpty;
      if (!hasReason) return chip;
      return WantedReasonChip(chip: chip, reason: item.reason!);
    }

    // 타입 전환 칩
    Widget typeChips() => (hasNight && hasNonNight)
        ? Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Center(
              child: WantedModeTabs(
                isNight: isNight,
                onWanted: () => ref
                    .read(wantedAdminViewModelProvider(teamId).notifier)
                    .selectClosedType('day_off'),
                onNight: () => ref
                    .read(wantedAdminViewModelProvider(teamId).notifier)
                    .selectClosedType('night_dedicated'),
              ),
            ),
          )
        : const SizedBox.shrink();

    // 마감 배너
    Widget closedBanner() => Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.lg,
        AppSpacing.xxl,
        AppSpacing.xxl,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _WantedStatusPill(
            label: '수집 마감',
            color: colorScheme.onSurfaceVariant,
            icon: Icons.check_circle_outline,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            isNight ? '나이트 전담 수집 결과' : '원티드 수집 결과',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${DateFormat('yyyy.MM.dd').format(request.periodStart)} ~ '
            '${DateFormat('yyyy.MM.dd').format(request.periodEnd)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _WantedMetricChip(
                icon: Icons.groups_rounded,
                label: '${userGroups.length}명 응답',
              ),
              _WantedMetricChip(
                icon: Icons.checklist_rounded,
                label: '${state.lastClosedEntries.length}건',
              ),
            ],
          ),
        ],
      ),
    );

    // 하단 버튼 영역 (수집 재개 + 새 수집 시작)
    Widget bottomButtons() => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 수집 재개
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final picked = await _showWantedReopenSheet(context);
                  if (picked == null || !context.mounted) return;
                  final ok = await ref
                      .read(wantedAdminViewModelProvider(teamId).notifier)
                      .reopenRequests(deadline: picked);
                  if (!ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('수집 재개 중 오류가 발생했습니다')),
                    );
                  }
                },
                icon: const Icon(Icons.replay),
                label: const Text('수집 재개'),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            // 새 수집 시작
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => ref
                    .read(wantedAdminViewModelProvider(teamId).notifier)
                    .startNewCollection(),
                icon: const Icon(Icons.add),
                label: const Text('새 수집 시작'),
              ),
            ),
          ],
        ),
      ),
    );

    // 엔트리 목록 (모바일 기준)
    Widget entryList() => state.lastClosedEntries.isEmpty
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.inbox_outlined,
                  size: 48,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  '수집된 원티드가 없습니다',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          )
        : ListView.builder(
            padding: AppSpacing.screenAll,
            itemCount: userGroups.length,
            itemBuilder: (context, index) {
              final group = userGroups[index];
              final isExpanded = expandedClosedUserIds.value.contains(
                group.userId,
              );
              final closedInitial = group.displayName.isNotEmpty
                  ? group.displayName[0].toUpperCase()
                  : '?';
              return Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                elevation: 0,
                color: colorScheme.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.borderRadiusLg,
                  side: BorderSide(color: colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: AppRadius.borderRadiusMd,
                        ),
                        child: InkWell(
                          borderRadius: AppRadius.borderRadiusMd,
                          onTap: () {
                            final next = Set<String>.from(
                              expandedClosedUserIds.value,
                            );
                            if (isExpanded) {
                              next.remove(group.userId);
                            } else {
                              next.add(group.userId);
                            }
                            expandedClosedUserIds.value = next;
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor:
                                      colorScheme.surfaceContainerHigh,
                                  child: Text(
                                    closedInitial,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Text(
                                    group.displayName,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                if (!isNight)
                                  Text(
                                    '${group.items.length}건',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                const SizedBox(width: AppSpacing.xs),
                                Icon(
                                  isExpanded
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      AnimatedCrossFade(
                        firstChild: const SizedBox.shrink(),
                        secondChild: Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.md),
                          child: isNight
                              ? Chip(
                                  label: Text(
                                    '${dateFormat.format(request.periodStart)} ~ ${dateFormat.format(request.periodEnd)}',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  backgroundColor:
                                      colorScheme.surfaceContainerHigh,
                                  side: BorderSide(
                                    color: colorScheme.outlineVariant,
                                  ),
                                  padding: EdgeInsets.zero,
                                )
                              : Wrap(
                                  spacing: AppSpacing.sm,
                                  runSpacing: AppSpacing.sm,
                                  children: group.items.map(entryChip).toList(),
                                ),
                        ),
                        crossFadeState: isExpanded
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        duration: const Duration(milliseconds: 180),
                      ),
                    ],
                  ),
                ),
              );
            },
          );

    return Column(
      children: [
        closedBanner(),
        typeChips(),
        if (isNight)
          Expanded(
            child: _NightDedicatedSelector(
              teamId: teamId,
              entries: state.lastClosedEntries,
              isActive: false,
            ),
          )
        else
          Expanded(child: entryList()),
        bottomButtons(),
      ],
    );
  }
}

/// 나이트 전담 신청자 목록에서 관리자가 확정할 인원을 선택하는 위젯
class _NightDedicatedSelector extends HookConsumerWidget {
  const _NightDedicatedSelector({
    required this.teamId,
    required this.entries,
    required this.isActive,
    this.footerButton,
  });

  final String teamId;
  final List<WantedEntryWithUser> entries;
  final Widget? footerButton;

  /// true: 활성 수집 중 (수집 마감 버튼도 표시), false: 마감 후 결과 보기
  final bool isActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final membersAsync = ref.watch(_requestWidgetsTeamMembersProvider(teamId));

    // 신청자 목록 (userId → displayName, 중복 제거)
    final applicantsMap = <String, String>{};
    for (final ew in entries) {
      applicantsMap[ew.entry.userId] = ew.displayName;
    }
    final applicantIds = applicantsMap.keys.toList();
    final applicantIdSet = applicantIds.toSet();

    final approvedByDb = membersAsync.maybeWhen(
      data: (members) => members
          .where(
            (m) => applicantIdSet.contains(m.userId) && m.member.nightDedicated,
          )
          .map((m) => m.userId)
          .toSet(),
      orElse: () => <String>{},
    );
    final hasExistingApproval = approvedByDb.isNotEmpty;
    final approvedStatusMap = {
      for (final id in applicantIds) id: approvedByDb.contains(id),
    };
    final loadedFromDb = membersAsync.maybeWhen(
      data: (_) => true,
      orElse: () => false,
    );

    final initialSelected = hasExistingApproval
        ? approvedByDb
        : Set<String>.from(applicantIds);
    final seedApplicants = [...applicantIds]..sort();
    final seedApproved = [...approvedByDb]..sort();
    final initSeed =
        '${seedApplicants.join(",")}|${seedApproved.join(",")}|$hasExistingApproval';

    // 선택된 userId Set (기본: 전체 선택, 기존 확정 상태가 있으면 해당 상태로 초기화)
    final selected = useState<Set<String>>(initialSelected);
    useEffect(() {
      selected.value = Set<String>.from(initialSelected);
      return null;
    }, [initSeed]);
    final isConfirming = useState(false);

    if (applicantIds.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.nightlight_round,
              size: 48,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '나이트 전담 신청자가 없습니다',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    final approvedCount = selected.value.length;
    final totalCount = applicantIds.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 안내 배너
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF0061A4).withValues(alpha: 0.08),
            borderRadius: AppRadius.borderRadiusMd,
            border: Border.all(
              color: const Color(0xFF0061A4).withValues(alpha: 0.14),
            ),
          ),
          child: Builder(builder: (context) {
            // 다크모드에서는 대비를 위해 밝은 블루를 쓴다.
            final nightInk = colorScheme.brightness == Brightness.dark
                ? const Color(0xFF7FB7E8)
                : const Color(0xFF0061A4);
            return Row(
              children: [
                Icon(
                  Icons.nightlight_round,
                  size: 16,
                  color: nightInk,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    hasExistingApproval
                        ? '기존 확정 상태를 불러왔습니다.\n체크를 변경해 나이트 전담 인원을 수정할 수 있습니다.'
                        : '확정할 나이트 전담 인원을 선택하세요.\n선택된 인원의 나이트 전담 속성이 활성화됩니다.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: nightInk,
                    ),
                  ),
                ),
              ],
            );
          }),
        ),

        // 전체 선택 / 카운터
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: AppRadius.borderRadiusMd,
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Row(
              children: [
                Text(
                  '$approvedCount명 ${hasExistingApproval ? '선택됨' : '확정 예정'} / 전체 $totalCount명',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    if (selected.value.length == totalCount) {
                      selected.value = {};
                    } else {
                      selected.value = Set.from(applicantIds);
                    }
                  },
                  child: Text(
                    selected.value.length == totalCount ? '전체 해제' : '전체 선택',
                  ),
                ),
              ],
            ),
          ),
        ),

        // 신청자 체크박스 목록
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            itemCount: applicantIds.length,
            itemBuilder: (context, index) {
              final uid = applicantIds[index];
              final name = applicantsMap[uid]!;
              final isChecked = selected.value.contains(uid);

              return Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                elevation: 0,
                color: colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.borderRadiusMd,
                  side: BorderSide(color: colorScheme.outlineVariant),
                ),
                child: CheckboxListTile(
                  value: isChecked,
                  onChanged: (_) {
                    final next = Set<String>.from(selected.value);
                    if (isChecked) {
                      next.remove(uid);
                    } else {
                      next.add(uid);
                    }
                    selected.value = next;
                  },
                  title: Text(
                    name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: loadedFromDb
                      ? Text(
                          approvedStatusMap[uid] == true ? '현재 확정됨' : '현재 미확정',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        )
                      : null,
                  secondary: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isChecked
                          ? const Color(0xFF0061A4).withValues(alpha: 0.12)
                          : colorScheme.surfaceContainerHigh,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.nightlight_round,
                      size: 18,
                      color: isChecked
                          ? const Color(0xFF0061A4)
                          : colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    ),
                  ),
                  activeColor: const Color(0xFF0061A4),
                  checkColor: Colors.white,
                  controlAffinity: ListTileControlAffinity.trailing,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                ),
              );
            },
          ),
        ),

        // 확정 버튼
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0061A4),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: isConfirming.value
                        ? null
                        : () async {
                            final confirm = await showMoniqConfirmSheet(
                              context: context,
                              title: hasExistingApproval
                                  ? '나이트 전담 수정'
                                  : '나이트 전담 확정',
                              message: selected.value.isEmpty
                                  ? '선택된 인원이 없습니다. 모든 신청자의 나이트 전담을 해제하시겠습니까?'
                                  : '${selected.value.length}명을 나이트 전담으로 ${hasExistingApproval ? '수정' : '확정'}하시겠습니까?\n'
                                        '선택하지 않은 인원은 나이트 전담이 자동으로 해제됩니다.',
                              confirmLabel: hasExistingApproval ? '수정' : '확정',
                            );
                            if (confirm != true) return;
                            isConfirming.value = true;
                            final ok = await ref
                                .read(
                                  wantedAdminViewModelProvider(teamId).notifier,
                                )
                                .confirmNightDedicated(
                                  approvedUserIds: selected.value.toList(),
                                  allApplicantUserIds: applicantIds,
                                );
                            isConfirming.value = false;
                            if (ok && context.mounted) {
                              ref.invalidate(
                                _requestWidgetsTeamMembersProvider(teamId),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    hasExistingApproval
                                        ? '나이트 전담이 수정되었습니다'
                                        : '나이트 전담이 확정되었습니다',
                                  ),
                                ),
                              );
                            }
                          },
                    icon: isConfirming.value
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.nightlight_round),
                    label: Text(
                      isConfirming.value
                          ? '처리 중...'
                          : '나이트 전담 ${hasExistingApproval ? '수정' : '확정'} ($approvedCount명)',
                    ),
                  ),
                ),
                if (footerButton != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  footerButton!,
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class WantedEntryDisplayItem {
  const WantedEntryDisplayItem({
    required this.date,
    this.priority = 1,
    this.shiftTypeId,
    this.reason,
  });
  final DateTime date;
  final int priority;
  final String? shiftTypeId;
  final String? reason;
}

class WantedRequestUserEntryGroup {
  WantedRequestUserEntryGroup({
    required this.userId,
    required this.displayName,
    required this.items,
  });
  final String userId;
  final String displayName;
  final List<WantedEntryDisplayItem> items;
}

class WantedEntryPill extends StatelessWidget {
  const WantedEntryPill({
    super.key,
    required this.color,
    required this.avatarLabel,
    required this.label,
  });

  final Color color;
  final String avatarLabel;
  final Widget label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 36,
      padding: const EdgeInsets.fromLTRB(2, 2, AppSpacing.md, 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: AppRadius.borderRadiusFull,
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.22),
              shape: BoxShape.circle,
            ),
            child: Text(
              avatarLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          label,
        ],
      ),
    );
  }
}

class WantedModeTabs extends StatelessWidget {
  const WantedModeTabs({
    super.key,
    required this.isNight,
    required this.onWanted,
    required this.onNight,
  });

  final bool isNight;
  final VoidCallback onWanted;
  final VoidCallback onNight;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: AppRadius.borderRadiusFull,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _WantedModeTabButton(
            label: '원티드',
            icon: Icons.check_rounded,
            selected: !isNight,
            onTap: onWanted,
          ),
          const SizedBox(width: AppSpacing.xs),
          _WantedModeTabButton(
            label: '나이트 전담',
            icon: Icons.nightlight_round,
            selected: isNight,
            onTap: onNight,
          ),
        ],
      ),
    );
  }
}

class _WantedModeTabButton extends StatelessWidget {
  const _WantedModeTabButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final foreground = selected
        ? AppColors.onPrimaryContainer
        : colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.borderRadiusFull,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryContainer : Colors.transparent,
          borderRadius: AppRadius.borderRadiusFull,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: foreground),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WantedStatusPill extends StatelessWidget {
  const _WantedStatusPill({
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: AppRadius.borderRadiusFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: color),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _WantedMissingMembersSheet extends StatefulWidget {
  const _WantedMissingMembersSheet({
    required this.teamId,
    required this.teamName,
    required this.request,
    required this.missingMembers,
  });

  final String teamId;
  final String teamName;
  final WantedRequestModel request;
  final List<TeamMemberWithUser> missingMembers;

  @override
  State<_WantedMissingMembersSheet> createState() =>
      _WantedMissingMembersSheetState();
}

class _WantedMissingMembersSheetState
    extends State<_WantedMissingMembersSheet> {
  bool _isSending = false;

  Future<void> _sendReminder() async {
    if (_isSending || widget.missingMembers.isEmpty) return;
    setState(() => _isSending = true);

    await PushService.instance.sendToUsers(
      userIds: widget.missingMembers.map((member) => member.userId).toList(),
      title: '원티드 입력 요청',
      body: '${widget.teamName} 원티드 수집에 아직 응답하지 않았습니다. 마감 전 입력해주세요.',
      data: {
        'type': 'wanted_request',
        'teamId': widget.teamId,
        'requestId': widget.request.id,
      },
    );

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isSending = false);
    Navigator.of(context).pop();
    messenger.showSnackBar(const SnackBar(content: Text('미응답자에게 알림을 보냈습니다')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dateFormat = DateFormat('yyyy.MM.dd');
    final deadline = widget.request.deadline;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          deadline == null
              ? '아직 응답하지 않은 팀원입니다.'
              : '마감 ${dateFormat.format(deadline)} 전까지 입력이 필요합니다.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (widget.missingMembers.isEmpty)
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.successLight.withValues(alpha: 0.45),
              borderRadius: AppRadius.borderRadiusMd,
            ),
            child: Text(
              '모든 팀원이 응답했습니다',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.success,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: widget.missingMembers.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.xs),
              itemBuilder: (context, index) {
                final member = widget.missingMembers[index];
                final initial = member.displayName.isNotEmpty
                    ? member.displayName[0]
                    : '?';
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLowest,
                    borderRadius: AppRadius.borderRadiusMd,
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: colorScheme.primary.withValues(
                          alpha: 0.14,
                        ),
                        child: Text(
                          initial,
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          member.displayName,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton.icon(
          onPressed: widget.missingMembers.isEmpty || _isSending
              ? null
              : _sendReminder,
          icon: _isSending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.notifications_active_outlined),
          label: Text(
            _isSending
                ? '알림 보내는 중...'
                : '미응답자에게 알림 보내기 (${widget.missingMembers.length}명)',
          ),
        ),
      ],
    );
  }
}

class _WantedMetricChip extends StatelessWidget {
  const _WantedMetricChip({
    required this.icon,
    required this.label,
    this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final resolvedColor = color ?? colorScheme.onSurfaceVariant;

    final chip = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: AppRadius.borderRadiusFull,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: resolvedColor),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: resolvedColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return chip;

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.borderRadiusFull,
      child: chip,
    );
  }
}

Future<DateTime?> _showWantedReopenSheet(BuildContext context) {
  final now = DateTime.now();
  final minDate = DateTime(now.year, now.month, now.day);
  final maxDate = DateTime(now.year + 1, now.month, now.day);
  final initialDate = minDate.add(const Duration(days: 7));

  return showMoniqBottomSheet<DateTime>(
    context: context,
    title: '수집 재개',
    eyebrow: 'REOPEN',
    child: _WantedReopenSheetBody(
      initialDate: initialDate,
      minDate: minDate,
      maxDate: maxDate,
    ),
  );
}

class _WantedReopenSheetBody extends StatefulWidget {
  const _WantedReopenSheetBody({
    required this.initialDate,
    required this.minDate,
    required this.maxDate,
  });

  final DateTime initialDate;
  final DateTime minDate;
  final DateTime maxDate;

  @override
  State<_WantedReopenSheetBody> createState() => _WantedReopenSheetBodyState();
}

class _WantedReopenSheetBodyState extends State<_WantedReopenSheetBody> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dateLabel = DateFormat('yyyy.MM.dd (E)').format(_selectedDate);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '마감된 수집을 다시 열어 팀원이 입력할 수 있도록 합니다.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLowest,
            borderRadius: AppRadius.borderRadiusMd,
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Text(
                '새 마감일',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                dateLabel,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        ClipRRect(
          borderRadius: AppRadius.borderRadiusMd,
          child: Container(
            height: 220,
            color: colorScheme.surfaceContainerLowest,
            child: CupertinoTheme(
              data: CupertinoThemeData(
                brightness: theme.brightness,
                primaryColor: colorScheme.primary,
              ),
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: _selectedDate,
                minimumDate: widget.minDate,
                maximumDate: widget.maxDate,
                onDateTimeChanged: (value) {
                  setState(() {
                    _selectedDate = DateTime(
                      value.year,
                      value.month,
                      value.day,
                    );
                  });
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.borderRadiusFull,
                    ),
                    side: BorderSide(color: colorScheme.outlineVariant),
                  ),
                  child: const Text('취소'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, _selectedDate),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.borderRadiusFull,
                    ),
                  ),
                  child: const Text('재개'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── reason helpers ───────────────────────────────────────────────────────────

/// 시스템 reason 태그를 사람이 읽기 좋은 레이블로 변환한다.
String _reasonDisplayLabel(String reason) {
  switch (reason) {
    case '#생리휴가':
      return '생리휴가';
    case '#연차':
      return '연차';
    case '#필수교육':
      return '필수교육';
    default:
      return reason;
  }
}

/// 사유가 있는 원티드 칩을 탭하면 칩 근처에 작은 툴팁 카드를 띄운다.
///
/// AlertDialog 대신 OverlayEntry + CompositedTransformFollower를 사용해
/// 칩 바로 아래에 인라인 카드를 표시한다. 외부 탭 시 자동으로 닫힌다.
class WantedReasonChip extends StatefulWidget {
  const WantedReasonChip({super.key, required this.chip, required this.reason});

  /// 실제로 렌더링할 Chip 위젯
  final Widget chip;

  /// 원시 reason 문자열 (레이블 변환은 내부에서 처리)
  final String reason;

  @override
  State<WantedReasonChip> createState() => _WantedReasonChipState();
}

class _WantedReasonChipState extends State<WantedReasonChip> {
  final _link = LayerLink();
  OverlayEntry? _entry;

  void _show() {
    if (_entry != null) {
      _hide();
      return;
    }
    final label = _reasonDisplayLabel(widget.reason);
    final overlay = Overlay.of(context);
    _entry = OverlayEntry(
      builder: (_) =>
          _ReasonOverlay(link: _link, label: label, onDismiss: _hide),
    );
    overlay.insert(_entry!);
  }

  void _hide() {
    _entry?.remove();
    _entry = null;
  }

  @override
  void dispose() {
    _hide();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: GestureDetector(onTap: _show, child: widget.chip),
    );
  }
}

/// 칩 아래에 위치하는 오버레이 카드.
///
/// 배경 배리어를 탭하면 [onDismiss]를 호출한다.
class _ReasonOverlay extends StatelessWidget {
  const _ReasonOverlay({
    required this.link,
    required this.label,
    required this.onDismiss,
  });

  final LayerLink link;
  final String label;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Stack(
      children: [
        // 배경 배리어: 탭하면 닫힘
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: onDismiss,
            child: const SizedBox.expand(),
          ),
        ),
        // 칩 아래 카드
        CompositedTransformFollower(
          link: link,
          showWhenUnlinked: false,
          offset: const Offset(0, 28),
          child: Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              color: colorScheme.surfaceContainerHigh,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      label,
                      style: textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class WantedRequestDatePickerRow extends StatelessWidget {
  const WantedRequestDatePickerRow({
    super.key,
    required this.label,
    this.date,
    required this.dateFormat,
    required this.onTap,
  });

  final String label;
  final DateTime? date;
  final DateFormat dateFormat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Row(
            children: [
              Text(
                date != null ? dateFormat.format(date!) : '선택',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(Icons.calendar_today, size: 18, color: colorScheme.primary),
            ],
          ),
        ],
      ),
    );
  }
}
