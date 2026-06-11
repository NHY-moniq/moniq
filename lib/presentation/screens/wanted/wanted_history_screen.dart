import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moniq/core/utils/color_utils.dart';
import 'package:moniq/data/models/shift_type_model.dart';
import 'package:moniq/data/models/wanted_request_model.dart';
import 'package:moniq/data/providers/shift_providers.dart';
import 'package:moniq/data/providers/wanted_providers.dart';
import 'package:moniq/presentation/screens/wanted/wanted_request_widgets.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/widgets/common/moniq_app_bar.dart';
import 'package:moniq/presentation/widgets/common/moniq_bottom_sheet.dart';
import 'package:moniq/presentation/widgets/common/moniq_empty_state.dart';
import 'package:moniq/presentation/widgets/common/moniq_error_view.dart';
import 'package:moniq/presentation/widgets/common/moniq_loading_view.dart';

// ─── Public data class (web DDC requires non-private generic type params) ─────

class WantedHistoryGroup {
  WantedHistoryGroup({
    required this.periodStart,
    required this.periodEnd,
    required this.requests,
    required this.allEntries,
    required this.myEntries,
  });
  final DateTime periodStart;
  final DateTime periodEnd;
  final List<WantedRequestModel> requests;
  final List<WantedEntryWithUser> allEntries;
  final List<WantedEntryModel> myEntries;

  int get respondentCount =>
      allEntries.map((e) => e.entry.userId).toSet().length;
}

// ─── Top-level providers ──────────────────────────────────────────────────────

final _historyShiftTypesProvider = FutureProvider.autoDispose
    .family<List<ShiftTypeModel>, String>(
      (ref, teamId) => ref.watch(shiftRepositoryProvider).getShiftTypes(teamId),
    );

// Key format: "teamId|true" or "teamId|false"
final wantedHistoryProvider = FutureProvider.autoDispose
    .family<List<WantedHistoryGroup>, String>((ref, key) async {
      final sep = key.lastIndexOf('|');
      final teamId = key.substring(0, sep);
      final isAdmin = key.substring(sep + 1) == 'true';

      final repo = ref.watch(wantedRepositoryProvider);
      final allRequests = await repo.getWantedRequests(teamId);
      final closed = allRequests.where((r) => r.status == 'closed').toList();

      // Group by period (same periodStart + periodEnd)
      final groupMap = <String, List<WantedRequestModel>>{};
      for (final r in closed) {
        final key =
            '${r.periodStart.millisecondsSinceEpoch}__${r.periodEnd.millisecondsSinceEpoch}';
        groupMap.putIfAbsent(key, () => []).add(r);
      }

      const typeOrder = ['day_off', 'preferred_shift', 'night_dedicated'];
      final groups = <WantedHistoryGroup>[];

      for (final reqs in groupMap.values) {
        reqs.sort(
          (a, b) => typeOrder
              .indexOf(a.wantedType)
              .compareTo(typeOrder.indexOf(b.wantedType)),
        );

        final List<WantedEntryWithUser> allEntries = [];
        final List<WantedEntryModel> myEntries = [];

        if (isAdmin) {
          for (final req in reqs) {
            allEntries.addAll(await repo.getAllEntries(req.id));
          }
        } else {
          for (final req in reqs) {
            myEntries.addAll(await repo.getMyEntries(req.id));
          }
        }

        groups.add(
          WantedHistoryGroup(
            periodStart: reqs.first.periodStart,
            periodEnd: reqs.first.periodEnd,
            requests: reqs,
            allEntries: allEntries,
            myEntries: myEntries,
          ),
        );
      }

      groups.sort((a, b) => b.periodStart.compareTo(a.periodStart));
      return groups;
    });

// ─── Screen ──────────────────────────────────────────────────────────────────

class WantedHistoryScreen extends ConsumerWidget {
  const WantedHistoryScreen({
    super.key,
    required this.teamId,
    required this.isAdmin,
  });

  final String teamId;
  final bool isAdmin;

  String get _providerKey => '$teamId|$isAdmin';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(wantedHistoryProvider(_providerKey));

    return Scaffold(
      appBar: MoniqAppBar(
        title: isAdmin ? '원티드 히스토리' : '내 원티드 내역',
        trailing: MoniqAppBarAction(
          icon: Icons.refresh_rounded,
          onTap: () => ref.invalidate(wantedHistoryProvider(_providerKey)),
        ),
      ),
      body: historyAsync.when(
        loading: () => const MoniqLoadingView(),
        error: (e, _) => MoniqErrorView(
          message: '히스토리를 불러올 수 없습니다',
          onRetry: () => ref.invalidate(wantedHistoryProvider(_providerKey)),
        ),
        data: (groups) {
          if (groups.isEmpty) {
            return MoniqEmptyState.peaceful(
              title: '수집 히스토리가 없어요',
              message: '원티드 수집이 마감되면 여기서 확인할 수 있어요',
            );
          }

          // 수집 기간의 시작월 기준으로 월별 섹션을 구성한다
          // (근무 변경 요청 히스토리와 동일한 레이아웃).
          final monthMap = <String, List<WantedHistoryGroup>>{};
          final yearMonthFormat = DateFormat('yyyy년 M월', 'ko');
          for (final g in groups) {
            final key = yearMonthFormat.format(
              DateTime(g.periodStart.year, g.periodStart.month),
            );
            monthMap.putIfAbsent(key, () => []).add(g);
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            itemCount: monthMap.length,
            itemBuilder: (context, index) {
              final monthLabel = monthMap.keys.elementAt(index);
              final items = monthMap[monthLabel]!;
              return _WantedMonthSection(
                label: monthLabel,
                groups: items,
                teamId: teamId,
                isAdmin: isAdmin,
              );
            },
          );
        },
      ),
    );
  }
}

// ─── Month section (근무 변경 요청 히스토리 _MonthSection과 동일 레이아웃) ──────────

class _WantedMonthSection extends StatelessWidget {
  const _WantedMonthSection({
    required this.label,
    required this.groups,
    required this.teamId,
    required this.isAdmin,
  });

  final String label;
  final List<WantedHistoryGroup> groups;
  final String teamId;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '${groups.length}건 수집',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          for (var idx = 0; idx < groups.length; idx++)
            _WantedRecordTile(
              group: groups[idx],
              teamId: teamId,
              isAdmin: isAdmin,
              showDivider: idx != groups.length - 1,
            ),
        ],
      ),
    );
  }
}

/// 타임라인 형태의 수집 기록 한 줄 (요청 히스토리 _HistoryRecordTile과 동일 스펙)
class _WantedRecordTile extends ConsumerWidget {
  const _WantedRecordTile({
    required this.group,
    required this.teamId,
    required this.isAdmin,
    required this.showDivider,
  });

  final WantedHistoryGroup group;
  final String teamId;
  final bool isAdmin;
  final bool showDivider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final dayFormat = DateFormat('MM.dd');

    final hasMine = !isAdmin && group.myEntries.isNotEmpty;
    final dotColor = isAdmin
        ? (group.respondentCount > 0
            ? const Color(0xFF10B981)
            : cs.onSurfaceVariant)
        : (hasMine ? cs.primary : cs.onSurfaceVariant);

    final countText = isAdmin
        ? '${group.respondentCount}명 · ${group.allEntries.length}건'
        : group.myEntries.isEmpty
            ? '내역 없음'
            : '${group.myEntries.length}건 신청';
    final countColor = isAdmin
        ? cs.onSurfaceVariant
        : (hasMine ? cs.primary : cs.onSurfaceVariant);

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            onTap: () => _showWantedDetailSheet(
              context,
              ref,
              group: group,
              teamId: teamId,
              isAdmin: isAdmin,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Row(
                children: [
                  SizedBox(
                    width: 52,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dayFormat.format(group.periodStart),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '~${dayFormat.format(group.periodEnd)}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '원티드 수집',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          group.requests
                              .map((r) => _wantedTypeShortLabel(r.wantedType))
                              .toSet()
                              .join(' · '),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    countText,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: countColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 0.5,
            color: cs.outline.withValues(alpha: 0.2),
          ),
      ],
    );
  }
}

String _wantedTypeShortLabel(String wantedType) {
  switch (wantedType) {
    case 'day_off':
      return '오프';
    case 'preferred_shift':
      return '희망 근무';
    case 'night_dedicated':
      return '나이트 전담';
    default:
      return wantedType;
  }
}

/// 수집 기록 상세 — 항목 목록을 바텀시트로 표시 (요청 히스토리의 상세 시트와 동일 패턴).
Future<void> _showWantedDetailSheet(
  BuildContext context,
  WidgetRef ref, {
  required WantedHistoryGroup group,
  required String teamId,
  required bool isAdmin,
}) {
  final dateFormat = DateFormat('MM.dd');
  final periodStr =
      '${dateFormat.format(group.periodStart)} ~ ${dateFormat.format(group.periodEnd)}';
  final shiftTypes =
      ref.read(_historyShiftTypesProvider(teamId)).valueOrNull ?? [];
  final shiftTypeMap = {for (final t in shiftTypes) t.id: t};

  return showMoniqBottomSheet<void>(
    context: context,
    eyebrow: 'WANTED',
    title: periodStr,
    child: SingleChildScrollView(
      child: isAdmin
          ? _AdminEntryList(
              entries: group.allEntries,
              shiftTypeMap: shiftTypeMap,
            )
          : _MemberEntryList(
              entries: group.myEntries,
              shiftTypeMap: shiftTypeMap,
            ),
    ),
  );
}

// ─── Admin entry list ─────────────────────────────────────────────────────────

class _AdminEntryList extends StatelessWidget {
  const _AdminEntryList({required this.entries, required this.shiftTypeMap});

  final List<WantedEntryWithUser> entries;
  final Map<String, ShiftTypeModel> shiftTypeMap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dateFormat = DateFormat('MM.dd');

    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(
          '수집된 원티드가 없습니다',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    // Group by user
    final grouped = <String, List<WantedEntryWithUser>>{};
    for (final ew in entries) {
      grouped.putIfAbsent(ew.entry.userId, () => []).add(ew);
    }
    for (final list in grouped.values) {
      list.sort((a, b) => a.entry.wantedDate.compareTo(b.entry.wantedDate));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Column(
        children: grouped.values.map((userList) {
          final displayName = userList.first.displayName;
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 72,
                  child: Text(
                    displayName,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: userList.map((ew) {
                      final entry = ew.entry;
                      final Color chipColor;
                      final String avatarLabel;
                      if (entry.shiftTypeId != null) {
                        final st = shiftTypeMap[entry.shiftTypeId];
                        chipColor = st != null
                            ? parseHexColor(st.color)
                            : AppColors.shiftOff;
                        avatarLabel = st?.code ?? 'O';
                      } else {
                        chipColor = AppColors.shiftOff;
                        avatarLabel = 'O';
                      }
                      final chip = WantedEntryPill(
                        color: chipColor,
                        avatarLabel: avatarLabel,
                        label: Text(
                          '${dateFormat.format(entry.wantedDate)} · '
                          '${entry.priority}순위',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                      final reason = entry.reason?.trim();
                      if (reason == null || reason.isEmpty) return chip;
                      return WantedReasonChip(chip: chip, reason: reason);
                    }).toList(),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Member entry list ────────────────────────────────────────────────────────

class _MemberEntryList extends StatelessWidget {
  const _MemberEntryList({required this.entries, required this.shiftTypeMap});

  final List<WantedEntryModel> entries;
  final Map<String, ShiftTypeModel> shiftTypeMap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dateFormat = DateFormat('MM.dd');

    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(
          '신청한 원티드가 없습니다',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final sorted = [...entries]
      ..sort((a, b) => a.wantedDate.compareTo(b.wantedDate));

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: sorted.map((entry) {
          final Color chipColor;
          final String avatarLabel;
          if (entry.shiftTypeId != null) {
            final st = shiftTypeMap[entry.shiftTypeId];
            chipColor = st != null
                ? parseHexColor(st.color)
                : AppColors.shiftOff;
            avatarLabel = st?.code ?? 'O';
          } else {
            chipColor = AppColors.shiftOff;
            avatarLabel = 'O';
          }
          final chip = WantedEntryPill(
            color: chipColor,
            avatarLabel: avatarLabel,
            label: Text(
              '${dateFormat.format(entry.wantedDate)} · ${entry.priority}순위',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          );
          final reason = entry.reason?.trim();
          if (reason == null || reason.isEmpty) return chip;
          return WantedReasonChip(chip: chip, reason: reason);
        }).toList(),
      ),
    );
  }
}
