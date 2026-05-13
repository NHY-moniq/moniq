import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:moniq/core/utils/color_utils.dart';
import 'package:moniq/data/models/shift_model.dart';
import 'package:moniq/data/models/shift_type_model.dart';
import 'package:moniq/data/models/team_member_with_user.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';

// ── 스케줄 상세 본문 (그리드) ──
// 레이아웃: 사람=행, 날짜=열 (preview와 동일)

class ScheduleHistoryDetailBody extends StatelessWidget {
  const ScheduleHistoryDetailBody({
    super.key,
    required this.shifts,
    required this.members,
    required this.shiftTypes,
  });
  final List<ShiftModel> shifts;
  final List<TeamMemberWithUser> members;
  final List<ShiftTypeModel> shiftTypes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dateFormat = DateFormat('MM.dd\n(E)', 'ko');

    // ── 레이아웃 상수 ──
    const double memberRowHeight = 52.0;
    const double memberColWidth = 80.0;
    const double summaryRowHeight = 56.0;

    // ── 그리드 구성: Map<date, Map<userId, shiftTypeId>> ──
    final grid = <DateTime, Map<String, String>>{};
    for (final shift in shifts) {
      final day = DateTime(
        shift.shiftDate.year,
        shift.shiftDate.month,
        shift.shiftDate.day,
      );
      grid.putIfAbsent(day, () => {})[shift.userId] = shift.shiftTypeId;
    }
    final sortedDays = grid.keys.toList()..sort();

    // ── shiftTypeId → ShiftTypeModel 맵 ──
    final typeMap = {for (final t in shiftTypes) t.id: t};

    // 근무 유형 → 표시 코드 (D/E/N/O로 정규화)
    String canonicalCode(ShiftTypeModel t) {
      final c = t.code.trim().toUpperCase();
      final n = t.name;
      if (c == 'N' || n.contains('야간') || n.contains('나이트')) return 'N';
      if (c == 'E' || n.contains('이브닝') || n.contains('저녁')) return 'E';
      if (c == 'D' || n.contains('데이') || n.contains('주간')) return 'D';
      if (c.isNotEmpty) return c; // 그 외는 원래 코드 유지
      return n.isNotEmpty ? n.substring(0, 1).toUpperCase() : '?';
    }

    int codePriority(String code) {
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

    final orderedShiftTypes = [...shiftTypes]
      ..sort((a, b) {
        final pa = codePriority(canonicalCode(a));
        final pb = codePriority(canonicalCode(b));
        if (pa != pb) return pa.compareTo(pb);
        return a.displayOrder.compareTo(b.displayOrder);
      });
    final orderedCodes = <String>[];
    final codeColors = <String, Color>{};
    for (final type in orderedShiftTypes) {
      final code = canonicalCode(type);
      if (!orderedCodes.contains(code)) {
        orderedCodes.add(code);
      }
      codeColors.putIfAbsent(code, () => parseHexColor(type.color));
    }

    // ── 멤버별 근무 횟수 집계 ──
    final memberShiftCounts = <String, Map<String, int>>{};
    for (final m in members) {
      final counts = <String, int>{};
      for (final day in sortedDays) {
        final shiftTypeId = grid[day]?[m.userId];
        final type = shiftTypeId != null ? typeMap[shiftTypeId] : null;
        if (type != null) {
          final code = canonicalCode(type);
          counts[code] = (counts[code] ?? 0) + 1;
        }
      }
      memberShiftCounts[m.userId] = counts;
    }

    // ── 날짜별 근무 인원 집계 ──
    final dayShiftCounts = <DateTime, Map<String, int>>{};
    for (final day in sortedDays) {
      final counts = <String, int>{};
      for (final m in members) {
        final shiftTypeId = grid[day]?[m.userId];
        final type = shiftTypeId != null ? typeMap[shiftTypeId] : null;
        if (type != null) {
          final code = canonicalCode(type);
          counts[code] = (counts[code] ?? 0) + 1;
        }
      }
      dayShiftCounts[day] = counts;
    }

    // ── 셀 빌더 ──
    Widget buildCell(String? shiftTypeId) {
      if (shiftTypeId == null) {
        return Container(
          width: 44,
          height: 36,
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: AppColors.shiftOff.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppRadius.xs),
          ),
          child: Center(
            child: Text(
              'O',
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.shiftOff,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }
      final st = typeMap[shiftTypeId];
      final color = st != null ? parseHexColor(st.color) : AppColors.shiftOff;
      final code = st != null ? canonicalCode(st) : '?';
      return Container(
        width: 44,
        height: 36,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(AppRadius.xs),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Center(
          child: Text(
            code,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    // ── 멤버 이름 고정 열 ──
    Widget memberColumn() => Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        ...members.map((m) {
          final counts = memberShiftCounts[m.userId] ?? {};
          // D/E/N 각각
          final dCount = counts['D'] ?? 0;
          final eCount = counts['E'] ?? 0;
          final nCount = counts['N'] ?? 0;
          // D/E/N 외 코드도 총합에 포함
          final workTotal = counts.values.fold(0, (s, v) => s + v);
          final offCount = sortedDays.length - workTotal;

          // D·E·N 중 하나라도 있으면 색상 칩으로 표시
          final denParts = <InlineSpan>[];
          if (dCount > 0) {
            denParts.add(
              TextSpan(
                text: 'D:$dCount',
                style: TextStyle(
                  color: codeColors['D'] ?? AppColors.brandBlue,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }
          if (eCount > 0) {
            if (denParts.isNotEmpty) {
              denParts.add(const TextSpan(text: ' '));
            }
            denParts.add(
              TextSpan(
                text: 'E:$eCount',
                style: TextStyle(
                  color: codeColors['E'] ?? AppColors.brandOrange,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }
          if (nCount > 0) {
            if (denParts.isNotEmpty) {
              denParts.add(const TextSpan(text: ' '));
            }
            denParts.add(
              TextSpan(
                text: 'N:$nCount',
                style: TextStyle(
                  color: codeColors['N'] ?? colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }

          return SizedBox(
            width: memberColWidth,
            height: memberRowHeight,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    m.displayName.length > 4
                        ? m.displayName.substring(0, 4)
                        : m.displayName,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  if (denParts.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(children: denParts),
                      style: const TextStyle(fontSize: 9, height: 1),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 1),
                  Text(
                    '총:$workTotal OFF:$offCount',
                    style: TextStyle(
                      fontSize: 8,
                      color: colorScheme.onSurfaceVariant,
                      height: 1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }),
        // 합계 행 레이블
        Container(
          width: memberColWidth,
          height: summaryRowHeight,
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
          ),
          child: Center(
            child: Text(
              '합계',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );

    // ── 날짜 그리드 (가로 스크롤) ──
    Widget dateGrid() => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 날짜 헤더
          Row(
            children: sortedDays
                .map(
                  (day) => SizedBox(
                    width: 48,
                    height: 40,
                    child: Center(
                      child: Text(
                        dateFormat.format(day),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          // 멤버 행
          ...members.map(
            (m) => SizedBox(
              height: memberRowHeight,
              child: Row(
                children: sortedDays
                    .map((day) => buildCell(grid[day]?[m.userId]))
                    .toList(),
              ),
            ),
          ),
          // 일자별 합계 행
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: colorScheme.outlineVariant),
              ),
            ),
            child: Row(
              children: sortedDays.map((day) {
                final counts = dayShiftCounts[day] ?? {};
                final entries = <(String, int, Color)>[];
                for (final code in orderedCodes) {
                  final count = counts[code] ?? 0;
                  if (count > 0) {
                    entries.add((
                      code,
                      count,
                      codeColors[code] ?? AppColors.onSurfaceVariant,
                    ));
                  }
                }
                return SizedBox(
                  width: 48,
                  height: summaryRowHeight,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: entries
                        .map(
                          (e) => Text(
                            '${e.$1}:${e.$2}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: e.$3,
                              height: 1.3,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );

    return SingleChildScrollView(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          memberColumn(),
          Flexible(child: dateGrid()),
        ],
      ),
    );
  }
}
