import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/core/utils/color_utils.dart';
import 'package:moniq/data/datasources/personal_shift_type_local_data_source.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';

import 'calendar_providers.dart';

// ── 홈 드로어 ──

class CalendarDrawer extends HookConsumerWidget {
  const CalendarDrawer({
    super.key,
    required this.onImportCalendar,
    required this.onExportCalendar,
  });

  final VoidCallback onImportCalendar;
  final VoidCallback onExportCalendar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final shiftTypes = ref.watch(personalShiftTypesProvider);
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: AppSpacing.screenAll,
              child: Text('메뉴', style: theme.textTheme.titleLarge),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.schedule_outlined),
              title: const Text('내 근무 유형 설정'),
              subtitle: Text('${shiftTypes.length}개 설정됨'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                _showPersonalShiftTypeManager(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month_outlined),
              title: const Text('외부 캘린더 일정 가져오기'),
              subtitle: const Text('외부 캘린더 설정'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                onImportCalendar();
              },
            ),
            ListTile(
              leading: const Icon(Icons.ios_share_outlined),
              title: const Text('캘린더 내보내기'),
              subtitle: const Text('이미지 또는 스프레드시트로 내보내기'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                onExportCalendar();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showPersonalShiftTypeManager(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => const PersonalShiftTypeSheet(),
    );
  }
}

// ── PersonalShiftTypeSheet widget ──

class PersonalShiftTypeSheet extends HookConsumerWidget {
  const PersonalShiftTypeSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final shiftTypes = ref.watch(personalShiftTypesProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollController) => Column(
        children: [
          // 핸들
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(
                  top: AppSpacing.md, bottom: AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              children: [
                Text('근무 유형 설정',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () =>
                      _showAddShiftTypeForm(context, ref),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('추가'),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg),
              itemCount: shiftTypes.length,
              itemBuilder: (context, index) {
                final st = shiftTypes[index];
                final color = parseHexColor(st.color);
                return Card(
                  margin:
                      const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: ListTile(
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: AppRadius.borderRadiusSm,
                      ),
                      child: Center(
                        child: Text(st.code,
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            )),
                      ),
                    ),
                    title: Text(st.name),
                    subtitle: st.startTime != null
                        ? Text(
                            '${st.startTime} ~ ${st.endTime ?? ''}')
                        : null,
                    trailing: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 18),
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                            value: 'edit', child: Text('수정')),
                        const PopupMenuItem(
                            value: 'delete', child: Text('삭제')),
                      ],
                      onSelected: (action) {
                        if (action == 'edit') {
                          _showEditShiftTypeForm(
                              context, ref, st);
                        } else if (action == 'delete') {
                          ref
                              .read(
                                  personalShiftTypeDataSourceProvider)
                              .remove(st.id);
                          ref.invalidate(personalShiftTypesProvider);
                        }
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAddShiftTypeForm(BuildContext context, WidgetRef ref) {
    _showShiftTypeForm(context, ref, null);
  }

  void _showEditShiftTypeForm(
      BuildContext context, WidgetRef ref, PersonalShiftType existing) {
    _showShiftTypeForm(context, ref, existing);
  }

  void _showShiftTypeForm(
      BuildContext context, WidgetRef ref, PersonalShiftType? existing) {
    final nameController =
        TextEditingController(text: existing?.name ?? '');
    final codeController =
        TextEditingController(text: existing?.code ?? '');
    int startHour = existing?.startTime != null
        ? int.parse(existing!.startTime!.split(':')[0])
        : 7;
    int startMinute = existing?.startTime != null
        ? int.parse(existing!.startTime!.split(':')[1])
        : 0;
    int endHour = existing?.endTime != null
        ? int.parse(existing!.endTime!.split(':')[0])
        : 15;
    int endMinute = existing?.endTime != null
        ? int.parse(existing!.endTime!.split(':')[1])
        : 0;
    bool hasStartTime = existing?.startTime != null;
    bool hasEndTime = existing?.endTime != null;
    String selectedColor = existing?.color ?? '#E8923A';

    const colorOptions = [
      '#F0C040',
      '#E8923A',
      '#5A8BB5',
      '#E53E3E',
      '#38A169',
      '#A0AEC0',
      '#9F7AEA',
      '#ED64A6',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
              existing == null ? '근무 유형 추가' : '근무 유형 수정'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                      labelText: '이름 (예: 데이)'),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: codeController,
                  decoration: const InputDecoration(
                      labelText: '코드 (예: D)'),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          _showSheetCupertinoTimePicker(
                            context: ctx,
                            initialHour: startHour,
                            initialMinute: startMinute,
                            onChanged: (h, m) {
                              setDialogState(() {
                                startHour = h;
                                startMinute = m;
                                hasStartTime = true;
                              });
                            },
                          );
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: '시작',
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: AppSpacing.sm),
                          ),
                          child: Text(
                            hasStartTime
                                ? '${startHour.toString().padLeft(2, '0')}:${startMinute.toString().padLeft(2, '0')}'
                                : '없음',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          _showSheetCupertinoTimePicker(
                            context: ctx,
                            initialHour: endHour,
                            initialMinute: endMinute,
                            onChanged: (h, m) {
                              setDialogState(() {
                                endHour = h;
                                endMinute = m;
                                hasEndTime = true;
                              });
                            },
                          );
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: '종료',
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: AppSpacing.sm),
                          ),
                          child: Text(
                            hasEndTime
                                ? '${endHour.toString().padLeft(2, '0')}:${endMinute.toString().padLeft(2, '0')}'
                                : '없음',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: colorOptions.map((hex) {
                    final isSelected = selectedColor == hex;
                    return GestureDetector(
                      onTap: () => setDialogState(
                          () => selectedColor = hex),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: parseHexColor(hex),
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(
                                  color: AppColors.textPrimaryLight,
                                  width: 2.5)
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                final code = codeController.text.trim();
                if (name.isEmpty || code.isEmpty) {
                  showDialog(
                    context: ctx,
                    builder: (dialogCtx) => AlertDialog(
                      title: const Text('입력 오류'),
                      content: const Text(
                          '필수 항목을 입력해주세요.\n이름과 코드는 반드시 입력해야 합니다.'),
                      actions: [
                        TextButton(
                          onPressed: () =>
                              Navigator.pop(dialogCtx),
                          child: const Text('확인'),
                        ),
                      ],
                    ),
                  );
                  return;
                }

                final ds = ref
                    .read(personalShiftTypeDataSourceProvider);
                final st = PersonalShiftType(
                  id: existing?.id ??
                      DateTime.now()
                          .millisecondsSinceEpoch
                          .toString(),
                  name: name,
                  code: code,
                  startTime: hasStartTime
                      ? '${startHour.toString().padLeft(2, '0')}:${startMinute.toString().padLeft(2, '0')}'
                      : null,
                  endTime: hasEndTime
                      ? '${endHour.toString().padLeft(2, '0')}:${endMinute.toString().padLeft(2, '0')}'
                      : null,
                  color: selectedColor,
                );

                if (existing == null) {
                  ds.add(st);
                } else {
                  ds.update(existing.id, st);
                }
                ref.invalidate(personalShiftTypesProvider);
                Navigator.pop(ctx);
              },
              child: Text(existing == null ? '추가' : '저장'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSheetCupertinoTimePicker({
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
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm),
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
}
