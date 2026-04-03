import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/core/utils/color_utils.dart';
import 'package:moniq/data/datasources/personal_event_local_data_source.dart';
import 'package:moniq/data/datasources/personal_shift_type_local_data_source.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';

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

// ── Dialog / Bottom Sheet functions ──

void showAddMenu(BuildContext context, WidgetRef ref, DateTime date) {
  final shiftTypes = ref.read(personalShiftTypesProvider);

  showModalBottomSheet(
    context: context,
    useRootNavigator: true,
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
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // 근무 일정 빠른 추가 (근무 유형 칩) — 하루 최대 1개
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Builder(
                builder: (innerCtx) {
                  final existingEvents = ref.read(dateEventsProvider(date));
                  final hasShift = existingEvents.any((e) =>
                      shiftTypes.any((st) =>
                          st.name == e.title && st.color == e.color));

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('근무 일정 추가',
                          style: Theme.of(ctx)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      if (hasShift) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '이미 등록된 근무가 있습니다 (1일 1개)',
                          style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                color: AppColors.error,
                              ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      Opacity(
                        opacity: hasShift ? 0.4 : 1.0,
                        child: Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: shiftTypes.map((st) {
                            final color = parseHexColor(st.color);
                            return ActionChip(
                              avatar: CircleAvatar(
                                backgroundColor: color,
                                radius: 8,
                              ),
                              label: Text(st.name),
                              onPressed: hasShift
                                  ? null
                                  : () {
                                      Navigator.pop(ctx);
                                      addShiftEvent(ref, date, st);
                                    },
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  );
                },
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
                child:
                    const Icon(Icons.event, color: AppColors.success),
              ),
              title: const Text('일정 추가'),
              subtitle: const Text('시간, 색상, 설명을 포함한 일정'),
              onTap: () {
                Navigator.pop(ctx);
                showEventForm(context, ref, date, null, null);
              },
            ),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.tertiary.withValues(alpha: 0.12),
                  borderRadius: AppRadius.borderRadiusMd,
                ),
                child: const Icon(Icons.edit_note,
                    color: AppColors.tertiary),
              ),
              title: const Text('메모 추가'),
              subtitle: const Text('간단한 텍스트 메모'),
              onTap: () {
                Navigator.pop(ctx);
                showNoteForm(context, ref, date, null, null);
              },
            ),
          ],
        ),
      ),
    ),
  );
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

void showEventForm(BuildContext context, WidgetRef ref,
    DateTime date, int? index, PersonalEvent? existing) {
  final titleController =
      TextEditingController(text: existing?.title ?? '');
  final descController =
      TextEditingController(text: existing?.description ?? '');
  TimeOfDay? startTime =
      existing?.startTime != null ? parseTime(existing!.startTime!) : null;
  TimeOfDay? endTime =
      existing?.endTime != null ? parseTime(existing!.endTime!) : null;
  String selectedColor = existing?.color ?? '#38A169';

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
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheetState) => Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.lg,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.lg,
        ),
        child: SingleChildScrollView(
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
                    color: AppColors.borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                index == null ? '일정 추가' : '일정 수정',
                style: Theme.of(ctx)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: titleController,
                autofocus: true,
                maxLength: 30,
                maxLengthEnforcement: MaxLengthEnforcement.enforced,
                inputFormatters: [LengthLimitingTextInputFormatter(30)],
                decoration: const InputDecoration(
                    hintText: '일정 제목',
                    prefixIcon: Icon(Icons.event)),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
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
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: '시작',
                          prefixIcon:
                              Icon(Icons.access_time, size: 20),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm),
                        ),
                        child: Text(startTime != null
                            ? formatTime(startTime!)
                            : '종일'),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: InkWell(
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
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: '종료',
                          prefixIcon:
                              Icon(Icons.access_time, size: 20),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm),
                        ),
                        child: Text(endTime != null
                            ? formatTime(endTime!)
                            : '-'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: colorOptions.map((hex) {
                  final isSelected = selectedColor == hex;
                  return Padding(
                    padding:
                        const EdgeInsets.only(right: AppSpacing.sm),
                    child: GestureDetector(
                      onTap: () => setSheetState(
                          () => selectedColor = hex),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: isSelected ? 36 : 32,
                        height: isSelected ? 36 : 32,
                        decoration: BoxDecoration(
                          color: parseHexColor(hex),
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(
                                  color: AppColors.textPrimaryLight,
                                  width: 2.5)
                              : null,
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                      color: parseHexColor(hex)
                                          .withValues(alpha: 0.4),
                                      blurRadius: 6)
                                ]
                              : null,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                    hintText: '설명 (선택)',
                    prefixIcon: Icon(Icons.notes)),
                maxLines: 2,
              ),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton(
                onPressed: () async {
                  final title = titleController.text.trim();
                  if (title.isEmpty) return;
                  final event = PersonalEvent(
                    date:
                        DateTime(date.year, date.month, date.day),
                    title: title,
                    startTime: startTime != null
                        ? formatTime(startTime!)
                        : null,
                    endTime: endTime != null
                        ? formatTime(endTime!)
                        : null,
                    description:
                        descController.text.trim().isNotEmpty
                            ? descController.text.trim()
                            : null,
                    color: selectedColor,
                    createdAt: DateTime.now(),
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
                child: Text(index == null ? '추가' : '저장'),
              ),
            ],
          ),
        ),
      ),
    ),
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
                color: AppColors.borderLight,
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
                  showDialog(
                    context: ctx,
                    builder: (dCtx) => AlertDialog(
                      content: const Text('추가하실 메모를 입력해주세요.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dCtx),
                          child: const Text('확인'),
                        ),
                      ],
                    ),
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
                    ? Colors.white
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
                  color: AppColors.borderLight,
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

