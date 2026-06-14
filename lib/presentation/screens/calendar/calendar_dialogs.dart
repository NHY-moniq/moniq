import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/core/utils/color_utils.dart';
import 'package:moniq/core/utils/time_utils.dart';
import 'package:moniq/data/datasources/personal_event_local_data_source.dart';
import 'package:moniq/data/datasources/personal_shift_override_remote_data_source.dart';
import 'package:moniq/data/datasources/personal_shift_type_local_data_source.dart';
import 'package:moniq/data/models/shift_type_model.dart';
import 'package:moniq/data/models/shift_with_type.dart';
import 'package:moniq/data/providers/shift_providers.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/home_viewmodel.dart';
import 'package:moniq/presentation/widgets/common/moniq_bottom_sheet.dart';

import 'calendar_providers.dart';

part 'calendar_dialogs_forms.dart';
part 'calendar_dialogs_widgets.dart';

// ── Helper functions ──

void refreshAll(WidgetRef ref, DateTime date) {
  // 모든 이벤트/노트 provider 캐시를 한번에 갱신
  ref.read(eventRefreshProvider.notifier).state++;
}

TimeOfDay parseTime(String time) {
  final parts = time.split(':');
  return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
}

String formatTime(TimeOfDay time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

/// 팀 근무 유형(ShiftTypeModel)을 개인 근무 유형(PersonalShiftType)으로 변환.
/// 개인 캘린더의 빠른추가/변경 칩과 셀 미리보기에서 팀 유형을 재사용하기 위함.
PersonalShiftType personalTypeFromTeam(ShiftTypeModel t) => PersonalShiftType(
  id: t.id,
  name: t.name,
  code: t.code,
  startTime: t.startTime ?? '',
  endTime: t.endTime ?? '',
  color: t.color,
);

// ── Dialog / Bottom Sheet functions ──

void showAddMenu(BuildContext context, WidgetRef ref, DateTime date) {
  showMoniqBottomSheet<void>(
    context: context,
    eyebrow: 'ADD',
    title: '추가하기',
    child: Consumer(
      builder: (ctx, ref2, _) {
        // 즐겨찾기 팀이 있으면 그 팀의 근무 유형을 우선 사용.
        // 없으면 개인 근무 유형, 그마저 비어 있으면(전체 삭제됨) 빠른 근무
        // 추가가 사라지지 않도록 기본 근무 유형(데이/이브닝/나이트)으로 대체한다.
        // (reactive watch만 ref2 사용. 시트 닫힌 뒤 실행되는 read/액션은
        //  dispose되지 않는 바깥 ref를 써야 한다.)
        final teamTypes = ref2
            .watch(favoriteTeamShiftTypesProvider)
            .valueOrNull;
        final shiftTypes = (teamTypes != null && teamTypes.isNotEmpty)
            ? teamTypes.map(personalTypeFromTeam).toList()
            : (ref.read(personalShiftTypesProvider).isNotEmpty
                  ? ref.read(personalShiftTypesProvider)
                  : PersonalShiftTypeLocalDataSource.defaultTypes);
        final cs = Theme.of(ctx).colorScheme;
        final existingEvents = ref.read(dateEventsProvider(date));
        final dateKey = DateTime(date.year, date.month, date.day);
        // 개인 근무 일정(이름이 근무유형과 매칭)의 인덱스
        final personalShiftIndex = existingEvents.indexWhere(
          (e) => shiftTypes.any((st) => st.name == e.title),
        );
        final hasPersonalShift = personalShiftIndex >= 0;
        // 팀(서버) 근무
        final teamShifts =
            ref
                .read(homeViewModelProvider)
                .valueOrNull
                ?.monthlyShifts[dateKey] ??
            const <ShiftWithType>[];
        final teamShift = teamShifts.isNotEmpty ? teamShifts.first : null;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 근무 섹션 ──
            if (teamShift != null) ...[
              // 팀(서버) 근무가 있으면 근무 수정 옵션 제공
              MoniqSheetOption(
                icon: Icons.swap_horiz,
                label: '근무 수정',
                description: '${teamShift.shiftType.name} · 근무 유형 변경',
                accentColor: parseHexColor(teamShift.shiftType.color),
                trailing: const SizedBox.shrink(),
                onTap: () {
                  Navigator.pop(ctx);
                  editTeamShiftAsPersonal(context, ref, date, teamShift);
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              Divider(height: 1, color: cs.outlineVariant),
              const SizedBox(height: AppSpacing.sm),
            ] else if (shiftTypes.isNotEmpty) ...[
              // ── 근무 일정 빠른 추가/변경 (근무 유형 칩) ──
              Text(
                hasPersonalShift ? '근무 변경' : '근무 일정 추가',
                style: Theme.of(ctx).textTheme.labelLarge?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: shiftTypes.map((st) {
                  final color = parseHexColor(st.color);
                  return _ShiftQuickChip(
                    color: color,
                    label: st.name,
                    onTap: () {
                      Navigator.pop(ctx);
                      hasPersonalShift
                          ? changeShiftEvent(ref, date, personalShiftIndex, st)
                          : addShiftEvent(ref, date, st);
                    },
                  );
                }).toList(),
              ),
              if (hasPersonalShift) ...[
                const SizedBox(height: AppSpacing.md),
                MoniqSheetOption(
                  icon: Icons.delete_outline,
                  label: '근무 삭제',
                  description: '이 날의 개인 근무 일정을 삭제',
                  accentColor: AppColors.error,
                  trailing: const SizedBox.shrink(),
                  onTap: () {
                    Navigator.pop(ctx);
                    removeShiftEvent(ref, date, personalShiftIndex);
                  },
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              Divider(height: 1, color: cs.outlineVariant),
              const SizedBox(height: AppSpacing.sm),
            ],
            // ── 일정 추가 ──
            MoniqSheetOption(
              icon: Icons.event,
              label: '일정 추가',
              description: '시간, 색상, 설명을 포함한 일정',
              accentColor: AppColors.success,
              trailing: const SizedBox.shrink(),
              onTap: () {
                Navigator.pop(ctx);
                showEventForm(context, ref, date, null, null);
              },
            ),
            // ── 메모 추가 ──
            MoniqSheetOption(
              icon: Icons.edit_note,
              label: '메모 추가',
              description: '간단한 텍스트 메모',
              accentColor: cs.tertiary,
              trailing: const SizedBox.shrink(),
              onTap: () {
                Navigator.pop(ctx);
                showNoteForm(context, ref, date, null, null);
              },
            ),
          ],
        );
      },
    ),
  );
}

/// 근무 유형 빠른 선택 칩 — 색 점 + 이름. 흰색 셸 위에서 단정한 톤.
class _ShiftQuickChip extends StatelessWidget {
  const _ShiftQuickChip({
    required this.color,
    required this.label,
    required this.onTap,
  });

  final Color color;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHighest,
      borderRadius: AppRadius.borderRadiusFull,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.borderRadiusFull,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 근무 유형 변경 시트의 한 줄 옵션. 색 칩(코드) + 이름 + 시간(있을 때만).
/// `request_create_widgets.dart`의 `_PickerOptionTile`과 동일한 톤으로,
/// 선택(현재 근무 유형) 시 primary 배경/테두리 + 체크로 강조하고 탭을 막는다.
class _ShiftTypePickerTile extends StatelessWidget {
  const _ShiftTypePickerTile({
    required this.code,
    required this.name,
    required this.color,
    required this.selected,
    required this.onTap,
    this.timeText,
  });

  final String code;
  final String name;
  final Color color;
  final bool selected;
  final VoidCallback? onTap;
  final String? timeText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // 선택(현재) 항목은 primary 톤(연한 배경 + 테두리)으로 강조하고,
    // 그 외는 표준 시트 행처럼 surfaceContainer 톤으로 둔다.
    final bgColor = selected
        ? cs.primaryContainer.withValues(alpha: 0.5)
        : cs.surfaceContainerHigh;
    final borderColor = selected ? cs.primary : Colors.transparent;

    return Material(
      color: bgColor,
      borderRadius: AppRadius.borderRadiusMd,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.borderRadiusMd,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: AppRadius.borderRadiusMd,
            border: Border.all(color: borderColor),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: AppRadius.borderRadiusSm,
                ),
                child: Text(
                  code,
                  style: TextStyle(color: color, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurface,
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                    ),
                    if (timeText != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        timeText!,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_rounded, size: 20, color: cs.primary),
            ],
          ),
        ),
      ),
    );
  }
}

/// 근무 유형으로 빠르게 일정 추가
Future<void> addShiftEvent(
  WidgetRef ref,
  DateTime date,
  PersonalShiftType st,
) async {
  final event = PersonalEvent(
    date: DateTime(date.year, date.month, date.day),
    title: st.name,
    startTime: st.startTime,
    endTime: st.endTime,
    color: st.color,
    createdAt: DateTime.now(),
  );
  final ds = ref.read(personalEventDataSourceProvider);
  await ds.addEvent(event);
  refreshAll(ref, date);
}

/// 기존 개인 근무 일정을 다른 근무 유형으로 교체(변경).
Future<void> changeShiftEvent(
  WidgetRef ref,
  DateTime date,
  int index,
  PersonalShiftType st,
) async {
  final event = PersonalEvent(
    date: DateTime(date.year, date.month, date.day),
    title: st.name,
    startTime: st.startTime,
    endTime: st.endTime,
    color: st.color,
    createdAt: DateTime.now(),
  );
  final ds = ref.read(personalEventDataSourceProvider);
  await ds.updateEvent(date, index, event);
  refreshAll(ref, date);
}

/// 개인 근무 일정 삭제.
Future<void> removeShiftEvent(WidgetRef ref, DateTime date, int index) async {
  final ds = ref.read(personalEventDataSourceProvider);
  await ds.removeEvent(date, index);
  refreshAll(ref, date);
}

/// 팀 캘린더 근무를 팀 근무 유형 중 하나로 변경 (팀 shift 레코드 직접 수정)
Future<void> editTeamShiftAsPersonal(
  BuildContext context,
  WidgetRef ref,
  DateTime date,
  ShiftWithType shift,
) async {
  final shiftRepo = ref.read(shiftRepositoryProvider);
  final List<ShiftTypeModel> types = await shiftRepo
      .getShiftTypes(shift.shift.teamId)
      .catchError((_) => <ShiftTypeModel>[]);

  if (!context.mounted) return;

  // 현재 "적용된" 근무 타입 = 오버라이드가 있으면 그 타입, 없으면 원본 팀 근무.
  // (오버라이드로 바꿔도 원본을 다시 고를 수 있도록 effective 기준으로 판정)
  final currentOverride =
      ref.read(personalShiftOverridesProvider).valueOrNull?[shift.shift.id];
  final effectiveTypeId =
      currentOverride?.shiftTypeId ?? shift.shift.shiftTypeId;

  final selected = await showMoniqBottomSheet<ShiftTypeModel>(
    context: context,
    eyebrow: 'SELECT',
    title: '근무 유형 변경',
    child: Builder(
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '변경 내용은 내 개인 캘린더에만 반영됩니다',
              style: Theme.of(
                ctx,
              ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (types.isEmpty)
              Text(
                '등록된 근무 유형이 없습니다',
                style: Theme.of(
                  ctx,
                ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.5,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: types.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, i) {
                    final t = types[i];
                    final isCurrent = t.id == effectiveTypeId;
                    final hasTime =
                        t.startTime != null &&
                        t.endTime != null &&
                        t.startTime!.isNotEmpty &&
                        t.endTime!.isNotEmpty;
                    return _ShiftTypePickerTile(
                      code: t.code,
                      name: t.name,
                      color: parseHexColor(t.color),
                      timeText: hasTime
                          ? '${formatTimeString(t.startTime)}'
                                ' ~ ${formatTimeString(t.endTime)}'
                          : null,
                      selected: isCurrent,
                      onTap: isCurrent ? null : () => Navigator.pop(ctx, t),
                    );
                  },
                ),
              ),
          ],
        );
      },
    ),
  );

  if (selected == null || !context.mounted) return;

  // 팀 근무 레코드는 그대로 두고, 개인 오버라이드만 upsert 한다.
  // (승인 불필요 — 변경은 내 개인 캘린더에만 반영되고 기기 간 동기화됨)
  // 단, 원본 팀 근무를 다시 고른 경우엔 오버라이드를 삭제해 완전 복원한다.
  final isRestoreToOriginal = selected.id == shift.shift.shiftTypeId;
  try {
    final overrideRepo = ref.read(personalShiftOverrideRemoteProvider);
    if (isRestoreToOriginal) {
      await overrideRepo.remove(shift.shift.id);
    } else {
      await overrideRepo.upsert(
        PersonalShiftOverrideRemote(
          shiftId: shift.shift.id,
          shiftTypeId: selected.id,
          code: selected.code,
          name: selected.name,
          color: selected.color,
          startTime: selected.startTime,
          endTime: selected.endTime,
        ),
      );
    }
    refreshAll(ref, date);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isRestoreToOriginal
                ? '팀 근무로 복원되었습니다'
                : '"${selected.name}"(으)로 변경되었습니다',
          ),
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('변경 실패: $e')));
    }
  }
}

/// [descriptionMarker]가 주어지면 저장 시 description 앞에 마커가 prepend된다.
/// (프라이빗 팀 일정처럼 일반 개인 일정과 구분하기 위함.)
