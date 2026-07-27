part of 'calendar_dialogs.dart';

void showEventForm(
  BuildContext context,
  WidgetRef ref,
  DateTime date,
  int? index,
  PersonalEvent? existing, {
  String? descriptionMarker,
}) {
  final titleController = TextEditingController(text: existing?.title ?? '');
  final descController = TextEditingController(
    text: existing?.description ?? '',
  );
  TimeOfDay? startTime = existing?.startTime != null
      ? parseTime(existing!.startTime!)
      : null;
  TimeOfDay? endTime = existing?.endTime != null
      ? parseTime(existing!.endTime!)
      : null;
  // 시작 일자는 캘린더에서 선택한 날짜(수정 시에는 기존 일정의 시작일)를 기본값으로,
  // 종료 일자는 시작 일자와 같은 날을 기본값으로 둔다. 사용자가 각각 변경 가능.
  final baseDate = DateTime(date.year, date.month, date.day);
  DateTime startDate = existing != null
      ? DateTime(existing.date.year, existing.date.month, existing.date.day)
      : baseDate;
  DateTime endDate = existing?.endDate != null
      ? DateTime(
          existing!.endDate!.year,
          existing.endDate!.month,
          existing.endDate!.day,
        )
      : startDate;
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

  // 로그아웃·근무 유형 시트와 동일한 MoniqBottomSheetShell 스타일로 통일.
  showMoniqBottomSheet<void>(
    context: context,
    eyebrow: 'SCHEDULE',
    title: index == null ? '일정 추가' : '일정 수정',
    // 시작/종료 일자 행이 늘어나 기본 높이(0.56)로는 폼이 답답해진다.
    maxHeightFactor: 0.72,
    child: StatefulBuilder(
      builder: (ctx, setSheetState) {
        final cs = Theme.of(ctx).colorScheme;
        final tt = Theme.of(ctx).textTheme;
        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                    borderSide: BorderSide(color: cs.primary, width: 1.5),
                  ),
                  counterStyle: tt.labelMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              // 종일 체크박스 + 시작/종료 일시 (날짜 + 시간)
              Row(
                children: [
                  SizedBox(
                    width: 64,
                    height: 108,
                    child: _EventAllDayCheckbox(
                      selected: startTime == null && endTime == null,
                      onChanged: (v) {
                        setSheetState(() {
                          if (v) {
                            startTime = null;
                            endTime = null;
                          } else {
                            startTime ??= const TimeOfDay(hour: 9, minute: 0);
                            endTime ??= const TimeOfDay(hour: 10, minute: 0);
                          }
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 시작 일자 + 시작 시간
                        SizedBox(
                          height: 50,
                          child: Row(
                            children: [
                              Expanded(
                                flex: 5,
                                child: _EventTimeButton(
                                  icon: Icons.event_rounded,
                                  label: '시작일',
                                  value: formatEventDate(startDate),
                                  onTap: () async {
                                    final picked =
                                        await showMoniqDatePickerSheet(
                                          context: ctx,
                                          initialDate: startDate,
                                          firstDate: DateTime(
                                            startDate.year - 3,
                                            1,
                                            1,
                                          ),
                                          lastDate: DateTime(
                                            startDate.year + 5,
                                            12,
                                            31,
                                          ),
                                          title: '시작 일자',
                                        );
                                    if (picked == null) return;
                                    setSheetState(() {
                                      startDate = DateTime(
                                        picked.year,
                                        picked.month,
                                        picked.day,
                                      );
                                      // 시작일이 종료일보다 뒤로 가면 종료일을 함께 밀어준다.
                                      if (endDate.isBefore(startDate)) {
                                        endDate = startDate;
                                      }
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                flex: 4,
                                child: _EventTimeButton(
                                  label: '시작 시간',
                                  value: startTime != null
                                      ? formatTime(startTime!)
                                      : '--:--',
                                  onTap: () {
                                    showCupertinoTimePicker(
                                      context: ctx,
                                      initialHour: startTime?.hour ?? 9,
                                      initialMinute: startTime?.minute ?? 0,
                                      onChanged: (h, m) {
                                        setSheetState(() {
                                          startTime = TimeOfDay(
                                            hour: h,
                                            minute: m,
                                          );
                                          endTime ??= TimeOfDay(
                                            hour: (h + 1) % 24,
                                            minute: m,
                                          );
                                        });
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        // 종료 일자 + 종료 시간
                        SizedBox(
                          height: 50,
                          child: Row(
                            children: [
                              Expanded(
                                flex: 5,
                                child: _EventTimeButton(
                                  icon: Icons.event_available_rounded,
                                  label: '종료일',
                                  value: formatEventDate(endDate),
                                  onTap: () async {
                                    // firstDate를 시작일로 제한해 시작일보다 앞선
                                    // 종료일은 아예 선택할 수 없게 한다.
                                    final picked =
                                        await showMoniqDatePickerSheet(
                                          context: ctx,
                                          initialDate: endDate.isBefore(
                                            startDate,
                                          )
                                              ? startDate
                                              : endDate,
                                          firstDate: startDate,
                                          lastDate: DateTime(
                                            startDate.year + 5,
                                            12,
                                            31,
                                          ),
                                          title: '종료 일자',
                                        );
                                    if (picked == null) return;
                                    setSheetState(() {
                                      endDate = DateTime(
                                        picked.year,
                                        picked.month,
                                        picked.day,
                                      );
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                flex: 4,
                                child: _EventTimeButton(
                                  label: '종료 시간',
                                  value: endTime != null
                                      ? formatTime(endTime!)
                                      : '--:--',
                                  onTap: () {
                                    showCupertinoTimePicker(
                                      context: ctx,
                                      initialHour:
                                          endTime?.hour ??
                                          (startTime?.hour ?? 9) + 1,
                                      initialMinute:
                                          endTime?.minute ??
                                          startTime?.minute ??
                                          0,
                                      onChanged: (h, m) {
                                        setSheetState(
                                          () => endTime = TimeOfDay(
                                            hour: h,
                                            minute: m,
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              // Color picker row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: colorOptions.map((hex) {
                    return _ColorChip(
                      hex: hex,
                      isSelected: selectedColor == hex,
                      onTap: () => setSheetState(() => selectedColor = hex),
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
                    borderSide: BorderSide(color: cs.primary, width: 1.5),
                  ),
                ),
              ),
              // 반복 설정 (새 일정만)
              if (index == null) ...[
                const SizedBox(height: AppSpacing.md),
                _RecurrenceField(
                  value: selectedRecurrence,
                  options: recurrenceOptions,
                  onChanged: (v) => setSheetState(() => selectedRecurrence = v),
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
                    // 시작 일시는 반드시 종료 일시보다 앞서야 한다.
                    if (endDate.isBefore(startDate)) {
                      await showMoniqInfoSheet(
                        context: ctx,
                        eyebrow: 'SCHEDULE',
                        title: '종료 일자를 확인해주세요',
                        message: '종료 일자는 시작 일자보다 앞설 수 없습니다.',
                      );
                      return;
                    }
                    if (endDate == startDate &&
                        startTime != null &&
                        endTime != null &&
                        _minutesOf(endTime!) <= _minutesOf(startTime!)) {
                      await showMoniqInfoSheet(
                        context: ctx,
                        eyebrow: 'SCHEDULE',
                        title: '종료 시간을 확인해주세요',
                        message: '같은 날이면 종료 시간이 시작 시간보다 늦어야 합니다.\n'
                            '자정을 넘기는 일정이면 종료 일자를 다음 날로 선택해주세요.',
                      );
                      return;
                    }
                    final userDesc = descController.text.trim();
                    // 마커가 있으면 description 앞에 prepend (구분용).
                    final desc = descriptionMarker != null
                        ? (userDesc.isEmpty
                              ? descriptionMarker
                              : '$descriptionMarker\n$userDesc')
                        : (userDesc.isEmpty ? null : userDesc);
                    final event = PersonalEvent(
                      date: startDate,
                      title: title,
                      // 당일 일정은 endDate를 비워 기존 데이터와 동일하게 둔다.
                      endDate: endDate.isAfter(startDate) ? endDate : null,
                      startTime: startTime != null
                          ? formatTime(startTime!)
                          : null,
                      endTime: endTime != null ? formatTime(endTime!) : null,
                      description: desc,
                      color: selectedColor,
                      createdAt: DateTime.now(),
                      recurrence: index == null ? selectedRecurrence : null,
                    );
                    final ds = ref.read(personalEventDataSourceProvider);
                    if (index == null) {
                      await ds.addEvent(event);
                    } else if (startDate != baseDate) {
                      // 시작 일자가 바뀌면 저장되는 날짜 키 자체가 달라지므로
                      // 기존 항목을 지우고 새 날짜로 다시 등록한다.
                      await ds.removeEvent(baseDate, index);
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
        );
      },
    ),
  );
}

void showNoteForm(
  BuildContext context,
  WidgetRef ref,
  DateTime date,
  int? index,
  String? currentContent,
) {
  final controller = TextEditingController(text: currentContent ?? '');
  final hasText = ValueNotifier<bool>((currentContent ?? '').trim().isNotEmpty);
  controller.addListener(() {
    hasText.value = controller.text.trim().isNotEmpty;
  });

  showMoniqBottomSheet<void>(
    context: context,
    eyebrow: 'NOTE',
    title: index == null ? '메모 추가' : '메모 수정',
    child: Builder(
      builder: (ctx) => SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(hintText: '메모를 입력하세요'),
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
                      eyebrow: 'MEMO',
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
                      : Theme.of(
                          ctx,
                        ).colorScheme.onPrimary.withValues(alpha: 0.3),
                ),
                child: Text(index == null ? '추가' : '저장'),
              ),
            ),
          ],
        ),
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
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
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
                2000,
                1,
                1,
                selectedHour,
                selectedMinute,
              ),
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
void showEventEditWithShiftTypes(
  BuildContext context,
  WidgetRef ref,
  DateTime date,
  int index,
  PersonalEvent existing,
) {
  final shiftTypes = ref.read(personalShiftTypesProvider);

  showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
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
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '근무 유형으로 변경',
                    style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: shiftTypes.map((st) {
                      final color = parseHexColor(st.color);
                      final isSelected =
                          existing.title == st.name &&
                          existing.color == st.color;
                      return ActionChip(
                        avatar: CircleAvatar(backgroundColor: color, radius: 8),
                        label: Text(st.name),
                        backgroundColor: isSelected
                            ? color.withValues(alpha: 0.2)
                            : null,
                        side: isSelected
                            ? BorderSide(color: color, width: 1.5)
                            : null,
                        onPressed: () {
                          final ds = ref.read(personalEventDataSourceProvider);
                          final updated = PersonalEvent(
                            date: DateTime(date.year, date.month, date.day),
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
                child: const Icon(Icons.edit, color: AppColors.success),
              ),
              title: const Text('상세 수정'),
              subtitle: const Text('제목, 시간, 색상, 설명 직접 편집'),
              onTap: () {
                Navigator.pop(ctx);
                showEventForm(context, ref, date, index, existing);
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
/// 종일 체크박스 — 약속잡기 시트의 `_AllDayCheckboxButton`과 동일 스펙.
