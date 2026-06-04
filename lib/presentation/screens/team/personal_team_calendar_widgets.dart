import 'package:flutter/material.dart';
import 'package:moniq/data/models/personal_team_member_shift.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';

const personalShiftDayColor = Color(0xFFF0C040);
const personalShiftEveningColor = Color(0xFFE8923A);
const personalShiftNightColor = Color(0xFF5A8BB5);

bool isPersonalOffShift(PersonalMemberShift shift) {
  final code = (shift.shiftCode ?? '').trim().toUpperCase();
  final name = (shift.shiftName ?? '').trim().toLowerCase();
  return code == 'O' ||
      code == 'OFF' ||
      name.contains('off') ||
      name.contains('오프') ||
      name.contains('휴무');
}

bool isPersonalDayShift(PersonalMemberShift shift) {
  final code = (shift.shiftCode ?? '').trim().toUpperCase();
  final name = (shift.shiftName ?? '').trim().toLowerCase();
  return code == 'D' ||
      code == 'DAY' ||
      name.contains('day') ||
      name.contains('데이');
}

String? personalShiftDenCode(PersonalMemberShift shift) {
  final code = (shift.shiftCode ?? '').trim().toUpperCase();
  final name = (shift.shiftName ?? '').trim().toLowerCase();

  if (code == 'D' ||
      code == 'DAY' ||
      name.contains('day') ||
      name.contains('데이')) {
    return 'D';
  }
  if (code == 'E' ||
      code == 'EVENING' ||
      name.contains('eve') ||
      name.contains('이브닝')) {
    return 'E';
  }
  if (code == 'N' ||
      code == 'NIGHT' ||
      name.contains('night') ||
      name.contains('나이트')) {
    return 'N';
  }
  return null;
}

int personalShiftDenSortKey(String code) {
  switch (code) {
    case 'D':
      return 0;
    case 'E':
      return 1;
    case 'N':
      return 2;
    default:
      return 99;
  }
}

Color personalShiftColorByCode(String code) {
  switch (code.toUpperCase()) {
    case 'D':
      return personalShiftDayColor;
    case 'E':
      return personalShiftEveningColor;
    case 'N':
      return personalShiftNightColor;
    default:
      return AppColors.shiftOff;
  }
}

Color resolvePersonalShiftColor(
  BuildContext context,
  PersonalMemberShift shift,
) {
  final code = (shift.shiftCode ?? '').trim().toUpperCase();
  if (code == 'D' || code == 'E' || code == 'N') {
    return personalShiftColorByCode(code);
  }
  if (isPersonalOffShift(shift)) {
    return AppColors.shiftOff;
  }

  final den = personalShiftDenCode(shift);
  if (den != null) {
    return personalShiftColorByCode(den);
  }

  return _parseColor(
    shift.shiftColor,
    fallback: Theme.of(context).colorScheme.primary,
  );
}

/// 개인 팀 캘린더 날짜 셀 — markerBuilder 외부에서 독립적으로도 사용 가능하도록
/// 보조 위젯으로 제공.
///
/// MoniqCalendar는 자체 셀 렌더링을 사용하므로 이 위젯은
/// markerBuilder 내 Positioned 자식이나 테스트 용도로 활용한다.
class PersonalCalendarDayCell extends StatelessWidget {
  const PersonalCalendarDayCell({
    super.key,
    required this.date,
    required this.shifts,
    required this.members,
    required this.isSelected,
    required this.isToday,
    this.isOutside = false,
  });

  final DateTime date;
  final List<PersonalMemberShift> shifts;
  final List<PersonalTeamMember> members;
  final bool isSelected;
  final bool isToday;
  final bool isOutside;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final double opacity = isOutside ? 0.3 : 1.0;

    final dots = shifts.take(3).toList();

    return Opacity(
      opacity: opacity,
      child: SizedBox(
        height: 52,
        width: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 6),
            // 날짜 숫자
            _DateNumber(
              day: date.day,
              isToday: isToday,
              isSelected: isSelected,
              cs: cs,
            ),
            const SizedBox(height: 4),
            // 멤버 shift 색상 도트
            if (dots.isNotEmpty)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: dots.map((s) {
                  final color = _parseColor(
                    s.shiftColor,
                    fallback: cs.onSurfaceVariant.withValues(alpha: 0.4),
                  );
                  return Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _DateNumber extends StatelessWidget {
  const _DateNumber({
    required this.day,
    required this.isToday,
    required this.isSelected,
    required this.cs,
  });

  final int day;
  final bool isToday;
  final bool isSelected;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    if (isToday) {
      return Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Text(
          '$day',
          style: TextStyle(
            color: cs.onPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      );
    }
    return Text(
      '$day',
      style: TextStyle(
        color: cs.onSurface,
        fontWeight: isSelected ? FontWeight.w800 : FontWeight.normal,
        fontSize: 13,
      ),
    );
  }
}

/// 선택된 날짜의 근무 유형별 멤버 상세 패널
class PersonalDayDetailPanel extends StatelessWidget {
  const PersonalDayDetailPanel({
    super.key,
    required this.date,
    required this.shifts,
    required this.members,
  });

  final DateTime date;
  final List<PersonalMemberShift> shifts;
  final List<PersonalTeamMember> members;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    final shiftByUser = {for (final s in shifts) s.userId: s};
    final groups = _buildShiftGroups(context, shiftByUser);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: AppRadius.borderRadiusLg,
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 날짜 헤더
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.xs,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _formatDate(date),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '${members.length}명',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (members.isEmpty)
            const _EmptyMemberState()
          else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Column(
                children: [
                  for (var i = 0; i < groups.length; i++) ...[
                    _ShiftGroupBlock(group: groups[i]),
                    if (i < groups.length - 1)
                      const SizedBox(height: AppSpacing.xs),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<_ShiftMemberGroup> _buildShiftGroups(
    BuildContext context,
    Map<String, PersonalMemberShift> shiftByUser,
  ) {
    final cs = Theme.of(context).colorScheme;
    final map = <String, _ShiftMemberGroup>{};

    _ShiftMemberGroup ensureGroup({
      required String key,
      required String label,
      required String? code,
      required Color color,
      required int sortKey,
    }) {
      return map.putIfAbsent(
        key,
        () => _ShiftMemberGroup(
          label: label,
          code: code,
          color: color,
          sortKey: sortKey,
          members: [],
        ),
      );
    }

    for (final member in members) {
      final shift = shiftByUser[member.userId];
      final codeText = (shift?.shiftCode ?? '').trim();
      if (shift == null || codeText.isEmpty || isPersonalOffShift(shift)) {
        ensureGroup(
          key: 'OFF',
          label: '오프',
          code: null,
          color: cs.onSurfaceVariant,
          sortKey: 90,
        ).members.add(member);
        continue;
      }

      final denCode = personalShiftDenCode(shift);
      if (denCode != null) {
        ensureGroup(
          key: denCode,
          label: _denLabel(denCode),
          code: denCode,
          color: personalShiftColorByCode(denCode),
          sortKey: personalShiftDenSortKey(denCode),
        ).members.add(member);
        continue;
      }

      final normalizedCode = codeText.toUpperCase();
      ensureGroup(
        key: 'CUSTOM_$normalizedCode',
        label: (shift.shiftName ?? '').trim().isNotEmpty
            ? shift.shiftName!.trim()
            : normalizedCode,
        code: normalizedCode,
        color: resolvePersonalShiftColor(context, shift),
        sortKey: 50,
      ).members.add(member);
    }

    final groups = map.values.toList()
      ..sort((a, b) {
        final sort = a.sortKey.compareTo(b.sortKey);
        if (sort != 0) return sort;
        return a.label.compareTo(b.label);
      });
    return groups;
  }

  String _denLabel(String code) {
    switch (code) {
      case 'D':
        return '데이';
      case 'E':
        return '이브닝';
      case 'N':
        return '나이트';
      default:
        return code;
    }
  }

  String _formatDate(DateTime d) {
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final wd = weekdays[d.weekday - 1];
    return '${d.month}월 ${d.day}일 ($wd)';
  }
}

class _ShiftMemberGroup {
  _ShiftMemberGroup({
    required this.label,
    required this.code,
    required this.color,
    required this.sortKey,
    required this.members,
  });

  final String label;
  final String? code;
  final Color color;
  final int sortKey;
  final List<PersonalTeamMember> members;
}

class _ShiftGroupBlock extends StatelessWidget {
  const _ShiftGroupBlock({required this.group});

  final _ShiftMemberGroup group;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final isOff = group.code == null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: isOff
            ? cs.surfaceContainerHighest.withValues(alpha: 0.32)
            : group.color.withValues(alpha: 0.07),
        borderRadius: AppRadius.borderRadiusMd,
        border: Border.all(
          color: isOff
              ? cs.outlineVariant.withValues(alpha: 0.4)
              : group.color.withValues(alpha: 0.24),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 92,
            child: Row(
              children: [
                if (group.code != null)
                  _GroupCodeBadge(code: group.code!, color: group.color)
                else
                  _GroupCodeBadge(code: 'O', color: group.color),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    group.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLowest,
              borderRadius: AppRadius.borderRadiusFull,
            ),
            child: Text(
              '${group.members.length}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Wrap(
              spacing: AppSpacing.xs,
              runSpacing: 4,
              children: [
                for (final member in group.members)
                  _GroupedMemberChip(member: member),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupCodeBadge extends StatelessWidget {
  const _GroupCodeBadge({required this.code, required this.color});

  final String code;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 22,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: AppRadius.borderRadiusFull,
        border: Border.all(color: color.withValues(alpha: 0.42)),
      ),
      alignment: Alignment.center,
      child: Text(
        code,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _GroupedMemberChip extends StatelessWidget {
  const _GroupedMemberChip({required this.member});

  final PersonalTeamMember member;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.only(left: 4, right: 7, top: 3, bottom: 3),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: AppRadius.borderRadiusFull,
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MemberAvatar(member: member, radius: 10),
          const SizedBox(width: AppSpacing.xs),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 76),
            child: Text(
              member.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberAvatar extends StatelessWidget {
  const _MemberAvatar({required this.member, this.radius = 16});

  final PersonalTeamMember member;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final initials = _initials(member.displayName);
    final avatarUrl = member.avatarUrl;

    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: cs.primaryContainer,
        backgroundImage: NetworkImage(avatarUrl),
        onBackgroundImageError: (_, __) {},
        child: null,
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: cs.primaryContainer,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: radius <= 12 ? 8 : 10,
          fontWeight: FontWeight.w700,
          color: cs.onPrimaryContainer,
        ),
      ),
    );
  }

  String _initials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    // 한글 이름이면 마지막 글자, 영어면 첫 글자
    if (trimmed.length >= 2) {
      return trimmed.substring(0, 1).toUpperCase();
    }
    return trimmed.toUpperCase();
  }
}

class _EmptyMemberState extends StatelessWidget {
  const _EmptyMemberState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxxl),
      child: Center(
        child: Text(
          '멤버가 없습니다',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// hex 문자열 '#RRGGBB' 또는 'RRGGBB'를 Color로 변환.
/// 실패 시 [fallback] 반환.
Color _parseColor(String? hex, {required Color fallback}) {
  if (hex == null || hex.isEmpty) return fallback;
  try {
    final clean = hex.replaceFirst('#', '');
    return Color(int.parse('FF$clean', radix: 16));
  } catch (_) {
    return fallback;
  }
}
