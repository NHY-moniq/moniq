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
        showBack: true,
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

          // 요청 히스토리와 동일하게 월별 섹션으로 분리.
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
              return _WantedMonthSection(
                label: monthLabel,
                groups: monthMap[monthLabel]!,
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

/// 월별 섹션 — 요청 히스토리의 _MonthSection과 동일한 헤더 스타일.
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
            child: Text(
              '$label · ${groups.length}건',
              style: theme.textTheme.labelLarge?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ...groups.map(
            (g) => _HistoryGroupTile(
              group: g,
              teamId: teamId,
              isAdmin: isAdmin,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Group tile ───────────────────────────────────────────────────────────────

class _HistoryGroupTile extends ConsumerStatefulWidget {
  const _HistoryGroupTile({
    required this.group,
    required this.teamId,
    required this.isAdmin,
  });

  final WantedHistoryGroup group;
  final String teamId;
  final bool isAdmin;

  @override
  ConsumerState<_HistoryGroupTile> createState() => _HistoryGroupTileState();
}

class _HistoryGroupTileState extends ConsumerState<_HistoryGroupTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final teamId = widget.teamId;
    final isAdmin = widget.isAdmin;
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
        ? '${group.respondentCount}명 응답 · ${group.allEntries.length}건'
        : group.myEntries.isEmpty
        ? '신청 내역 없음'
        : '${group.myEntries.length}건 신청';

    // 요청 히스토리(RequestCard)와 동일한 카드 크롬:
    // 좌측 컬러바 + 제목 + 상태 배지 + 아이콘 정보행.
    final accent = colorScheme.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      shadowColor: accent.withValues(alpha: 0.15),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: accent),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 헤더 — 탭하면 상세 엔트리 펼침/접힘 (드롭다운)
                    InkWell(
                      onTap: () => setState(() => _expanded = !_expanded),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1행: 수집 기간 + 마감 배지 + 펼침 화살표
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  periodStr,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const _ClosedBadge(),
                              const SizedBox(width: AppSpacing.xs),
                              AnimatedRotation(
                                turns: _expanded ? 0.5 : 0,
                                duration: const Duration(milliseconds: 180),
                                child: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 20,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          // 응답/신청 건수 (신청자 행과 동일 스타일)
                          _WantedInfoRow(
                            icon: Icons.person_outline,
                            text: countText,
                          ),
                          const SizedBox(height: 2),
                          // 수집 기간 (년월)
                          _WantedInfoRow(
                            icon: Icons.calendar_today_outlined,
                            text: yearStr,
                          ),
                        ],
                      ),
                    ),
                    // 상세 엔트리 — 펼쳤을 때만 노출
                    if (_expanded)
                      if (isAdmin) ...[
                        const SizedBox(height: AppSpacing.sm),
                        _AdminEntryList(
                          entries: group.allEntries,
                          shiftTypeMap: shiftTypeMap,
                        ),
                      ] else if (group.myEntries.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.sm),
                        _MemberEntryList(
                          entries: group.myEntries,
                          shiftTypeMap: shiftTypeMap,
                        ),
                      ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 요청 히스토리 카드의 아이콘 정보행과 동일한 스타일.
class _WantedInfoRow extends StatelessWidget {
  const _WantedInfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Row(
      children: [
        Icon(icon, size: 14, color: cs.onSurfaceVariant),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// 마감된 수집을 나타내는 상태 배지 — 요청 히스토리의 StatusBadge와 같은 형태.
class _ClosedBadge extends StatelessWidget {
  const _ClosedBadge();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = cs.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        '마감',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
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

    return Column(
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
                      final String chipLabel;
                      if (entry.shiftTypeId != null) {
                        final st = shiftTypeMap[entry.shiftTypeId];
                        chipColor = st != null
                            ? parseHexColor(st.color)
                            : AppColors.shiftOff;
                        avatarLabel = st?.code ?? 'O';
                        chipLabel =
                            '${dateFormat.format(entry.wantedDate)} · '
                            '${entry.priority}순위';
                      } else {
                        chipColor = AppColors.shiftOff;
                        avatarLabel = 'O';
                        chipLabel =
                            '${dateFormat.format(entry.wantedDate)} · '
                            '${entry.priority}순위';
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
                          chipLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: chipColor.withValues(alpha: 0.08),
                        side: BorderSide(
                          color: chipColor.withValues(alpha: 0.2),
                        ),
                        padding: EdgeInsets.zero,
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

    return Wrap(
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
              '${dateFormat.format(entry.wantedDate)} · ${entry.priority}순위',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            visualDensity: VisualDensity.compact,
            backgroundColor: chipColor.withValues(alpha: 0.08),
            side: BorderSide(color: chipColor.withValues(alpha: 0.2)),
            padding: EdgeInsets.zero,
          );
          final reason = entry.reason?.trim();
          if (reason == null || reason.isEmpty) return chip;
          return WantedReasonChip(chip: chip, reason: reason);
        }).toList(),
    );
  }
}
