import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:moniq/data/models/shift_model.dart';
import 'package:moniq/data/models/shift_type_model.dart';
import 'package:moniq/data/models/team_member_with_user.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';

// ── 스케줄 상세 본문 (그리드) ──

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
    final colorScheme = Theme.of(context).colorScheme;
    final dateFormat = DateFormat('MM.dd\n(E)', 'ko');

    // 그리드 구성
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

    // shiftTypeId -> ShiftTypeModel 맵
    final typeMap = {for (final t in shiftTypes) t.id: t};

    return SingleChildScrollView(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 날짜 고정 열
          Column(
            children: [
              const SizedBox(height: 40),
              ...sortedDays.map(
                (day) => SizedBox(
                  width: 60,
                  height: 44,
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
              ),
            ],
          ),
          // 멤버별 열
          Flexible(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: members.map((m) {
                      return SizedBox(
                        width: 48,
                        height: 40,
                        child: Center(
                          child: Text(
                            m.displayName.length > 3
                                ? m.displayName.substring(0, 3)
                                : m.displayName,
                            style:
                                theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  ...sortedDays.map(
                    (day) => SizedBox(
                      height: 44,
                      child: Row(
                        children: members.map((m) {
                          return _ScheduleHistoryCell(
                            shiftTypeId: grid[day]?[m.userId],
                            typeMap: typeMap,
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 그리드 셀 위젯 ──

class _ScheduleHistoryCell extends StatelessWidget {
  const _ScheduleHistoryCell({
    required this.shiftTypeId,
    required this.typeMap,
  });
  final String? shiftTypeId;
  final Map<String, ShiftTypeModel> typeMap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

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
            style: textTheme.labelSmall?.copyWith(
              color: AppColors.shiftOff,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    final st = typeMap[shiftTypeId];
    final code = st?.code ?? '?';
    Color cellColor = colorScheme.primary;
    try {
      if (st != null) {
        final hex = st.color.replaceAll('#', '');
        final val = int.parse(
          hex.length == 6 ? 'FF$hex' : hex,
          radix: 16,
        );
        cellColor = Color(val);
      }
    } catch (_) {}

    return Container(
      width: 44,
      height: 36,
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: cellColor.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border.all(
          color: cellColor.withValues(alpha: 0.45),
        ),
      ),
      child: Center(
        child: Text(
          code,
          style: textTheme.labelSmall?.copyWith(
            color: cellColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
