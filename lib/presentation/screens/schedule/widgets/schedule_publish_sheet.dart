import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/providers/feedback_providers.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/schedule_generation_viewmodel.dart';

import 'schedule_common_widgets.dart';

// ────────────────────────────────────────
// Step 3: 발행 완료 피드백 바텀시트
// ────────────────────────────────────────

class PublishSuccessSheet extends StatefulWidget {
  const PublishSuccessSheet({
    super.key,
    required this.onClose,
    required this.teamId,
    required this.ref,
    this.showSuccessHeader = true,
  });

  final VoidCallback onClose;
  final String teamId;
  final WidgetRef ref;
  final bool showSuccessHeader;

  @override
  State<PublishSuccessSheet> createState() => PublishSuccessSheetState();
}

class PublishSuccessSheetState extends State<PublishSuccessSheet> {
  int _overallRating = 0; // 0 = 미선택
  // ruleRatings: 1=좋음, -1=아쉬움, 0=미평가
  final Map<String, int> _ruleRatings = {
    'wanted': 0,
    'avoid_pattern': 0,
    'skill_balance': 0,
  };
  bool _isSaving = false;
  bool _hasExisting = false;
  bool _isLoadingExisting = true;
  bool _showSavedToast = false;

  static const _ruleLabels = {
    'wanted': '원티드 반영',
    'avoid_pattern': '기피패턴 처리',
    'skill_balance': '숙련도 배치',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadExistingFeedback();
    });
  }

  Future<void> _loadExistingFeedback() async {
    try {
      final vmState = widget.ref
          .read(scheduleGenerationViewModelProvider(widget.teamId))
          .valueOrNull;
      final scheduleId = vmState?.generatedSchedule?.id;
      if (scheduleId == null) {
        if (!mounted) return;
        setState(() => _isLoadingExisting = false);
        return;
      }

      final repo = widget.ref.read(feedbackRepositoryProvider);
      final data = await repo.getFeedback(scheduleId);
      if (!mounted) return;

      setState(() {
        if (data != null) {
          _overallRating = (data['overall_rating'] as num?)?.toInt() ?? 0;
          final rr = (data['rule_ratings'] as Map?) ?? {};
          for (final k in _ruleRatings.keys) {
            _ruleRatings[k] = (rr[k] as num?)?.toInt() ?? 0;
          }
          _hasExisting = true;
        }
        _isLoadingExisting = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingExisting = false);
    }
  }

  Future<void> _save() async {
    if (_overallRating == 0) return;
    setState(() => _isSaving = true);
    try {
      final ratings = Map<String, int>.from(_ruleRatings)
        ..removeWhere((_, v) => v == 0);
      await widget.ref
          .read(scheduleGenerationViewModelProvider(widget.teamId).notifier)
          .saveFeedback(overallRating: _overallRating, ruleRatings: ratings);
      setState(() {
        _isSaving = false;
        _hasExisting = true;
        _showSavedToast = true;
      });
    } catch (_) {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: AppSpacing.xxl,
          right: AppSpacing.xxl,
          top: AppSpacing.xxl,
          bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.showSuccessHeader) ...[
              // -- 단계 표시 --
              const ScheduleStepIndicator(currentStep: 2, totalSteps: 3),
              const SizedBox(height: AppSpacing.xxl),

              // -- 완료 아이콘 --
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: AppColors.successLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  size: 48,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              Text(
                '스케줄이 발행되었습니다',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '팀 멤버에게 알림이 전송됩니다.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: AppSpacing.xxl),
              const Divider(),
              const SizedBox(height: AppSpacing.md),
            ] else ...[
              // 핸들
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
              ),
              Text(
                '근무표 피드백',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '피드백은 다음 달 스케줄 생성에 반영됩니다',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],

            // -- 피드백 섹션 --
            if (_isLoadingExisting)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: CircularProgressIndicator(),
              )
            else if (_showSavedToast)
              Column(
                children: [
                  const Icon(
                    Icons.favorite,
                    color: AppColors.brandOrange,
                    size: 32,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '피드백이 저장되었습니다',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.brandOrange,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '다음 달 근무표 생성에 반영됩니다.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              )
            else ...[
              Text(
                '이번 근무표는 어떠셨나요?',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '피드백은 다음 달 스케줄 생성에 반영됩니다',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // 별점
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final star = i + 1;
                  return GestureDetector(
                    onTap: () => setState(() => _overallRating = star),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        star <= _overallRating
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 36,
                        color: star <= _overallRating
                            ? AppColors.brandOrange
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: AppSpacing.lg),

              // 항목별 좋음/아쉬움
              ..._ruleLabels.entries.map((entry) {
                final current = _ruleRatings[entry.key] ?? 0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.value,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      RatingToggle(
                        value: current,
                        onChanged: (v) =>
                            setState(() => _ruleRatings[entry.key] = v),
                      ),
                    ],
                  ),
                );
              }),

              if (_hasExisting) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '저장된 피드백입니다. 수정 후 다시 저장할 수 있습니다.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.lg),

              // 저장 버튼
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_overallRating == 0 || _isSaving) ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_hasExisting ? '피드백 수정 저장' : '피드백 저장'),
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: widget.onClose,
                child: const Text('닫기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RatingToggle extends StatelessWidget {
  const RatingToggle({super.key, required this.value, required this.onChanged});
  final int value; // -1, 0, 1
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ToggleChip(
          label: '좋아요',
          icon: Icons.thumb_up_outlined,
          selected: value == 1,
          selectedColor: AppColors.success,
          onTap: () => onChanged(value == 1 ? 0 : 1),
        ),
        const SizedBox(width: AppSpacing.sm),
        ToggleChip(
          label: '아쉬워요',
          icon: Icons.thumb_down_outlined,
          selected: value == -1,
          selectedColor: AppColors.error,
          onTap: () => onChanged(value == -1 ? 0 : -1),
        ),
      ],
    );
  }
}

class ToggleChip extends StatelessWidget {
  const ToggleChip({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? selectedColor.withValues(alpha: 0.1)
              : Colors.transparent,
          border: Border.all(
            color: selected
                ? selectedColor
                : colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
          ),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected ? selectedColor : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: selected ? selectedColor : colorScheme.onSurfaceVariant,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
