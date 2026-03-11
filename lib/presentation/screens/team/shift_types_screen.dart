import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/core/utils/color_utils.dart';
import 'package:moniq/core/utils/time_utils.dart';
import 'package:moniq/data/models/shift_type_model.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/team_detail_viewmodel.dart';
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
      appBar: AppBar(title: const Text('근무 유형')),
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
    final startC = TextEditingController(
        text: existing?.startTime != null
            ? formatTimeString(existing!.startTime!)
            : '');
    final endC = TextEditingController(
        text: existing?.endTime != null
            ? formatTimeString(existing!.endTime!)
            : '');
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
                    child: TextField(
                      controller: startC,
                      decoration:
                          const InputDecoration(labelText: '시작 (HH:MM)'),
                      keyboardType: TextInputType.datetime,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: TextField(
                      controller: endC,
                      decoration:
                          const InputDecoration(labelText: '종료 (HH:MM)'),
                      keyboardType: TextInputType.datetime,
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
                                color: Colors.black87, width: 2.5)
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
                  if (name.isEmpty || code.isEmpty) return;

                  final startTime =
                      startC.text.trim().isNotEmpty ? '${startC.text.trim()}:00' : null;
                  final endTime =
                      endC.text.trim().isNotEmpty ? '${endC.text.trim()}:00' : null;

                  final notifier = ref.read(
                      teamDetailViewModelProvider(teamId).notifier);

                  if (isEdit) {
                    await notifier.updateShiftType(existing.id,
                        name: name,
                        code: code,
                        startTime: startTime,
                        endTime: endTime,
                        color: selectedColor);
                  } else {
                    await notifier.createShiftType(
                        name: name,
                        code: code,
                        startTime: startTime,
                        endTime: endTime,
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
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      title: Text(shiftType.name,
          style: TextStyle(
            color: shiftType.isActive ? null : AppColors.textSecondaryLight,
            decoration: shiftType.isActive ? null : TextDecoration.lineThrough,
          )),
      subtitle: timeText.isNotEmpty
          ? Text(timeText,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppColors.textSecondaryLight))
          : null,
      trailing: isAdmin
          ? Switch.adaptive(
              value: shiftType.isActive,
              onChanged: onToggle,
              activeColor: AppColors.primary,
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
