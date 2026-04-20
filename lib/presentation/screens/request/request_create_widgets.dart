import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moniq/core/utils/color_utils.dart';
import 'package:moniq/data/models/roster_entry.dart';
import 'package:moniq/data/models/shift_type_model.dart';
import 'package:moniq/data/models/shift_with_type.dart';
import 'package:moniq/data/providers/shift_providers.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';

/// 1:N 교환의 한 항목 — (대상 팀원, 그 사람의 그 날의 근무).
class MultiSwapItem {
  const MultiSwapItem({
    required this.userId,
    required this.userName,
    required this.date,
    required this.shiftTypeId,
    required this.shiftTypeName,
    required this.shiftCode,
  });

  final String userId;
  final String userName;
  final DateTime date;
  final String shiftTypeId;
  final String shiftTypeName;
  final String shiftCode;
}

/// 근무 변경 섹션 — 현재 내 근무 + 변경할 근무 유형 선택
class RequestCreateShiftChangeSection extends StatelessWidget {
  const RequestCreateShiftChangeSection({
    super.key,
    required this.isLoading,
    required this.myShiftTypeName,
    required this.shiftTypes,
    required this.selectedShiftTypeId,
    required this.onShiftTypeSelected,
  });

  final bool isLoading;
  final String? myShiftTypeName;
  final List<ShiftTypeModel> shiftTypes;
  final String? selectedShiftTypeId;
  /// nullable — 같은 칩을 다시 누르면 null로 호출되어 선택 해제됨
  final ValueChanged<String?> onShiftTypeSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 현재 내 근무
        Text(
          '현재 내 근무',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: AppRadius.borderRadiusMd,
          ),
          child: Text(
            myShiftTypeName ?? '해당 날짜에 배정된 근무가 없습니다',
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: myShiftTypeName != null
                  ? null
                  : colorScheme.onSurfaceVariant,
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.lg),

        // 변경할 근무 유형 선택
        Text(
          '변경할 근무 유형',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: shiftTypes.map((st) {
            final color = parseHexColor(st.color);
            final selected = selectedShiftTypeId == st.id;
            return ChoiceChip(
              avatar: CircleAvatar(
                backgroundColor: color,
                radius: 8,
              ),
              label: Text(st.name),
              selected: selected,
              onSelected: (_) =>
                  onShiftTypeSelected(selected ? null : st.id),
              selectedColor: color.withValues(alpha: 0.2),
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// 근무 교환 섹션.
/// 1:1 (one): 변경 전(본인 현재) + 변경 후 유형 + 같은 날 후보 1명 선택
/// 1:N (many): 변경 후 유형 + 추천 교환(룰 위반 0건) + 교환 항목 다중 추가
class RequestCreateSwapSection extends ConsumerStatefulWidget {
  const RequestCreateSwapSection({
    super.key,
    required this.isLoading,
    required this.myShiftTypeName,
    required this.roster,
    required this.shiftTypes,
    required this.myUserId,
    required this.teamId,
    required this.desiredShiftTypeId,
    required this.onDesiredShiftTypeSelected,
    required this.swapMode,
    required this.onSwapModeChanged,
    required this.selectedSwapUserId,
    required this.selectedSwapUserName,
    required this.selectedSwapUserIds,
    required this.onSwapUserSelected,
    required this.multiSwapItems,
    required this.onMultiItemAdded,
    required this.onMultiItemRemoved,
  });

  final bool isLoading;
  final String? myShiftTypeName;
  final List<RosterEntry> roster;
  final List<ShiftTypeModel> shiftTypes;
  final String? myUserId;
  final String teamId;
  final String? desiredShiftTypeId;
  final ValueChanged<String?> onDesiredShiftTypeSelected;
  final String swapMode; // 'one' | 'many'
  final ValueChanged<String> onSwapModeChanged;
  final String? selectedSwapUserId;
  final String? selectedSwapUserName;
  final Set<String> selectedSwapUserIds;
  final void Function(String? userId, String? userName) onSwapUserSelected;
  final List<MultiSwapItem> multiSwapItems;
  final void Function(MultiSwapItem) onMultiItemAdded;
  final void Function(int index) onMultiItemRemoved;

  @override
  ConsumerState<RequestCreateSwapSection> createState() =>
      _RequestCreateSwapSectionState();
}

class _RequestCreateSwapSectionState
    extends ConsumerState<RequestCreateSwapSection> {
  /// 룰 기반 추천 결과 (1:N 모드 + desired 유형 선택 시 자동 계산)
  List<MultiSwapItem> _suggestions = [];
  bool _suggesting = false;

  // helper accessors
  bool get isLoading => widget.isLoading;
  String? get myShiftTypeName => widget.myShiftTypeName;
  List<RosterEntry> get roster => widget.roster;
  List<ShiftTypeModel> get shiftTypes => widget.shiftTypes;
  String? get myUserId => widget.myUserId;
  String get teamId => widget.teamId;
  String? get desiredShiftTypeId => widget.desiredShiftTypeId;
  ValueChanged<String?> get onDesiredShiftTypeSelected =>
      widget.onDesiredShiftTypeSelected;
  String get swapMode => widget.swapMode;
  ValueChanged<String> get onSwapModeChanged => widget.onSwapModeChanged;
  String? get selectedSwapUserId => widget.selectedSwapUserId;
  String? get selectedSwapUserName => widget.selectedSwapUserName;
  Set<String> get selectedSwapUserIds => widget.selectedSwapUserIds;
  void Function(String?, String?) get onSwapUserSelected =>
      widget.onSwapUserSelected;
  List<MultiSwapItem> get multiSwapItems => widget.multiSwapItems;
  void Function(MultiSwapItem) get onMultiItemAdded => widget.onMultiItemAdded;
  void Function(int) get onMultiItemRemoved => widget.onMultiItemRemoved;

  @override
  void didUpdateWidget(covariant RequestCreateSwapSection old) {
    super.didUpdateWidget(old);
    if (swapMode == 'many' &&
        desiredShiftTypeId != null &&
        (old.desiredShiftTypeId != desiredShiftTypeId ||
            old.swapMode != swapMode)) {
      _computeSuggestions();
    }
  }

  /// 룰 기반 추천: 본인 currentCode 날짜마다 desired 유형 근무자 중 안전한 1명.
  void _computeSuggestions() {
    setState(() => _suggesting = true);
    final monthly = ref
        .read(shiftRepositoryProvider); // not used directly; need monthlyShifts
    // monthlyShifts는 viewmodel에 있으나 변경 요청 화면에선 직접 로드하지 않으므로
    // shift_repository.getTeamMonthlyShifts 호출
    _loadSuggestionsAsync();
    monthly; // suppress warning
  }

  Future<void> _loadSuggestionsAsync() async {
    try {
      final desiredId = desiredShiftTypeId;
      final me = myUserId;
      if (desiredId == null || me == null) {
        if (mounted) {
          setState(() {
            _suggestions = [];
            _suggesting = false;
          });
        }
        return;
      }
      final desired = shiftTypes.firstWhere((t) => t.id == desiredId);
      final desiredCode = _shortCode(desired.code, desired.name);

      // 본인의 현재 근무 유형 추정 (myShiftTypeName 기반)
      final myCurrentType = shiftTypes
          .where((t) => t.name == myShiftTypeName)
          .cast<ShiftTypeModel?>()
          .firstWhere((_) => true, orElse: () => null);
      if (myCurrentType == null) {
        if (mounted) {
          setState(() {
            _suggestions = [];
            _suggesting = false;
          });
        }
        return;
      }
      final myCode = _shortCode(myCurrentType.code, myCurrentType.name);

      // 현재 월의 monthlyShifts 로드 — 이번 달 기준
      final now = DateTime.now();
      final repo = ref.read(shiftRepositoryProvider);
      final monthly =
          await repo.getTeamMonthlyShifts(teamId: teamId, month: now);

      // 일별 코드 맵: userId → date → code
      final byUserDate = <String, Map<DateTime, String>>{};
      for (final entry in monthly.entries) {
        for (final s in entry.value) {
          final code = _shortCode(s.shiftType.code, s.shiftType.name);
          byUserDate.putIfAbsent(s.shift.userId, () => {})[entry.key] = code;
        }
      }

      // 본인의 myCode 날짜 목록
      final myDates = <DateTime>[];
      for (final entry in monthly.entries) {
        for (final s in entry.value) {
          if (s.shift.userId != me) continue;
          final code = _shortCode(s.shiftType.code, s.shiftType.name);
          if (code == myCode) myDates.add(entry.key);
        }
      }

      final out = <MultiSwapItem>[];
      for (final d in myDates) {
        // 그 날 desired 유형 근무자 후보들
        final candidates = (monthly[d] ?? const <ShiftWithType>[])
            .where((s) {
          final c = _shortCode(s.shiftType.code, s.shiftType.name);
          return c == desiredCode && s.shift.userId != me;
        }).toList();
        if (candidates.isEmpty) continue;

        // 가장 안전한 후보 1명 선정 (룰 위반 0건 우선)
        ShiftWithType? best;
        int bestViols = 999;
        for (final s in candidates) {
          final mySim =
              Map<DateTime, String>.from(byUserDate[me] ?? {});
          mySim[d] = desiredCode;
          final otherSim =
              Map<DateTime, String>.from(byUserDate[s.shift.userId] ?? {});
          otherSim[d] = myCode;
          final v = _findViolations(mySim, d) +
              _findViolations(otherSim, d);
          if (v < bestViols) {
            bestViols = v;
            best = s;
          }
        }
        if (best == null || bestViols > 0) continue;
        // 본인이 추가 자동 추출 — 표시 이름은 monthly에 없으므로 roster fallback or user_id 일부
        final displayName =
            _resolveName(best.shift.userId);
        out.add(MultiSwapItem(
          userId: best.shift.userId,
          userName: displayName,
          date: d,
          shiftTypeId: best.shiftType.id,
          shiftTypeName: best.shiftType.name,
          shiftCode: best.shiftType.code,
        ));
      }

      if (mounted) {
        setState(() {
          _suggestions = out;
          _suggesting = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _suggestions = [];
          _suggesting = false;
        });
      }
    }
  }

  /// 같은 날짜 ±2일 시퀀스 룰 위반 카운트 (N→D, NOD, E→D)
  int _findViolations(Map<DateTime, String> codes, DateTime changedDate) {
    String? at(DateTime d) =>
        codes[DateTime(d.year, d.month, d.day)];
    int viols = 0;
    for (int offset = -1; offset <= 2; offset++) {
      final d = changedDate.add(Duration(days: offset));
      final today = at(d);
      final yesterday = at(d.subtract(const Duration(days: 1)));
      final dayBefore = at(d.subtract(const Duration(days: 2)));
      if (today == null) continue;
      if (yesterday == 'N' && today == 'D') viols++;
      if (dayBefore == 'N' && yesterday == null && today == 'D') viols++;
      if (yesterday == 'E' && today == 'D') viols++;
    }
    return viols;
  }

  String _shortCode(String code, String name) {
    final c = code.toUpperCase();
    if (c == 'D' || name.contains('데이') || name.toLowerCase().contains('day')) {
      return 'D';
    }
    if (c == 'E' || name.contains('이브닝')) return 'E';
    if (c == 'N' || name.contains('나이트') || name.contains('야간')) return 'N';
    return c;
  }

  /// roster에서 user_id → displayName 시도, 없으면 user_id 앞 6자
  String _resolveName(String userId) {
    for (final entry in roster) {
      for (final w in entry.workers) {
        if (w.user.id == userId) {
          return w.user.displayName ?? w.user.email;
        }
      }
    }
    return userId.length > 6 ? userId.substring(0, 6) : userId;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 교환 모드 (1:1 / 1:N) ──
        Text('교환 모드',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            ChoiceChip(
              label: const Text('1:1 교환'),
              selected: swapMode == 'one',
              onSelected: (_) {
                if (swapMode != 'one') onSwapModeChanged('one');
              },
            ),
            ChoiceChip(
              label: const Text('1:N 일괄 교환'),
              selected: swapMode == 'many',
              onSelected: (_) {
                if (swapMode != 'many') onSwapModeChanged('many');
              },
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),

        // ── 변경 전: 현재 내 근무 ──
        Text('변경 전 (현재 근무)',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: AppSpacing.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: AppRadius.borderRadiusMd,
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.work_outline,
                  color: theme.colorScheme.onSurfaceVariant, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Text(
                myShiftTypeName ?? '해당 날짜에 배정된 근무가 없습니다',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: myShiftTypeName == null
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        // ── 변경 후: 원하는 근무 유형 ──
        Text('변경 후 (희망 근무 유형)',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: shiftTypes.map((t) {
            final color = parseHexColor(t.color);
            final selected = desiredShiftTypeId == t.id;
            return ChoiceChip(
              avatar: CircleAvatar(
                backgroundColor: color,
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
              selected: selected,
              onSelected: (_) =>
                  onDesiredShiftTypeSelected(selected ? null : t.id),
              selectedColor: color.withValues(alpha: 0.2),
            );
          }).toList(),
        ),

        // ── 1:N 추천 교환 (룰 기반) ──
        if (swapMode == 'many' && desiredShiftTypeId != null) ...[
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Icon(Icons.auto_awesome,
                  size: 18, color: colorScheme.primary),
              const SizedBox(width: AppSpacing.xs),
              Text('추천 교환',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '본인 ${myShiftTypeName ?? "근무"}를 변경하기 위해 팀 근무 규칙 위반 없이 교환 가능한 후보입니다',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (_suggesting)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_suggestions.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: AppRadius.borderRadiusMd,
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                '안전한 교환 후보를 찾지 못했습니다',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            )
          else
            Column(
              children: [
                for (final s in _suggestions)
                  _SuggestionTile(
                    item: s,
                    alreadyAdded: multiSwapItems.any(
                        (e) => e.userId == s.userId && e.date == s.date),
                    onAdd: () => onMultiItemAdded(s),
                  ),
                const SizedBox(height: AppSpacing.xs),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      for (final s in _suggestions) {
                        final dup = multiSwapItems.any(
                            (e) => e.userId == s.userId && e.date == s.date);
                        if (!dup) onMultiItemAdded(s);
                      }
                    },
                    icon: const Icon(Icons.playlist_add, size: 18),
                    label: const Text('전체 추가'),
                  ),
                ),
              ],
            ),
        ],

        // ── 1:N 교환 항목 ──
        if (swapMode == 'many') ...[
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Text('교환 항목',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _showAddMultiItemDialog(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('추가'),
              ),
            ],
          ),
          if (multiSwapItems.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              margin: const EdgeInsets.only(top: AppSpacing.sm),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: AppRadius.borderRadiusMd,
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                '+ 추가 버튼으로 교환할 (팀원 / 날짜 / 근무) 항목을 추가하세요',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Column(
                children: [
                  for (int i = 0; i < multiSwapItems.length; i++)
                    _MultiItemTile(
                      item: multiSwapItems[i],
                      onRemove: () => onMultiItemRemoved(i),
                    ),
                ],
              ),
            ),
        ],

        // ── 수동 선택: 전체 로스터 (1:1 모드만) ──
        if (swapMode == 'one') ...[
        const SizedBox(height: AppSpacing.xl),
        Text('직접 선택 (전체 로스터)',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '해당 날짜의 모든 근무자에서 직접 교환 상대를 고를 수 있습니다',
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondaryLight,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (roster.isEmpty)
          Text(
            '해당 날짜에 배정된 근무가 없습니다',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          )
        else
          // 1:1 모드 + 희망 유형 선택됐으면 해당 유형 그룹만 노출.
          // 1:N 모드는 모든 그룹 노출 (다양한 후보 선택 가능).
          ...roster
              .where((entry) =>
                  swapMode != 'one' ||
                  desiredShiftTypeId == null ||
                  entry.shiftType.id == desiredShiftTypeId)
              .map((entry) {
            final color = parseHexColor(entry.shiftType.color);
            // 같은 user_id 중복 제거 — 같은 그룹 안에 한 사용자가 여러 RosterWorker로 들어와 있을 수 있음
            final seenIds = <String>{};
            final otherWorkers = entry.workers
                .where((w) => w.user.id != myUserId)
                .where((w) => seenIds.add(w.user.id))
                .toList();
            if (otherWorkers.isEmpty) return const SizedBox.shrink();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: AppRadius.borderRadiusSm,
                      ),
                      child: Center(
                        child: Text(
                          entry.shiftType.code,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.surface,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      entry.shiftType.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Padding(
                  padding: const EdgeInsets.only(left: 32),
                  child: Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: otherWorkers.map((w) {
                      final name = w.user.displayName ?? w.user.email;
                      final isSelected = swapMode == 'many'
                          ? selectedSwapUserIds.contains(w.user.id)
                          : selectedSwapUserId == w.user.id;
                      return ChoiceChip(
                        label: Text(name),
                        selected: isSelected,
                        onSelected: (_) {
                          if (swapMode == 'many') {
                            onSwapUserSelected(w.user.id, name);
                          } else {
                            isSelected
                                ? onSwapUserSelected(null, null)
                                : onSwapUserSelected(w.user.id, name);
                          }
                        },
                        selectedColor:
                            color.withValues(alpha: 0.2),
                        avatar: isSelected
                            ? Icon(
                                Icons.check,
                                size: 16,
                                color: color,
                              )
                            : null,
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            );
          }),

        if (selectedSwapUserName != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: AppRadius.borderRadiusMd,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.swap_horiz,
                  color: colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    '$selectedSwapUserName 님과 근무 교환 요청',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        ], // close: if (swapMode == 'one') 직접 선택 + 선택 미리보기
      ],
    );
  }

  /// 1:N 모드 — 항목 추가 다이얼로그.
  /// 날짜 선택 → 그 날짜의 전체 근무자(모든 그룹) 목록 → 선택 → 항목 추가.
  Future<void> _showAddMultiItemDialog(BuildContext context) async {
    final picked = await showDialog<MultiSwapItem>(
      context: context,
      builder: (ctx) => _AddMultiItemDialog(
        teamId: teamId,
        myUserId: myUserId,
      ),
    );
    if (picked != null) {
      onMultiItemAdded(picked);
    }
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({
    required this.item,
    required this.alreadyAdded,
    required this.onAdd,
  });

  final MultiSwapItem item;
  final bool alreadyAdded;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final color = _codeColor(item.shiftCode);
    final dateLabel = DateFormat('M/d (E)', 'ko_KR').format(item.date);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xxs),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.18),
        borderRadius: AppRadius.borderRadiusMd,
        border: Border.all(
          color: cs.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color,
            radius: 14,
            child: Text(item.shiftCode,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                )),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.userName,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                Text('$dateLabel · ${item.shiftTypeName}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          if (alreadyAdded)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Icon(Icons.check_circle,
                  size: 18, color: cs.primary),
            )
          else
            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 22),
              color: cs.primary,
              tooltip: '추가',
              onPressed: onAdd,
            ),
        ],
      ),
    );
  }

  Color _codeColor(String code) {
    switch (code.toUpperCase()) {
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

class _MultiItemTile extends StatelessWidget {
  const _MultiItemTile({required this.item, required this.onRemove});
  final MultiSwapItem item;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final dateLabel = DateFormat('M/d (E)', 'ko_KR').format(item.date);
    final color = _codeColor(item.shiftCode);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: AppRadius.borderRadiusMd,
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color,
            radius: 14,
            child: Text(item.shiftCode,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                )),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.userName,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                Text('$dateLabel · ${item.shiftTypeName}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }

  Color _codeColor(String code) {
    switch (code.toUpperCase()) {
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

/// 1:N 항목 추가 다이얼로그 — 날짜 선택 + 그 날짜의 desired 유형 팀원 선택.
class _AddMultiItemDialog extends ConsumerStatefulWidget {
  const _AddMultiItemDialog({
    required this.teamId,
    required this.myUserId,
  });

  final String teamId;
  final String? myUserId;

  @override
  ConsumerState<_AddMultiItemDialog> createState() =>
      _AddMultiItemDialogState();
}

class _AddMultiItemDialogState extends ConsumerState<_AddMultiItemDialog> {
  DateTime? _date;
  List<RosterEntry> _roster = [];
  bool _loading = false;
  String? _selectedUserId;
  String? _selectedUserName;
  String? _selectedShiftTypeId;
  String? _selectedShiftTypeName;
  String? _selectedShiftCode;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (picked == null) return;
    setState(() {
      _date = picked;
      _selectedUserId = null;
      _selectedUserName = null;
      _selectedShiftTypeId = null;
      _selectedShiftTypeName = null;
      _selectedShiftCode = null;
      _loading = true;
    });
    try {
      final shiftRepo = ref.read(shiftRepositoryProvider);
      final r = await shiftRepo.getTeamRoster(
        teamId: widget.teamId,
        date: picked,
      );
      if (mounted) {
        setState(() {
          _roster = r;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // 그 날짜의 모든 그룹 표시 (Off 제외, 본인 제외, dedupe)
    final groupEntries = <RosterEntry>[];
    if (_date != null) {
      for (final entry in _roster) {
        if (entry.shiftType.id == '_off') continue;
        groupEntries.add(entry);
      }
    }

    return AlertDialog(
      title: const Text('교환 항목 추가'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(_date == null
                    ? '날짜 선택'
                    : DateFormat('yyyy년 M월 d일 (E)', 'ko_KR').format(_date!)),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_date == null)
                Text('날짜를 먼저 선택하세요',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant))
              else if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (groupEntries.isEmpty)
                Text('해당 날짜에 배정된 근무가 없습니다',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant))
              else
                ...groupEntries.map((entry) {
                  final color = parseHexColor(entry.shiftType.color);
                  final seen = <String>{};
                  final workers = entry.workers
                      .where((w) => w.user.id != widget.myUserId)
                      .where((w) => seen.add(w.user.id))
                      .toList();
                  if (workers.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: color,
                              radius: 12,
                              child: Text(entry.shiftType.code,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10,
                                  )),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(entry.shiftType.name,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                )),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Padding(
                          padding: const EdgeInsets.only(left: 32),
                          child: Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.xs,
                            children: workers.map((w) {
                              final name =
                                  w.user.displayName ?? w.user.email;
                              final isSel = _selectedUserId == w.user.id &&
                                  _selectedShiftTypeId == entry.shiftType.id;
                              return ChoiceChip(
                                label: Text(name),
                                selected: isSel,
                                onSelected: (_) {
                                  setState(() {
                                    if (isSel) {
                                      _selectedUserId = null;
                                      _selectedUserName = null;
                                      _selectedShiftTypeId = null;
                                      _selectedShiftTypeName = null;
                                      _selectedShiftCode = null;
                                    } else {
                                      _selectedUserId = w.user.id;
                                      _selectedUserName = name;
                                      _selectedShiftTypeId =
                                          entry.shiftType.id;
                                      _selectedShiftTypeName =
                                          entry.shiftType.name;
                                      _selectedShiftCode =
                                          entry.shiftType.code;
                                    }
                                  });
                                },
                                selectedColor:
                                    color.withValues(alpha: 0.25),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: (_date == null ||
                  _selectedUserId == null ||
                  _selectedShiftTypeId == null)
              ? null
              : () {
                  Navigator.pop(
                    context,
                    MultiSwapItem(
                      userId: _selectedUserId!,
                      userName: _selectedUserName ?? '',
                      date: _date!,
                      shiftTypeId: _selectedShiftTypeId!,
                      shiftTypeName: _selectedShiftTypeName ?? '',
                      shiftCode: _selectedShiftCode ?? '',
                    ),
                  );
                },
          child: const Text('추가'),
        ),
      ],
    );
  }
}
