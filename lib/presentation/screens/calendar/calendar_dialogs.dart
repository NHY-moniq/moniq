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

// ── Helper functions ──

void refreshAll(WidgetRef ref, DateTime date) {
  // 모든 이벤트/노트 provider 캐시를 한번에 갱신
  ref.read(eventRefreshProvider.notifier).state++;
}

TimeOfDay parseTime(String time) {
  final parts = time.split(':');
  return TimeOfDay(
      hour: int.parse(parts[0]), minute: int.parse(parts[1]));
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
    title: '추가하기',
    child: Consumer(
      builder: (ctx, ref2, _) {
        // 즐겨찾기 팀이 있으면 그 팀의 근무 유형을 우선 사용.
        // 없으면 개인 근무 유형, 그마저 비어 있으면(전체 삭제됨) 빠른 근무
        // 추가가 사라지지 않도록 기본 근무 유형(데이/이브닝/나이트)으로 대체한다.
        // (reactive watch만 ref2 사용. 시트 닫힌 뒤 실행되는 read/액션은
        //  dispose되지 않는 바깥 ref를 써야 한다.)
        final teamTypes =
            ref2.watch(favoriteTeamShiftTypesProvider).valueOrNull;
        final shiftTypes = (teamTypes != null && teamTypes.isNotEmpty)
            ? teamTypes.map(personalTypeFromTeam).toList()
            : (ref.read(personalShiftTypesProvider).isNotEmpty
                ? ref.read(personalShiftTypesProvider)
                : PersonalShiftTypeLocalDataSource.defaultTypes);
        final cs = Theme.of(ctx).colorScheme;
        final existingEvents = ref.read(dateEventsProvider(date));
        final dateKey = DateTime(date.year, date.month, date.day);
        // 개인 근무 일정(이름이 근무유형과 매칭)의 인덱스
        final personalShiftIndex = existingEvents
            .indexWhere((e) => shiftTypes.any((st) => st.name == e.title));
        final hasPersonalShift = personalShiftIndex >= 0;
        // 팀(서버) 근무
        final teamShifts = ref
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
                          ? changeShiftEvent(
                              ref, date, personalShiftIndex, st)
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
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
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
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
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
    WidgetRef ref, DateTime date, PersonalShiftType st) async {
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
    WidgetRef ref, DateTime date, int index, PersonalShiftType st) async {
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
Future<void> editTeamShiftAsPersonal(BuildContext context, WidgetRef ref,
    DateTime date, ShiftWithType shift) async {
  final shiftRepo = ref.read(shiftRepositoryProvider);
  final List<ShiftTypeModel> types = await shiftRepo
      .getShiftTypes(shift.shift.teamId)
      .catchError((_) => <ShiftTypeModel>[]);

  if (!context.mounted) return;

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
              style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (types.isEmpty)
              Text(
                '등록된 근무 유형이 없습니다',
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
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
                    final isCurrent =
                        t.id == shift.shift.shiftTypeId;
                    final hasTime = t.startTime != null &&
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
                      onTap: isCurrent
                          ? null
                          : () => Navigator.pop(ctx, t),
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
  try {
    await ref.read(personalShiftOverrideRemoteProvider).upsert(
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
    refreshAll(ref, date);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${selected.name}"(으)로 변경되었습니다')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('변경 실패: $e')),
      );
    }
  }
}

/// [descriptionMarker]가 주어지면 저장 시 description 앞에 마커가 prepend된다.
/// (프라이빗 팀 일정처럼 일반 개인 일정과 구분하기 위함.)
void showEventForm(
  BuildContext context,
  WidgetRef ref,
  DateTime date,
  int? index,
  PersonalEvent? existing, {
  String? descriptionMarker,
}) {
  final titleController =
      TextEditingController(text: existing?.title ?? '');
  final descController =
      TextEditingController(text: existing?.description ?? '');
  TimeOfDay? startTime =
      existing?.startTime != null ? parseTime(existing!.startTime!) : null;
  TimeOfDay? endTime =
      existing?.endTime != null ? parseTime(existing!.endTime!) : null;
  String selectedColor = existing?.color ?? '#38A169';
  String selectedRecurrence = existing?.recurrence ?? 'none';

  const recurrenceOptions = [
    ('none', '반복 안함'),
    ('daily', '매일'),
    ('weekly', '매주'),
    ('biweekly', '2주'),
    ('monthly', '매달'),
    ('yearly', '매년'),
  ];

  const colorOptions = [
    '#38A169',
    '#E8923A',
    '#5A8BB5',
    '#E53E3E',
    '#F0C040',
    '#A0AEC0',
  ];

  showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      final tt = Theme.of(ctx).textTheme;

      return StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            top: AppSpacing.md,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.lg,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: cs.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Header — stronger weight, more breathing room
                Padding(
                  padding: const EdgeInsets.only(
                    top: AppSpacing.xs,
                    bottom: AppSpacing.lg,
                  ),
                  child: Text(
                    index == null ? '일정 추가' : '일정 수정',
                    style: tt.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                // Title input
                TextField(
                  controller: titleController,
                  autofocus: true,
                  maxLength: 30,
                  maxLengthEnforcement: MaxLengthEnforcement.enforced,
                  inputFormatters: [LengthLimitingTextInputFormatter(30)],
                  style: tt.bodyLarge?.copyWith(color: cs.onSurface),
                  decoration: InputDecoration(
                    hintText: '일정 제목',
                    hintStyle: tt.bodyLarge?.copyWith(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                    prefixIcon: Icon(
                      Icons.event_outlined,
                      color: cs.onSurfaceVariant,
                      size: 20,
                    ),
                    filled: true,
                    fillColor: cs.surfaceContainerHigh,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.lg,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.borderRadiusLg,
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: AppRadius.borderRadiusLg,
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: AppRadius.borderRadiusLg,
                      borderSide: BorderSide(
                        color: cs.primary,
                        width: 1.5,
                      ),
                    ),
                    counterStyle: tt.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                // Start / End time cards
                Row(
                  children: [
                    Expanded(
                      child: _TimeFieldCard(
                        label: '시작',
                        value: startTime != null
                            ? formatTime(startTime!)
                            : '종일',
                        isPlaceholder: startTime == null,
                        onTap: () {
                          showCupertinoTimePicker(
                            context: ctx,
                            initialHour: startTime?.hour ?? 9,
                            initialMinute: startTime?.minute ?? 0,
                            onChanged: (h, m) {
                              setSheetState(() => startTime =
                                  TimeOfDay(hour: h, minute: m));
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _TimeFieldCard(
                        label: '종료',
                        value:
                            endTime != null ? formatTime(endTime!) : '-',
                        isPlaceholder: endTime == null,
                        onTap: () {
                          showCupertinoTimePicker(
                            context: ctx,
                            initialHour: endTime?.hour ??
                                (startTime?.hour ?? 9) + 1,
                            initialMinute: endTime?.minute ??
                                startTime?.minute ??
                                0,
                            onChanged: (h, m) {
                              setSheetState(() => endTime =
                                  TimeOfDay(hour: h, minute: m));
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                // Color picker row
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: colorOptions.map((hex) {
                      return _ColorChip(
                        hex: hex,
                        isSelected: selectedColor == hex,
                        onTap: () => setSheetState(
                            () => selectedColor = hex),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                // Description input
                TextField(
                  controller: descController,
                  maxLines: 2,
                  style: tt.bodyMedium?.copyWith(color: cs.onSurface),
                  decoration: InputDecoration(
                    hintText: '설명 (선택)',
                    hintStyle: tt.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(
                        left: AppSpacing.md,
                        right: AppSpacing.sm,
                        top: AppSpacing.md,
                      ),
                      child: Align(
                        alignment: Alignment.topLeft,
                        widthFactor: 1.0,
                        heightFactor: 1.0,
                        child: Icon(
                          Icons.notes_rounded,
                          color: cs.onSurfaceVariant,
                          size: 20,
                        ),
                      ),
                    ),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    filled: true,
                    fillColor: cs.surfaceContainerHigh,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.md,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.borderRadiusLg,
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: AppRadius.borderRadiusLg,
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: AppRadius.borderRadiusLg,
                      borderSide: BorderSide(
                        color: cs.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                // 반복 설정 (새 일정만)
                if (index == null) ...[
                  const SizedBox(height: AppSpacing.md),
                  _RecurrenceField(
                    value: selectedRecurrence,
                    options: recurrenceOptions,
                    onChanged: (v) =>
                        setSheetState(() => selectedRecurrence = v),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                // CTA
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: () async {
                      final title = titleController.text.trim();
                      if (title.isEmpty) return;
                      final userDesc = descController.text.trim();
                      // 마커가 있으면 description 앞에 prepend (구분용).
                      final desc = descriptionMarker != null
                          ? (userDesc.isEmpty
                              ? descriptionMarker
                              : '$descriptionMarker\n$userDesc')
                          : (userDesc.isEmpty ? null : userDesc);
                      final event = PersonalEvent(
                        date: DateTime(date.year, date.month, date.day),
                        title: title,
                        startTime: startTime != null
                            ? formatTime(startTime!)
                            : null,
                        endTime: endTime != null
                            ? formatTime(endTime!)
                            : null,
                        description: desc,
                        color: selectedColor,
                        createdAt: DateTime.now(),
                        recurrence:
                            index == null ? selectedRecurrence : null,
                      );
                      final ds =
                          ref.read(personalEventDataSourceProvider);
                      if (index == null) {
                        await ds.addEvent(event);
                      } else {
                        await ds.updateEvent(date, index, event);
                      }
                      refreshAll(ref, date);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                      elevation: 2,
                      shadowColor: cs.primary.withValues(alpha: 0.35),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.borderRadiusFull,
                      ),
                      textStyle: tt.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    child: Text(index == null ? '추가' : '저장'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

void showNoteForm(BuildContext context, WidgetRef ref,
    DateTime date, int? index, String? currentContent) {
  final controller =
      TextEditingController(text: currentContent ?? '');
  final hasText =
      ValueNotifier<bool>((currentContent ?? '').trim().isNotEmpty);
  controller.addListener(() {
    hasText.value = controller.text.trim().isNotEmpty;
  });

  showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.lg),
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            index == null ? '메모 추가' : '메모 수정',
            style: Theme.of(ctx)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: controller,
            autofocus: true,
            decoration:
                const InputDecoration(hintText: '메모를 입력하세요'),
            maxLines: 3,
            maxLength: 1000,
            maxLengthEnforcement: MaxLengthEnforcement.enforced,
            inputFormatters: [LengthLimitingTextInputFormatter(1000)],
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: AppSpacing.lg),
          ValueListenableBuilder<bool>(
            valueListenable: hasText,
            builder: (ctx, hasValue, _) => ElevatedButton(
              onPressed: () async {
                final text = controller.text.trim();
                if (text.isEmpty) {
                  await showMoniqInfoSheet(
                    context: ctx,
                    title: '메모를 입력해주세요',
                    message: '추가하실 메모 내용을 입력해주세요.',
                  );
                  return;
                }
                final ds = ref.read(personalNoteDataSourceProvider);
                if (index == null) {
                  await ds.addNote(date, text);
                } else {
                  await ds.updateNote(date, index, text);
                }
                refreshAll(ref, date);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                foregroundColor: hasValue
                    ? Theme.of(ctx).colorScheme.onPrimary
                    : Theme.of(ctx)
                        .colorScheme
                        .onPrimary
                        .withValues(alpha: 0.3),
              ),
              child: Text(index == null ? '추가' : '저장'),
            ),
          ),
        ],
      ),
    ),
  );
}

void showCupertinoTimePicker({
  required BuildContext context,
  required int initialHour,
  required int initialMinute,
  required void Function(int hour, int minute) onChanged,
}) {
  int selectedHour = initialHour;
  int selectedMinute = initialMinute;

  showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    builder: (ctx) => SizedBox(
      height: 280,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('취소'),
                ),
                TextButton(
                  onPressed: () {
                    onChanged(selectedHour, selectedMinute);
                    Navigator.pop(ctx);
                  },
                  child: const Text('확인'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.time,
              use24hFormat: false,
              initialDateTime: DateTime(
                  2000, 1, 1, selectedHour, selectedMinute),
              onDateTimeChanged: (dateTime) {
                selectedHour = dateTime.hour;
                selectedMinute = dateTime.minute;
              },
            ),
          ),
        ],
      ),
    ),
  );
}

/// 수정 시 근무 유형 선택 가능한 편집 폼
void showEventEditWithShiftTypes(BuildContext context,
    WidgetRef ref, DateTime date, int index, PersonalEvent existing) {
  final shiftTypes = ref.read(personalShiftTypesProvider);

  showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('근무 유형으로 변경',
                      style: Theme.of(ctx)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: shiftTypes.map((st) {
                      final color = parseHexColor(st.color);
                      final isSelected = existing.title == st.name &&
                          existing.color == st.color;
                      return ActionChip(
                        avatar: CircleAvatar(
                            backgroundColor: color, radius: 8),
                        label: Text(st.name),
                        backgroundColor: isSelected
                            ? color.withValues(alpha: 0.2)
                            : null,
                        side: isSelected
                            ? BorderSide(color: color, width: 1.5)
                            : null,
                        onPressed: () {
                          final ds = ref
                              .read(personalEventDataSourceProvider);
                          final updated = PersonalEvent(
                            date: DateTime(
                                date.year, date.month, date.day),
                            title: st.name,
                            startTime: st.startTime,
                            endTime: st.endTime,
                            color: st.color,
                            createdAt: DateTime.now(),
                          );
                          ds.updateEvent(date, index, updated);
                          refreshAll(ref, date);
                          Navigator.pop(ctx);
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const Divider(height: AppSpacing.xxl),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: AppRadius.borderRadiusMd,
                ),
                child: const Icon(Icons.edit,
                    color: AppColors.success),
              ),
              title: const Text('상세 수정'),
              subtitle: const Text('제목, 시간, 색상, 설명 직접 편집'),
              onTap: () {
                Navigator.pop(ctx);
                showEventForm(
                    context, ref, date, index, existing);
              },
            ),
          ],
        ),
      ),
    ),
  );
}


// ── Event form helper widgets ─────────────────────────────────────────

/// 시작/종료 시간을 보여주는 카드. 탭하면 시간 선택 picker가 뜬다.
class _TimeFieldCard extends StatelessWidget {
  const _TimeFieldCard({
    required this.label,
    required this.value,
    required this.isPlaceholder,
    required this.onTap,
  });

  final String label;
  final String value;
  final bool isPlaceholder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: AppRadius.borderRadiusLg,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: tt.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: 18,
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      value,
                      style: tt.bodyMedium?.copyWith(
                        color: isPlaceholder
                            ? cs.onSurfaceVariant
                            : cs.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 색상 chip — 선택 시 흰색 inner ring + primary 2px outer outline로 강조.
class _ColorChip extends StatelessWidget {
  const _ColorChip({
    required this.hex,
    required this.isSelected,
    required this.onTap,
  });

  final String hex;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = parseHexColor(hex);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          // Outer primary ring when selected
          border: isSelected
              ? Border.all(color: cs.primary, width: 2)
              : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        padding: EdgeInsets.all(isSelected ? 3 : 0),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            // Inner white ring for the double-ring effect
            border: isSelected
                ? Border.all(color: cs.surface, width: 2)
                : null,
          ),
        ),
      ),
    );
  }
}

/// 반복 선택 — 다른 입력과 동일한 fill bg + radius로 통일.
class _RecurrenceField extends StatelessWidget {
  const _RecurrenceField({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String value;
  final List<(String, String)> options;
  final ValueChanged<String> onChanged;

  /// 각 옵션 값에 매핑되는 아이콘 — 빈도의 의미를 시각적으로 보조.
  IconData _iconFor(String val) {
    switch (val) {
      case 'none':
        return Icons.do_disturb_alt_outlined;
      case 'daily':
        return Icons.today_outlined;
      case 'weekly':
        return Icons.calendar_view_week_rounded;
      case 'biweekly':
        return Icons.event_repeat_rounded;
      case 'monthly':
        return Icons.calendar_month_outlined;
      case 'yearly':
        return Icons.cake_outlined;
      default:
        return Icons.repeat_rounded;
    }
  }

  String _labelFor(String val) {
    return options
        .firstWhere(
          (o) => o.$1 == val,
          orElse: () => options.first,
        )
        .$2;
  }

  Future<void> _openPicker(BuildContext context) async {
    final selected = await showMoniqBottomSheet<String>(
      context: context,
      title: '일정 반복',
      eyebrow: 'RECURRENCE',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final opt in options) ...[
            _RecurrenceOptionTile(
              icon: _iconFor(opt.$1),
              label: opt.$2,
              selected: opt.$1 == value,
              onTap: () => Navigator.of(context, rootNavigator: true)
                  .pop(opt.$1),
            ),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
    if (selected != null && selected != value) onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.xs,
            bottom: AppSpacing.xs,
          ),
          child: Text(
            '반복',
            style: tt.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Material(
          color: cs.surfaceContainerHigh,
          borderRadius: AppRadius.borderRadiusLg,
          child: InkWell(
            borderRadius: AppRadius.borderRadiusLg,
            onTap: () => _openPicker(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: [
                  Icon(
                    _iconFor(value),
                    size: 20,
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      _labelFor(value),
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.expand_more_rounded,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 반복 선택 바텀시트의 옵션 행 — 아이콘 + 라벨 + 선택 체크.
class _RecurrenceOptionTile extends StatelessWidget {
  const _RecurrenceOptionTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bg = selected
        ? cs.primary.withValues(alpha: 0.10)
        : cs.surfaceContainerHigh;
    final fg = selected ? cs.primary : cs.onSurface;
    return Material(
      color: bg,
      borderRadius: AppRadius.borderRadiusLg,
      child: InkWell(
        borderRadius: AppRadius.borderRadiusLg,
        onTap: onTap,
        child: Padding(
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
                  color: selected
                      ? cs.primary.withValues(alpha: 0.18)
                      : cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: selected ? cs.primary : cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: fg,
                    fontWeight:
                        selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
              if (selected)
                Icon(
                  Icons.check_rounded,
                  size: 20,
                  color: cs.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 개인 캘린더 — 연/월 선택 후 해당 월의 개인 일정(personal_events) +
/// 메모(personal_notes)를 일괄 삭제하는 바텀시트. team의 showDeleteScheduleSheet
/// 와 시각/플로우를 일치.
void showDeletePersonalScheduleSheet({
  required BuildContext context,
  required WidgetRef ref,
}) {
  final now = DateTime.now();
  DateTime selectedDate = DateTime(now.year, now.month);

  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (ctx) => SizedBox(
      height: 350,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('취소'),
                ),
                Text('삭제할 연월 선택',
                    style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        )),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final year = selectedDate.year;
                    final month = selectedDate.month;

                    final confirm = await showMoniqDestructiveConfirm(
                      context: context,
                      title: '정말 삭제하시겠습니까?',
                      message:
                          '$year년 $month월의 내 개인 일정과 메모가\n삭제되며 복구할 수 없습니다.',
                    );
                    if (!confirm) return;

                    try {
                      final eventDs =
                          ref.read(personalEventDataSourceProvider);
                      final noteLocal =
                          ref.read(personalNoteDataSourceProvider);
                      final removedEvents = await eventDs
                          .deleteEventsByMonth(year: year, month: month);
                      final removedNotes = await noteLocal
                          .deleteNotesByMonth(year: year, month: month);

                      // 캐시 무효화 — 이벤트/메모/날짜 단위 모두
                      ref.read(eventRefreshProvider.notifier).state++;
                      ref.invalidate(monthlyEventsProvider);
                      ref.invalidate(monthlyNotesProvider);
                      ref.invalidate(dateEventsProvider);
                      ref.invalidate(dateNotesProvider);
                      // 개인 캘린더 화면(homeViewModel) 자체도 강제 리프레시
                      try {
                        await ref
                            .read(homeViewModelProvider.notifier)
                            .refresh();
                      } catch (_) {}

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '$year년 $month월 일정 $removedEvents건, '
                              '메모 $removedNotes건이 삭제되었습니다',
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('삭제 실패: $e')),
                        );
                      }
                    }
                  },
                  child: Text(
                    '삭제',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StatefulBuilder(
              builder: (ctx, setSheetState) => CupertinoDatePicker(
                mode: CupertinoDatePickerMode.monthYear,
                initialDateTime: selectedDate,
                onDateTimeChanged: (d) {
                  setSheetState(() {
                    selectedDate = DateTime(d.year, d.month);
                  });
                },
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
