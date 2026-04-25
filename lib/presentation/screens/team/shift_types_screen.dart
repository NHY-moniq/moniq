import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/core/utils/color_utils.dart';
import 'package:moniq/core/utils/time_utils.dart';
import 'package:moniq/data/models/shift_type_model.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/team_detail_viewmodel.dart';
import 'package:moniq/presentation/widgets/common/moniq_app_bar.dart';
import 'package:moniq/presentation/widgets/common/moniq_bottom_sheet.dart';
import 'package:moniq/presentation/widgets/common/moniq_error_view.dart';
import 'package:moniq/presentation/widgets/common/moniq_loading_view.dart';

const _presetColors = [
  '#F0C040', // yellow
  '#E8923A', // orange
  '#5A8BB5', // blue
  '#A0AEC0', // gray
  '#48BB78', // green
  '#ED64A6', // pink
  '#9F7AEA', // purple
  '#ED8936', // amber
];

class ShiftTypesScreen extends HookConsumerWidget {
  const ShiftTypesScreen({super.key, required this.teamId});

  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(teamDetailViewModelProvider(teamId));

    return Scaffold(
      appBar: const MoniqAppBar(title: '근무 유형'),
      floatingActionButton: detailAsync.whenOrNull(
        data: (s) => s.isAdmin
            ? FloatingActionButton(
                onPressed: () => _showShiftTypeSheet(context, ref, null),
                child: const Icon(Icons.add),
              )
            : null,
      ),
      body: detailAsync.when(
        loading: () => const MoniqLoadingView(),
        error: (e, _) => MoniqErrorView(
          message: '근무 유형을 불러올 수 없습니다',
          onRetry: () => ref.invalidate(teamDetailViewModelProvider(teamId)),
        ),
        data: (state) {
          if (state.shiftTypes.isEmpty) {
            return const Center(child: Text('등록된 근무 유형이 없습니다'));
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            itemCount: state.shiftTypes.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final t = state.shiftTypes[index];
              return _ShiftTypeTile(
                shiftType: t,
                isAdmin: state.isAdmin,
                onTap: state.isAdmin
                    ? () => _showShiftTypeSheet(context, ref, t)
                    : null,
                onToggle: state.isAdmin
                    ? (val) => ref
                        .read(
                            teamDetailViewModelProvider(teamId).notifier)
                        .toggleShiftTypeActive(t.id, val)
                    : null,
              );
            },
          );
        },
      ),
    );
  }

  void _showShiftTypeSheet(
      BuildContext context, WidgetRef ref, ShiftTypeModel? existing) {
    final isEdit = existing != null;
    final nameC = TextEditingController(text: existing?.name ?? '');
    final codeC = TextEditingController(text: existing?.code ?? '');
    TimeOfDay? startTime = existing?.startTime != null
        ? _parseTimeOfDay(existing!.startTime!)
        : null;
    TimeOfDay? endTime = existing?.endTime != null
        ? _parseTimeOfDay(existing!.endTime!)
        : null;
    var selectedColor = existing?.color ?? _presetColors[0];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
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
              Text(isEdit ? '근무 유형 수정' : '근무 유형 추가',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      )),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: nameC,
                      decoration: const InputDecoration(labelText: '이름'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    flex: 1,
                    child: TextField(
                      controller: codeC,
                      decoration: const InputDecoration(labelText: '코드'),
                      maxLength: 2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        _showCupertinoTimePicker(
                          context: ctx,
                          initialHour: startTime?.hour ?? 9,
                          initialMinute: startTime?.minute ?? 0,
                          onChanged: (h, m) {
                            setSheetState(() =>
                                startTime = TimeOfDay(hour: h, minute: m));
                          },
                        );
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: '시작',
                          prefixIcon: Icon(Icons.access_time, size: 20),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm),
                        ),
                        child: Text(startTime != null
                            ? _formatTime(startTime!)
                            : '설정 안함'),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        _showCupertinoTimePicker(
                          context: ctx,
                          initialHour:
                              endTime?.hour ?? (startTime?.hour ?? 9) + 1,
                          initialMinute:
                              endTime?.minute ?? startTime?.minute ?? 0,
                          onChanged: (h, m) {
                            setSheetState(() =>
                                endTime = TimeOfDay(hour: h, minute: m));
                          },
                        );
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: '종료',
                          prefixIcon: Icon(Icons.access_time, size: 20),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm),
                        ),
                        child: Text(endTime != null
                            ? _formatTime(endTime!)
                            : '설정 안함'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('색상', style: Theme.of(ctx).textTheme.labelLarge),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                children: _presetColors.map((c) {
                  final isSelected = c == selectedColor;
                  return GestureDetector(
                    onTap: () => setSheetState(() => selectedColor = c),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: parseHexColor(c),
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(
                                color: Theme.of(ctx)
                                    .colorScheme
                                    .onSurface,
                                width: 2.5,
                              )
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.xl),
              ElevatedButton(
                onPressed: () async {
                  final name = nameC.text.trim();
                  final code = codeC.text.trim();
                  if (name.isEmpty || code.isEmpty) {
                    await showMoniqInfoSheet(
                      context: ctx,
                      title: '필수 항목을 입력해주세요',
                      message: '이름과 코드는 반드시 입력해야 해요.',
                    );
                    return;
                  }

                  final startTimeStr =
                      startTime != null ? '${_formatTime(startTime!)}:00' : null;
                  final endTimeStr =
                      endTime != null ? '${_formatTime(endTime!)}:00' : null;

                  final notifier = ref.read(
                      teamDetailViewModelProvider(teamId).notifier);

                  if (isEdit) {
                    await notifier.updateShiftType(existing.id,
                        name: name,
                        code: code,
                        startTime: startTimeStr,
                        endTime: endTimeStr,
                        color: selectedColor);
                  } else {
                    await notifier.createShiftType(
                        name: name,
                        code: code,
                        startTime: startTimeStr,
                        endTime: endTimeStr,
                        color: selectedColor);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: Text(isEdit ? '저장' : '추가'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShiftTypeTile extends StatelessWidget {
  const _ShiftTypeTile({
    required this.shiftType,
    required this.isAdmin,
    this.onTap,
    this.onToggle,
  });

  final ShiftTypeModel shiftType;
  final bool isAdmin;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeText = _buildTimeText();

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: parseHexColor(shiftType.color),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          shiftType.code,
          style: TextStyle(
              color: Theme.of(context).colorScheme.surface,
              fontWeight: FontWeight.bold,
              fontSize: 16),
        ),
      ),
      title: Text(shiftType.name,
          style: TextStyle(
            color: shiftType.isActive
                ? null
                : Theme.of(context).colorScheme.onSurfaceVariant,
            decoration: shiftType.isActive ? null : TextDecoration.lineThrough,
          )),
      subtitle: timeText.isNotEmpty
          ? Text(timeText,
              style: theme.textTheme.bodySmall
                  ?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant,
                  ))
          : null,
      trailing: isAdmin
          ? Switch.adaptive(
              value: shiftType.isActive,
              onChanged: onToggle,
              activeColor: Theme.of(context).colorScheme.primary,
            )
          : null,
      onTap: onTap,
    );
  }

  String _buildTimeText() {
    if (shiftType.startTime == null && shiftType.endTime == null) return '';
    final start =
        shiftType.startTime != null ? formatTimeString(shiftType.startTime!) : '';
    final end =
        shiftType.endTime != null ? formatTimeString(shiftType.endTime!) : '';
    if (start.isEmpty && end.isEmpty) return '';
    return '$start ~ $end';
  }
}

String _formatTime(TimeOfDay time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

TimeOfDay? _parseTimeOfDay(String timeStr) {
  final cleaned = timeStr.replaceAll(RegExp(r'[^0-9:]'), '');
  final parts = cleaned.split(':');
  if (parts.length < 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  return TimeOfDay(hour: hour, minute: minute);
}

void _showCupertinoTimePicker({
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
              initialDateTime:
                  DateTime(2000, 1, 1, selectedHour, selectedMinute),
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
