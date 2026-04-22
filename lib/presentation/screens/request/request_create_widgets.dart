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

/// 근무 교환 섹션 — 팀원 선택 → 날짜 선택 → 변경할 근무 드롭박스.
///
/// 1:1 / 1:N 구분 없이 한 번에 한 팀원과 한 날짜의 근무를 선택한다.
/// 드롭박스의 기본값은 선택된 날짜의 본인 현재 근무이며,
/// 사용자는 다른 근무 유형으로 변경할 수 있다.
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
