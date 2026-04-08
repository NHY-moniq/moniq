import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moniq/core/utils/color_utils.dart';
import 'package:moniq/data/models/roster_entry.dart';
import 'package:moniq/data/models/shift_type_model.dart';
import 'package:moniq/data/models/user_model.dart';
import 'package:moniq/data/providers/auth_providers.dart';
import 'package:moniq/data/providers/request_providers.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/team_calendar_viewmodel.dart';
import 'package:moniq/presentation/viewmodels/team_detail_viewmodel.dart';

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
    final dateStr = DateFormat('M월 d일 (E)', 'ko_KR').format(date);

    return Padding(
      padding: AppSpacing.screenHorizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.md),
          Text(
            dateStr,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (rosterEntries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Center(
                child: Text(
                  '이 날짜에 배정된 근무가 없습니다',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            ...rosterEntries.map(
              (entry) => _ShiftTypeGroup(
                entry: entry,
                date: date,
                teamId: teamId,
                allEntries: rosterEntries,
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
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
    final theme = Theme.of(context);
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 그룹 헤더
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color,
                borderRadius: AppRadius.borderRadiusSm,
              ),
              child: Center(
                child: Text(
                  entry.shiftType.code,
                  style: TextStyle(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '${entry.shiftType.name} (${entry.workers.length}명)',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        // 근무자 목록
        Padding(
          padding: const EdgeInsets.only(left: 36),
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: entry.workers.map((worker) {
              final name = worker.user.displayName ?? worker.user.email;
              final isMe = worker.user.id == myUserId;

              return GestureDetector(
                onTap: (teamId == null || isMe)
                    ? null
                    : () {
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
                      },
                child: Chip(
                  label: Text(
                    isMe ? '$name (나)' : name,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isMe ? AppColors.primary : null,
                      fontWeight: isMe ? FontWeight.w600 : null,
                    ),
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  labelPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  backgroundColor: isMe
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : null,
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
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
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.md),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              '$targetName · $targetShiftType',
              style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            // 근무 수정
            ListTile(
              leading: const Icon(Icons.edit_outlined,
                  color: AppColors.primary),
              title: const Text('근무 수정'),
              subtitle: const Text('근무 유형 변경 또는 삭제 (관리자)'),
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
            if (!isMe)
              ListTile(
                leading: const Icon(Icons.swap_horiz,
                    color: AppColors.tertiary),
                title: const Text('근무 교환 요청'),
                subtitle: const Text('본인 근무와 교환 요청 제출'),
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
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
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
            Text('근무 수정 (관리자)',
                style: Theme.of(ctx)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSpacing.sm),
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
                final confirm = await showDialog<bool>(
                  context: ctx,
                  builder: (dctx) => AlertDialog(
                    title: const Text('근무 삭제'),
                    content: Text('$workerName의 $dateStr 근무를 삭제하시겠습니까?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dctx, false),
                        child: const Text('취소'),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                            foregroundColor: AppColors.error),
                        onPressed: () => Navigator.pop(dctx, true),
                        child: const Text('삭제'),
                      ),
                    ],
                  ),
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

    // 미리 repo를 읽어둠 (바텀시트에서 ref 접근 불가 방지)
    final repo = ref.read(requestRepositoryProvider);

    final dateStr = DateFormat('M월 d일', 'ko_KR').format(date);
    String reason = '';

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
            Text('근무 교환 요청',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    )),
            const SizedBox(height: AppSpacing.xxl),

            // 교환 정보 카드
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: AppRadius.borderRadiusMd,
              ),
              child: Column(
                children: [
                  // 날짜
                  Row(
                    children: [
                      Icon(Icons.calendar_today,
                          size: 16, color: AppColors.onSurfaceVariant),
                      const SizedBox(width: AppSpacing.sm),
                      Text(dateStr,
                          style: Theme.of(ctx).textTheme.bodyMedium),
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
                                      color: AppColors.onSurfaceVariant,
                                    )),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              myShiftType ?? '없음',
                              style: Theme.of(ctx)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.swap_horiz,
                          color: AppColors.primary, size: 28),
                      Expanded(
                        child: Column(
                          children: [
                            Text(targetName,
                                style: Theme.of(ctx)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: AppColors.onSurfaceVariant,
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
                  await repo.createRequest(
                    teamId: teamId!,
                    changeType: 'swap',
                    requestedDate: date,
                    reason: reason.isNotEmpty
                        ? '$targetName 근무($targetShiftType)와 교환 요청. $reason'
                        : '$targetName 근무($targetShiftType)와 교환 요청',
                  );
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
    );
  }
}
