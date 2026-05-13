import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moniq/data/datasources/push_service.dart';
import 'package:moniq/data/providers/auth_providers.dart';
import 'package:moniq/data/providers/request_providers.dart';
import 'package:moniq/presentation/screens/request/request_create_widgets.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/request_viewmodel.dart';
import 'package:moniq/presentation/widgets/common/moniq_app_bar.dart';
import 'package:moniq/presentation/widgets/common/moniq_stepper.dart';

class RequestCreateScreen extends HookConsumerWidget {
  const RequestCreateScreen({super.key, required this.teamId});

  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: const MoniqAppBar(title: '근무 변경 요청'),
      body: _RequestCreateForm(teamId: teamId),
    );
  }
}

class _RequestCreateForm extends ConsumerStatefulWidget {
  const _RequestCreateForm({required this.teamId});

  final String teamId;

  @override
  ConsumerState<_RequestCreateForm> createState() => _RequestCreateFormState();
}

class _RequestCreateFormState extends ConsumerState<_RequestCreateForm> {
  /// UI 카테고리: 'self' = 내 근무 변경 · 'swap' = 멤버 간 근무 변경.
  /// 실제 서버 changeType은 제출 시 entry별로 결정된다.
  String _category = 'self';

  /// 내 근무 변경 — 다중 entry (1행~N행)
  final List<SelfChangeEntry> _selfEntries = [SelfChangeEntry()];

  /// 멤버 간 근무 변경 (swap) — 다중 entry (1행~N행)
  final List<SwapEntry> _swapEntries = [SwapEntry()];

  bool _isSubmitting = false;
  String? _errorMessage;
  String? _successMessage;

  static const _categories = [
    ('self', '내 근무 변경', Icons.swap_vert),
    ('swap', '멤버 간 근무 변경', Icons.swap_horiz),
  ];

  @override
  void initState() {
    super.initState();
    _selfEntries.first.date = DateTime.now();
  }

  /// 다중 swap entry 중 완료된(제출 가능한) 것만 추출
  List<SwapEntry> get _validSwapEntries =>
      _swapEntries.where((e) => e.isComplete).toList();

  /// 다중 self-change entry 중 완료된 것만 추출
  List<SelfChangeEntry> get _validSelfEntries =>
      _selfEntries.where((e) => e.isComplete).toList();

  bool get _canSubmit {
    if (_isSubmitting) return false;
    if (_category == 'swap') {
      return _validSwapEntries.isNotEmpty;
    }
    return _validSelfEntries.isNotEmpty;
  }

  /// 0=카테고리 선택 · 1=상세 입력 완료
  int get _currentStep {
    if (_category == 'swap') {
      return _validSwapEntries.isNotEmpty ? 1 : 0;
    }
    return _validSelfEntries.isNotEmpty ? 1 : 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSwap = _category == 'swap';

    return SingleChildScrollView(
      padding: AppSpacing.screenAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MoniqStepper.bars(current: _currentStep, total: 2),
          const SizedBox(height: AppSpacing.xxl),
          // Step 1: 요청 유형
          Text('요청 유형',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: _categories.map((t) {
              final (type, label, icon) = t;
              final selected = _category == type;
              final cs = theme.colorScheme;
              return ChoiceChip(
                avatar: Icon(
                  icon,
                  size: 18,
                  color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                ),
                label: Text(label),
                labelStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: selected ? cs.onPrimaryContainer : cs.onSurface,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
                selected: selected,
                showCheckmark: false,
                onSelected: (_) {
                  setState(() {
                    _category = type;
                  });
                },
                backgroundColor: cs.surface,
                selectedColor: cs.primaryContainer,
                side: BorderSide(
                  color: selected
                      ? cs.primary.withValues(alpha: 0.4)
                      : cs.outlineVariant,
                  width: 1,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: AppSpacing.xxl),

          // 내 근무 변경 — 다중 entry (날짜 → 변경 근무)
          if (!isSwap)
            SelfChangeEntriesSection(
              teamId: widget.teamId,
              myUserId: ref.read(currentUserProvider)?.id,
              entries: _selfEntries,
              onChanged: () => setState(() {}),
            ),

          // 멤버 간 근무 변경 (swap) — 다중 entry (팀원 → 날짜 → 변경 근무)
          if (isSwap)
            SwapEntriesSection(
              teamId: widget.teamId,
              myUserId: ref.read(currentUserProvider)?.id,
              entries: _swapEntries,
              onChanged: () => setState(() {}),
            ),

          const SizedBox(height: AppSpacing.xxxl),

          // 에러/성공 메시지
          if (_errorMessage != null) ...[
            SelectableText.rich(
              TextSpan(
                text: _errorMessage,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          if (_successMessage != null) ...[
            SelectableText.rich(
              TextSpan(
                text: _successMessage,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.success,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // 제출 버튼
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _canSubmit ? () => _submit(context) : null,
              style: ElevatedButton.styleFrom(
                disabledBackgroundColor: theme.colorScheme.surfaceContainerHigh,
                disabledForegroundColor: theme.colorScheme.onSurfaceVariant
                    .withValues(alpha: 0.7),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('요청 제출'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit(BuildContext context) async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final repo = ref.read(requestRepositoryProvider);
      final myName = ref
              .read(currentUserProvider)
              ?.userMetadata?['display_name'] as String? ??
          '동료';

      if (_category == 'swap') {
        // 멤버 간 근무 변경 (swap) — 완료된 entry별로 1건씩 createRequest
        for (final e in _validSwapEntries) {
          await repo.createRequest(
            teamId: widget.teamId,
            changeType: 'swap',
            requestedDate: e.date,
            requestedShiftTypeId: e.desiredShiftType?.id,
            targetUserId: e.userId,
            reason: '${e.userName ?? '동료'}님과 근무 교환',
          );
          try {
            final dateLabel = DateFormat('M/d', 'ko_KR').format(e.date!);
            final shiftLabel = e.desiredShiftType?.name ?? '';
            await PushService.instance.sendToUsers(
              userIds: [e.userId!],
              title: '근무 교환 요청',
              body:
                  '$myName 님이 $dateLabel $shiftLabel 근무 교환을 요청했습니다',
              data: {
                'type': 'swap_request',
                'team_id': widget.teamId,
              },
            );
          } catch (_) {}
        }
      } else {
        // 내 근무 변경 — entry별로 submit. OFF면 day_off, 그 외엔 shift_change.
        for (final e in _validSelfEntries) {
          final isOff = e.isOff;
          await repo.createRequest(
            teamId: widget.teamId,
            changeType: isOff ? 'day_off' : 'shift_change',
            requestedDate: e.date,
            requestedShiftTypeId: isOff ? null : e.desiredShiftType?.id,
            reason: isOff
                ? '휴무 요청'
                : '${e.desiredShiftType?.name ?? ''}(으)로 근무 변경',
          );
        }
      }

      ref.invalidate(
        requestListViewModelProvider(widget.teamId),
      );

      if (mounted) {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _errorMessage = '오류가 발생했습니다: $e',
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
