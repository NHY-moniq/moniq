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
                  onTap: () => ref.read(dateExpandedProvider.notifier).state =
                      !isExpanded,
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
    final shiftTypes =
        ref
            .read(teamDetailViewModelProvider(tid))
            .valueOrNull
            ?.shiftTypes
            .where((t) => t.isActive)
            .toList() ??
        <ShiftTypeModel>[];
    final currentShiftTypeId = entry.shiftType.id;

    // 로그아웃 등 다른 시트와 동일한 MoniqBottomSheetShell 스타일로 통일.
    showMoniqBottomSheet<void>(
      context: context,
      eyebrow: 'REQUEST',
      title: '근무 변경 요청',
      child: Builder(
        builder: (ctx) => SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '$dateStr · $workerName',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: AppRadius.borderRadiusSm,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 18,
                      color: AppColors.primary,
                    ),
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
              Text(
                '변경할 근무 유형',
                style: Theme.of(
                  ctx,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
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
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      label: Text(t.name),
                      backgroundColor: isCurrent
                          ? c.withValues(alpha: 0.2)
                          : null,
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
      // 다른 시트와 동일한 MoniqBottomSheetShell 스타일로 통일.
      await showMoniqInfoSheet(
        context: context,
        eyebrow: 'REQUEST',
        title: '요청 접수 완료',
        message:
            '${DateFormat('M월 d일', 'ko_KR').format(date)} 근무를 '
            '"${requestedShiftType.name}"(으)로 변경하는 요청이 접수되었습니다.\n'
            '관리자 승인 후 반영됩니다.',
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('요청 접수 실패: $e')));
    }
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
    final shiftTypes =
        ref
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
        builder: (ctx) => SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '$dateStr · $workerName',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                '근무 유형 선택',
                style: Theme.of(
                  ctx,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
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
                            fontWeight: FontWeight.w700,
                          ),
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
    final shiftTypes =
        ref
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
        builder: (ctx) => SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '$dateStr · $workerName',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                '근무 유형 변경',
                style: Theme.of(
                  ctx,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
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
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    label: Text(t.name),
                    backgroundColor: isCurrent
                        ? c.withValues(alpha: 0.2)
                        : null,
                    onPressed: isCurrent
                        ? null
                        : () async {
                            Navigator.pop(ctx);
                            try {
                              await ref
                                  .read(
                                    teamCalendarViewModelProvider(tid).notifier,
                                  )
                                  .updateShiftType(
                                    shiftId,
                                    t.id,
                                    affectedWorkerName: workerName,
                                    newShiftTypeName: t.name,
                                  );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('${t.name}으로 변경되었습니다'),
                                  ),
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
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
                    }
                  }
                },
              ),
            ],
          ),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('동일한 근무 유형끼리는 교환할 수 없습니다')));
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
              Builder(
                builder: (ctx) {
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
                            Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: cs.onSurfaceVariant,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              dateStr,
                              style: Theme.of(ctx).textTheme.bodyMedium
                                  ?.copyWith(color: cs.onSurface),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        // 내 근무 → 상대 근무
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    '내 근무',
                                    style: Theme.of(ctx).textTheme.bodySmall
                                        ?.copyWith(color: cs.onSurfaceVariant),
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    myShiftType ?? '없음',
                                    style: Theme.of(ctx).textTheme.titleSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: cs.onSurface,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.swap_horiz, color: cs.primary, size: 28),
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    targetName,
                                    style: Theme.of(ctx).textTheme.bodySmall
                                        ?.copyWith(color: cs.onSurfaceVariant),
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    targetShiftType,
                                    style: Theme.of(ctx).textTheme.titleSmall
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
                },
              ),

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
                    final myName =
                        ref
                                .read(currentUserProvider)
                                ?.userMetadata?['display_name']
                            as String? ??
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
                        data: {'type': 'swap_request', 'team_id': teamId!},
                      );
                    } catch (_) {}
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('근무 교환 요청이 제출되었습니다')),
                      );
                    }
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('오류: $e')));
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
