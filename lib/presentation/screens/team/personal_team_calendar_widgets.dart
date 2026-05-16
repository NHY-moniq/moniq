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

/// 선택된 날짜의 멤버별 근무 상세 패널
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

    // 멤버별 shift map
    final shiftByUser = {for (final s in shifts) s.userId: s};

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cs.surface,
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
              AppSpacing.xl,
              AppSpacing.xl,
              AppSpacing.xl,
              AppSpacing.md,
            ),
            child: Text(
              _formatDate(date),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const Divider(height: 1),
          if (members.isEmpty)
            const _EmptyMemberState()
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: members.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final member = members[index];
                final shift = shiftByUser[member.userId];
                return _MemberShiftRow(member: member, shift: shift);
              },
            ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final wd = weekdays[d.weekday - 1];
    return '${d.month}월 ${d.day}일 ($wd)';
  }
}

class _MemberShiftRow extends StatelessWidget {
  const _MemberShiftRow({required this.member, this.shift});

  final PersonalTeamMember member;
  final PersonalMemberShift? shift;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final hasShift = shift != null && shift!.shiftCode != null;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          // 아바타
          _MemberAvatar(member: member),
          const SizedBox(width: AppSpacing.md),
          // 이름
          Expanded(
            child: Text(
              member.displayName,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // shift chip
          if (hasShift)
            _ShiftChip(shift: shift!)
          else
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.1),
                borderRadius: AppRadius.borderRadiusFull,
              ),
              child: Text(
                '근무 없음',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MemberAvatar extends StatelessWidget {
  const _MemberAvatar({required this.member});

  final PersonalTeamMember member;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final initials = _initials(member.displayName);
    final avatarUrl = member.avatarUrl;

    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 16,
        backgroundColor: cs.primaryContainer,
        backgroundImage: NetworkImage(avatarUrl),
        onBackgroundImageError: (_, __) {},
        child: null,
      );
    }

    return CircleAvatar(
      radius: 16,
      backgroundColor: cs.primaryContainer,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: 10,
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

class _ShiftChip extends StatelessWidget {
  const _ShiftChip({required this.shift});

  final PersonalMemberShift shift;

  @override
  Widget build(BuildContext context) {
    final chipColor = resolvePersonalShiftColor(context, shift);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.15),
        borderRadius: AppRadius.borderRadiusFull,
        border: Border.all(color: chipColor.withValues(alpha: 0.4), width: 1),
      ),
      child: Text(
        shift.shiftCode ?? '',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: chipColor,
        ),
      ),
    );
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
