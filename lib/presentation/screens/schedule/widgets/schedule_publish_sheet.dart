import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/providers/feedback_providers.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/screens/schedule/widgets/schedule_common_widgets.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/schedule_generation_viewmodel.dart';

// ────────────────────────────────────────
// Step 4: 발행 완료 피드백 바텀시트
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

  /// 별점 옆에 붙는 설명. 선택한 점수를 말로 되짚어 주면 오터치를 바로 알아챈다.
  static const _ratingCaptions = {
    1: '많이 아쉬워요',
    2: '아쉬워요',
    3: '보통이에요',
    4: '좋아요',
    5: '아주 좋아요',
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
          top: widget.showSuccessHeader ? AppSpacing.xxl : AppSpacing.md,
          bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.showSuccessHeader)
              _buildSuccessHeader(theme, colorScheme)
            else
              _buildSheetHeader(theme, colorScheme),
            const SizedBox(height: AppSpacing.xl),

            // -- 피드백 섹션: 성공 알림과 섞이지 않도록 하나의 카드로 묶는다 --
            if (_isLoadingExisting)
              _buildLoadingCard(colorScheme)
            else if (_showSavedToast)
              _buildSavedCard(theme, colorScheme)
            else
              _buildFeedbackCard(theme, colorScheme),

            const SizedBox(height: AppSpacing.xl),
            _buildActions(colorScheme),
          ],
        ),
      ),
    );
  }

  // ── 헤더 ──

  Widget _buildSuccessHeader(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      children: [
        // 발행이 끝난 시점에는 4단계 인디케이터가 더 이상 길잡이 역할을 하지 않는다.
        // "마지막 단계를 끝냈다"는 사실만 배지로 압축해 성공 메시지에 붙인다.
        _StepCompleteBadge(
          label: 'STEP 4/4 · 발행 완료',
          colorScheme: colorScheme,
          textStyle: theme.textTheme.labelSmall,
        ),
        const SizedBox(height: AppSpacing.xl),

        // -- 완료 아이콘 --
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            // 고정 파스텔 대신 반투명 틴트라 라이트/다크 어디서도 배경과 겉돌지 않는다.
            color: AppColors.success.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_rounded,
            size: 40,
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
        const SizedBox(height: AppSpacing.xs),
        Text(
          '팀 멤버에게 알림이 전송됩니다.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSheetHeader(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      children: [
        // 핸들 (드래그로 닫을 수 있는 모드에서만 노출된다)
        Container(
          width: 36,
          height: 4,
          margin: const EdgeInsets.only(bottom: AppSpacing.lg),
          decoration: BoxDecoration(
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            borderRadius: AppRadius.borderRadiusFull,
          ),
        ),
        Text(
          '근무표 피드백',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  // ── 피드백 카드 ──

  BoxDecoration _cardDecoration(ColorScheme colorScheme) => BoxDecoration(
    // 시트 배경(surfaceContainerLow)보다 한 톤 낮춰 "부가 요청" 영역임을 드러낸다.
    color: colorScheme.surfaceContainerLowest,
    borderRadius: AppRadius.borderRadiusLg,
    border: Border.all(
      color: colorScheme.outlineVariant.withValues(alpha: 0.6),
    ),
  );

  Widget _buildLoadingCard(ColorScheme colorScheme) {
    return Container(
      height: 140,
      alignment: Alignment.center,
      decoration: _cardDecoration(colorScheme),
      child: const CircularProgressIndicator(),
    );
  }

  Widget _buildSavedCard(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      decoration: _cardDecoration(colorScheme),
      child: Column(
        children: [
          const Icon(Icons.favorite, color: AppColors.brandOrange, size: 32),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '피드백이 저장되었습니다',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.brandOrange,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '다음 달 근무표 생성에 반영됩니다.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackCard(ThemeData theme, ColorScheme colorScheme) {
    final caption = _ratingCaptions[_overallRating] ?? '별점을 눌러 평가해주세요';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      decoration: _cardDecoration(colorScheme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '이번 근무표는 어떠셨나요?',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            '피드백은 다음 달 스케줄 생성에 반영됩니다',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),

          // 별점
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final star = i + 1;
              final selected = star <= _overallRating;
              return Semantics(
                button: true,
                selected: selected,
                label: '$star점',
                child: InkWell(
                  onTap: () => setState(() => _overallRating = star),
                  customBorder: const CircleBorder(),
                  // 아이콘만으로는 터치 영역이 좁아 44px 타깃을 따로 확보한다.
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(
                      selected
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 34,
                      color: selected
                          ? AppColors.brandOrange
                          : colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            caption,
            style: theme.textTheme.labelMedium?.copyWith(
              color: _overallRating > 0
                  ? colorScheme.onSurface
                  : colorScheme.onSurfaceVariant,
              fontWeight: _overallRating > 0
                  ? FontWeight.w700
                  : FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: AppSpacing.lg),
          Divider(
            height: 1,
            color: colorScheme.outlineVariant.withValues(alpha: 0.6),
          ),
          const SizedBox(height: AppSpacing.md),

          // 항목별 평가: 좋아요/아쉬워요 라벨을 줄마다 반복하지 않고
          // 상단 범례 한 줄로 모아 세 줄이 가볍게 읽히도록 한다.
          Row(
            children: [
              Expanded(
                child: Text(
                  '세부 평가 (선택)',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              // 글자 크기를 키운 기기에서도 넘치지 않도록 범례는 줄어들 수 있게 둔다.
              Flexible(
                child: _RatingLegend(
                  colorScheme: colorScheme,
                  textStyle: theme.textTheme.labelSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),

          ..._ruleLabels.entries.map((entry) {
            final current = _ruleRatings[entry.key] ?? 0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
              child: Row(
                children: [
                  Expanded(
                    child: Text(entry.value, style: theme.textTheme.bodyMedium),
                  ),
                  RatingToggle(
                    label: entry.value,
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
        ],
      ),
    );
  }

  // ── 하단 액션 ──

  Widget _buildActions(ColorScheme colorScheme) {
    final close = OutlinedButton(
      onPressed: widget.onClose,
      child: const Text('닫기'),
    );

    // 피드백 폼이 없는 상태(로딩·저장완료)에서는 닫기 하나만 남기고,
    // 저장 완료 시엔 닫기 자체가 다음 행동이므로 주 버튼으로 올린다.
    if (_isLoadingExisting) return close;
    if (_showSavedToast) {
      return ElevatedButton(onPressed: widget.onClose, child: const Text('닫기'));
    }

    // 세로로 쌓아두면 최종 행동이 흐려져, 한 줄에 부/주 액션을 나란히 둔다.
    return Row(
      children: [
        Expanded(child: close),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: (_overallRating == 0 || _isSaving) ? null : _save,
            child: _isSaving
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.onPrimary,
                    ),
                  )
                : Text(_hasExisting ? '수정 저장' : '피드백 저장'),
          ),
        ),
      ],
    );
  }
}

/// 발행 완료 시 단계 진행을 한 줄로 압축해 보여주는 배지.
///
/// 탭하면 지나온 단계(규칙 → 기간 → 미리보기 → 발행)를 펼쳐 보여준다.
/// 완료 화면에서 4단계를 항상 펼쳐두면 성공 메시지보다 자리를 많이 먹어서,
/// 평소엔 접어두고 궁금할 때만 펴도록 했다.
class _StepCompleteBadge extends StatefulWidget {
  const _StepCompleteBadge({
    required this.label,
    required this.colorScheme,
    required this.textStyle,
  });

  final String label;
  final ColorScheme colorScheme;
  final TextStyle? textStyle;

  @override
  State<_StepCompleteBadge> createState() => _StepCompleteBadgeState();
}

class _StepCompleteBadgeState extends State<_StepCompleteBadge> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = widget.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          expanded: _expanded,
          label: '${widget.label}. 지나온 단계 보기',
          child: Material(
            color: cs.primaryContainer,
            borderRadius: AppRadius.borderRadiusFull,
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: AppRadius.borderRadiusFull,
              child: Padding(
                // primaryContainer/onPrimaryContainer 쌍이라 시프트별
                // primary(금색·남색 등)와 다크 모드에서도 대비가 유지된다.
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: cs.onPrimaryContainer,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      widget.label,
                      style: widget.textStyle?.copyWith(
                        color: cs.onPrimaryContainer,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xxs),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: _expanded
              ? Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: _StepTrail(colorScheme: cs, textStyle: widget.textStyle),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

/// 지나온 단계를 가로 한 줄로 되짚는 흔적. 전부 완료 상태라 강약 없이
/// 같은 무게로 두고, 마지막 단계만 채워 현재 위치를 표시한다.
class _StepTrail extends StatelessWidget {
  const _StepTrail({required this.colorScheme, required this.textStyle});

  final ColorScheme colorScheme;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    const labels = ScheduleStepIndicator.stepLabels;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: Icon(
                Icons.chevron_right_rounded,
                size: 14,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 16,
                height: 16,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.primaryContainer,
                ),
                child: Icon(
                  Icons.check_rounded,
                  size: 10,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: AppSpacing.xxs),
              Text(
                labels[i],
                style: textStyle?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight:
                      i == labels.length - 1 ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// 아이콘만 남긴 좋아요/아쉬워요 토글의 의미를 알려주는 범례.
class _RatingLegend extends StatelessWidget {
  const _RatingLegend({required this.colorScheme, required this.textStyle});

  final ColorScheme colorScheme;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final style = textStyle?.copyWith(color: colorScheme.onSurfaceVariant);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.thumb_up_outlined,
          size: 12,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: AppSpacing.xxs),
        Text('좋아요', style: style),
        const SizedBox(width: AppSpacing.sm),
        Icon(
          Icons.thumb_down_outlined,
          size: 12,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: AppSpacing.xxs),
        Text('아쉬워요', style: style),
      ],
    );
  }
}

class RatingToggle extends StatelessWidget {
  const RatingToggle({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  /// 스크린 리더용 항목명. 아이콘만 표시하므로 의미 전달을 여기에 의존한다.
  final String label;
  final int value; // -1, 0, 1
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ToggleChip(
          label: '$label 좋아요',
          icon: Icons.thumb_up_rounded,
          selected: value == 1,
          selectedColor: AppColors.success,
          onTap: () => onChanged(value == 1 ? 0 : 1),
        ),
        const SizedBox(width: AppSpacing.xs),
        ToggleChip(
          label: '$label 아쉬워요',
          icon: Icons.thumb_down_rounded,
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
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.borderRadiusFull,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 48,
            height: 36,
            decoration: BoxDecoration(
              color: selected
                  ? selectedColor.withValues(alpha: 0.14)
                  : colorScheme.surfaceContainer,
              border: Border.all(
                color: selected
                    ? selectedColor.withValues(alpha: 0.55)
                    : colorScheme.outlineVariant.withValues(alpha: 0.6),
              ),
              borderRadius: AppRadius.borderRadiusFull,
            ),
            child: Icon(
              icon,
              size: 18,
              color: selected ? selectedColor : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
