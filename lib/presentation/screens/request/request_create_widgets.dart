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

/// 근무 교환 섹션 — 변경 전(현재) + 변경 후(희망) 선택 후 추천/수동 교환 상대 선택
class RequestCreateSwapSection extends StatelessWidget {
  const RequestCreateSwapSection({
    super.key,
    required this.isLoading,
    required this.myShiftTypeName,
    required this.roster,
    required this.shiftTypes,
    required this.myUserId,
    required this.desiredShiftTypeId,
    required this.onDesiredShiftTypeSelected,
    required this.selectedSwapUserId,
    required this.selectedSwapUserName,
    required this.onSwapUserSelected,
  });

  final bool isLoading;
  final String? myShiftTypeName;
  final List<RosterEntry> roster;
  final List<ShiftTypeModel> shiftTypes;
  final String? myUserId;
  final String? desiredShiftTypeId;
  final ValueChanged<String> onDesiredShiftTypeSelected;
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

    // 추천 후보: 현재 날짜 로스터 중 (a) 자기 자신 제외 (b) 내가 원하는 shift_type과 일치
    final recommended = <({RosterEntry entry, String userId, String name})>[];
    if (desiredShiftTypeId != null) {
      for (final entry in roster) {
        if (entry.shiftType.id != desiredShiftTypeId) continue;
        for (final w in entry.workers) {
          if (w.user.id == myUserId) continue;
          recommended.add((
            entry: entry,
            userId: w.user.id,
            name: w.user.displayName ?? w.user.email,
          ));
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 변경 전: 현재 내 근무 ──
        Text('변경 전 (현재 근무)',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: AppSpacing.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: AppRadius.borderRadiusMd,
          ),
          child: Row(
            children: [
              Icon(Icons.work_outline,
                  color: AppColors.onSurfaceVariant, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Text(
                myShiftTypeName ?? '해당 날짜에 배정된 근무가 없습니다',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: myShiftTypeName == null
                      ? AppColors.textSecondaryLight
                      : null,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        // ── 변경 후: 원하는 근무 유형 ──
        Text('변경 후 (희망 근무 유형)',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: shiftTypes.map((t) {
            final color = parseHexColor(t.color);
            final selected = desiredShiftTypeId == t.id;
            return ChoiceChip(
              avatar: CircleAvatar(
                backgroundColor: color,
                child: Text(
                  t.code,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              label: Text(t.name),
              selected: selected,
              onSelected: (_) => onDesiredShiftTypeSelected(t.id),
              selectedColor: color.withValues(alpha: 0.2),
            );
          }).toList(),
        ),

        // ── 추천 교환 상대 ──
        if (desiredShiftTypeId != null) ...[
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              const Icon(Icons.recommend,
                  color: AppColors.primary, size: 18),
              const SizedBox(width: AppSpacing.xs),
              Text('추천 교환 상대',
                  style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      )),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '선택한 근무 유형을 같은 날에 맡은 팀원입니다',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (recommended.isEmpty)
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: AppRadius.borderRadiusMd,
              ),
              child: Text(
                '해당 근무 유형에 배정된 다른 팀원이 없습니다',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondaryLight,
                ),
              ),
            )
          else
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: recommended.map((c) {
                final color = parseHexColor(c.entry.shiftType.color);
                final isSelected = selectedSwapUserId == c.userId;
                return ChoiceChip(
                  label: Text(c.name),
                  selected: isSelected,
                  onSelected: (_) => onSwapUserSelected(c.userId, c.name),
                  selectedColor: color.withValues(alpha: 0.25),
                  avatar: isSelected
                      ? Icon(Icons.check, size: 16, color: color)
                      : const Icon(Icons.star, size: 14, color: AppColors.primary),
                );
              }).toList(),
            ),
        ],

        // ── 수동 선택: 전체 로스터 ──
        const SizedBox(height: AppSpacing.xl),
        Text('직접 선택 (전체 로스터)',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '해당 날짜의 모든 근무자에서 직접 교환 상대를 고를 수 있습니다',
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondaryLight,
          ),
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
            final otherWorkers =
                entry.workers.where((w) => w.user.id != myUserId).toList();
            if (otherWorkers.isEmpty) return const SizedBox.shrink();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                Padding(
                  padding: const EdgeInsets.only(left: 32),
                  child: Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: otherWorkers.map((w) {
                      final name = w.user.displayName ?? w.user.email;
                      final isSelected = selectedSwapUserId == w.user.id;
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
