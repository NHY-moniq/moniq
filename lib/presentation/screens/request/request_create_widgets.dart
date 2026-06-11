import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moniq/core/utils/color_utils.dart';
import 'package:moniq/data/models/shift_type_model.dart';
import 'package:moniq/data/models/team_member_with_user.dart';
import 'package:moniq/data/providers/shift_providers.dart';
import 'package:moniq/data/providers/team_providers.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/widgets/common/moniq_bottom_sheet.dart';

/// 한 건의 "내 근무 변경" 요청 (다중 등록용).
///
/// 날짜 + 변경 근무(TO-BE) 2개 필드로 구성된다.
/// `desiredShiftType.id == '_off'` 이면 휴무 요청(day_off)으로 처리한다.
class SelfChangeEntry {
  SelfChangeEntry({this.date});

  DateTime? date;

  /// 본인이 해당 날짜에 현재 배정된 근무 (AS-IS — 안내용)
  ShiftTypeModel? myCurrentShiftType;

  /// 변경할 근무(TO-BE) — 드롭박스에서 선택한 값. OFF 포함.
  ShiftTypeModel? desiredShiftType;

  bool get isComplete => date != null && desiredShiftType != null;

  /// 변경할 근무가 OFF(휴무)인지
  bool get isOff =>
      desiredShiftType?.id == '_off' ||
      (desiredShiftType?.code.toUpperCase() == 'OFF');
}

/// 다중 "내 근무 변경" 요청 섹션 — 한 건씩 행으로 추가하여 N건을 한 번에 제출.
class SelfChangeEntriesSection extends ConsumerStatefulWidget {
  const SelfChangeEntriesSection({
    super.key,
    required this.teamId,
    required this.myUserId,
    required this.entries,
    required this.onChanged,
  });

  final String teamId;
  final String? myUserId;
  final List<SelfChangeEntry> entries;
  final VoidCallback onChanged;

  @override
  ConsumerState<SelfChangeEntriesSection> createState() =>
      _SelfChangeEntriesSectionState();
}

class _SelfChangeEntriesSectionState
    extends ConsumerState<SelfChangeEntriesSection> {
  bool _loading = false;
  List<ShiftTypeModel> _shiftTypes = [];

  /// 드롭박스 선택지로 노출할 OFF 합성 항목.
  static const ShiftTypeModel _offShiftType = ShiftTypeModel(
    id: '_off',
    teamId: '',
    name: '오프(휴무)',
    code: 'OFF',
    color: '#A0AEC0',
    displayOrder: 9999,
  );

  @override
  void initState() {
    super.initState();
    _loadShiftTypes();
  }

  Future<void> _loadShiftTypes() async {
    setState(() => _loading = true);
    try {
      final shiftRepo = ref.read(shiftRepositoryProvider);
      final types = await shiftRepo.getShiftTypes(widget.teamId);
      if (!mounted) return;
      setState(() {
        _shiftTypes = [
          ...types.where((t) => t.isActive),
          _offShiftType,
        ];
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resolveMyShift(SelfChangeEntry entry) async {
    final me = widget.myUserId;
    final date = entry.date;
    if (me == null || date == null) return;

    try {
      final shiftRepo = ref.read(shiftRepositoryProvider);
      final roster =
          await shiftRepo.getTeamRoster(teamId: widget.teamId, date: date);

      ShiftTypeModel? mine;
      for (final entryRoster in roster) {
        if (entryRoster.shiftType.id == '_off') continue;
        for (final w in entryRoster.workers) {
          if (w.user.id == me) {
            mine = entryRoster.shiftType;
            break;
          }
        }
        if (mine != null) break;
      }

      if (!mounted) return;
      setState(() => entry.myCurrentShiftType = mine);
      widget.onChanged();
    } catch (_) {
      // ignore
    }
  }

  Future<void> _pickDate(SelfChangeEntry entry) async {
    final now = DateTime.now();
    final picked = await _showDatePickerSheet(
      context,
      initial: entry.date ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
    );
    if (picked == null) return;
    setState(() {
      entry.date = picked;
      entry.myCurrentShiftType = null;
      entry.desiredShiftType = null;
    });
    widget.onChanged();
    await _resolveMyShift(entry);
  }

  void _selectShift(SelfChangeEntry entry, ShiftTypeModel? shift) {
    setState(() => entry.desiredShiftType = shift);
    widget.onChanged();
  }

  void _addEntry() {
    setState(() => widget.entries.add(SelfChangeEntry()));
    widget.onChanged();
  }

  void _removeEntry(int index) {
    setState(() => widget.entries.removeAt(index));
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final lastComplete =
        widget.entries.isNotEmpty && widget.entries.last.isComplete;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < widget.entries.length; i++) ...[
          _SelfChangeEntryRow(
            entry: widget.entries[i],
            shiftTypes: _shiftTypes,
            index: i,
            canRemove: widget.entries.length > 1,
            onPickDate: () => _pickDate(widget.entries[i]),
            onShiftSelected: (s) => _selectShift(widget.entries[i], s),
            onRemove: () => _removeEntry(i),
          ),
          if (i < widget.entries.length - 1)
            const SizedBox(height: AppSpacing.md),
        ],
        const SizedBox(height: AppSpacing.md),
        _AddEntryButton(
          label: '변경 요청 추가',
          enabled: lastComplete,
          onPressed: _addEntry,
        ),
      ],
    );
  }
}

class _SelfChangeEntryRow extends StatelessWidget {
  const _SelfChangeEntryRow({
    required this.entry,
    required this.shiftTypes,
    required this.index,
    required this.canRemove,
    required this.onPickDate,
    required this.onShiftSelected,
    required this.onRemove,
  });

  final SelfChangeEntry entry;
  final List<ShiftTypeModel> shiftTypes;
  final int index;
  final bool canRemove;
  final VoidCallback onPickDate;
  final ValueChanged<ShiftTypeModel?> onShiftSelected;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: AppRadius.borderRadiusMd,
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                '#${index + 1}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
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
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              // 날짜 — 멤버 컬럼이 없으므로 더 넓게 (flex 5)
              Expanded(
                flex: 5,
                child: _LabeledField(
                  label: '날짜',
                  child: InkWell(
                    onTap: onPickDate,
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 14, color: cs.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            entry.date != null
                                ? DateFormat('M월 d일 (E)', 'ko_KR')
                                    .format(entry.date!)
                                : '선택',
                            style: entry.date != null
                                ? _entryFieldTextStyle(context)
                                : _entryHintStyle(context),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // 변경 근무 (TO-BE) — 더 넓게 (flex 5)
              Expanded(
                flex: 5,
                child: _LabeledField(
                  label: '변경 근무',
                  child: _SelectorTrigger(
                    text: entry.desiredShiftType?.name,
                    enabled: entry.date != null,
                    onTap: () async {
                      final picked = await _showShiftPickerSheet(
                        context,
                        shiftTypes,
                        entry.desiredShiftType?.id,
                      );
                      if (picked != null) onShiftSelected(picked);
                    },
                  ),
                ),
              ),
              ],
            ),
          ),
          if (entry.date != null) ...[
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: _CurrentShiftLine(shift: entry.myCurrentShiftType),
            ),
          ],
        ],
      ),
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
    final picked = await _showDatePickerSheet(
      context,
      initial: entry.date ?? now,
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
        _AddEntryButton(
          label: '교환 요청 추가',
          enabled: lastComplete,
          onPressed: _addEntry,
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
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: AppRadius.borderRadiusMd,
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                '#${index + 1}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
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
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              // 팀원
              Expanded(
                flex: 4,
                child: _LabeledField(
                  label: '팀원',
                  child: _SelectorTrigger(
                    text: entry.userName,
                    enabled: true,
                    onTap: () async {
                      final picked = await _showMemberPickerSheet(
                        context,
                        members,
                        entry.userId,
                      );
                      if (picked != null) onMemberSelected(picked);
                    },
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
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 14, color: cs.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            entry.date != null
                                ? DateFormat('M/d (E)', 'ko_KR')
                                    .format(entry.date!)
                                : '선택',
                            style: entry.date != null
                                ? _entryFieldTextStyle(context)
                                : _entryHintStyle(context),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
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
                  child: _SelectorTrigger(
                    text: entry.desiredShiftType?.name,
                    enabled: entry.userId != null && entry.date != null,
                    onTap: () async {
                      final picked = await _showShiftPickerSheet(
                        context,
                        shiftTypes,
                        entry.desiredShiftType?.id,
                      );
                      if (picked != null) onShiftSelected(picked);
                    },
                  ),
                ),
              ),
              ],
            ),
          ),
          if (entry.userId != null && entry.date != null) ...[
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              // swap에서는 "대상자"의 현재 근무를 표시해야 의미가 맞다.
              // (이걸 어떤 근무로 바꿀지 요청하는 것이므로)
              child: _CurrentShiftLine(shift: entry.targetCurrentShiftType),
            ),
          ],
        ],
      ),
    );
  }
}

/// Entry 행에서 모든 selector(드롭다운/InkWell)가 같은 텍스트 스타일을 갖도록 통일.
TextStyle _entryFieldTextStyle(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return TextStyle(
    fontSize: 14,
    color: cs.onSurface,
    height: 1.2,
  );
}

TextStyle _entryHintStyle(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return TextStyle(
    fontSize: 14,
    color: cs.onSurfaceVariant,
    height: 1.2,
  );
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});
  final String label;
  final Widget child;

  /// 모든 child(드롭박스/InkWell)가 동일한 baseline을 갖도록 고정 높이 적용.
  static const double _fieldHeight = 32;

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
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          height: _fieldHeight,
          child: Align(
            alignment: Alignment.centerLeft,
            child: child,
          ),
        ),
      ],
    );
  }
}

/// 드롭다운 대신 사용하는 선택 트리거 — 선택값(또는 '선택') + 아래 화살표.
/// 탭하면 바텀시트가 열린다.
class _SelectorTrigger extends StatelessWidget {
  const _SelectorTrigger({
    required this.text,
    required this.enabled,
    required this.onTap,
  });

  final String? text;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Row(
        children: [
          Expanded(
            child: Text(
              text ?? '선택',
              style: text != null
                  ? _entryFieldTextStyle(context)
                  : _entryHintStyle(context),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: enabled
                ? cs.onSurfaceVariant
                : cs.onSurfaceVariant.withValues(alpha: 0.4),
          ),
        ],
      ),
    );
  }
}

/// 날짜 선택 바텀시트 — 휠(CupertinoDatePicker) + 취소/확인.
Future<DateTime?> _showDatePickerSheet(
  BuildContext context, {
  required DateTime initial,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  final minDate = DateTime(firstDate.year, firstDate.month, firstDate.day);
  final maxDate = DateTime(lastDate.year, lastDate.month, lastDate.day);
  var init = DateTime(initial.year, initial.month, initial.day);
  if (init.isBefore(minDate)) init = minDate;
  if (init.isAfter(maxDate)) init = maxDate;
  var selected = init;

  return showMoniqBottomSheet<DateTime>(
    context: context,
    title: '날짜 선택',
    eyebrow: 'DATE',
    child: Builder(
      builder: (sheetCtx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 200,
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.date,
              initialDateTime: init,
              minimumDate: minDate,
              maximumDate: maxDate,
              onDateTimeChanged: (d) =>
                  selected = DateTime(d.year, d.month, d.day),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () =>
                      Navigator.of(sheetCtx, rootNavigator: true).pop(),
                  child: const Text('취소'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(sheetCtx, rootNavigator: true)
                      .pop(selected),
                  child: const Text('확인'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// 변경 근무(근무 유형) 선택 바텀시트.
Future<ShiftTypeModel?> _showShiftPickerSheet(
  BuildContext context,
  List<ShiftTypeModel> shiftTypes,
  String? selectedId,
) {
  return showMoniqBottomSheet<ShiftTypeModel>(
    context: context,
    title: '변경 근무 선택',
    eyebrow: 'SHIFT',
    child: Builder(
      builder: (sheetCtx) {
        final cs = Theme.of(sheetCtx).colorScheme;
        return ListView(
          shrinkWrap: true,
          children: shiftTypes.map((t) {
            final color = parseHexColor(t.color);
            final selected = t.id == selectedId;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  t.code,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              title: Text(t.name),
              trailing: selected
                  ? Icon(Icons.check_rounded, color: cs.primary)
                  : null,
              onTap: () =>
                  Navigator.of(sheetCtx, rootNavigator: true).pop(t),
            );
          }).toList(),
        );
      },
    ),
  );
}

/// 팀원 선택 바텀시트.
Future<TeamMemberWithUser?> _showMemberPickerSheet(
  BuildContext context,
  List<TeamMemberWithUser> members,
  String? selectedId,
) {
  return showMoniqBottomSheet<TeamMemberWithUser>(
    context: context,
    title: '팀원 선택',
    eyebrow: 'MEMBER',
    child: Builder(
      builder: (sheetCtx) {
        final cs = Theme.of(sheetCtx).colorScheme;
        return ListView(
          shrinkWrap: true,
          children: members.map((m) {
            final selected = m.userId == selectedId;
            final initial = m.displayName.isNotEmpty
                ? m.displayName.characters.first
                : '?';
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: cs.primaryContainer,
                foregroundColor: cs.onPrimaryContainer,
                child: Text(initial),
              ),
              title: Text(m.displayName),
              trailing: selected
                  ? Icon(Icons.check_rounded, color: cs.primary)
                  : null,
              onTap: () =>
                  Navigator.of(sheetCtx, rootNavigator: true).pop(m),
            );
          }).toList(),
        );
      },
    ),
  );
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
          color: cs.onSurfaceVariant.withValues(alpha: 0.8),
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
            color: cs.onSurfaceVariant.withValues(alpha: 0.8),
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
        const SizedBox(width: AppSpacing.xs),
        Text(
          shift!.name,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

/// 차분한 톤의 "변경/교환 요청 추가" 버튼 (outlined pill).
class _AddEntryButton extends StatelessWidget {
  const _AddEntryButton({
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final fg =
        enabled ? cs.onSurface : cs.onSurfaceVariant.withValues(alpha: 0.5);
    final border = enabled
        ? cs.outlineVariant
        : cs.outlineVariant.withValues(alpha: 0.5);

    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: enabled ? onPressed : null,
        icon: Icon(Icons.add_rounded, size: 18, color: fg),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: fg,
          backgroundColor: Colors.transparent,
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          textStyle: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          minimumSize: const Size(0, 40),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}
