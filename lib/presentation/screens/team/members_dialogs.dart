import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/models/team_member_with_user.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/team_detail_viewmodel.dart';
import 'package:moniq/presentation/widgets/common/moniq_bottom_sheet.dart';

// ── 숙련도 옵션 ──

class SkillOption {
  const SkillOption({
    required this.value,
    required this.label,
    required this.description,
  });

  final String? value;
  final String label;
  final String description;
}

const skillOptions = [
  SkillOption(value: null, label: '미지정', description: '숙련도 미설정'),
  SkillOption(value: 'junior', label: '신규', description: '신규 간호사'),
  SkillOption(value: 'mid', label: '중간', description: '중간 경력'),
  SkillOption(value: 'senior', label: '올드', description: '올드 간호사'),
];

Color _skillColor(String? skillLevel) {
  switch (skillLevel) {
    case 'junior':
      return AppColors.shiftDay;
    case 'mid':
      return AppColors.shiftEvening;
    case 'senior':
      return AppColors.shiftNight;
    default:
      return AppColors.textSecondaryLight;
  }
}

// ────────────────────────────────────────
// 멤버 편집 시트
// ────────────────────────────────────────

class MemberEditSheet extends ConsumerStatefulWidget {
  const MemberEditSheet({
    super.key,
    required this.teamId,
    required this.member,
    required this.state,
    this.isSelf = false,
    this.scrollController,
  });

  final String teamId;
  final TeamMemberWithUser member;
  final TeamDetailState state;
  final bool isSelf;
  final ScrollController? scrollController;

  @override
  ConsumerState<MemberEditSheet> createState() => _MemberEditSheetState();
}

class _MemberEditSheetState extends ConsumerState<MemberEditSheet> {
  bool _saving = false;

  late bool _nightExempt;
  late bool _dayOnly;
  late bool _nightDedicated;
  late String? _skillLevel;
  late List<String> _preferredShifts;

  // 선호 근무 코드별 메타
  static const _shiftMeta = [
    _ShiftMeta('D', '데이', AppColors.shiftDay),
    _ShiftMeta('E', '이브닝', AppColors.shiftEvening),
    _ShiftMeta('N', '나이트', AppColors.shiftNight),
  ];

  @override
  void initState() {
    super.initState();
    _nightExempt = widget.member.member.nightExempt;
    _dayOnly = widget.member.member.dayOnly;
    _nightDedicated = widget.member.member.nightDedicated;
    _skillLevel = widget.member.member.skillLevel;
    _preferredShifts = List<String>.from(widget.member.member.preferredShifts);
  }

  // 근무 속성 기준 선택 가능 코드
  Set<String> get _allowedShiftCodes {
    if (_nightDedicated) return {'N'};
    if (_dayOnly) return {'D'};
    if (_nightExempt) return {'D', 'E'};
    return {'D', 'E', 'N'};
  }

  Future<void> _saveAttrs({
    required bool nightExempt,
    required bool dayOnly,
    required bool nightDedicated,
    List<String>? preferredShifts,
  }) async {
    setState(() => _saving = true);
    try {
      await ref
          .read(teamDetailViewModelProvider(widget.teamId).notifier)
          .updateMemberAttrs(
            widget.member.userId,
            nightExempt: nightExempt,
            dayOnly: dayOnly,
            nightDedicated: nightDedicated,
            preferredShifts: preferredShifts,
          );
    } catch (e) {
      if (mounted) _showError('저장 중 오류가 발생했습니다: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _togglePreferredShift(String code) async {
    final allowed = _allowedShiftCodes;
    if (!allowed.contains(code)) {
      _showError(_attrConflictMessage(code));
      return;
    }
    final next = List<String>.from(_preferredShifts);
    if (next.contains(code)) {
      next.remove(code);
    } else {
      if (next.length >= 2) {
        _showError('선호 근무는 최대 2개까지 선택할 수 있습니다');
        return;
      }
      next.add(code);
    }
    setState(() => _preferredShifts = next);
    await _saveAttrs(
      nightExempt: _nightExempt,
      dayOnly: _dayOnly,
      nightDedicated: _nightDedicated,
      preferredShifts: next,
    );
  }

  String _attrConflictMessage(String code) {
    if (_nightDedicated && code != 'N') {
      return '나이트 전담 속성으로 데이·이브닝 선호를 설정할 수 없습니다';
    }
    if (_dayOnly && code != 'D') {
      return '데이 전담 속성으로 이브닝·나이트 선호를 설정할 수 없습니다';
    }
    if (_nightExempt && code == 'N') {
      return '나이트 제외 속성으로 나이트 선호를 설정할 수 없습니다';
    }
    return '근무 속성과 충돌하는 선호 근무입니다';
  }

  Future<void> _changeRole() async {
    final m = widget.member;
    final newRole = m.role == 'admin' ? 'member' : 'admin';
    final adminCount = widget.state.members
        .where((x) => x.role == 'admin')
        .length;
    if (m.role == 'admin' && adminCount <= 1) {
      _showError('관리자가 1명만 남아 있어 역할을 변경할 수 없습니다.');
      return;
    }

    final nextRoleLabel = newRole == 'admin' ? '관리자' : '일반 멤버';
    final confirmTitle = newRole == 'admin' ? '관리자로 변경' : '관리자 권한 해제';
    final confirmLabel = newRole == 'admin' ? '변경' : '해제';
    final ok = await showMoniqConfirmSheet(
      context: context,
      title: confirmTitle,
      message: '${m.displayName}님의 역할을 $nextRoleLabel로 변경하시겠습니까?',
      confirmLabel: confirmLabel,
    );
    if (!ok || !mounted) return;

    setState(() => _saving = true);
    try {
      await ref
          .read(teamDetailViewModelProvider(widget.teamId).notifier)
          .updateMemberRole(m.userId, newRole);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) _showError('역할 변경 중 오류가 발생했습니다: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changeSkillLevel(String? skillLevel) async {
    setState(() {
      _skillLevel = skillLevel;
      _saving = true;
    });
    try {
      await ref
          .read(teamDetailViewModelProvider(widget.teamId).notifier)
          .updateMemberSkillLevel(widget.member.userId, skillLevel);
    } catch (e) {
      if (mounted) _showError('숙련도 변경 중 오류가 발생했습니다: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _setNightDedicated(bool value) {
    final newNightExempt = value ? false : _nightExempt;
    final newDayOnly = value ? false : _dayOnly;
    final newPreferredShifts = value
        ? _preferredShifts.where((code) => code == 'N').toList()
        : _preferredShifts;
    setState(() {
      _nightDedicated = value;
      _nightExempt = newNightExempt;
      _dayOnly = newDayOnly;
      _preferredShifts = newPreferredShifts;
    });
    _saveAttrs(
      nightExempt: newNightExempt,
      dayOnly: newDayOnly,
      nightDedicated: value,
      preferredShifts: newPreferredShifts,
    );
  }

  void _setNightExempt(bool value) {
    final newPreferredShifts = value
        ? _preferredShifts.where((code) => code != 'N').toList()
        : _preferredShifts;
    setState(() {
      _nightExempt = value;
      _preferredShifts = newPreferredShifts;
    });
    _saveAttrs(
      nightExempt: value,
      dayOnly: _dayOnly,
      nightDedicated: _nightDedicated,
      preferredShifts: newPreferredShifts,
    );
  }

  void _setDayOnly(bool value) {
    final newPreferredShifts = value
        ? _preferredShifts.where((code) => code == 'D').toList()
        : _preferredShifts;
    setState(() {
      _dayOnly = value;
      _preferredShifts = newPreferredShifts;
    });
    _saveAttrs(
      nightExempt: _nightExempt,
      dayOnly: value,
      nightDedicated: _nightDedicated,
      preferredShifts: newPreferredShifts,
    );
  }

  Future<void> _confirmRemove() async {
    final ok = await showMoniqConfirmSheet(
      context: context,
      title: '멤버 제거',
      message: '${widget.member.displayName}님을 팀에서 제거하시겠습니까?',
      confirmLabel: '제거',
      destructive: true,
    );
    if (!ok) return;
    if (mounted) Navigator.pop(context);
    await ref
        .read(teamDetailViewModelProvider(widget.teamId).notifier)
        .removeMember(widget.member.userId);
  }

  void _showError(String message) {
    showMoniqInfoSheet(context: context, title: '안내', message: message);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final m = widget.member;
    final isPersonal = widget.state.team.teamType == 'personal';
    final isBottomSheet = widget.scrollController != null;
    final sheetColor = colorScheme.brightness == Brightness.dark
        ? colorScheme.surface
        : Colors.white;

    final content = SingleChildScrollView(
      controller: widget.scrollController,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 헤더 ──
          _MemberHeader(
            member: m,
            isSelf: widget.isSelf,
            showHandle: isBottomSheet,
          ),

          const SizedBox(height: AppSpacing.lg),

          // ── 역할 ──
          if (!widget.isSelf)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
              child: _RoleCard(
                role: m.role,
                saving: _saving,
                onTap: _changeRole,
              ),
            ),

          // ── 조직 팀 전용: 숙련도 · 근무 속성 · 선호 근무 ──
          if (!isPersonal) ...[
            const SizedBox(height: AppSpacing.lg),

            // 숙련도
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionLabel(label: '숙련도'),
                  const SizedBox(height: AppSpacing.sm),
                  _SkillSelector(
                    selected: _skillLevel,
                    saving: _saving,
                    onChanged: _changeSkillLevel,
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // 근무 속성
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionLabel(label: '근무 속성'),
                  const SizedBox(height: AppSpacing.sm),
                  _AttrSegmentedToggle(
                    options: [
                      _AttrSegmentOption(
                        icon: Icons.nights_stay_rounded,
                        color: AppColors.shiftNight,
                        label: '나이트전담',
                        selected: _nightDedicated,
                        disabled: _saving,
                        onTap: () => _setNightDedicated(!_nightDedicated),
                      ),
                      _AttrSegmentOption(
                        icon: Icons.bedtime_off_outlined,
                        color: AppColors.primary,
                        label: '나이트제외',
                        selected: _nightExempt,
                        disabled: _saving || _nightDedicated,
                        onTap: () => _setNightExempt(!_nightExempt),
                      ),
                      _AttrSegmentOption(
                        icon: Icons.wb_sunny_outlined,
                        color: AppColors.shiftDay,
                        label: '데이전담',
                        selected: _dayOnly,
                        disabled: _saving || _nightDedicated,
                        onTap: () => _setDayOnly(!_dayOnly),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // 선호 근무
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionLabel(label: '선호 근무'),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '최대 2개 선택 · 근무 속성과 충돌 시 비활성화',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _ShiftPreferenceSelector(
                    metas: _shiftMeta,
                    selectedCodes: _preferredShifts,
                    allowedCodes: _allowedShiftCodes,
                    saving: _saving,
                    onToggle: _togglePreferredShift,
                  ),
                ],
              ),
            ),
          ],

          // ── 멤버 제거 ──
          if (!widget.isSelf) ...[
            const SizedBox(height: AppSpacing.xl),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : _confirmRemove,
                  icon: const Icon(Icons.person_remove_outlined, size: 18),
                  label: const Text('팀에서 제거'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.error,
                    side: BorderSide(
                      color: colorScheme.error.withValues(alpha: 0.4),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );

    if (!isBottomSheet) {
      return content;
    }

    const sheetRadius = BorderRadius.vertical(
      top: Radius.circular(AppRadius.xl),
    );
    return ClipRRect(
      borderRadius: sheetRadius,
      child: DecoratedBox(
        decoration: BoxDecoration(color: sheetColor, borderRadius: sheetRadius),
        child: content,
      ),
    );
  }
}

// ────────────────────────────────────────
// 헤더
// ────────────────────────────────────────

class _MemberHeader extends StatelessWidget {
  const _MemberHeader({
    required this.member,
    required this.isSelf,
    required this.showHandle,
  });
  final TeamMemberWithUser member;
  final bool isSelf;
  final bool showHandle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final initial = member.displayName.isNotEmpty
        ? member.displayName[0].toUpperCase()
        : '?';
    final isAdmin = member.role == 'admin';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colorScheme.brightness == Brightness.dark
            ? colorScheme.surface
            : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 드래그 핸들
          if (showHandle)
            Padding(
              padding: const EdgeInsets.only(top: 14, bottom: AppSpacing.lg),
              child: Center(
                child: Container(
                  width: 52,
                  height: 5,
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
                    borderRadius: AppRadius.borderRadiusFull,
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xxl,
              0,
              AppSpacing.xxl,
              AppSpacing.xl,
            ),
            child: Row(
              children: [
                // 아바타
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: AppColors.primary.withValues(
                        alpha: 0.15,
                      ),
                      backgroundImage: member.user.avatarUrl != null
                          ? NetworkImage(member.user.avatarUrl!)
                          : null,
                      child: member.user.avatarUrl == null
                          ? Text(
                              initial,
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: AppColors.onPrimaryContainer,
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          : null,
                    ),
                    // 관리자 뱃지
                    if (isAdmin)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colorScheme.brightness == Brightness.dark
                                  ? colorScheme.surface
                                  : Colors.white,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.star_rounded,
                            size: 11,
                            color: AppColors.onPrimary,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              member.displayName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (isSelf) ...[
                            const SizedBox(width: AppSpacing.xs),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.full,
                                ),
                              ),
                              child: Text(
                                '나',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        member.user.email,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ), // Row
          ), // Padding
        ], // Column children
      ), // Column
    ); // Container
  }
}

// ────────────────────────────────────────
// 역할 카드
// ────────────────────────────────────────

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.role,
    required this.saving,
    required this.onTap,
  });
  final String role;
  final bool saving;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isAdmin = role == 'admin';
    final currentLabel = isAdmin ? '관리자' : '일반 멤버';
    final nextLabel = isAdmin ? '일반 멤버로 변경' : '관리자로 변경';
    final roleColor = isAdmin
        ? AppColors.primary
        : colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: saving ? null : onTap,
      borderRadius: AppRadius.borderRadiusLg,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        decoration: BoxDecoration(
          color: colorScheme.brightness == Brightness.dark
              ? colorScheme.surfaceContainer
              : Colors.white,
          borderRadius: AppRadius.borderRadiusLg,
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.8),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: roleColor.withValues(alpha: 0.12),
                borderRadius: AppRadius.borderRadiusMd,
              ),
              child: Icon(
                isAdmin ? Icons.star_rounded : Icons.person_rounded,
                size: 18,
                color: roleColor,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '역할',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    currentLabel,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              nextLabel,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Icon(
              Icons.swap_horiz_rounded,
              size: 16,
              color: colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────
// 숙련도 세그먼트 선택기
// ────────────────────────────────────────

class _SkillSelector extends StatelessWidget {
  const _SkillSelector({
    required this.selected,
    required this.saving,
    required this.onChanged,
  });
  final String? selected;
  final bool saving;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: colorScheme.brightness == Brightness.dark
            ? colorScheme.surfaceContainer
            : Colors.white,
        borderRadius: AppRadius.borderRadiusLg,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.8),
        ),
      ),
      child: Row(
        children: List.generate(skillOptions.length, (i) {
          final opt = skillOptions[i];
          final isSelected = opt.value == selected;
          final color = _skillColor(opt.value);

          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: i == 0 ? 0 : AppSpacing.xs),
              child: InkWell(
                onTap: saving ? null : () => onChanged(opt.value),
                borderRadius: AppRadius.borderRadiusMd,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color.withValues(alpha: 0.14)
                        : Colors.transparent,
                    borderRadius: AppRadius.borderRadiusMd,
                    border: Border.all(
                      color: isSelected
                          ? color.withValues(alpha: 0.32)
                          : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    opt.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: isSelected ? color : colorScheme.onSurfaceVariant,
                      fontWeight: isSelected
                          ? FontWeight.w900
                          : FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ────────────────────────────────────────
// 근무 속성 · 선호 근무 compact multi segment
// ────────────────────────────────────────

class _AttrSegmentedToggle extends StatelessWidget {
  const _AttrSegmentedToggle({required this.options});

  final List<_AttrSegmentOption> options;

  @override
  Widget build(BuildContext context) {
    return _CompactSegmentSurface(
      children: [
        for (var index = 0; index < options.length; index++)
          _CompactToggleSegment(
            icon: options[index].icon,
            label: options[index].label,
            color: options[index].color,
            selected: options[index].selected,
            disabled: options[index].disabled,
            onTap: options[index].onTap,
            leadingPadding: index == 0 ? 0 : AppSpacing.xs,
          ),
      ],
    );
  }
}

class _AttrSegmentOption {
  const _AttrSegmentOption({
    required this.icon,
    required this.color,
    required this.label,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;
}

class _ShiftPreferenceSelector extends StatelessWidget {
  const _ShiftPreferenceSelector({
    required this.metas,
    required this.selectedCodes,
    required this.allowedCodes,
    required this.saving,
    required this.onToggle,
  });

  final List<_ShiftMeta> metas;
  final List<String> selectedCodes;
  final Set<String> allowedCodes;
  final bool saving;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return _CompactSegmentSurface(
      children: [
        for (var index = 0; index < metas.length; index++)
          _CompactToggleSegment(
            code: metas[index].code,
            label: metas[index].label,
            color: metas[index].color,
            selected: selectedCodes.contains(metas[index].code),
            disabled: saving || !allowedCodes.contains(metas[index].code),
            onTap: () => onToggle(metas[index].code),
            leadingPadding: index == 0 ? 0 : AppSpacing.xs,
          ),
      ],
    );
  }
}

class _CompactSegmentSurface extends StatelessWidget {
  const _CompactSegmentSurface({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: colorScheme.brightness == Brightness.dark
            ? colorScheme.surfaceContainer
            : Colors.white,
        borderRadius: AppRadius.borderRadiusLg,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.8),
        ),
      ),
      child: Row(children: children),
    );
  }
}

class _CompactToggleSegment extends StatelessWidget {
  const _CompactToggleSegment({
    required this.label,
    required this.color,
    required this.selected,
    required this.disabled,
    required this.onTap,
    required this.leadingPadding,
    this.icon,
    this.code,
  });

  final IconData? icon;
  final String? code;
  final String label;
  final Color color;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;
  final double leadingPadding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final effectiveColor = disabled
        ? colorScheme.onSurfaceVariant.withValues(alpha: 0.38)
        : color;
    final textColor = selected && !disabled
        ? color
        : disabled
        ? colorScheme.onSurfaceVariant.withValues(alpha: 0.42)
        : colorScheme.onSurfaceVariant;

    return Expanded(
      child: Padding(
        padding: EdgeInsets.only(left: leadingPadding),
        child: InkWell(
          onTap: disabled ? null : onTap,
          borderRadius: AppRadius.borderRadiusMd,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            decoration: BoxDecoration(
              color: selected && !disabled
                  ? color.withValues(alpha: 0.14)
                  : Colors.transparent,
              borderRadius: AppRadius.borderRadiusMd,
              border: Border.all(
                color: selected && !disabled
                    ? color.withValues(alpha: 0.34)
                    : Colors.transparent,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: 19,
                  child: Center(
                    child: icon != null
                        ? Icon(icon, size: 17, color: effectiveColor)
                        : Text(
                            code ?? '',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: effectiveColor,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: textColor,
                    fontWeight: selected && !disabled
                        ? FontWeight.w900
                        : FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── 선호 근무 메타 ──

class _ShiftMeta {
  const _ShiftMeta(this.code, this.label, this.color);
  final String code;
  final String label;
  final Color color;
}

// ── 섹션 레이블 ──

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      label,
      style: theme.textTheme.titleSmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.3,
      ),
    );
  }
}
