import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moniq/core/utils/color_utils.dart';
import 'package:moniq/data/models/shift_type_model.dart';
import 'package:moniq/data/models/team_member_with_user.dart';
import 'package:moniq/data/models/wanted_request_model.dart';
import 'package:moniq/data/providers/shift_providers.dart';
import 'package:moniq/data/providers/team_providers.dart';
import 'package:moniq/presentation/layout/adaptive_layout.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/wanted_viewmodel.dart';

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
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _periodStart ?? DateTime.now(),
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
                        final picked = await showDatePicker(
                          context: context,
                          initialDate:
                              _periodEnd ??
                              (_periodStart ?? DateTime.now()).add(
                                const Duration(days: 30),
                              ),
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
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _deadline ?? DateTime.now(),
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
    if (request == null) return const Center(child: CircularProgressIndicator());
    final isNight = request.wantedType == 'night_dedicated';

    // 근무 유형 맵
    final shiftTypesAsync = ref.watch(
      _requestWidgetsShiftTypesProvider(teamId),
    );
    final shiftTypeMap = {
      for (final t in (shiftTypesAsync.valueOrNull ?? [])) t.id: t,
    };

    // 팀원별 엔트리 그루핑
    final groupedByUser = <String, WantedRequestUserEntryGroup>{};
    for (final ew in state.allEntries) {
      final uid = ew.entry.userId;
      groupedByUser.putIfAbsent(
        uid,
        () =>
            WantedRequestUserEntryGroup(displayName: ew.displayName, items: []),
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
      final chip = Chip(
        avatar: CircleAvatar(
          backgroundColor: chipColor.withValues(alpha: 0.25),
          child: Text(
            avatarLabel,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: chipColor,
            ),
          ),
        ),
        label: Text(
          '${dateFormat.format(item.date)} · ${item.priority}순위',
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        visualDensity: VisualDensity.compact,
        backgroundColor: chipColor.withValues(alpha: 0.08),
        side: BorderSide(color: chipColor.withValues(alpha: 0.2)),
        padding: EdgeInsets.zero,
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
            child: Wrap(
              spacing: AppSpacing.sm,
              children: [
                ChoiceChip(
                  label: const Text('원티드'),
                  selected: !isNight,
                  onSelected: (_) => ref
                      .read(wantedAdminViewModelProvider(teamId).notifier)
                      .selectType('day_off'),
                ),
                ChoiceChip(
                  label: const Text('나이트 전담'),
                  selected: isNight,
                  onSelected: (_) => ref
                      .read(wantedAdminViewModelProvider(teamId).notifier)
                      .selectType('night_dedicated'),
                ),
              ],
            ),
          )
        : const SizedBox.shrink();

    // 상태 배너 (공통)
    Widget statusBanner() => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      color: colorScheme.primary.withValues(alpha: 0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.brandOrange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  border: Border.all(
                    color: AppColors.brandOrange.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 8, color: AppColors.brandOrange),
                    const SizedBox(width: 4),
                    Text(
                      '수집 중',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandOrange,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (request.deadline != null)
                Text(
                  dDayText(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '원티드 수집 진행 중',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${dateFormat.format(request.periodStart)} ~ '
            '${dateFormat.format(request.periodEnd)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          if (request.deadline != null) ...[
            const SizedBox(height: 2),
            Text(
              '마감: ${DateFormat('yyyy.MM.dd').format(request.deadline!)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(Icons.people_outline, size: 14, color: colorScheme.primary),
              const SizedBox(width: 4),
              Text(
                '${userGroups.length}명 응답 · ${state.allEntries.length}건',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    // 하단 버튼 (공통)
    Widget bottomButtons() => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.errorContainer,
              foregroundColor: colorScheme.onErrorContainer,
            ),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('수집 마감'),
                  content: const Text('원티드 수집을 마감하시겠습니까?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('취소'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('마감'),
                    ),
                  ],
                ),
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
        ),
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

                        final initial = group.displayName.isNotEmpty
                            ? group.displayName[0].toUpperCase()
                            : '?';
                        return Card(
                          margin: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: colorScheme.primary
                                          .withValues(alpha: 0.12),
                                      child: Text(
                                        initial,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.md),
                                    Expanded(
                                      child: Text(
                                        group.displayName,
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                    Text(
                                      '${group.items.length}건',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: colorScheme.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.md),
                                Wrap(
                                  spacing: AppSpacing.sm,
                                  runSpacing: AppSpacing.sm,
                                  children: group.items.map(entryChip).toList(),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),

        bottomButtons(),
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
        () =>
            WantedRequestUserEntryGroup(displayName: ew.displayName, items: []),
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
      final chip = Chip(
        avatar: CircleAvatar(
          backgroundColor: chipColor.withValues(alpha: 0.25),
          child: Text(
            avatarLabel,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: chipColor,
            ),
          ),
        ),
        label: Text(
          !isNight
              ? '${DateFormat('MM.dd').format(item.date)} · ${item.priority}순위'
              : DateFormat('MM.dd').format(item.date),
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        visualDensity: VisualDensity.compact,
        backgroundColor: chipColor.withValues(alpha: 0.08),
        side: BorderSide(color: chipColor.withValues(alpha: 0.2)),
        padding: EdgeInsets.zero,
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
            child: Wrap(
              spacing: AppSpacing.sm,
              children: [
                ChoiceChip(
                  label: const Text('원티드'),
                  selected: !isNight,
                  onSelected: (_) => ref
                      .read(wantedAdminViewModelProvider(teamId).notifier)
                      .selectClosedType('day_off'),
                ),
                ChoiceChip(
                  label: const Text('나이트 전담'),
                  selected: isNight,
                  onSelected: (_) => ref
                      .read(wantedAdminViewModelProvider(teamId).notifier)
                      .selectClosedType('night_dedicated'),
                ),
              ],
            ),
          )
        : const SizedBox.shrink();

    // 마감 배너
    Widget closedBanner() => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      color: colorScheme.surfaceContainerHigh,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  border: Border.all(
                    color: colorScheme.outline.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 10,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '수집 마감',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            isNight ? '나이트 전담 수집 결과' : '원티드 수집 결과',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${dateFormat.format(request.periodStart)} ~ '
            '${dateFormat.format(request.periodEnd)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(
                Icons.people_outline,
                size: 14,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                '${userGroups.length}명 응답 · ${state.lastClosedEntries.length}건',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
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
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('수집 재개'),
                      content: const Text(
                        '마감된 수집을 다시 열어 팀원이 입력할 수 있도록 합니다.\n계속하시겠습니까?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('취소'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('재개'),
                        ),
                      ],
                    ),
                  );
                  if (confirm != true) return;
                  final ok = await ref
                      .read(wantedAdminViewModelProvider(teamId).notifier)
                      .reopenRequests();
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
              final closedInitial = group.displayName.isNotEmpty
                  ? group.displayName[0].toUpperCase()
                  : '?';
              return Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: colorScheme.surfaceContainerHigh,
                            child: Text(
                              closedInitial,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              group.displayName,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (!isNight)
                            Text(
                              '${group.items.length}건',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      isNight
                          ? Chip(
                              label: Text(
                                '${dateFormat.format(request.periodStart)} ~ ${dateFormat.format(request.periodEnd)}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              visualDensity: VisualDensity.compact,
                              backgroundColor: colorScheme.surfaceContainerHigh,
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
  });

  final String teamId;
  final List<WantedEntryWithUser> entries;

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
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          color: const Color(0xFF0061A4).withValues(alpha: 0.08),
          child: Row(
            children: [
              Icon(
                Icons.nightlight_round,
                size: 16,
                color: const Color(0xFF0061A4),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  hasExistingApproval
                      ? '기존 확정 상태를 불러왔습니다.\n체크를 변경해 나이트 전담 인원을 수정할 수 있습니다.'
                      : '확정할 나이트 전담 인원을 선택하세요.\n선택된 인원의 나이트 전담 속성이 활성화됩니다.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF0061A4),
                  ),
                ),
              ),
            ],
          ),
        ),

        // 전체 선택 / 카운터
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Text(
                '$approvedCount명 ${hasExistingApproval ? '선택됨' : '확정 예정'} / 전체 $totalCount명',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
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

        const Divider(height: 1),

        // 신청자 체크박스 목록
        Expanded(
          child: ListView.builder(
            itemCount: applicantIds.length,
            itemBuilder: (context, index) {
              final uid = applicantIds[index];
              final name = applicantsMap[uid]!;
              final isChecked = selected.value.contains(uid);

              return CheckboxListTile(
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
                    fontWeight: FontWeight.w500,
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
                  width: 36,
                  height: 36,
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
              );
            },
          ),
        ),

        // 확정 버튼
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0061A4),
                  foregroundColor: Colors.white,
                ),
                onPressed: isConfirming.value
                    ? null
                    : () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text(
                              hasExistingApproval ? '나이트 전담 수정' : '나이트 전담 확정',
                            ),
                            content: Text(
                              selected.value.isEmpty
                                  ? '선택된 인원이 없습니다. 모든 신청자의 나이트 전담을 해제하시겠습니까?'
                                  : '${selected.value.length}명을 나이트 전담으로 ${hasExistingApproval ? '수정' : '확정'}하시겠습니까?\n'
                                        '(나머지 ${totalCount - selected.value.length}명은 해제됩니다)',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('취소'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: Text(hasExistingApproval ? '수정' : '확정'),
                              ),
                            ],
                          ),
                        );
                        if (confirm != true) return;
                        isConfirming.value = true;
                        final ok = await ref
                            .read(wantedAdminViewModelProvider(teamId).notifier)
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
  WantedRequestUserEntryGroup({required this.displayName, required this.items});
  final String displayName;
  final List<WantedEntryDisplayItem> items;
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
  const WantedReasonChip({
    super.key,
    required this.chip,
    required this.reason,
  });

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
      builder: (_) => _ReasonOverlay(
        link: _link,
        label: label,
        onDismiss: _hide,
      ),
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
      child: GestureDetector(
        onTap: _show,
        child: widget.chip,
      ),
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
