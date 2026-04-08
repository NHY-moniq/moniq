import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/providers/feedback_providers.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';

// ── 버전별 피드백 바텀시트 ──

class ScheduleHistoryFeedbackSheet extends ConsumerStatefulWidget {
  const ScheduleHistoryFeedbackSheet({
    super.key,
    required this.scheduleId,
    required this.teamId,
    required this.versionLabel,
  });
  final String scheduleId;
  final String teamId;
  final String versionLabel;

  @override
  ConsumerState<ScheduleHistoryFeedbackSheet> createState() =>
      _ScheduleHistoryFeedbackSheetState();
}

class _ScheduleHistoryFeedbackSheetState
    extends ConsumerState<ScheduleHistoryFeedbackSheet> {
  int _overallRating = 0;
  final Map<String, int> _ruleRatings = {
    'wanted': 0,
    'avoid_pattern': 0,
    'skill_balance': 0,
  };
  bool _isSaving = false;
  bool _saved = false;
  bool _loaded = false;

  static const _ruleLabels = {
    'wanted': '원티드 반영',
    'avoid_pattern': '기피패턴 처리',
    'skill_balance': '숙련도 배치',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadExisting());
  }

  Future<void> _loadExisting() async {
    final repo = ref.read(feedbackRepositoryProvider);
    final data = await repo.getFeedback(widget.scheduleId);
    if (!mounted) return;
    setState(() {
      if (data != null) {
        _overallRating = (data['overall_rating'] as num?)?.toInt() ?? 0;
        final rr = (data['rule_ratings'] as Map?) ?? {};
        for (final k in _ruleRatings.keys) {
          _ruleRatings[k] = (rr[k] as num?)?.toInt() ?? 0;
        }
        _saved = true;
      }
      _loaded = true;
    });
  }

  Future<void> _save() async {
    if (_overallRating == 0) return;
    setState(() => _isSaving = true);
    try {
      final repo = ref.read(feedbackRepositoryProvider);
      final ratings = Map<String, int>.from(_ruleRatings)
        ..removeWhere((_, v) => v == 0);
      await repo.saveFeedback(
        scheduleId: widget.scheduleId,
        teamId: widget.teamId,
        overallRating: _overallRating,
        ruleRatings: ratings,
      );
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _saved = true;
      });
    } catch (_) {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = Theme.of(context).colorScheme;

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
            // 핸들
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.lg),
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant
                    .withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            Text(
              '${widget.versionLabel} 근무표 피드백',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '피드백은 다음 달 스케줄 생성에 반영됩니다',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),

            if (!_loaded)
              const CircularProgressIndicator()
            else if (_saved && _overallRating == 0)
              ..._buildForm(theme, colorScheme)
            else if (_saved && _overallRating > 0)
              ..._buildForm(theme, colorScheme)
            else
              ..._buildForm(theme, colorScheme),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildForm(
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return [
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
                size: 40,
                color: star <= _overallRating
                    ? AppColors.brandOrange
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }),
      ),
      const SizedBox(height: AppSpacing.xl),

      // 항목별 평가
      ..._ruleLabels.entries.map((e) {
        final cur = _ruleRatings[e.key] ?? 0;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  e.value,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              ScheduleHistoryRatingToggle(
                value: cur,
                onChanged: (v) =>
                    setState(() => _ruleRatings[e.key] = v),
              ),
            ],
          ),
        );
      }),

      const SizedBox(height: AppSpacing.xl),

      if (_saved && _overallRating > 0)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.check_circle_outline,
                color: AppColors.success,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                '저장된 피드백입니다. 수정 후 다시 저장할 수 있습니다.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),

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
              : Text(_saved ? '피드백 수정 저장' : '피드백 저장'),
        ),
      ),
    ];
  }
}

// ── 평가 토글 ──

class ScheduleHistoryRatingToggle extends StatelessWidget {
  const ScheduleHistoryRatingToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ScheduleHistoryChip(
          label: '좋아요',
          icon: Icons.thumb_up_outlined,
          selected: value == 1,
          color: AppColors.success,
          onTap: () => onChanged(value == 1 ? 0 : 1),
        ),
        const SizedBox(width: 6),
        ScheduleHistoryChip(
          label: '아쉬워요',
          icon: Icons.thumb_down_outlined,
          selected: value == -1,
          color: colorScheme.error,
          onTap: () => onChanged(value == -1 ? 0 : -1),
        ),
      ],
    );
  }
}

// ── 칩 ──

class ScheduleHistoryChip extends StatelessWidget {
  const ScheduleHistoryChip({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.1)
              : Colors.transparent,
          border: Border.all(
            color: selected
                ? color
                : colorScheme.onSurfaceVariant
                    .withValues(alpha: 0.3),
          ),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: selected
                  ? color
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 3),
            Text(
              label,
              style: textTheme.labelSmall?.copyWith(
                color: selected
                    ? color
                    : colorScheme.onSurfaceVariant,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
