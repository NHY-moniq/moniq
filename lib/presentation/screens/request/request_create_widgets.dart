import 'package:flutter/material.dart';
import 'package:moniq/core/utils/color_utils.dart';
import 'package:moniq/data/models/roster_entry.dart';
import 'package:moniq/data/models/shift_type_model.dart';
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
  final ValueChanged<String> onShiftTypeSelected;

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
              onSelected: (_) => onShiftTypeSelected(st.id),
              selectedColor: color.withValues(alpha: 0.2),
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// 근무 교환 섹션 — 해당 날짜 팀원 근무 목록에서 교환 상대 선택
class RequestCreateSwapSection extends StatelessWidget {
  const RequestCreateSwapSection({
    super.key,
    required this.isLoading,
    required this.myShiftTypeName,
    required this.roster,
    required this.myUserId,
    required this.selectedSwapUserId,
    required this.selectedSwapUserName,
    required this.onSwapUserSelected,
  });

  final bool isLoading;
  final String? myShiftTypeName;
  final List<RosterEntry> roster;
  final String? myUserId;
  final String? selectedSwapUserId;
  final String? selectedSwapUserName;
  final void Function(String userId, String userName) onSwapUserSelected;

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
        if (myShiftTypeName != null) ...[
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
              myShiftTypeName!,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],

        // 팀원 근무 목록
        Text(
          '교환할 팀원 선택',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.sm),

        if (roster.isEmpty)
          Text(
            '해당 날짜에 배정된 근무가 없습니다',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          )
        else
          ...roster.map((entry) {
            final color = parseHexColor(entry.shiftType.color);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 근무 유형 헤더
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: AppRadius.borderRadiusSm,
                      ),
                      child: Center(
                        child: Text(
                          entry.shiftType.code,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.surface,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      entry.shiftType.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                // 근무자 목록 (자기 자신 제외)
                Padding(
                  padding: const EdgeInsets.only(left: 32),
                  child: Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: entry.workers
                        .where((w) => w.user.id != myUserId)
                        .map((w) {
                      final name =
                          w.user.displayName ?? w.user.email;
                      final isSelected =
                          selectedSwapUserId == w.user.id;

                      return ChoiceChip(
                        label: Text(name),
                        selected: isSelected,
                        onSelected: (_) =>
                            onSwapUserSelected(w.user.id, name),
                        selectedColor:
                            color.withValues(alpha: 0.2),
                        avatar: isSelected
                            ? Icon(
                                Icons.check,
                                size: 16,
                                color: color,
                              )
                            : null,
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            );
          }),

        if (selectedSwapUserName != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: AppRadius.borderRadiusMd,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.swap_horiz,
                  color: colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    '$selectedSwapUserName 님과 근무 교환 요청',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
