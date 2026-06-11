import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moniq/core/utils/color_utils.dart';
import 'package:moniq/data/datasources/push_service.dart';
import 'package:moniq/data/models/roster_entry.dart';
import 'package:moniq/data/models/shift_type_model.dart';
import 'package:moniq/data/models/user_model.dart';
import 'package:moniq/data/providers/auth_providers.dart';
import 'package:moniq/data/providers/request_providers.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/request_viewmodel.dart';
import 'package:moniq/presentation/screens/calendar/calendar_providers.dart';
import 'package:moniq/presentation/viewmodels/team_calendar_viewmodel.dart';
import 'package:moniq/presentation/viewmodels/team_detail_viewmodel.dart';
import 'package:moniq/presentation/widgets/calendar/shift_member_group_block.dart';
import 'package:moniq/presentation/widgets/common/moniq_bottom_sheet.dart';

class RosterPanel extends ConsumerWidget {
  const RosterPanel({
    super.key,
    required this.date,
    required this.rosterEntries,
    this.teamId,
  });

  final DateTime date;
  final List<RosterEntry> rosterEntries;
  final String? teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isExpanded = ref.watch(dateExpandedProvider);
    final hasItems = rosterEntries.isNotEmpty;

    return Padding(
      padding: AppSpacing.screenHorizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.md),
          // 개인 캘린더와 동일한 chevron pill 토글
          if (hasItems)
            Center(
              child: Material(
                color: theme.colorScheme.surfaceContainerHigh,
                shape: const StadiumBorder(),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: () => ref
                      .read(dateExpandedProvider.notifier)
                      .state = !isExpanded,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: 6,
                    ),
                    child: AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          if (!hasItems)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Center(
                child: Column(
                  children: [
                    SizedBox(
                      width: 72,
                      height: 72,
                      child: Image.asset(
                        'assets/images/off.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '이 날짜에 배정된 근무가 없습니다',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (isExpanded)
            // 개인 팀 day detail과 동일한 카드 + 좁은 행 간격(xs).
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: AppRadius.borderRadiusLg,
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.shadow.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Builder(
                builder: (context) {
                  final sorted = _sortedRoster(rosterEntries);
                  return Column(
                    children: [
                      for (var i = 0; i < sorted.length; i++) ...[
                        _ShiftTypeGroup(
                          entry: sorted[i],
                          date: date,
                          teamId: teamId,
                          allEntries: rosterEntries,
                        ),
                        if (i < sorted.length - 1)
                          const SizedBox(height: AppSpacing.xs),
                      ],
                    ],
                  );
                },
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

/// 데이 → 이브닝 → 나이트 → 기타 순서로 RosterEntry 정렬
List<RosterEntry> _sortedRoster(List<RosterEntry> entries) {
  int sortKey(RosterEntry e) {
    final c = e.shiftType.code.toUpperCase();
    final n = e.shiftType.name;
    if (c == 'D' || n.contains('데이') || n.toLowerCase().contains('day')) {
      return 0;
    }
    if (c == 'E' || n.contains('이브닝') || n.toLowerCase().contains('eve')) {
      return 1;
    }
    if (c == 'N' || n.contains('나이트') || n.toLowerCase().contains('night')) {
      return 2;
    }
    if (c == 'OFF' || n.toLowerCase() == 'off') return 9;
    return 3;
  }
  final sorted = [...entries]..sort((a, b) => sortKey(a).compareTo(sortKey(b)));
  return sorted;
}

class _SwapCandidate {
  _SwapCandidate({
    required this.worker,
    required this.shiftType,
    required this.isDifferentType,
  });
  final RosterWorker worker;
  final ShiftTypeModel shiftType;
  final bool isDifferentType;
}

class _ShiftTypeGroup extends ConsumerWidget {
  const _ShiftTypeGroup({
    required this.entry,
    required this.date,
    this.teamId,
    required this.allEntries,
  });

  final RosterEntry entry;
  final DateTime date;
  final String? teamId;
  final List<RosterEntry> allEntries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = parseHexColor(entry.shiftType.color);
    final currentUser = ref.watch(currentUserProvider);
    final myUserId = currentUser?.id;
    final isAdmin = teamId != null
        ? (ref
                .watch(teamDetailViewModelProvider(teamId!))
                .valueOrNull
                ?.isAdmin ??
            false)
        : false;
    final isOff = entry.shiftType.code.toUpperCase() == 'OFF';

    // 개인 팀과 동일한 간결 레이아웃 — 칩은 기본 한 줄, 넘치면 +N으로 펼침.
    // 칩 탭 시 기존 근무 교환/수정/요청 흐름은 그대로 유지한다.
    // 행 간격은 바깥 Column에서 처리(개인 팀과 동일).
    return ShiftMemberGroupBlock(
      code: isOff ? null : entry.shiftType.code,
      label: entry.shiftType.name,
      color: color,
      members: [
        for (final worker in entry.workers)
          ShiftMemberChipData(
            // '(나)' 접미사는 제거하되, 본인 강조(색)는 유지.
            displayName: worker.user.displayName ?? worker.user.email,
            avatarUrl: worker.user.avatarUrl,
            highlighted: worker.user.id == myUserId,
            onTap: teamId == null
                ? null
                : () => _onWorkerTap(
                      context,
                      ref,
                      worker: worker,
                      isMe: worker.user.id == myUserId,
                      isAdmin: isAdmin,
                      color: color,
                    ),
          ),
      ],
    );
  }

  /// 근무자 칩 탭 — 본인/관리자 여부에 따라 수정·요청·교환 시트를 연다.
  void _onWorkerTap(
    BuildContext context,
    WidgetRef ref, {
    required RosterWorker worker,
    required bool isMe,
    required bool isAdmin,
    required Color color,
  }) {
    final name = worker.user.displayName ?? worker.user.email;
    // 본인 근무: 관리자면 직접 수정, 아니면 변경 요청 흐름
    if (isMe) {
      if (worker.shiftId != null) {
        if (isAdmin) {
          // 본인 근무도 팀원과 동일한 액션 시트로 통일하되, 교환 요청은 제외(isMe).
          _showAdminActionSheet(
            context,
            ref,
            shiftId: worker.shiftId!,
            targetUser: worker.user,
            targetName: name,
            targetShiftType: entry.shiftType.name,
            targetShiftColor: color,
            isMe: true,
          );
        } else {
          _showSelfRequestSheet(
            context,
            ref,
            shiftId: worker.shiftId!,
            workerName: name,
          );
        }
      } else {
        // OFF 상태 → 새 근무 추가 시트
        _showAddSelfShiftSheet(context, ref, workerName: name);
      }
      return;
    }
    if (isAdmin && worker.shiftId != null) {
      // 관리자: 수정 / 교환 선택 액션시트
      _showAdminActionSheet(
        context,
        ref,
        shiftId: worker.shiftId!,
        targetUser: worker.user,
        targetName: name,
        targetShiftType: entry.shiftType.name,
        targetShiftColor: color,
        isMe: isMe,
      );
    } else {
      _showSwapSheet(
        context,
        ref,
        targetUserId: worker.user.id,
        targetName: name,
        targetShiftType: entry.shiftType.name,
        targetShiftColor: color,
      );
    }
  }

  /// 관리자: 근무자 칩 탭 시 "근무 수정" + "근무 교환" 중 선택
  void _showAdminActionSheet(
    BuildContext context,
    WidgetRef ref, {
    required String shiftId,
    required UserModel targetUser,
    required String targetName,
    required String targetShiftType,
    required Color targetShiftColor,
    required bool isMe,
  }) {
    showMoniqBottomSheet<void>(
      context: context,
      eyebrow: 'ACTIONS',
      title: '근무 수정',
      child: Builder(
        builder: (ctx) {
          final cs = Theme.of(ctx).colorScheme;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 대상 근무자 컨텍스트
              Text(
                '$targetName · $targetShiftType',
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: AppSpacing.lg),
              // 근무 수정
              _AdminActionRow(
                icon: Icons.edit_outlined,
                label: '근무 수정',
                subLabel: '근무 유형 변경 또는 삭제 (관리자)',
                onTap: () {
                  Navigator.pop(ctx);
                  _showAdminEditSheet(
                    context,
                    ref,
                    shiftId: shiftId,
                    workerName: targetName,
                  );
                },
              ),
              // 근무 교환 (본인 제외)
              if (!isMe) ...[
                const SizedBox(height: 6),
                _AdminActionRow(
                  icon: Icons.swap_horiz,
                  label: '근무 교환 요청',
                  subLabel: '본인 근무와 교환 요청 제출',
                  onTap: () {
                    Navigator.pop(ctx);
                    _showSwapSheet(
                      context,
                      ref,
                      targetUserId: targetUser.id,
                      targetName: targetName,
                      targetShiftType: targetShiftType,
                      targetShiftColor: targetShiftColor,
                    );
                  },
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  /// 본인 근무 탭 → 같은 날짜에 다른 유형으로 근무 중인 후보들을 정렬해 보여주는 시트.
  /// 후보를 누르면 기존 1:1 교환 요청 흐름으로 진입한다.
  void _showRecommendedSwapSheet(BuildContext context, WidgetRef ref) {
    final tid = teamId!;
    final myUserId = ref.read(currentUserProvider)?.id;
    final myShiftTypeId = entry.shiftType.id;
    final dateStr = DateFormat('M월 d일 (E)', 'ko_KR').format(date);

    // 후보: 같은 날짜의 모든 근무자 중 (a) 본인 제외 (b) 다른 shift_type을 우선
    final candidates = <_SwapCandidate>[];
    for (final e in allEntries) {
      for (final w in e.workers) {
        if (w.user.id == myUserId) continue;
        candidates.add(_SwapCandidate(
          worker: w,
          shiftType: e.shiftType,
          isDifferentType: e.shiftType.id != myShiftTypeId,
        ));
      }
    }
    // 정렬: 다른 유형 우선 → 이름순
    candidates.sort((a, b) {
      if (a.isDifferentType != b.isDifferentType) {
        return a.isDifferentType ? -1 : 1;
      }
      final an = a.worker.user.displayName ?? a.worker.user.email;
      final bn = b.worker.user.displayName ?? b.worker.user.email;
      return an.compareTo(bn);
    });

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
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
            Text('교환 후보 추천',
                style: Theme.of(ctx)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSpacing.sm),
            Text('$dateStr · 다른 유형 우선 정렬',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: AppColors.onSurfaceVariant,
                    )),
            const SizedBox(height: AppSpacing.lg),
            if (candidates.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Text(
                  '같은 날짜에 교환 가능한 다른 근무자가 없습니다',
                  style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                  textAlign: TextAlign.center,
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: candidates.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.xs),
                  itemBuilder: (lctx, i) {
                    final c = candidates[i];
                    final cColor = parseHexColor(c.shiftType.color);
                    final cName =
                        c.worker.user.displayName ?? c.worker.user.email;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: cColor,
                        child: Text(c.shiftType.code,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            )),
                      ),
                      title: Text(cName),
                      subtitle: Text(c.shiftType.name),
                      trailing: c.isDifferentType
                          ? const Icon(Icons.recommend,
                              color: AppColors.primary, size: 20)
                          : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        _showSwapSheet(
                          context,
                          ref,
                          targetUserId: c.worker.user.id,
                          targetName: cName,
                          targetShiftType: c.shiftType.name,
                          targetShiftColor: cColor,
                        );
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 본인 근무 칩 탭 시 — 바로 수정 시트로 진입.
  /// (1:N 추천 / 여러 날짜 일괄 교환은 변경 요청 화면에서 진입)
  /// 비관리자: 본인 근무 변경 시 shift_change 변경 요청을 생성하고 모달 표시.
  void _showSelfRequestSheet(
    BuildContext context,
    WidgetRef ref, {
    required String shiftId,
    required String workerName,
  }) {
    final tid = teamId!;
    final dateStr = DateFormat('M월 d일 (E)', 'ko_KR').format(date);
    final shiftTypes = ref
            .read(teamDetailViewModelProvider(tid))
            .valueOrNull
            ?.shiftTypes
            .where((t) => t.isActive)
            .toList() ??
        <ShiftTypeModel>[];
    final currentShiftTypeId = entry.shiftType.id;

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
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
            Text('근무 변경 요청',
                style: Theme.of(ctx)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSpacing.sm),
            Text('$dateStr · $workerName',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: AppColors.onSurfaceVariant,
                    )),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: AppRadius.borderRadiusSm,
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      size: 18, color: AppColors.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '관리자 승인이 필요한 근무 변경 요청으로 접수됩니다.',
                      style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('변경할 근무 유형',
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    )),
            const SizedBox(height: AppSpacing.md),
            if (shiftTypes.isEmpty)
              Text(
                '등록된 근무 유형이 없습니다',
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
              )
            else
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: shiftTypes.map((t) {
                  final c = parseHexColor(t.color);
                  final isCurrent = t.id == currentShiftTypeId;
                  return ActionChip(
                    avatar: CircleAvatar(
                      backgroundColor: c,
                      child: Text(
                        t.code,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                    label: Text(t.name),
                    backgroundColor:
                        isCurrent ? c.withValues(alpha: 0.2) : null,
                    onPressed: isCurrent
                        ? null
                        : () async {
                            Navigator.pop(ctx);
                            await _submitSelfShiftChangeRequest(
                              context,
                              ref,
                              requestedShiftType: t,
                              sourceShiftId: shiftId,
                            );
                          },
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitSelfShiftChangeRequest(
    BuildContext context,
    WidgetRef ref, {
    required ShiftTypeModel requestedShiftType,
    required String sourceShiftId,
  }) async {
    final tid = teamId!;
    final repo = ref.read(requestRepositoryProvider);
    try {
      await repo.createRequest(
        teamId: tid,
        changeType: 'shift_change',
        sourceShiftId: sourceShiftId,
        requestedDate: date,
        requestedShiftTypeId: requestedShiftType.id,
        reason: '근무 변경 요청',
      );
      ref.invalidate(requestListViewModelProvider(tid));
      if (!context.mounted) return;
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dctx) {
          final dtheme = Theme.of(dctx);
          final dcs = dtheme.colorScheme;
          return Dialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.borderRadiusLg,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.success,
                          size: 22,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          '요청 접수 완료',
                          style: dtheme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      '${DateFormat('M월 d일', 'ko_KR').format(date)} 근무를 '
                      '"${requestedShiftType.name}"(으)로 변경하는 요청이 접수되었습니다.\n'
                      '관리자 승인 후 반영됩니다.',
                      style: dtheme.textTheme.bodyMedium?.copyWith(
                        color: dcs.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.pop(dctx),
                        child: const Text('확인'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('요청 접수 실패: $e')),
      );
    }
  }

  /// 1:N 교환 후보 추천 시트 — AI 추천 + 다중 선택 + 일괄 발송
  void _showSwapSuggestSheet(
    BuildContext context,
    WidgetRef ref, {
    required String workerName,
  }) {
    final tid = teamId!;
    final myUserId = ref.read(currentUserProvider)?.id;
    if (myUserId == null) return;

    final myShiftCode = _shortShiftCode(
      entry.shiftType.code,
      entry.shiftType.name,
    );
    final dateStr = DateFormat('M월 d일 (E)', 'ko_KR').format(date);
    final repo = ref.read(requestRepositoryProvider);
    final teamName = ref
            .read(teamCalendarViewModelProvider(tid))
            .valueOrNull
            ?.teamName ??
        '';

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => _SwapSuggestSheet(
        teamId: tid,
        teamName: teamName,
        myUserId: myUserId,
        myDisplayName: workerName,
        myShiftDate: date,
        myShiftCode: myShiftCode,
        myShiftTypeName: entry.shiftType.name,
        myShiftTypeId: entry.shiftType.id,
        dateStr: dateStr,
        allEntries: allEntries,
        requestRepo: repo,
      ),
    );
  }

  /// 여러 날짜 일괄 교환 시트 — 본인 근무 여러 날 + 변경 후 유형(공통) + 일괄 발송
  void _showMultiDateSwapSheet(
    BuildContext context,
    WidgetRef ref, {
    required String workerName,
  }) {
    final tid = teamId!;
    final myUserId = ref.read(currentUserProvider)?.id;
    if (myUserId == null) return;
    final repo = ref.read(requestRepositoryProvider);
    final teamName = ref
            .read(teamCalendarViewModelProvider(tid))
            .valueOrNull
            ?.teamName ??
        '';

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => _MultiDateSwapSheet(
        teamId: tid,
        teamName: teamName,
        myUserId: myUserId,
        myDisplayName: workerName,
        currentDate: date,
        currentShiftCode: _shortShiftCode(
          entry.shiftType.code,
          entry.shiftType.name,
        ),
        currentShiftTypeName: entry.shiftType.name,
        requestRepo: repo,
      ),
    );
  }

  /// OFF 상태 본인 → 새 근무 추가 시트.
  /// 같은 날짜에 등록된 다른 사람 shift의 schedule_id를 viewmodel이 자동 사용.
  void _showAddSelfShiftSheet(
    BuildContext context,
    WidgetRef ref, {
    required String workerName,
  }) {
    final tid = teamId!;
    final dateStr = DateFormat('M월 d일 (E)', 'ko_KR').format(date);
    final shiftTypes = ref
            .read(teamDetailViewModelProvider(tid))
            .valueOrNull
            ?.shiftTypes
            .where((t) => t.isActive)
            .toList() ??
        <ShiftTypeModel>[];
    final myUserId = ref.read(currentUserProvider)?.id;

    // 근무 수정 시트(_showAdminEditSheet)와 동일한 MoniqBottomSheetShell 포맷으로 통일.
    showMoniqBottomSheet<void>(
      context: context,
      title: '내 근무 추가',
      eyebrow: 'ADMIN',
      child: Builder(
        builder: (ctx) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('$dateStr · $workerName',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: AppColors.onSurfaceVariant,
                    )),
            const SizedBox(height: AppSpacing.xl),
            Text('근무 유형 선택',
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    )),
            const SizedBox(height: AppSpacing.md),
            if (shiftTypes.isEmpty)
              Text(
                '등록된 근무 유형이 없습니다',
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
              )
            else
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: shiftTypes.map((t) {
                  final c = parseHexColor(t.color);
                  return ActionChip(
                    avatar: CircleAvatar(
                      backgroundColor: c,
                      child: Text(
                        t.code,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                    label: Text(t.name),
                    onPressed: () async {
                      if (myUserId == null) return;
                      Navigator.pop(ctx);
                      try {
                        await ref
                            .read(teamCalendarViewModelProvider(tid).notifier)
                            .createShiftForSelf(
                              date: date,
                              userId: myUserId,
                              shiftTypeId: t.id,
                              userDisplayName: workerName,
                              shiftTypeName: t.name,
                            );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${t.name} 근무가 추가되었습니다')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('추가 실패: $e')),
                          );
                        }
                      }
                    },
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  void _showAdminEditSheet(
    BuildContext context,
    WidgetRef ref, {
    required String shiftId,
    required String workerName,
  }) {
    final tid = teamId!;
    final dateStr = DateFormat('M월 d일 (E)', 'ko_KR').format(date);
    // 팀의 전체 shift types (활성만) — teamDetail에서 가져옴
    final shiftTypes = ref
            .read(teamDetailViewModelProvider(tid))
            .valueOrNull
            ?.shiftTypes
            .where((t) => t.isActive)
            .toList() ??
        <ShiftTypeModel>[];

    showMoniqBottomSheet<void>(
      context: context,
      title: '근무 수정',
      eyebrow: 'ADMIN',
      child: Builder(
        builder: (ctx) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('$dateStr · $workerName',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: AppColors.onSurfaceVariant,
                    )),
            const SizedBox(height: AppSpacing.xl),
            Text('근무 유형 변경',
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    )),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: shiftTypes.map((t) {
                final c = parseHexColor(t.color);
                final isCurrent = t.id == entry.shiftType.id;
                return ActionChip(
                  avatar: CircleAvatar(
                    backgroundColor: c,
                    child: Text(
                      t.code,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                  label: Text(t.name),
                  backgroundColor:
                      isCurrent ? c.withValues(alpha: 0.2) : null,
                  onPressed: isCurrent
                      ? null
                      : () async {
                          Navigator.pop(ctx);
                          try {
                            await ref
                                .read(teamCalendarViewModelProvider(tid)
                                    .notifier)
                                .updateShiftType(
                                  shiftId,
                                  t.id,
                                  affectedWorkerName: workerName,
                                  newShiftTypeName: t.name,
                                );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('${t.name}으로 변경되었습니다')),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('변경 실패: $e')),
                              );
                            }
                          }
                        },
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.xl),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
              ),
              icon: const Icon(Icons.delete_outline),
              label: const Text('이 근무 삭제'),
              onPressed: () async {
                final confirm = await showMoniqDestructiveConfirm(
                  context: ctx,
                  title: '근무 삭제',
                  message: '$workerName의 $dateStr 근무를 삭제하시겠습니까?',
                  confirmLabel: '삭제',
                );
                if (confirm != true) return;
                if (ctx.mounted) Navigator.pop(ctx);
                try {
                  await ref
                      .read(teamCalendarViewModelProvider(tid).notifier)
                      .deleteShift(shiftId, affectedWorkerName: workerName);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('근무가 삭제되었습니다')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('삭제 실패: $e')),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSwapSheet(
    BuildContext context,
    WidgetRef ref, {
    required String targetUserId,
    required String targetName,
    required String targetShiftType,
    required Color targetShiftColor,
  }) {
    // 내 근무 유형 찾기
    final currentUser = ref.read(currentUserProvider);
    final myUserId = currentUser?.id;
    String? myShiftType;
    for (final e in allEntries) {
      for (final w in e.workers) {
        if (w.user.id == myUserId) {
          myShiftType = e.shiftType.name;
          break;
        }
      }
      if (myShiftType != null) break;
    }

    // 동일 근무 유형끼리는 교환 불가 (의미 없음)
    if (myShiftType != null && myShiftType == targetShiftType) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('동일한 근무 유형끼리는 교환할 수 없습니다')),
      );
      return;
    }

    // 미리 repo를 읽어둠 (바텀시트에서 ref 접근 불가 방지)
    final repo = ref.read(requestRepositoryProvider);

    final dateStr = DateFormat('M월 d일', 'ko_KR').format(date);
    String reason = '';

    // 로그아웃 등 다른 시트와 동일한 MoniqBottomSheetShell 스타일로 통일.
    showMoniqBottomSheet<void>(
      context: context,
      eyebrow: 'SWAP',
      title: '근무 교환 요청',
      child: Builder(
        builder: (ctx) => SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 교환 정보 카드 — theme-aware로 다크모드 텍스트 대비 확보
              Builder(builder: (ctx) {
              final cs = Theme.of(ctx).colorScheme;
              return Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: AppRadius.borderRadiusMd,
                ),
                child: Column(
                  children: [
                    // 날짜
                    Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 16, color: cs.onSurfaceVariant),
                        const SizedBox(width: AppSpacing.sm),
                        Text(dateStr,
                            style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                                  color: cs.onSurface,
                                )),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    // 내 근무 → 상대 근무
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              Text('내 근무',
                                  style: Theme.of(ctx)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: cs.onSurfaceVariant,
                                      )),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                myShiftType ?? '없음',
                                style: Theme.of(ctx)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: cs.onSurface,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.swap_horiz,
                            color: cs.primary, size: 28),
                        Expanded(
                          child: Column(
                            children: [
                              Text(targetName,
                                  style: Theme.of(ctx)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: cs.onSurfaceVariant,
                                      )),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                targetShiftType,
                                style: Theme.of(ctx)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: targetShiftColor,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: AppSpacing.lg),

            // 사유
            TextField(
              onChanged: (v) => reason = v,
              decoration: const InputDecoration(
                hintText: '교환 사유 (선택)',
                prefixIcon: Icon(Icons.edit_note),
              ),
              maxLines: 2,
            ),

            const SizedBox(height: AppSpacing.xxl),

            ElevatedButton.icon(
              onPressed: () async {
                try {
                  final dateLabel = DateFormat('M/d', 'ko_KR').format(date);
                  final myName = ref
                          .read(currentUserProvider)
                          ?.userMetadata?['display_name'] as String? ??
                      '동료';
                  await repo.createRequest(
                    teamId: teamId!,
                    changeType: 'swap',
                    requestedDate: date,
                    targetUserId: targetUserId,
                    reason: reason.isNotEmpty
                        ? '$targetName 근무($targetShiftType)와 교환 요청. $reason'
                        : '$targetName 근무($targetShiftType)와 교환 요청',
                  );
                  // 교환 대상자에게 1:1 푸시 (실패 침묵)
                  try {
                    await PushService.instance.sendToUsers(
                      userIds: [targetUserId],
                      title: '근무 교환 요청',
                      body:
                          '$myName 님이 $dateLabel $targetShiftType 근무 교환을 요청했습니다',
                      data: {
                        'type': 'swap_request',
                        'team_id': teamId!,
                      },
                    );
                  } catch (_) {}
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('근무 교환 요청이 제출되었습니다')),
                    );
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('오류: $e')),
                    );
                  }
                }
              },
              icon: const Icon(Icons.swap_horiz),
              label: const Text('교환 요청'),
            ),
            ],
          ),
        ),
      ),
    );
  }
}

/// shift type code/name → 'D' / 'E' / 'N' / 기타.
String _shortShiftCode(String code, String name) {
  final c = code.toUpperCase();
  if (c == 'D' || name.contains('데이') || name.toLowerCase().contains('day')) {
    return 'D';
  }
  if (c == 'E' || name.contains('이브닝') || name.toLowerCase().contains('eve')) {
    return 'E';
  }
  if (c == 'N' || name.contains('나이트') || name.toLowerCase().contains('night')) {
    return 'N';
  }
  return c;
}

/// 1:N 교환 후보 시트
/// 사용자가 "변경 후 희망 근무 유형"을 선택하면, 해당 유형으로 같은 날 일하는
/// 팀원과의 1:1 교환을 시뮬레이션 → 시퀀스 룰 위반 개수가 적은 순으로 정렬해 추천.
class _SwapSuggestSheet extends ConsumerStatefulWidget {
  const _SwapSuggestSheet({
    required this.teamId,
    required this.teamName,
    required this.myUserId,
    required this.myDisplayName,
    required this.myShiftDate,
    required this.myShiftCode,
    required this.myShiftTypeName,
    required this.myShiftTypeId,
    required this.dateStr,
    required this.allEntries,
    required this.requestRepo,
  });

  final String teamId;
  final String teamName;
  final String myUserId;
  final String myDisplayName;
  final DateTime myShiftDate;
  final String myShiftCode;
  final String myShiftTypeName;
  final String myShiftTypeId;
  final String dateStr;
  final List<RosterEntry> allEntries;
  final dynamic requestRepo; // RequestRepository

  @override
  ConsumerState<_SwapSuggestSheet> createState() =>
      _SwapSuggestSheetState();
}

class _SwapSuggestSheetState extends ConsumerState<_SwapSuggestSheet> {
  final Set<String> _selected = {};
  List<_RuleSwapItem> _candidates = [];

  /// 변경 후 희망 근무 유형 — 같은 날에 활성 중인 코드(D/E/N) 중 본인 외 하나
  String? _desiredCode;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final defaultCode = _availableTargetCodes().firstOrNull;
    _desiredCode = defaultCode;
    _recompute();
  }

  String _itemKey(_RuleSwapItem c) => c.userId;

  /// 같은 날 활성 코드 중 본인 코드 제외 (D/E/N)
  List<String> _availableTargetCodes() {
    final codes = <String>{};
    for (final e in widget.allEntries) {
      if (e.shiftType.id == '_off') continue;
      final c = _shortShiftCode(e.shiftType.code, e.shiftType.name);
      if (c == widget.myShiftCode) continue;
      codes.add(c);
    }
    final order = ['D', 'E', 'N'];
    final list = codes.toList()
      ..sort((a, b) {
        final ai = order.indexOf(a);
        final bi = order.indexOf(b);
        if (ai == -1 && bi == -1) return a.compareTo(b);
        if (ai == -1) return 1;
        if (bi == -1) return -1;
        return ai.compareTo(bi);
      });
    return list;
  }

  /// 선택된 desiredCode에 맞는 후보를 룰 시뮬레이션해서 정렬.
  void _recompute() {
    final desired = _desiredCode;
    if (desired == null) {
      setState(() => _candidates = []);
      return;
    }

    final monthly = ref
        .read(teamCalendarViewModelProvider(widget.teamId))
        .valueOrNull
        ?.monthlyShifts;

    // 1) 전체 일별 코드 맵 (userId → date → code)
    final byUserDate = <String, Map<DateTime, String>>{};
    if (monthly != null) {
      for (final entry in monthly.entries) {
        for (final s in entry.value) {
          final code = _shortShiftCode(s.shiftType.code, s.shiftType.name);
          byUserDate.putIfAbsent(s.shift.userId, () => {})[entry.key] = code;
        }
      }
    }

    final dateKey = DateTime(
      widget.myShiftDate.year,
      widget.myShiftDate.month,
      widget.myShiftDate.day,
    );

    // 2) 같은 날 desiredCode로 근무 중인 다른 멤버 후보 모집
    final raw = <_RuleSwapItem>[];
    for (final e in widget.allEntries) {
      if (e.shiftType.id == '_off') continue;
      final code = _shortShiftCode(e.shiftType.code, e.shiftType.name);
      if (code != desired) continue;
      for (final w in e.workers) {
        if (w.user.id == widget.myUserId) continue;

        // 3) 가상 swap 후 양쪽 시퀀스 룰 위반 검사
        final mySim =
            Map<DateTime, String>.from(byUserDate[widget.myUserId] ?? {});
        mySim[dateKey] = desired;
        final otherSim =
            Map<DateTime, String>.from(byUserDate[w.user.id] ?? {});
        otherSim[dateKey] = widget.myShiftCode;

        final myViols = _findViolations(mySim, dateKey);
        final otherViols = _findViolations(otherSim, dateKey);
        final viols = [
          ...myViols.map((r) => '본인: $r'),
          ...otherViols.map((r) => '${w.user.displayName ?? w.user.email}: $r'),
        ];

        raw.add(_RuleSwapItem(
          userId: w.user.id,
          displayName: w.user.displayName ?? w.user.email,
          shiftCode: code,
          shiftTypeName: e.shiftType.name,
          violations: viols,
        ));
      }
    }

    raw.sort((a, b) {
      if (a.violations.length != b.violations.length) {
        return a.violations.length.compareTo(b.violations.length);
      }
      return a.displayName.compareTo(b.displayName);
    });

    setState(() {
      _candidates = raw;
      // 후보 변경 시 선택 초기화
      _selected.clear();
    });
  }

  /// 시퀀스 룰 위반 검사 — 변경된 날짜 전후 2일만 검사 (효율).
  /// 검사 룰: N→D, NOD(N→Off→D), E→D
  List<String> _findViolations(
    Map<DateTime, String> codes,
    DateTime changedDate,
  ) {
    final reasons = <String>[];
    String? at(DateTime d) {
      final key = DateTime(d.year, d.month, d.day);
      return codes[key];
    }

    DateTime add(int days) =>
        changedDate.add(Duration(days: days));

    // 변경된 날짜 자체와 ±2일 내의 변화만 영향 → 전후 2일 윈도우 검사
    for (int offset = -1; offset <= 2; offset++) {
      final d = add(offset);
      final today = at(d);
      final yesterday = at(d.subtract(const Duration(days: 1)));
      final dayBefore = at(d.subtract(const Duration(days: 2)));
      if (today == null) continue;
      // N→D
      if (yesterday == 'N' && today == 'D') {
        final dateLabel =
            '${d.month}/${d.day}';
        reasons.add('$dateLabel N→D 위반');
      }
      // NOD: 2일전 N + 어제 없음(off) + 오늘 D
      if (dayBefore == 'N' && yesterday == null && today == 'D') {
        final dateLabel =
            '${d.month}/${d.day}';
        reasons.add('$dateLabel NOD 패턴');
      }
      // E→D
      if (yesterday == 'E' && today == 'D') {
        final dateLabel =
            '${d.month}/${d.day}';
        reasons.add('$dateLabel E→D 위반');
      }
    }
    // dedupe
    return reasons.toSet().toList();
  }

  Future<void> _submitAll() async {
    if (_selected.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    final selectedItems = _candidates
        .where((c) => _selected.contains(_itemKey(c)))
        .toList();
    int success = 0;
    for (final t in selectedItems) {
      try {
        await widget.requestRepo.createRequest(
          teamId: widget.teamId,
          changeType: 'swap',
          requestedDate: widget.myShiftDate,
          targetUserId: t.userId,
          reason:
              '${t.displayName} 님의 ${widget.dateStr} ${t.shiftTypeName} 근무와 교환 요청 (1:N 후보)',
        );
        try {
          await PushService.instance.sendToUsers(
            userIds: [t.userId],
            title: '근무 교환 요청',
            body:
                '${widget.myDisplayName} 님이 ${widget.dateStr} ${widget.myShiftTypeName} 근무 교환을 요청했습니다',
            data: {
              'type': 'swap_request',
              'team_id': widget.teamId,
            },
          );
        } catch (_) {}
        success++;
      } catch (_) {}
    }
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$success/${selectedItems.length}명에게 교환 요청 발송')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final targetCodes = _availableTargetCodes();

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.xxl,
        right: AppSpacing.xxl,
        top: AppSpacing.xxl,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('교환 후보 추천',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.tertiary.withValues(alpha: 0.15),
                  borderRadius: AppRadius.borderRadiusFull,
                ),
                child: Text('1:N',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.tertiary,
                    )),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${widget.dateStr} · 현재 ${widget.myShiftTypeName}',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── 변경 후 희망 근무 유형 선택 ──
          Text('변경 후 희망 근무 유형',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.sm),
          if (targetCodes.isEmpty)
            Text(
              '같은 날 다른 유형으로 근무 중인 인원이 없습니다',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            )
          else
            Wrap(
              spacing: AppSpacing.sm,
              children: targetCodes.map((code) {
                final color = _codeColor(code);
                final selected = code == _desiredCode;
                return ChoiceChip(
                  selected: selected,
                  onSelected: (_) {
                    _desiredCode = code;
                    _recompute();
                  },
                  avatar: CircleAvatar(
                    backgroundColor: color,
                    child: Text(
                      code,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  label: Text(_codeLabel(code)),
                );
              }).toList(),
            ),
          const SizedBox(height: AppSpacing.lg),

          // ── 후보 목록 ──
          if (_candidates.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Text(
                _desiredCode == null
                    ? '교환 가능한 후보가 없습니다'
                    : '${_codeLabel(_desiredCode!)} 후보가 없습니다',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _candidates.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.xxs),
                itemBuilder: (lctx, i) {
                  final c = _candidates[i];
                  final key = _itemKey(c);
                  final selected = _selected.contains(key);
                  final color = _codeColor(c.shiftCode);
                  final safe = c.violations.isEmpty;
                  final badgeColor =
                      safe ? Colors.green.shade600 : AppColors.brandOrange;
                  final badgeText = safe ? '안전' : '위반 ${c.violations.length}건';
                  return CheckboxListTile(
                    value: selected,
                    onChanged: (v) => setState(() {
                      if (v == true) {
                        _selected.add(key);
                      } else {
                        _selected.remove(key);
                      }
                    }),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    title: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: color,
                          radius: 14,
                          child: Text(c.shiftCode,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              )),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            c.displayName,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.12),
                            borderRadius: AppRadius.borderRadiusFull,
                          ),
                          child: Text(badgeText,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: badgeColor,
                              )),
                        ),
                      ],
                    ),
                    subtitle: c.violations.isEmpty
                        ? null
                        : Padding(
                            padding: const EdgeInsets.only(
                              top: AppSpacing.xxs,
                              left: 36,
                            ),
                            child: Text(
                              c.violations.join(' · '),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                                fontSize: 11,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                  );
                },
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton.icon(
            onPressed: (_submitting || _selected.isEmpty) ? null : _submitAll,
            icon: _submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.swap_horiz),
            label: Text(_selected.isEmpty
                ? '후보를 1명 이상 선택하세요'
                : '${_selected.length}명에게 교환 요청 보내기'),
          ),
        ],
      ),
    );
  }

  String _codeLabel(String code) {
    switch (code) {
      case 'D':
        return '데이';
      case 'E':
        return '이브닝';
      case 'N':
        return '나이트';
      default:
        return code;
    }
  }

  Color _codeColor(String code) {
    switch (code) {
      case 'D':
        return AppColors.shiftDay;
      case 'E':
        return AppColors.shiftEvening;
      case 'N':
        return AppColors.shiftNight;
      default:
        return AppColors.onSurfaceVariant;
    }
  }
}

class _RuleSwapItem {
  _RuleSwapItem({
    required this.userId,
    required this.displayName,
    required this.shiftCode,
    required this.shiftTypeName,
    required this.violations,
  });

  final String userId;
  final String displayName;
  final String shiftCode;
  final String shiftTypeName;
  final List<String> violations;
}

/// 여러 날짜 일괄 교환 시트.
/// - 본인 근무 날짜 다중 선택 (현재 월의 본인 근무 날짜 목록)
/// - 변경 후 희망 근무 유형 1개 (공통)
/// - 각 선택 날짜마다 같은 유형으로 일하는 팀원 후보를 룰 위반 적은 순으로 1명 자동 매칭
///   (사용자가 후보를 변경할 수도 있음)
/// - 모든 (날짜, 후보) 조합으로 createRequest 일괄 발송
class _MultiDateSwapSheet extends ConsumerStatefulWidget {
  const _MultiDateSwapSheet({
    required this.teamId,
    required this.teamName,
    required this.myUserId,
    required this.myDisplayName,
    required this.currentDate,
    required this.currentShiftCode,
    required this.currentShiftTypeName,
    required this.requestRepo,
  });

  final String teamId;
  final String teamName;
  final String myUserId;
  final String myDisplayName;
  final DateTime currentDate;
  final String currentShiftCode;
  final String currentShiftTypeName;
  final dynamic requestRepo;

  @override
  ConsumerState<_MultiDateSwapSheet> createState() =>
      _MultiDateSwapSheetState();
}

class _MultiDateSwapSheetState extends ConsumerState<_MultiDateSwapSheet> {
  /// 본인의 모든 근무 날짜 (현재 월) — 같은 유형만
  List<DateTime> _myDates = [];

  /// 선택된 날짜
  final Set<DateTime> _selectedDates = {};

  /// 변경 후 희망 유형
  String? _desiredCode;
  List<String> _availableCodes = [];

  /// 날짜별 자동 매칭된 최선 후보
  Map<DateTime, _RuleSwapItem?> _bestPerDate = {};

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  void _initData() {
    final monthly = ref
        .read(teamCalendarViewModelProvider(widget.teamId))
        .valueOrNull
        ?.monthlyShifts;
    if (monthly == null) return;

    // 본인의 같은 유형 근무 날짜만 추출
    final dates = <DateTime>[];
    for (final entry in monthly.entries) {
      for (final s in entry.value) {
        if (s.shift.userId != widget.myUserId) continue;
        final code = _shortShiftCode(s.shiftType.code, s.shiftType.name);
        if (code != widget.currentShiftCode) continue;
        dates.add(entry.key);
      }
    }
    dates.sort();

    // 사용 가능한 다른 유형 코드 추출 (전체 월에서 본인 외 근무자가 가진 코드들)
    final codes = <String>{};
    for (final entry in monthly.entries) {
      for (final s in entry.value) {
        if (s.shift.userId == widget.myUserId) continue;
        final code = _shortShiftCode(s.shiftType.code, s.shiftType.name);
        if (code == widget.currentShiftCode) continue;
        codes.add(code);
      }
    }
    final order = ['D', 'E', 'N'];
    final codeList = codes.toList()
      ..sort((a, b) {
        final ai = order.indexOf(a);
        final bi = order.indexOf(b);
        if (ai == -1 && bi == -1) return a.compareTo(b);
        if (ai == -1) return 1;
        if (bi == -1) return -1;
        return ai.compareTo(bi);
      });

    setState(() {
      _myDates = dates;
      _selectedDates.add(_normalize(widget.currentDate));
      _availableCodes = codeList;
      _desiredCode = codeList.firstOrNull;
    });

    _recomputeMatches();
  }

  DateTime _normalize(DateTime d) => DateTime(d.year, d.month, d.day);

  /// 각 선택된 날짜에 대해 룰 위반 적은 후보 1명 자동 매칭
  void _recomputeMatches() {
    final desired = _desiredCode;
    if (desired == null) return;
    final monthly = ref
        .read(teamCalendarViewModelProvider(widget.teamId))
        .valueOrNull
        ?.monthlyShifts;
    if (monthly == null) return;

    final byUserDate = <String, Map<DateTime, String>>{};
    for (final entry in monthly.entries) {
      for (final s in entry.value) {
        final code = _shortShiftCode(s.shiftType.code, s.shiftType.name);
        byUserDate.putIfAbsent(s.shift.userId, () => {})[entry.key] = code;
      }
    }

    final result = <DateTime, _RuleSwapItem?>{};
    for (final d in _selectedDates) {
      final key = _normalize(d);
      final candidates = <_RuleSwapItem>[];
      // 같은 날 desired 코드로 일하는 팀원 찾기
      final shiftsThatDay = monthly[key] ?? const [];
      for (final s in shiftsThatDay) {
        if (s.shift.userId == widget.myUserId) continue;
        final code = _shortShiftCode(s.shiftType.code, s.shiftType.name);
        if (code != desired) continue;

        // 가상 swap 시뮬레이션
        final mySim =
            Map<DateTime, String>.from(byUserDate[widget.myUserId] ?? {});
        mySim[key] = desired;
        final otherSim =
            Map<DateTime, String>.from(byUserDate[s.shift.userId] ?? {});
        otherSim[key] = widget.currentShiftCode;
        final myViols = _findViolationsAround(mySim, key);
        final otherViols = _findViolationsAround(otherSim, key);

        candidates.add(_RuleSwapItem(
          userId: s.shift.userId,
          displayName: s.shift.userId, // 표시 이름은 아래에서 보정
          shiftCode: code,
          shiftTypeName: s.shiftType.name,
          violations: [
            ...myViols.map((r) => '본인: $r'),
            ...otherViols.map((r) => r),
          ],
        ));
      }
      // displayName 보정 — selectedDateRoster를 못 쓰는 시점이라 monthly 외부에서 가져와야
      // 임시로 user_id의 8자만 노출하거나, 외부에서 user repo 호출 필요. 단순히 user_id 마지막 일부 사용.
      candidates.sort(
          (a, b) => a.violations.length.compareTo(b.violations.length));
      result[key] = candidates.firstOrNull;
    }

    setState(() => _bestPerDate = result);
  }

  List<String> _findViolationsAround(
    Map<DateTime, String> codes,
    DateTime changedDate,
  ) {
    final reasons = <String>[];
    String? at(DateTime d) =>
        codes[DateTime(d.year, d.month, d.day)];
    DateTime add(int days) => changedDate.add(Duration(days: days));
    for (int offset = -1; offset <= 2; offset++) {
      final d = add(offset);
      final today = at(d);
      final yesterday = at(d.subtract(const Duration(days: 1)));
      final dayBefore = at(d.subtract(const Duration(days: 2)));
      if (today == null) continue;
      final dl = '${d.month}/${d.day}';
      if (yesterday == 'N' && today == 'D') reasons.add('$dl N→D');
      if (dayBefore == 'N' && yesterday == null && today == 'D') {
        reasons.add('$dl NOD');
      }
      if (yesterday == 'E' && today == 'D') reasons.add('$dl E→D');
    }
    return reasons.toSet().toList();
  }

  Future<void> _submitAll() async {
    if (_submitting) return;
    final desired = _desiredCode;
    if (desired == null) return;
    final entries = _selectedDates
        .map((d) {
          final key = _normalize(d);
          return MapEntry(key, _bestPerDate[key]);
        })
        .where((e) => e.value != null)
        .toList();
    if (entries.isEmpty) return;
    setState(() => _submitting = true);

    int success = 0;
    for (final entry in entries) {
      final d = entry.key;
      final t = entry.value!;
      final dateLabel = '${d.month}/${d.day}';
      try {
        await widget.requestRepo.createRequest(
          teamId: widget.teamId,
          changeType: 'swap',
          requestedDate: d,
          targetUserId: t.userId,
          reason:
              '$dateLabel ${widget.currentShiftTypeName} → ${_codeLabel(desired)}: ${t.shiftTypeName} (${t.displayName.substring(0, t.displayName.length.clamp(0, 6))}...)와 교환',
        );
        try {
          await PushService.instance.sendToUsers(
            userIds: [t.userId],
            title: '근무 교환 요청',
            body:
                '${widget.myDisplayName} 님이 $dateLabel ${t.shiftTypeName} 근무 교환을 요청했습니다',
            data: {
              'type': 'swap_request',
              'team_id': widget.teamId,
            },
          );
        } catch (_) {}
        success++;
      } catch (_) {}
    }
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$success/${entries.length}건 교환 요청 발송')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final candidatesReadyCount =
        _bestPerDate.values.where((v) => v != null).length;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.xxl,
        right: AppSpacing.xxl,
        top: AppSpacing.xxl,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('여러 날짜 일괄 교환',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.brandOrange.withValues(alpha: 0.15),
                  borderRadius: AppRadius.borderRadiusFull,
                ),
                child: Text('M:N',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.brandOrange,
                    )),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '본인 ${widget.currentShiftTypeName} 근무 → 다른 유형 일괄 변경',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── 변경 후 희망 유형 ──
          Text('변경 후 희망 근무 유형',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: _availableCodes.map((code) {
              final color = _codeColor(code);
              final selected = code == _desiredCode;
              return ChoiceChip(
                selected: selected,
                onSelected: (_) {
                  _desiredCode = code;
                  _recomputeMatches();
                },
                avatar: CircleAvatar(
                  backgroundColor: color,
                  child: Text(code,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      )),
                ),
                label: Text(_codeLabel(code)),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── 변경할 본인 근무 날짜 ──
          Text('변경할 본인 근무 날짜 (다중 선택)',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.sm),
          if (_myDates.isEmpty)
            Text(
              '본인 ${widget.currentShiftTypeName} 근무 날짜가 없습니다',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _myDates.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.xxs),
                itemBuilder: (lctx, i) {
                  final d = _myDates[i];
                  final key = _normalize(d);
                  final selected = _selectedDates.contains(key);
                  final best = _bestPerDate[key];
                  final hasMatch = best != null;
                  final viols = best?.violations ?? const [];
                  final safe = viols.isEmpty && hasMatch;
                  return CheckboxListTile(
                    value: selected,
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _selectedDates.add(key);
                        } else {
                          _selectedDates.remove(key);
                        }
                      });
                      _recomputeMatches();
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    title: Text('${d.month}/${d.day} (${_dow(d)})',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(
                        top: AppSpacing.xxs,
                        left: 36,
                      ),
                      child: Text(
                        selected
                            ? (hasMatch
                                ? (safe
                                    ? '추천 후보 매칭 (안전)'
                                    : '추천 후보 매칭 (위반 ${viols.length}건: ${viols.join(", ")})')
                                : '같은 날 ${_codeLabel(_desiredCode ?? "")} 근무자 없음')
                            : '체크 시 자동 매칭',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: !selected
                              ? cs.onSurfaceVariant
                              : (safe
                                  ? Colors.green.shade700
                                  : (hasMatch
                                      ? AppColors.brandOrange
                                      : cs.onSurfaceVariant)),
                          fontSize: 11,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton.icon(
            onPressed: (_submitting ||
                    candidatesReadyCount == 0 ||
                    _desiredCode == null)
                ? null
                : _submitAll,
            icon: _submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.swap_calls),
            label: Text(candidatesReadyCount == 0
                ? '매칭된 후보가 없습니다'
                : '$candidatesReadyCount건 교환 요청 일괄 발송'),
          ),
        ],
      ),
    );
  }

  String _codeLabel(String code) {
    switch (code) {
      case 'D':
        return '데이';
      case 'E':
        return '이브닝';
      case 'N':
        return '나이트';
      default:
        return code;
    }
  }

  Color _codeColor(String code) {
    switch (code) {
      case 'D':
        return AppColors.shiftDay;
      case 'E':
        return AppColors.shiftEvening;
      case 'N':
        return AppColors.shiftNight;
      default:
        return AppColors.onSurfaceVariant;
    }
  }

  String _dow(DateTime d) {
    const labels = ['월', '화', '수', '목', '금', '토', '일'];
    return labels[d.weekday - 1];
  }
}

/// 표준 액션 시트 행 — `date_items_panel.dart`의 `_ActionSheetTile`
/// (rounded filled 카드 + 아이콘 원형 칩) 모양을 본떠 제목/부제를 더한 행.
class _AdminActionRow extends StatelessWidget {
  const _AdminActionRow({
    required this.icon,
    required this.label,
    required this.subLabel,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, size: 18, color: cs.onSurface),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
