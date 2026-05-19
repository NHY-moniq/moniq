import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/models/personal_team_member_shift.dart';
import 'package:moniq/presentation/screens/calendar/calendar_providers.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';

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
        decoration: BoxDecoration(
          color: cs.primary,
          shape: BoxShape.circle,
        ),
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
class PersonalDayDetailPanel extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    if (members.isEmpty) {
      return const _EmptyMemberState();
    }
    final isExpanded = ref.watch(dateExpandedProvider);
    final shiftByUser = {for (final s in shifts) s.userId: s};

    // 근무 유형별 그룹핑 (이름 기준). 근무 없는 멤버는 'OFF' 그룹.
    final groups = <String, _ShiftGroup>{};
    for (final m in members) {
      final s = shiftByUser[m.userId];
      final isOff = s == null || s.shiftCode == null;
      final key = isOff
          ? '_off'
          : '${s.shiftName ?? s.shiftCode}|${s.shiftColor ?? ''}';
      final group = groups.putIfAbsent(
        key,
        () => _ShiftGroup(
          code: isOff ? 'O' : (s.shiftCode ?? ''),
          name: isOff ? '오프' : (s.shiftName ?? s.shiftCode ?? ''),
          color: isOff
              ? '#A0AEC0'
              : (s.shiftColor ?? '#A0AEC0'),
          members: [],
        ),
      );
      group.members.add(m);
    }

    final sorted = groups.values.toList()
      ..sort((a, b) => _sortKey(a).compareTo(_sortKey(b)));

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 펼치기/닫기 chevron pill (개인 / 팀 캘린더와 동일한 UX)
        Center(
          child: Material(
            color: cs.surfaceContainerHigh,
            shape: const StadiumBorder(),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: () => ref.read(dateExpandedProvider.notifier).state =
                  !isExpanded,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 6,
                ),
                child: AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    size: 20,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (isExpanded) ...[
          const SizedBox(height: AppSpacing.sm),
          ...sorted.map((g) => _ShiftGroupCard(group: g)),
        ],
      ],
    );
  }

  static int _sortKey(_ShiftGroup g) {
    final c = g.code.toUpperCase();
    final n = g.name;
    if (c == 'D' || n.contains('데이') || n.toLowerCase().contains('day')) {
      return 0;
    }
    if (c == 'E' || n.contains('이브닝') || n.toLowerCase().contains('eve')) {
      return 1;
    }
    if (c == 'N' || n.contains('나이트') || n.toLowerCase().contains('night')) {
      return 2;
    }
    if (c == 'O' || c == 'OFF' || n.contains('오프')) return 9;
    return 3;
  }
}

class _ShiftGroup {
  _ShiftGroup({
    required this.code,
    required this.name,
    required this.color,
    required this.members,
  });
  final String code;
  final String name;
  final String color;
  final List<PersonalTeamMember> members;
}

/// 조직 팀 RosterPanel 스타일과 동일한 그라디언트 카드.
class _ShiftGroupCard extends StatelessWidget {
  const _ShiftGroupCard({required this.group});
  final _ShiftGroup group;

  Color _parseHex(String hex) {
    try {
      final h = hex.replaceFirst('#', '');
      return Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      return const Color(0xFFA0AEC0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _parseHex(group.color);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.14),
            color.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: AppRadius.borderRadiusMd,
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: AppRadius.borderRadiusSm,
                ),
                child: Center(
                  child: Text(
                    group.code.toUpperCase() == 'OFF'
                        ? 'O'
                        : group.code,
                    style: TextStyle(
                      color:
                          ThemeData.estimateBrightnessForColor(color) ==
                                  Brightness.dark
                              ? Colors.white
                              : Colors.black87,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      height: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  group.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${group.members.length}명',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final m in group.members)
                Chip(
                  avatar: _MemberAvatar(member: m, radius: 11),
                  label: Text(
                    m.displayName,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  visualDensity: VisualDensity.compact,
                  backgroundColor:
                      theme.colorScheme.surfaceContainerHighest,
                  side: BorderSide.none,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MemberShiftRow extends StatelessWidget {
  const _MemberShiftRow({
    required this.member,
    this.shift,
  });

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
          fontSize: radius * 0.62,
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
    final chipColor = _parseColor(
      shift.shiftColor,
      fallback: Theme.of(context).colorScheme.primary,
    );

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.15),
        borderRadius: AppRadius.borderRadiusFull,
        border: Border.all(
          color: chipColor.withValues(alpha: 0.4),
          width: 1,
        ),
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
