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
    // ConsumerStatefulWidget으로 ref.watch가 실제 rebuild 트리거
    final state = ref.watch(
      scheduleGenerationViewModelProvider(widget.teamId),
    ).valueOrNull ?? widget.state;
    // 하드 위반: validationWarnings 전체
    final hardWarnings = state.validationWarnings ?? [];

    final wantedPct = state.wantedTotal > 0
        ? (state.wantedSatisfied / state.wantedTotal * 100).round()
        : 100;

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      expand: false,
      builder: (ctx, scrollCtrl) => Column(
        children: [
          // 핸들
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textSecondaryLight.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '위반 리포트',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                // AI 분석 버튼
                if (!state.isAnalyzing && state.aiAnalysis == null)
                  TextButton.icon(
                    onPressed: () {
                      final teamName =
                          ''; // teamName은 state에 없으므로 빈 문자열로 처리
                      ref
                          .read(
                            scheduleGenerationViewModelProvider(widget.teamId)
                                .notifier,
                          )
                          .analyzeViolations(teamName);
                    },
                    icon: const Icon(Icons.auto_awesome, size: 16),
                    label: const Text('AI 분석'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.brandOrange,
                    ),
                  )
              ],
            ),
          ),
          // AI 분석 로딩 카드
          if (state.isAnalyzing)
            Container(
              margin: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.brandOrange.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.brandOrange.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.brandOrange,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    'AI가 근무표를 분석하고 있습니다...',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.brandOrange,
                    ),
                  ),
                ],
              ),
            ),
          // AI 분석 결과 카드
          if (state.aiAnalysis != null && !state.isAnalyzing)
            Container(
              margin: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.brandOrange.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.brandOrange.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    size: 16,
                    color: AppColors.brandOrange,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      state.aiAnalysis!,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      ref
                          .read(
                            scheduleGenerationViewModelProvider(widget.teamId)
                                .notifier,
                          )
                          .analyzeViolations('');
                    },
                    child: const Icon(
                      Icons.refresh,
                      size: 16,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
          TabBar(
            controller: _tabController,
            tabs: [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hardWarnings.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${hardWarnings.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    const Text('하드 위반'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (state.customRuleViolations.isNotEmpty ||
                        state.softViolations.values.any((v) => v.isNotEmpty))
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.brandOrange,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${state.customRuleViolations.length + state.softViolations.values.fold(0, (s, v) => s + v.length)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    const Text('소프트 요약'),
                  ],
                ),
              ),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // -- 탭 1: 하드 위반 --
                hardWarnings.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.check_circle_outline,
                              size: 48,
                              color: AppColors.success,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              '하드 위반 없음',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: AppColors.success,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        itemCount: hardWarnings.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1),
                        itemBuilder: (_, i) => ListTile(
                          dense: true,
                          leading: const Icon(
                            Icons.warning_amber_rounded,
                            color: AppColors.error,
                            size: 20,
                          ),
                          title: Text(
                            hardWarnings[i],
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ),

                // -- 탭 2: 소프트 요약 --
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
    final hasIssue = hardCount > 0 || customViolCount > 0;

    // 소프트 기피 패턴 총 위반 수
    final softPatternTotal =
        state.softViolations.values.fold(0, (s, v) => s + v.length);

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
              hasIssue ? Icons.assignment_late_outlined : Icons.assignment_turned_in_outlined,
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
                      label: '하드 위반 ${hardCount}건',
                      color: AppColors.error,
                    ),
                  if (customViolCount > 0)
                    BannerChip(
                      label: '커스텀 룰 위반 ${customViolCount}건',
                      color: AppColors.error,
                    ),
                  if (softPatternTotal > 0)
                    BannerChip(
                      label: '기피패턴 ${softPatternTotal}회',
                      color: AppColors.brandOrange,
                    ),
                  if (state.wantedTotal > 0)
                    BannerChip(
                      label: '원티드 ${wantedPct}%',
                      color: wantedPct >= 80
                          ? AppColors.success
                          : AppColors.brandOrange,
                    ),
                  if (!hasIssue && softPatternTotal == 0 && state.wantedTotal == 0)
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
                Text(
                  '리포트',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondaryLight,
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: AppColors.textSecondaryLight,
                ),
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
    final hasSoftPattern = softViol.isNotEmpty &&
        softViol.values.any((v) => v.isNotEmpty);
    final customViols = state.customRuleViolations;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        // -- 원티드 반영률 --
        if (state.wantedTotal > 0) ...[
          SummaryCard(
            icon: Icons.favorite_outline,
            iconColor: AppColors.brandOrange,
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
                borderRadius: BorderRadius.circular(10),
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
                    (item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          const Icon(Icons.event_busy_outlined,
                              size: 14, color: AppColors.brandOrange),
                          const SizedBox(width: 6),
                          Text(item,
                              style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
        ],

        // -- 기피 패턴 위반 --
        if (hasSoftPattern) ...[
          Text(
            '기피패턴 위반',
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...{
            'NOD': ('NOD (나이트->오프->데이)', softViol['NOD']),
            'NOOD': ('NOOD (나이트->오프x2->데이)', softViol['NOOD']),
            'NOE': ('NOE (나이트->오프->이브닝)', softViol['NOE']),
            'EOD': ('EOD (이브닝->오프->데이)', softViol['EOD']),
          }.entries.where((e) => (e.value.$2?.isNotEmpty ?? false)).map((e) {
            final label = e.value.$1;
            final items = e.value.$2!;
            return PatternGroup(label: label, items: items);
          }),
          const SizedBox(height: AppSpacing.sm),
        ],

        // -- 커스텀 룰 위반 --
        if (customViols.isNotEmpty) ...[
          Text(
            '커스텀 룰 위반',
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.15)),
            ),
            child: Column(
              children: customViols
                  .map(
                    (v) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.error_outline,
                              size: 15, color: AppColors.error),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(v,
                                style: theme.textTheme.bodySmall),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],

        // -- 모두 양호 --
        if (state.wantedTotal == 0 && !hasSoftPattern && customViols.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xxl),
              child: Column(
                children: [
                  const Icon(Icons.check_circle_outline,
                      size: 40, color: AppColors.success),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    '소프트 위반 없음',
                    style: theme.textTheme.bodyMedium?.copyWith(
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

class PatternGroup extends StatelessWidget {
  const PatternGroup({super.key, required this.label, required this.items});
  final String label;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.brandOrange.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: AppColors.brandOrange.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  size: 15, color: AppColors.brandOrange),
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
              child: Text('- $item',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondaryLight,
                  )),
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
        borderRadius: BorderRadius.circular(12),
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
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondaryLight,
                    )),
                Text(subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondaryLight,
                    )),
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
