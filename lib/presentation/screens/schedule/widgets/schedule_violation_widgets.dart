import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/schedule_generation_viewmodel.dart';

// ────────────────────────────────────────
// 위반 리포트 바텀시트
// ────────────────────────────────────────

class ViolationSheet extends ConsumerStatefulWidget {
  const ViolationSheet({
    super.key,
    required this.state,
    required this.teamId,
  });
  final ScheduleGenerationState state;
  final String teamId;

  @override
  ConsumerState<ViolationSheet> createState() => _ViolationSheetState();
}

class _ViolationSheetState extends ConsumerState<ViolationSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final state = ref
            .watch(scheduleGenerationViewModelProvider(widget.teamId))
            .valueOrNull ??
        widget.state;

    final hardWarnings = state.validationWarnings ?? [];
    final customViolCount = state.customRuleViolations.length;
    final totalHard = hardWarnings.length + customViolCount;
    final softTotal =
        state.softViolations.values.fold(0, (s, v) => s + v.length) +
        state.softCustomViolations.length;
    final wantedPct = state.wantedTotal > 0
        ? (state.wantedSatisfied / state.wantedTotal * 100).round()
        : 100;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (ctx, scrollCtrl) => Column(
        children: [
          // ── 핸들 ──
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── 헤더 ──
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '분석 리포트',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    // AI 분석 버튼
                    if (!state.isAnalyzing && state.aiAnalysis == null)
                      _AiAnalysisButton(
                        onTap: () {
                          ref
                              .read(
                                scheduleGenerationViewModelProvider(widget.teamId)
                                    .notifier,
                              )
                              .analyzeViolations('');
                        },
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                // 요약 한 줄
                Wrap(
                  spacing: AppSpacing.md,
                  children: [
                    _SummaryPill(
                      label: totalHard > 0 ? '하드 $totalHard건' : '하드 없음',
                      color: totalHard > 0 ? AppColors.error : AppColors.success,
                    ),
                    if (state.wantedTotal > 0)
                      _SummaryPill(
                        label: '원티드 $wantedPct%',
                        color: wantedPct >= 80
                            ? AppColors.success
                            : AppColors.brandOrange,
                      ),
                    if (softTotal > 0)
                      _SummaryPill(
                        label: '소프트 $softTotal건',
                        color: AppColors.brandOrange,
                      ),
                  ],
                ),
              ],
            ),
          ),

          // ── AI 분석 카드 ──
          if (state.isAnalyzing || state.aiAnalysis != null)
            _AiAnalysisCard(
              state: state,
              onRefresh: () {
                ref
                    .read(
                      scheduleGenerationViewModelProvider(widget.teamId)
                          .notifier,
                    )
                    .analyzeViolations('');
              },
            ),

          // ── 필 탭바 ──
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
            child: _PillTabBar(
              controller: _tabController,
              tabs: [
                _PillTab(
                  label: '하드 위반',
                  count: totalHard,
                  activeColor: AppColors.error,
                ),
                _PillTab(
                  label: '소프트 요약',
                  count: softTotal,
                  activeColor: AppColors.brandOrange,
                ),
              ],
            ),
          ),

          // ── 탭 콘텐츠 ──
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // 탭 1: 하드 위반
                _HardViolationTab(
                  hardWarnings: hardWarnings,
                  customViolations: state.customRuleViolations,
                  scrollCtrl: scrollCtrl,
                ),
                // 탭 2: 소프트 요약
                SoftSummaryTab(state: state, wantedPct: wantedPct),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────
// 하드 위반 탭
// ────────────────────────────────────────

class _HardViolationTab extends StatelessWidget {
  const _HardViolationTab({
    required this.hardWarnings,
    required this.customViolations,
    required this.scrollCtrl,
  });

  final List<String> hardWarnings;
  final List<String> customViolations;
  final ScrollController scrollCtrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasWarnings = hardWarnings.isNotEmpty;
    final hasCustom = customViolations.isNotEmpty;

    if (!hasWarnings && !hasCustom) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded,
                  size: 32, color: AppColors.success),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '하드 위반 없음',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppColors.success,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '모든 필수 조건을 충족합니다',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      controller: scrollCtrl,
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        // ── 일반 하드 위반 (규칙 위반, 인원 부족 등) ──
        if (hasWarnings) ...[
          const _SectionHeader(label: '규칙 위반', color: AppColors.error),
          const SizedBox(height: AppSpacing.sm),
          ...hardWarnings.map(
            (msg) => Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(AppRadius.xs),
                border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.15)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: AppColors.error, size: 18),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(msg, style: theme.textTheme.bodySmall),
                  ),
                ],
              ),
            ),
          ),
          if (hasCustom) const SizedBox(height: AppSpacing.lg),
        ],

        // ── 하드 커스텀 룰 위반 ──
        if (hasCustom) ...[
          const _SectionHeader(label: '하드 커스텀 룰', color: AppColors.error),
          const SizedBox(height: AppSpacing.sm),
          ...CustomRuleViolationGroup.groupBy(customViolations)
              .map((g) => CustomRuleViolationGroup(group: g)),
        ],
      ],
    );
  }
}

// ────────────────────────────────────────
// 필 탭바
// ────────────────────────────────────────

class _PillTab {
  const _PillTab({
    required this.label,
    required this.count,
    required this.activeColor,
  });
  final String label;
  final int count;
  final Color activeColor;
}

class _PillTabBar extends StatefulWidget {
  const _PillTabBar({required this.controller, required this.tabs});
  final TabController controller;
  final List<_PillTab> tabs;

  @override
  State<_PillTabBar> createState() => _PillTabBarState();
}

class _PillTabBarState extends State<_PillTabBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTabChanged);
    super.dispose();
  }

  void _onTabChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final current = widget.controller.index;

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: List.generate(widget.tabs.length, (i) {
          final tab = widget.tabs[i];
          final isActive = i == current;
          final activeColor = tab.activeColor;

          return Expanded(
            child: GestureDetector(
              onTap: () => widget.controller.animateTo(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                margin: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: isActive ? activeColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      tab.label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: isActive
                            ? Colors.white
                            : colorScheme.onSurfaceVariant,
                        fontWeight:
                            isActive ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    if (tab.count > 0) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: isActive
                              ? Colors.white.withValues(alpha: 0.25)
                              : activeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Text(
                          '${tab.count}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isActive ? Colors.white : activeColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ────────────────────────────────────────
// AI 분석 버튼
// ────────────────────────────────────────

class _AiAnalysisButton extends StatelessWidget {
  const _AiAnalysisButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.brandOrange.withValues(alpha: 0.15),
              AppColors.primary.withValues(alpha: 0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(
              color: AppColors.brandOrange.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome_rounded,
                size: 14, color: AppColors.brandOrange),
            const SizedBox(width: 4),
            Text(
              'AI 분석',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.brandOrange,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────
// AI 분석 카드
// ────────────────────────────────────────

class _AiAnalysisCard extends StatelessWidget {
  const _AiAnalysisCard({required this.state, required this.onRefresh});
  final ScheduleGenerationState state;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(
          AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.brandOrange.withValues(alpha: 0.08),
            AppColors.primary.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.brandOrange.withValues(alpha: 0.2)),
      ),
      child: state.isAnalyzing
          ? Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.brandOrange),
                ),
                const SizedBox(width: AppSpacing.md),
                Text('AI가 근무표를 분석하고 있습니다...',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.brandOrange,
                    )),
              ],
            )
          // 분석 텍스트가 길어도 카드 높이를 제한하고 내부 스크롤로 처리해
          // 바텀시트 Column이 오버플로우되지 않도록 한다.
          : ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.28,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.auto_awesome_rounded,
                      size: 15, color: AppColors.brandOrange),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(state.aiAnalysis!,
                          style: theme.textTheme.bodySmall),
                    ),
                  ),
                  GestureDetector(
                    onTap: onRefresh,
                    child: const Icon(Icons.refresh_rounded,
                        size: 16, color: AppColors.textSecondaryLight),
                  ),
                ],
              ),
            ),
    );
  }
}

// ────────────────────────────────────────
// 위반 리포트 진입 배너 (항상 표시)
// ────────────────────────────────────────

class ViolationSummaryBanner extends StatelessWidget {
  const ViolationSummaryBanner({
    super.key,
    required this.state,
    required this.onTap,
  });

  final ScheduleGenerationState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hardCount = (state.validationWarnings ?? []).length;
    final customViolCount = state.customRuleViolations.length;
    final softCustomCount = state.softCustomViolations.length;
    final hasIssue = hardCount > 0 || customViolCount > 0;

    const patternKeys = {'NOD', 'NOOD', 'NOE', 'EOD'};
    final softPatternTotal = state.softViolations.entries
        .where((e) => patternKeys.contains(e.key))
        .fold(0, (s, e) => s + e.value.length);
    final skillViolTotal = (state.softViolations['신규단독'] ?? []).length;

    final wantedPct = state.wantedTotal > 0
        ? (state.wantedSatisfied / state.wantedTotal * 100).round()
        : 100;

    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        color: hasIssue
            ? AppColors.error.withValues(alpha: 0.06)
            : AppColors.success.withValues(alpha: 0.06),
        child: Row(
          children: [
            Icon(
              hasIssue
                  ? Icons.assignment_late_outlined
                  : Icons.assignment_turned_in_outlined,
              size: 20,
              color: hasIssue ? AppColors.error : AppColors.success,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  if (hardCount > 0)
                    BannerChip(
                        label: '하드 위반 $hardCount건',
                        color: AppColors.error),
                  if (customViolCount > 0)
                    BannerChip(
                        label: '커스텀 룰 위반 $customViolCount건',
                        color: AppColors.error),
                  if (softCustomCount > 0)
                    BannerChip(
                        label: '소프트 커스텀 $softCustomCount건',
                        color: AppColors.brandOrange),
                  if (softPatternTotal > 0)
                    BannerChip(
                        label: '기피패턴 $softPatternTotal회',
                        color: AppColors.brandOrange),
                  if (skillViolTotal > 0)
                    BannerChip(
                        label: '숙련도 $skillViolTotal건',
                        color: AppColors.brandOrange),
                  if (state.wantedTotal > 0)
                    BannerChip(
                      label: '원티드 $wantedPct%',
                      color: wantedPct >= 80
                          ? AppColors.success
                          : AppColors.brandOrange,
                    ),
                  if (!hasIssue &&
                      softPatternTotal == 0 &&
                      skillViolTotal == 0 &&
                      softCustomCount == 0 &&
                      state.wantedTotal == 0)
                    Text(
                      '위반 없음',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('리포트',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: AppColors.textSecondaryLight)),
                const Icon(Icons.chevron_right,
                    size: 16, color: AppColors.textSecondaryLight),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class BannerChip extends StatelessWidget {
  const BannerChip({super.key, required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600, color: color),
    );
  }
}

// ────────────────────────────────────────
// 헤더 요약 필
// ────────────────────────────────────────

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    );
  }
}

// ────────────────────────────────────────
// 소프트 요약 탭
// ────────────────────────────────────────

class SoftSummaryTab extends StatelessWidget {
  const SoftSummaryTab({
    super.key,
    required this.state,
    required this.wantedPct,
  });

  final ScheduleGenerationState state;
  final int wantedPct;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final softViol = state.softViolations;
    const patternKeys = {'NOD', 'NOOD', 'NOE', 'EOD'};
    final hasSoftPattern = softViol.entries
        .any((e) => patternKeys.contains(e.key) && e.value.isNotEmpty);
    final softCustomViols = state.softCustomViolations;
    final hasSkill = (softViol['신규단독'] ?? []).isNotEmpty;

    final allGood = state.wantedTotal == 0 &&
        !hasSoftPattern &&
        !hasSkill &&
        softCustomViols.isEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
      children: [
        // ── 원티드 반영률 ──
        if (state.wantedTotal > 0) ...[
          _SectionHeader(
            label: '원티드 반영률',
            color: wantedPct >= 80 ? AppColors.success : AppColors.brandOrange,
          ),
          const SizedBox(height: AppSpacing.sm),
          SummaryCard(
            icon: Icons.favorite_outline,
            iconColor: wantedPct >= 80 ? AppColors.success : AppColors.brandOrange,
            title: '원티드 반영률',
            value: '$wantedPct%',
            subtitle:
                '${state.wantedSatisfied}건 반영 / 전체 ${state.wantedTotal}건',
            valueColor:
                wantedPct >= 80 ? AppColors.success : AppColors.brandOrange,
          ),
          if (state.wantedUnsatisfied.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.brandOrange.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(AppRadius.xs),
                border: Border.all(
                    color: AppColors.brandOrange.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '미반영 원티드',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.brandOrange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...state.wantedUnsatisfied.map(
                    (item) {
                      final parts = item.split('\t');
                      final name = parts[0];
                      final detail = parts.length > 1 ? parts[1] : '';
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 1),
                              child: Icon(Icons.event_busy_outlined,
                                  size: 14, color: AppColors.brandOrange),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              name,
                              style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                detail,
                                style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
        ],

        // ── 기피 패턴 위반 ──
        if (hasSoftPattern) ...[
          const _SectionHeader(
              label: '기피패턴 위반', color: AppColors.brandOrange),
          const SizedBox(height: AppSpacing.sm),
          ...{
            'NOD': ('NOD (나이트→오프→데이)', softViol['NOD']),
            'NOOD': ('NOOD (나이트→오프×2→데이)', softViol['NOOD']),
            'NOE': ('NOE (나이트→오프→이브닝)', softViol['NOE']),
            'EOD': ('EOD (이브닝→오프→데이)', softViol['EOD']),
          }.entries.where((e) => (e.value.$2?.isNotEmpty ?? false)).map((e) {
            final label = e.value.$1;
            final items = e.value.$2!;
            return PatternGroup(label: label, items: items);
          }),
          const SizedBox(height: AppSpacing.lg),
        ],

        // ── 숙련도 위반 ──
        if (hasSkill) ...[
          const _SectionHeader(label: '숙련도 위반', color: AppColors.brandOrange),
          const SizedBox(height: AppSpacing.sm),
          PatternGroup(
            label: '신규 단독 근무',
            items: softViol['신규단독']!,
            icon: Icons.school_outlined,
          ),
          const SizedBox(height: AppSpacing.lg),
        ],

        // ── 소프트 커스텀 룰 위반 ──
        if (softCustomViols.isNotEmpty) ...[
          const _SectionHeader(
            label: '소프트 커스텀 룰',
            color: AppColors.brandOrange,
          ),
          const SizedBox(height: AppSpacing.sm),
          ...CustomRuleViolationGroup.groupBy(softCustomViols, isHard: false)
              .map((g) => CustomRuleViolationGroup(group: g, isHard: false)),
          const SizedBox(height: AppSpacing.md),
        ],

        // ── 모두 양호 ──
        if (allGood)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xxl),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_rounded,
                        size: 32, color: AppColors.success),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    '소프트 위반 없음',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ── 섹션 헤더 (왼쪽 컬러 바) ──
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class PatternGroup extends StatelessWidget {
  const PatternGroup({
    super.key,
    required this.label,
    required this.items,
    this.icon = Icons.warning_amber_rounded,
  });
  final String label;
  final List<String> items;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.brandOrange.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border.all(color: AppColors.brandOrange.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: AppColors.brandOrange),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ),
              Text(
                '${items.length}회',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.brandOrange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(left: 21, top: 2),
              child: Text(
                '- $item',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.textSecondaryLight),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.valueColor,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final String subtitle;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: iconColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.textSecondaryLight)),
                Text(subtitle,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.textSecondaryLight)),
              ],
            ),
          ),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              color: valueColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────
// 커스텀 룰 위반 그룹 카드
// ────────────────────────────────────────

class CustomRuleGroup {
  CustomRuleGroup({required this.ruleText, required this.items});
  final String ruleText;
  final List<String> items;
}

class CustomRuleViolationGroup extends StatelessWidget {
  const CustomRuleViolationGroup({
    super.key,
    required this.group,
    this.isHard = true,
  });
  final CustomRuleGroup group;
  final bool isHard;

  static (String rule, String body) _parse(String v) {
    final match = RegExp(r'^(.*)\s*\("(.+)"\)$').firstMatch(v.trim());
    if (match != null) return (match.group(2)!, match.group(1)!.trim());
    return ('기타', v);
  }

  static List<CustomRuleGroup> groupBy(
    List<String> viols, {
    bool isHard = true,
  }) {
    final map = <String, List<String>>{};
    for (final v in viols) {
      final (rule, body) = _parse(v);
      map.putIfAbsent(rule, () => []).add(body);
    }
    return map.entries
        .map((e) => CustomRuleGroup(ruleText: e.key, items: e.value))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isHard ? AppColors.error : AppColors.brandOrange;
    final icon = isHard ? Icons.gavel_rounded : Icons.warning_amber_rounded;
    final itemIcon = isHard ? Icons.error_outline : Icons.info_outline;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(7)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '"${group.ruleText}"',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
                Text(
                  '${group.items.length}건',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: group.items
                  .map(
                    (body) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(itemIcon, size: 14, color: color),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              body,
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondaryLight),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}
