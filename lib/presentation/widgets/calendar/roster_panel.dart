import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moniq/core/utils/color_utils.dart';
import 'package:moniq/data/models/roster_entry.dart';
import 'package:moniq/data/providers/auth_providers.dart';
import 'package:moniq/data/providers/request_providers.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';

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
                onTap: (teamId != null && !isMe)
                    ? () => _showSwapSheet(
                          context,
                          ref,
                          targetUserId: worker.user.id,
                          targetName: name,
                          targetShiftType: entry.shiftType.name,
                          targetShiftColor: color,
                        )
                    : null,
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
