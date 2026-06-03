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
      appBar: AppBar(
        title: Text(isAdmin ? '원티드 히스토리' : '내 원티드 내역'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '새로고침',
            onPressed: () =>
                ref.invalidate(wantedHistoryProvider(_providerKey)),
          ),
        ],
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
          return ListView.builder(
            padding: AppSpacing.screenAll,
            itemCount: groups.length,
            itemBuilder: (context, index) => _HistoryGroupTile(
              group: groups[index],
              teamId: teamId,
              isAdmin: isAdmin,
            ),
          );
        },
      ),
    );
  }
}

// ─── Group tile ───────────────────────────────────────────────────────────────

class _HistoryGroupTile extends ConsumerWidget {
  const _HistoryGroupTile({
    required this.group,
    required this.teamId,
    required this.isAdmin,
  });

  final WantedHistoryGroup group;
  final String teamId;
  final bool isAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dateFormat = DateFormat('MM.dd');
    final yearFormat = DateFormat('yyyy년 M월');

    final shiftTypes =
        ref.watch(_historyShiftTypesProvider(teamId)).valueOrNull ?? [];
    final shiftTypeMap = {for (final t in shiftTypes) t.id: t};

    final periodStr =
        '${dateFormat.format(group.periodStart)} ~ ${dateFormat.format(group.periodEnd)}';
    final yearStr = yearFormat.format(group.periodStart);

    final countText = isAdmin
        ? '${group.respondentCount}명 · ${group.allEntries.length}건'
        : group.myEntries.isEmpty
        ? '내역 없음'
        : '${group.myEntries.length}건 신청';
    final countColor = isAdmin
        ? colorScheme.onSurfaceVariant
        : group.myEntries.isEmpty
        ? colorScheme.onSurfaceVariant
        : colorScheme.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      clipBehavior: Clip.hardEdge,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.sm,
          ),
          childrenPadding: EdgeInsets.zero,
          title: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      yearStr,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      periodStr,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                countText,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: countColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          children: [
            const Divider(height: 1),
            if (isAdmin)
              _AdminEntryList(
                entries: group.allEntries,
                shiftTypeMap: shiftTypeMap,
              )
            else
              _MemberEntryList(
                entries: group.myEntries,
                shiftTypeMap: shiftTypeMap,
              ),
          ],
        ),
      ),
    );
  }
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
