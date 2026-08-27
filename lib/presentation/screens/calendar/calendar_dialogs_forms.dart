part of 'calendar_dialogs.dart';

void showEventForm(
  BuildContext context,
  WidgetRef ref,
  DateTime date,
  int? index,
  PersonalEvent? existing, {
  String? descriptionMarker,
  /// 근무 카드에서 연 경우 — 헤더를 "근무 일정 추가/수정"으로 바꾼다.
  /// (같은 폼이지만 사용자가 방금 누른 항목이 근무임을 잃지 않게)
  bool isShift = false,
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
  // 설명은 기본 폼에서 숨겨 시트를 짧게 유지한다.
  // 수정 시 기존 값이 있으면 처음부터 펼친 상태로 시작한다.
  bool showDescField = descController.text.trim().isNotEmpty;
  // 더보기 칩으로 방금 연 경우에만 autofocus — 수정 진입 시 기존 설명이
  // 있어 펼쳐진 상태에서는 키보드가 먼저 올라오지 않게 한다.
  bool descAutofocus = false;
  // "+ 더보기" 행의 펼침 여부 — 추가 가능한 항목 칩(반복/설명) 노출 토글.
  bool moreFieldsExpanded = false;

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
    eyebrow: isShift ? 'SHIFT' : 'SCHEDULE',
    title: isShift
        ? (index == null ? '근무 일정 추가' : '근무 일정 수정')
        : (index == null ? '일정 추가' : '일정 수정'),
    // 일시/색상/설명/반복 네 섹션이 세로로 쌓이므로 기본 높이(0.56)로는
    // 폼이 답답해진다. 키보드가 올라온 상태에서도 저장 버튼까지 닿도록 넉넉히.
    maxHeightFactor: 0.8,
    child: StatefulBuilder(
      builder: (ctx, setSheetState) {
        final cs = Theme.of(ctx).colorScheme;
        final tt = Theme.of(ctx).textTheme;
        // 더보기 행에 아직 추가할 수 있는 항목 — 반복은 새 일정에서만.
        final canAddRecurrence = index == null && selectedRecurrence == 'none';
        final canAddDesc = !showDescField;
        final isAllDay = startTime == null && endTime == null;

        // 날짜+시간을 하나의 DateTime으로 합친 값 — 휠 피커의 기준.
        DateTime composeStart() => DateTime(
          startDate.year,
          startDate.month,
          startDate.day,
          startTime?.hour ?? 0,
          startTime?.minute ?? 0,
        );

        // 반복 시트 열기 — 더보기 칩과 요약 행 탭이 같은 흐름을 공유한다.
        Future<void> pickRecurrence() async {
          final picked = await _showRecurrencePickerSheet(
            ctx,
            current: selectedRecurrence,
            startDate: startDate,
          );
          if (picked == null) return;
          setSheetState(() => selectedRecurrence = picked);
        }

        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 제목 — 시트의 주인공. prefix 아이콘을 빼서 아래 섹션들과
              // 같은 좌측 정렬 축을 공유하게 했다.
              // 시트가 열리자마자 키보드가 올라와 폼을 가리지 않도록 autofocus는
              // 두지 않는다 — 입력창을 직접 탭했을 때만 키보드가 뜬다.
              TextField(
                controller: titleController,
                textCapitalization: TextCapitalization.sentences,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.done,
                maxLength: 30,
                maxLengthEnforcement: MaxLengthEnforcement.enforced,
                inputFormatters: [LengthLimitingTextInputFormatter(30)],
                style: tt.titleMedium?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w700,
                ),
                // 글자 수는 한도에 가까워질 때만 보여줘 평소엔 화면을 조용하게 둔다.
                buildCounter:
                    (
                      _, {
                      required currentLength,
                      required isFocused,
                      required maxLength,
                    }) => currentLength < 20
                    ? null
                    : Text(
                        '$currentLength/${maxLength ?? 30}',
                        style: tt.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                decoration: InputDecoration(
                  hintText: '일정 제목',
                  hintStyle: tt.titleMedium?.copyWith(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.45),
                    fontWeight: FontWeight.w500,
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
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              // 일시 — 종일/시작/종료가 같은 라벨 축을 공유하는 세 줄.
              const _FormSectionLabel('일시'),
              _EventAllDayCheckbox(
                selected: isAllDay,
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
              const SizedBox(height: AppSpacing.sm),
              if (isAllDay) ...[
                // 종일 — 날짜만 고르는 기존 피커 유지.
                _EventDateTimeRow(
                  label: '시작',
                  dateField: _EventTimeButton(
                    label: '시작일',
                    value: formatEventDate(startDate),
                    onTap: () async {
                      final picked = await showMoniqDatePickerSheet(
                        context: ctx,
                        initialDate: startDate,
                        firstDate: DateTime(startDate.year - 3, 1, 1),
                        lastDate: DateTime(startDate.year + 5, 12, 31),
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
                const SizedBox(height: AppSpacing.sm),
                _EventDateTimeRow(
                  label: '종료',
                  dateField: _EventTimeButton(
                    label: '종료일',
                    value: formatEventDate(endDate),
                    onTap: () async {
                      // firstDate를 시작일로 제한해 시작일보다 앞선
                      // 종료일은 아예 선택할 수 없게 한다.
                      final picked = await showMoniqDatePickerSheet(
                        context: ctx,
                        initialDate: endDate.isBefore(startDate)
                            ? startDate
                            : endDate,
                        firstDate: startDate,
                        lastDate: DateTime(startDate.year + 5, 12, 31),
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
              ] else ...[
                // 시간 사용 — 날짜·시·분·오전/오후를 한 휠에서 고른다.
                _EventDateTimeRow(
                  label: '시작',
                  dateField: _EventTimeButton(
                    label: '시작 일시',
                    value:
                        '${formatEventDate(startDate)}'
                        ' ${startTime != null ? formatTime(startTime!) : '--:--'}',
                    onTap: () async {
                      final picked = await showMoniqDateTimePickerSheet(
                        context: ctx,
                        initialDateTime: composeStart(),
                        minimumDate: DateTime(startDate.year - 3, 1, 1),
                        maximumDate: DateTime(
                          startDate.year + 5,
                          12,
                          31,
                          23,
                          59,
                        ),
                        title: '시작 일시',
                      );
                      if (picked == null) return;
                      setSheetState(() {
                        startDate = DateTime(
                          picked.year,
                          picked.month,
                          picked.day,
                        );
                        startTime = TimeOfDay.fromDateTime(picked);
                        // 종료는 항상 시작 +1시간 — 날짜 포함 DateTime이라
                        // 자정을 넘어도 종료 일자가 자연히 따라간다.
                        final end = picked.add(const Duration(hours: 1));
                        endDate = DateTime(end.year, end.month, end.day);
                        endTime = TimeOfDay.fromDateTime(end);
                      });
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _EventDateTimeRow(
                  label: '종료',
                  dateField: _EventTimeButton(
                    label: '종료 일시',
                    value:
                        '${formatEventDate(endDate)}'
                        ' ${endTime != null ? formatTime(endTime!) : '--:--'}',
                    onTap: () async {
                      final startAt = composeStart();
                      // 시작 이하로는 휠 스크롤 자체가 되지 않게 막는다.
                      final minimum = startAt.add(const Duration(minutes: 1));
                      var initial = DateTime(
                        endDate.year,
                        endDate.month,
                        endDate.day,
                        endTime?.hour ?? startAt.hour,
                        endTime?.minute ?? startAt.minute,
                      );
                      if (initial.isBefore(minimum)) {
                        initial = startAt.add(const Duration(hours: 1));
                      }
                      final picked = await showMoniqDateTimePickerSheet(
                        context: ctx,
                        initialDateTime: initial,
                        minimumDate: minimum,
                        maximumDate: DateTime(
                          startDate.year + 5,
                          12,
                          31,
                          23,
                          59,
                        ),
                        title: '종료 일시',
                      );
                      if (picked == null) return;
                      setSheetState(() {
                        endDate = DateTime(
                          picked.year,
                          picked.month,
                          picked.day,
                        );
                        endTime = TimeOfDay.fromDateTime(picked);
                      });
                    },
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              // 색상
              const _FormSectionLabel('색상'),
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
              // 반복 — 값이 있으면 요약 라벨 행만 보여주고, 행을 탭하면
              // 반복 시트를 다시 연다 (수정 화면에서는 표기만, 변경 불가).
              if (selectedRecurrence != 'none') ...[
                const SizedBox(height: AppSpacing.xl),
                _RecurrenceSummaryRow(
                  label: recurrenceSummaryLabel(selectedRecurrence),
                  onTap: index == null ? pickRecurrence : null,
                ),
              ],
              // 설명 — 섹션 라벨이 역할을 알려주므로 필드 안 아이콘은 뺐다.
              if (showDescField) ...[
                const SizedBox(height: AppSpacing.xl),
                const _FormSectionLabel('설명'),
                TextField(
                  controller: descController,
                  maxLines: 2,
                  // 더보기 칩으로 방금 열었을 때만 바로 타이핑 가능하게.
                  autofocus: descAutofocus,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.newline,
                  style: tt.bodyMedium?.copyWith(color: cs.onSurface),
                  decoration: InputDecoration(
                    hintText: '자세한 내용 (선택)',
                    hintStyle: tt.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.45),
                    ),
                    filled: true,
                    fillColor: cs.surfaceContainerHigh,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
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
              ],
              // "+ 더보기" — 숨긴 항목이 남아 있을 때만 노출.
              // 두 항목이 모두 추가되면 행 자체가 사라진다.
              if (canAddRecurrence || canAddDesc) ...[
                const SizedBox(height: AppSpacing.lg),
                _MoreFieldsRow(
                  expanded: moreFieldsExpanded,
                  onToggle: () => setSheetState(
                    () => moreFieldsExpanded = !moreFieldsExpanded,
                  ),
                  chips: [
                    if (canAddRecurrence)
                      // 칩을 누르면 곧바로 반복 선택 시트 — 인라인 드롭다운을
                      // 한 번 더 누르던 중간 단계를 없앤다.
                      _AddFieldChip(
                        icon: Icons.repeat_rounded,
                        label: '반복',
                        onTap: pickRecurrence,
                      ),
                    if (canAddDesc)
                      _AddFieldChip(
                        icon: Icons.notes_rounded,
                        label: '설명',
                        onTap: () => setSheetState(() {
                          showDescField = true;
                          descAutofocus = true;
                        }),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.xxl),
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
                        message:
                            '같은 날이면 종료 시간이 시작 시간보다 늦어야 합니다.\n'
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
                      // 새 일정만 반복을 전개한다. 수정 시에는 기존 반복
                      // 표식을 보존해 "이후 일정 모두 삭제" 매칭이 깨지지
                      // 않게 한다.
                      recurrence: index == null
                          ? selectedRecurrence
                          : existing?.recurrence,
                    );
                    final container = sheetContainer(ctx);
                    final ds = container.read(personalEventDataSourceProvider);
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
                    container.read(eventRefreshProvider.notifier).state++;
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
            // 일정 폼과 동일 — 열자마자 키보드가 화면을 덮지 않게 autofocus 제거.
            TextField(
              controller: controller,
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
                  final container = sheetContainer(ctx);
                  final ds = container.read(personalNoteDataSourceProvider);
                  if (index == null) {
                    await ds.addNote(date, text);
                  } else {
                    await ds.updateNote(date, index, text);
                  }
                  container.read(eventRefreshProvider.notifier).state++;
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
                          final container = sheetContainer(ctx);
                          final ds = container.read(
                            personalEventDataSourceProvider,
                          );
                          final updated = PersonalEvent(
                            date: DateTime(date.year, date.month, date.day),
                            title: st.name,
                            startTime: st.startTime,
                            endTime: st.endTime,
                            color: st.color,
                            createdAt: DateTime.now(),
                          );
                          ds.updateEvent(date, index, updated);
                          container.read(eventRefreshProvider.notifier).state++;
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
