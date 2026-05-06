import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moniq/core/utils/color_utils.dart';
import 'package:moniq/data/models/shift_type_model.dart';
import 'package:moniq/data/models/team_member_with_user.dart';
import 'package:moniq/data/providers/shift_providers.dart';
import 'package:moniq/data/providers/team_providers.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';

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

/// 한 건의 swap 요청 정보 (다중 등록용).
class SwapEntry {
  SwapEntry({this.userId, this.userName, this.date});

  String? userId;
  String? userName;
  DateTime? date;

  /// 본인이 해당 날짜에 현재 배정된 근무 (AS-IS — 내 현재 근무)
  ShiftTypeModel? myCurrentShiftType;

  /// 선택된 팀원이 해당 날짜에 현재 배정된 근무 (드롭박스 기본값으로 사용)
  ShiftTypeModel? targetCurrentShiftType;

  /// 변경할 근무(TO-BE) — 드롭박스에서 선택한 값. 기본값은 targetCurrentShiftType.
  ShiftTypeModel? desiredShiftType;

  bool get isComplete =>
      userId != null && date != null && desiredShiftType != null;
}

/// 다중 근무 교환 요청 섹션 — 한 건씩 행으로 추가하여 N건을 한 번에 제출.
class SwapEntriesSection extends ConsumerStatefulWidget {
  const SwapEntriesSection({
    super.key,
    required this.teamId,
    required this.myUserId,
    required this.entries,
    required this.onChanged,
  });

  final String teamId;
  final String? myUserId;
  final List<SwapEntry> entries;
  final VoidCallback onChanged;

  @override
  ConsumerState<SwapEntriesSection> createState() =>
      _SwapEntriesSectionState();
}

class _SwapEntriesSectionState extends ConsumerState<SwapEntriesSection> {
  List<TeamMemberWithUser> _members = [];
  bool _loadingMembers = false;
  List<ShiftTypeModel> _shiftTypes = [];

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() => _loadingMembers = true);
    try {
      final teamRepo = ref.read(teamRepositoryProvider);
      final shiftRepo = ref.read(shiftRepositoryProvider);
      final results = await Future.wait([
        teamRepo.getTeamMembersWithUsers(widget.teamId),
        shiftRepo.getShiftTypes(widget.teamId),
      ]);
      if (!mounted) return;
      setState(() {
        _members = (results[0] as List<TeamMemberWithUser>)
            .where((m) => m.userId != widget.myUserId)
            .toList();
        _shiftTypes = (results[1] as List<ShiftTypeModel>)
            .where((t) => t.isActive)
            .toList();
        _loadingMembers = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMembers = false);
    }
  }

  /// 선택된 entry의 날짜 기준 본인/대상자 현재 근무를 조회 후 entry에 채움
  Future<void> _resolveShifts(SwapEntry entry) async {
    final me = widget.myUserId;
    final date = entry.date;
    final targetUserId = entry.userId;
    if (me == null || date == null || targetUserId == null) return;

    try {
      final shiftRepo = ref.read(shiftRepositoryProvider);
      final roster =
          await shiftRepo.getTeamRoster(teamId: widget.teamId, date: date);

      ShiftTypeModel? mine;
      ShiftTypeModel? target;
      for (final entryRoster in roster) {
        if (entryRoster.shiftType.id == '_off') continue;
        for (final w in entryRoster.workers) {
          if (w.user.id == me) mine = entryRoster.shiftType;
          if (w.user.id == targetUserId) target = entryRoster.shiftType;
        }
      }

      if (!mounted) return;
      setState(() {
        entry.myCurrentShiftType = mine;
        entry.targetCurrentShiftType = target;
      });
      widget.onChanged();
    } catch (_) {
      // ignore
    }
  }

  Future<void> _pickDate(SwapEntry entry) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: entry.date ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
    );
    if (picked == null) return;
    setState(() {
      entry.date = picked;
      entry.myCurrentShiftType = null;
      entry.targetCurrentShiftType = null;
      entry.desiredShiftType = null;
    });
    widget.onChanged();
    await _resolveShifts(entry);
  }

  void _selectMember(SwapEntry entry, TeamMemberWithUser? member) {
    setState(() {
      entry.userId = member?.userId;
      entry.userName = member?.displayName;
      entry.myCurrentShiftType = null;
      entry.targetCurrentShiftType = null;
      entry.desiredShiftType = null;
    });
    widget.onChanged();
    if (member != null && entry.date != null) {
      _resolveShifts(entry);
    }
  }

  void _selectShift(SwapEntry entry, ShiftTypeModel? shift) {
    setState(() => entry.desiredShiftType = shift);
    widget.onChanged();
  }

  void _addEntry() {
    setState(() => widget.entries.add(SwapEntry()));
    widget.onChanged();
  }

  void _removeEntry(int index) {
    setState(() => widget.entries.removeAt(index));
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (_loadingMembers) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_members.isEmpty) {
      return Text(
        '다른 팀원이 없습니다',
        style:
            theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
      );
    }

    final lastComplete =
        widget.entries.isNotEmpty && widget.entries.last.isComplete;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < widget.entries.length; i++) ...[
          _SwapEntryRow(
            entry: widget.entries[i],
            members: _members,
            shiftTypes: _shiftTypes,
            index: i,
            canRemove: widget.entries.length > 1,
            onMemberSelected: (m) =>
                _selectMember(widget.entries[i], m),
            onPickDate: () => _pickDate(widget.entries[i]),
            onShiftSelected: (s) =>
                _selectShift(widget.entries[i], s),
            onRemove: () => _removeEntry(i),
          ),
          if (i < widget.entries.length - 1)
            const SizedBox(height: AppSpacing.md),
        ],
        const SizedBox(height: AppSpacing.md),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: lastComplete ? _addEntry : null,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('교환 요청 추가'),
          ),
        ),
      ],
    );
  }
}

class _SwapEntryRow extends StatelessWidget {
  const _SwapEntryRow({
    required this.entry,
    required this.members,
    required this.shiftTypes,
    required this.index,
    required this.canRemove,
    required this.onMemberSelected,
    required this.onPickDate,
    required this.onShiftSelected,
    required this.onRemove,
  });

  final SwapEntry entry;
  final List<TeamMemberWithUser> members;
  final List<ShiftTypeModel> shiftTypes;
  final int index;
  final bool canRemove;
  final ValueChanged<TeamMemberWithUser?> onMemberSelected;
  final VoidCallback onPickDate;
  final ValueChanged<ShiftTypeModel?> onShiftSelected;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: AppRadius.borderRadiusMd,
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                '#${index + 1}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (canRemove)
                IconButton(
                  icon: Icon(Icons.close_rounded,
                      size: 18, color: cs.onSurfaceVariant),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(),
                  onPressed: onRemove,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 팀원
              Expanded(
                flex: 4,
                child: _LabeledField(
                  label: '팀원',
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      isDense: true,
                      hint: const Text('선택', style: TextStyle(fontSize: 13)),
                      value: entry.userId,
                      items: members
                          .map((m) => DropdownMenuItem<String>(
                                value: m.userId,
                                child: Text(
                                  m.displayName,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ))
                          .toList(),
                      onChanged: (id) {
                        final m = id == null
                            ? null
                            : members.firstWhere((m) => m.userId == id);
                        onMemberSelected(m);
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // 날짜
              Expanded(
                flex: 4,
                child: _LabeledField(
                  label: '날짜',
                  child: InkWell(
                    onTap: onPickDate,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today,
                              size: 13, color: cs.primary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              entry.date != null
                                  ? DateFormat('M/d (E)', 'ko_KR')
                                      .format(entry.date!)
                                  : '선택',
                              style: TextStyle(
                                fontSize: 13,
                                color: entry.date != null
                                    ? null
                                    : cs.onSurfaceVariant,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // 변경 근무 (TO-BE)
              Expanded(
                flex: 4,
                child: _LabeledField(
                  label: '변경 근무',
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      isDense: true,
                      hint: const Text('선택', style: TextStyle(fontSize: 13)),
                      value: entry.desiredShiftType?.id,
                      items: shiftTypes.map((t) {
                        final color = parseHexColor(t.color);
                        return DropdownMenuItem<String>(
                          value: t.id,
                          child: Row(
                            children: [
                              Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  t.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: entry.userId != null && entry.date != null
                          ? (id) {
                              final s = id == null
                                  ? null
                                  : shiftTypes
                                      .firstWhere((t) => t.id == id);
                              onShiftSelected(s);
                            }
                          : null,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (entry.userId != null && entry.date != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _CurrentShiftLine(shift: entry.myCurrentShiftType),
          ],
        ],
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        child,
      ],
    );
  }
}

/// 현재 등록된 본인 근무를 한 줄로 컴팩트하게 표시.
class _CurrentShiftLine extends StatelessWidget {
  const _CurrentShiftLine({required this.shift});
  final ShiftTypeModel? shift;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (shift == null) {
      return Text(
        '현재 근무: 없음',
        style: theme.textTheme.bodySmall?.copyWith(
          color: cs.onSurfaceVariant,
          fontSize: 12,
        ),
      );
    }
    final color = parseHexColor(shift!.color);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '현재 근무: ',
          style: theme.textTheme.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
          alignment: Alignment.center,
          child: Text(
            shift!.code,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          shift!.name,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

/// (Deprecated) 기존 단일 swap 섹션 — 호환성 유지용으로 남겨둠.
class RequestCreateSwapSection extends ConsumerStatefulWidget {
  const RequestCreateSwapSection({
    super.key,
    required this.teamId,
    required this.myUserId,
    required this.selectedSwapUserId,
    required this.selectedSwapUserName,
    required this.onSwapUserSelected,
    required this.requestedDate,
    required this.onDateSelected,
    required this.desiredShiftTypeId,
    required this.onDesiredShiftTypeSelected,
  });

  final String teamId;
  final String? myUserId;

  final String? selectedSwapUserId;
  final String? selectedSwapUserName;
  final void Function(String? userId, String? userName) onSwapUserSelected;

  final DateTime? requestedDate;
  final ValueChanged<DateTime> onDateSelected;

  final String? desiredShiftTypeId;
  final ValueChanged<String?> onDesiredShiftTypeSelected;

  @override
  ConsumerState<RequestCreateSwapSection> createState() =>
      _RequestCreateSwapSectionState();
}

class _RequestCreateSwapSectionState
    extends ConsumerState<RequestCreateSwapSection> {
  List<TeamMemberWithUser> _members = [];
  bool _loadingMembers = false;

  /// 선택된 날짜 기준 본인의 현재 근무 유형 id (드롭박스 기본값).
  String? _myCurrentShiftTypeId;

  /// 선택된 날짜에 실제로 배정된 근무 유형들 (드롭박스 항목).
  List<ShiftTypeModel> _dateShiftTypes = [];
  bool _loadingRoster = false;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  @override
  void didUpdateWidget(covariant RequestCreateSwapSection old) {
    super.didUpdateWidget(old);
    final dateChanged = old.requestedDate != widget.requestedDate;
    final userChanged = old.selectedSwapUserId != widget.selectedSwapUserId;
    if (widget.selectedSwapUserId != null &&
        widget.requestedDate != null &&
        (dateChanged || userChanged)) {
      _loadRosterForDate();
    }
  }

  Future<void> _loadMembers() async {
    setState(() => _loadingMembers = true);
    try {
      final repo = ref.read(teamRepositoryProvider);
      final members = await repo.getTeamMembersWithUsers(widget.teamId);
      if (!mounted) return;
      setState(() {
        _members =
            members.where((m) => m.userId != widget.myUserId).toList();
        _loadingMembers = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMembers = false);
    }
  }

  Future<void> _loadRosterForDate() async {
    final date = widget.requestedDate;
    final me = widget.myUserId;
    if (date == null || me == null) return;

    setState(() {
      _loadingRoster = true;
      _myCurrentShiftTypeId = null;
      _dateShiftTypes = [];
    });

    try {
      final shiftRepo = ref.read(shiftRepositoryProvider);
      final roster =
          await shiftRepo.getTeamRoster(teamId: widget.teamId, date: date);

      String? myShiftTypeId;
      final shiftTypes = <ShiftTypeModel>[];
      final seen = <String>{};
      for (final entry in roster) {
        if (entry.shiftType.id == '_off') continue;
        if (seen.add(entry.shiftType.id)) {
          shiftTypes.add(entry.shiftType);
        }
        for (final w in entry.workers) {
          if (w.user.id == me) {
            myShiftTypeId = entry.shiftType.id;
            break;
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _myCurrentShiftTypeId = myShiftTypeId;
        _dateShiftTypes = shiftTypes;
        _loadingRoster = false;
      });

      // 드롭박스 기본값: 본인 현재 근무. 없으면 첫 번째 항목.
      final fallback = myShiftTypeId ??
          (shiftTypes.isNotEmpty ? shiftTypes.first.id : null);
      if (fallback != null && widget.desiredShiftTypeId != fallback) {
        widget.onDesiredShiftTypeSelected(fallback);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingRoster = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.requestedDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
    );
    if (picked != null) widget.onDateSelected(picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Step 1: 교환할 팀원 선택 ──
        Text(
          '교환할 팀원',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (_loadingMembers)
          const Center(child: CircularProgressIndicator())
        else if (_members.isEmpty)
          Text(
            '다른 팀원이 없습니다',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: cs.onSurfaceVariant),
          )
        else
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: _members.map((m) {
              final name = m.displayName;
              final selected = widget.selectedSwapUserId == m.userId;
              return ChoiceChip(
                label: Text(name),
                selected: selected,
                onSelected: (_) {
                  if (selected) {
                    widget.onSwapUserSelected(null, null);
                  } else {
                    widget.onSwapUserSelected(m.userId, name);
                  }
                },
                selectedColor: cs.primary.withValues(alpha: 0.15),
                avatar: selected
                    ? Icon(Icons.check, size: 16, color: cs.primary)
                    : null,
              );
            }).toList(),
          ),

        // ── Step 2: 근무 변경 날짜 선택 ──
        if (widget.selectedSwapUserId != null) ...[
          const SizedBox(height: AppSpacing.xl),
          Text(
            '근무 변경 날짜',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.sm),
          InkWell(
            onTap: _pickDate,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                border: Border.all(color: cs.outlineVariant),
                borderRadius: AppRadius.borderRadiusMd,
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, size: 20, color: cs.primary),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    widget.requestedDate != null
                        ? DateFormat('yyyy년 MM월 dd일 (E)', 'ko_KR')
                            .format(widget.requestedDate!)
                        : '날짜를 선택해주세요',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: widget.requestedDate != null
                          ? null
                          : cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        // ── Step 3: 변경할 근무 드롭박스 ──
        if (widget.selectedSwapUserId != null &&
            widget.requestedDate != null) ...[
          const SizedBox(height: AppSpacing.xl),
          Text(
            '변경할 근무',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (_loadingRoster)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_dateShiftTypes.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: AppRadius.borderRadiusMd,
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                '해당 날짜에 배정된 근무가 없습니다',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
              ),
              decoration: BoxDecoration(
                border: Border.all(color: cs.outlineVariant),
                borderRadius: AppRadius.borderRadiusMd,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _dateShiftTypes.any(
                          (t) => t.id == widget.desiredShiftTypeId)
                      ? widget.desiredShiftTypeId
                      : _myCurrentShiftTypeId,
                  items: _dateShiftTypes.map((t) {
                    final color = parseHexColor(t.color);
                    return DropdownMenuItem<String>(
                      value: t.id,
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: color,
                            radius: 10,
                            child: Text(
                              t.code,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(t.name),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) =>
                      widget.onDesiredShiftTypeSelected(value),
                ),
              ),
            ),
          if (_myCurrentShiftTypeId == null &&
              !_loadingRoster &&
              _dateShiftTypes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                '해당 날짜에 본인 배정된 근무가 없습니다',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
        ],
      ],
    );
  }
}
