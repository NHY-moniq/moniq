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

    return SingleChildScrollView(
      controller: widget.scrollController,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 헤더 ──
          _MemberHeader(member: m, isSelf: widget.isSelf),

          const SizedBox(height: AppSpacing.lg),

          // ── 역할 ──
          if (!widget.isSelf)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
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
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
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
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionLabel(label: '근무 속성'),
                  const SizedBox(height: AppSpacing.sm),
                  _AttrToggleCard(
                    icon: Icons.nights_stay_rounded,
                    color: AppColors.shiftNight,
                    title: '나이트 전담',
                    subtitle: '나이트 근무만 배정',
                    value: _nightDedicated,
                    disabled: _saving,
                    onChanged: (v) {
                      final newNightExempt = v ? false : _nightExempt;
                      final newDayOnly = v ? false : _dayOnly;
                      final newPref = v
                          ? _preferredShifts.where((c) => c == 'N').toList()
                          : _preferredShifts;
                      setState(() {
                        _nightDedicated = v;
                        _nightExempt = newNightExempt;
                        _dayOnly = newDayOnly;
                        _preferredShifts = newPref;
                      });
                      _saveAttrs(
                        nightExempt: newNightExempt,
                        dayOnly: newDayOnly,
                        nightDedicated: v,
                        preferredShifts: newPref,
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _AttrToggleCard(
                    icon: Icons.bedtime_off_outlined,
                    color: AppColors.primary,
                    title: '나이트 제외',
                    subtitle: '나이트 근무 배정 안 함',
                    value: _nightExempt,
                    disabled: _saving || _nightDedicated,
                    onChanged: (v) {
                      final newPref = v
                          ? _preferredShifts.where((c) => c != 'N').toList()
                          : _preferredShifts;
                      setState(() {
                        _nightExempt = v;
                        _preferredShifts = newPref;
                      });
                      _saveAttrs(
                        nightExempt: v,
                        dayOnly: _dayOnly,
                        nightDedicated: _nightDedicated,
                        preferredShifts: newPref,
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _AttrToggleCard(
                    icon: Icons.wb_sunny_outlined,
                    color: AppColors.shiftDay,
                    title: '데이 전담',
                    subtitle: '데이 근무만 배정',
                    value: _dayOnly,
                    disabled: _saving || _nightDedicated,
                    onChanged: (v) {
                      final newPref = v
                          ? _preferredShifts.where((c) => c == 'D').toList()
                          : _preferredShifts;
                      setState(() {
                        _dayOnly = v;
                        _preferredShifts = newPref;
                      });
                      _saveAttrs(
                        nightExempt: _nightExempt,
                        dayOnly: v,
                        nightDedicated: _nightDedicated,
                        preferredShifts: newPref,
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // 선호 근무
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionLabel(label: '선호 근무'),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '최소 1개, 최대 2개 선택 (근무 속성 내에서만 선택 가능)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    children: _shiftMeta.map((meta) {
                      final isSelected = _preferredShifts.contains(meta.code);
                      final isAllowed = _allowedShiftCodes.contains(meta.code);
                      return FilterChip(
                        label: Text(meta.label),
                        selected: isSelected,
                        onSelected: _saving
                            ? null
                            : (_) => _togglePreferredShift(meta.code),
                        selectedColor: meta.color.withValues(alpha: 0.2),
                        checkmarkColor: meta.color,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? meta.color
                              : isAllowed
                              ? colorScheme.onSurface
                              : colorScheme.onSurface.withValues(alpha: 0.35),
                          fontWeight: isSelected ? FontWeight.w700 : null,
                        ),
                        side: BorderSide(
                          color: isSelected
                              ? meta.color.withValues(alpha: 0.6)
                              : colorScheme.outline.withValues(
                                  alpha: isAllowed ? 0.5 : 0.2,
                                ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],

          // ── 멤버 제거 ──
          if (!widget.isSelf) ...[
            const SizedBox(height: AppSpacing.xl),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
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
  }
}

// ────────────────────────────────────────
// 헤더
// ────────────────────────────────────────

class _MemberHeader extends StatelessWidget {
  const _MemberHeader({required this.member, required this.isSelf});
  final TeamMemberWithUser member;
  final bool isSelf;

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
        color: colorScheme.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 드래그 핸들
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.xs,
              AppSpacing.lg,
              AppSpacing.md,
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
                              color: colorScheme.surfaceContainerLow,
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
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: roleColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.xs),
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
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: List.generate(skillOptions.length, (i) {
          final opt = skillOptions[i];
          final isSelected = opt.value == selected;
          final color = _skillColor(opt.value);
          final isLast = i == skillOptions.length - 1;

          return InkWell(
            onTap: saving ? null : () => onChanged(opt.value),
            borderRadius: BorderRadius.vertical(
              top: i == 0 ? const Radius.circular(AppRadius.sm) : Radius.zero,
              bottom: isLast
                  ? const Radius.circular(AppRadius.sm)
                  : Radius.zero,
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withValues(alpha: 0.08)
                    : Colors.transparent,
                border: isLast
                    ? null
                    : Border(
                        bottom: BorderSide(
                          color: colorScheme.outlineVariant,
                          width: 0.5,
                        ),
                      ),
              ),
              child: Row(
                children: [
                  // 컬러 인디케이터
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 4,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isSelected ? color : Colors.transparent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          opt.label,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSelected ? color : colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          opt.description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Icon(Icons.check_circle_rounded, size: 18, color: color)
                  else
                    Icon(
                      Icons.radio_button_unchecked,
                      size: 18,
                      color: colorScheme.outlineVariant,
                    ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ────────────────────────────────────────
// 근무 속성 토글 카드
// ────────────────────────────────────────

class _AttrToggleCard extends StatelessWidget {
  const _AttrToggleCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.disabled,
    required this.onChanged,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool value;
  final bool disabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final effectiveColor = disabled
        ? colorScheme.onSurfaceVariant.withValues(alpha: 0.4)
        : color;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: value && !disabled
            ? color.withValues(alpha: 0.07)
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: value && !disabled
              ? color.withValues(alpha: 0.3)
              : colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: effectiveColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
            child: Icon(icon, size: 18, color: effectiveColor),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: disabled
                        ? colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
                        : null,
                  ),
                ),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: disabled
                        ? colorScheme.onSurfaceVariant.withValues(alpha: 0.4)
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: disabled ? null : onChanged,
            activeTrackColor: color,
          ),
        ],
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
      style: theme.textTheme.labelMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
    );
  }
}
