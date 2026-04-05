import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moniq/data/providers/request_providers.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/request_viewmodel.dart';

class RequestCreateScreen extends HookConsumerWidget {
  const RequestCreateScreen({super.key, required this.teamId});

  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('변경 요청')),
      body: _RequestCreateForm(teamId: teamId),
    );
  }
}

class _RequestCreateForm extends StatefulWidget {
  const _RequestCreateForm({required this.teamId});

  final String teamId;

  @override
  State<_RequestCreateForm> createState() => _RequestCreateFormState();
}

class _RequestCreateFormState extends State<_RequestCreateForm> {
  String _changeType = 'day_off';
  DateTime? _requestedDate;
  String? _selectedShiftTypeId;
  String _reason = '';
  String _note = '';
  bool _isSubmitting = false;

  static const _changeTypes = [
    ('day_off', '휴무 요청', Icons.event_busy),
    ('shift_change', '근무 변경', Icons.swap_vert),
    ('swap', '근무 교환', Icons.swap_horiz),
    ('schedule_change', '일정 변경', Icons.edit_calendar),
  ];

  static const _presetReasons = [
    '개인 사유',
    '병원 방문',
    '가족 행사',
    '학업/시험',
    '기타',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: AppSpacing.screenAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step 1: 요청 유형
          Text('요청 유형',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: _changeTypes.map((t) {
              final (type, label, icon) = t;
              final selected = _changeType == type;
              return ChoiceChip(
                avatar: Icon(icon, size: 18),
                label: Text(label),
                selected: selected,
                onSelected: (_) => setState(() => _changeType = type),
                selectedColor: theme.colorScheme.primary.withValues(alpha: 0.15),
              );
            }).toList(),
          ),

          const SizedBox(height: AppSpacing.xxl),

          // Step 2: 희망 날짜
          Text('희망 날짜',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.md),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _requestedDate ?? DateTime.now(),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 90)),
              );
              if (picked != null) {
                setState(() => _requestedDate = picked);
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                border: Border.all(
                  color: theme.colorScheme.outlineVariant,
                ),
                borderRadius: AppRadius.borderRadiusMd,
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today,
                      size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    _requestedDate != null
                        ? DateFormat('yyyy년 MM월 dd일')
                            .format(_requestedDate!)
                        : '날짜를 선택해주세요',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: _requestedDate != null
                          ? null
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xxl),

          // Step 3: 사유
          Text('사유',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: _presetReasons.map((reason) {
              final selected = _reason == reason;
              return ChoiceChip(
                label: Text(reason),
                selected: selected,
                onSelected: (_) => setState(() => _reason = reason),
                selectedColor: theme.colorScheme.primary.withValues(alpha: 0.15),
              );
            }).toList(),
          ),

          const SizedBox(height: AppSpacing.xxl),

          // 메모 (선택)
          Text('메모 (선택)',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.md),
          TextField(
            onChanged: (v) => _note = v,
            decoration: const InputDecoration(
              hintText: '추가 메모를 입력해주세요',
            ),
            maxLines: 3,
          ),

          const SizedBox(height: AppSpacing.xxxl),

          // 제출 버튼
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting || _reason.isEmpty
                  ? null
                  : () => _submit(context),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('요청 제출'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit(BuildContext context) async {
    setState(() => _isSubmitting = true);

    try {
      final container = ProviderScope.containerOf(context);
      final repo = container.read(requestRepositoryProvider);

      await repo.createRequest(
        teamId: widget.teamId,
        changeType: _changeType,
        requestedDate: _requestedDate,
        requestedShiftTypeId: _selectedShiftTypeId,
        reason: _reason,
        note: _note.isNotEmpty ? _note : null,
      );

      // 목록 새로고침
      container.invalidate(requestListViewModelProvider(widget.teamId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('요청이 제출되었습니다')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류가 발생했습니다: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
