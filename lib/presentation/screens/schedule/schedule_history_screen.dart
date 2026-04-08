import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moniq/data/models/schedule_model.dart';
import 'package:moniq/data/models/shift_model.dart';
import 'package:moniq/data/models/shift_type_model.dart';
import 'package:moniq/data/models/team_member_with_user.dart';
import 'package:moniq/data/providers/feedback_providers.dart';
import 'package:moniq/data/providers/schedule_providers.dart';
import 'package:moniq/data/providers/shift_providers.dart';
import 'package:moniq/data/providers/team_providers.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/widgets/common/moniq_error_view.dart';
import 'package:moniq/presentation/widgets/common/moniq_loading_view.dart';

// ── Provider: 팀의 스케줄 버전 목록 ──
final scheduleVersionsProvider =
    FutureProvider.family<List<ScheduleModel>, String>((ref, teamId) async {
  final repo = ref.watch(scheduleRepositoryProvider);
  return repo.getSchedules(teamId);
});

class ScheduleHistoryScreen extends ConsumerWidget {
  const ScheduleHistoryScreen({super.key, required this.teamId});
  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final versionsAsync = ref.watch(scheduleVersionsProvider(teamId));

    return Scaffold(
      appBar: AppBar(title: const Text('근무표 히스토리')),
      body: versionsAsync.when(
        loading: () => const MoniqLoadingView(),
        error: (e, _) => MoniqErrorView(
          message: '불러올 수 없습니다',
          onRetry: () => ref.invalidate(scheduleVersionsProvider(teamId)),
        ),
        data: (versions) {
          if (versions.isEmpty) {
            return const Center(child: Text('생성된 근무표가 없습니다'));
          }
          return ListView.separated(
            padding: AppSpacing.screenAll,
            itemCount: versions.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: AppSpacing.md),
            itemBuilder: (_, i) => _VersionCard(
              schedule: versions[i],
              teamId: teamId,
            ),
          );
        },
      ),
    );
  }
}

class _VersionCard extends ConsumerWidget {
  const _VersionCard({required this.schedule, required this.teamId});
  final ScheduleModel schedule;
  final String teamId;

  void _showFeedbackSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _VersionFeedbackSheet(
        scheduleId: schedule.id,
        teamId: teamId,
        versionLabel: 'v${schedule.versionNo}',
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final fmt = DateFormat('yyyy.MM.dd');
    final isPublished = schedule.status == 'published';

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push(
          '/teams/$teamId/schedule/history/${schedule.id}',
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              // 버전 배지
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isPublished
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : AppColors.textSecondaryLight.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    'v${schedule.versionNo}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: isPublished
                          ? AppColors.primary
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${fmt.format(schedule.periodStart)} ~ ${fmt.format(schedule.periodEnd)}',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isPublished
                                ? AppColors.success.withValues(alpha: 0.12)
                                : AppColors.brandOrange
                                    .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isPublished ? '발행됨' : '초안',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isPublished
                                  ? AppColors.success
                                  : AppColors.brandOrange,
                            ),
                          ),
                        ),
                        if (schedule.createdAt != null) ...[
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            DateFormat('MM.dd HH:mm')
                                .format(schedule.createdAt!.toLocal()),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // 피드백 버튼
              IconButton(
                icon: const Icon(Icons.rate_review_outlined),
                color: AppColors.brandOrange,
                tooltip: '피드백 남기기',
                onPressed: () => _showFeedbackSheet(context),
              ),
              GestureDetector(
                onTap: () => context.push(
                  '/teams/$teamId/schedule/history/${schedule.id}',
                ),
                child: const Icon(
                  Icons.chevron_right,
                  color: AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 버전별 피드백 바텀시트 ──
class _VersionFeedbackSheet extends ConsumerStatefulWidget {
  const _VersionFeedbackSheet({
    required this.scheduleId,
    required this.teamId,
    required this.versionLabel,
  });
  final String scheduleId;
  final String teamId;
  final String versionLabel;

  @override
  ConsumerState<_VersionFeedbackSheet> createState() =>
      _VersionFeedbackSheetState();
}

class _VersionFeedbackSheetState extends ConsumerState<_VersionFeedbackSheet> {
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
    // initState에서 바로 호출해도 ConsumerState는 ref 접근 가능
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
                color: AppColors.textSecondaryLight.withValues(alpha: 0.3),
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
                color: AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),

            if (!_loaded)
              const CircularProgressIndicator()
            else if (_saved && _overallRating == 0)
              // 저장된 상태이지만 화면 첫 진입 후 수정하기 전
              ..._buildForm(theme)
            else if (_saved && _overallRating > 0)
              ..._buildForm(theme)
            else
              ..._buildForm(theme),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildForm(ThemeData theme) {
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
                    : AppColors.textSecondaryLight,
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
                child: Text(e.value, style: theme.textTheme.bodyMedium),
              ),
              _RatingToggle(
                value: cur,
                onChanged: (v) => setState(() => _ruleRatings[e.key] = v),
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
              const Icon(Icons.check_circle_outline,
                  color: AppColors.success, size: 16),
              const SizedBox(width: 6),
              Text(
                '저장된 피드백입니다. 수정 후 다시 저장할 수 있습니다.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondaryLight,
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

// ────────────────────────────────────────
// 버전 상세 화면 (그리드 + 피드백)
// ────────────────────────────────────────

final _shiftTypesForTeamProvider =
    FutureProvider.autoDispose.family<List<ShiftTypeModel>, String>(
  (ref, teamId) => ref.watch(shiftRepositoryProvider).getShiftTypes(teamId),
);


final _scheduleDetailProvider = FutureProvider.autoDispose
    .family<_ScheduleDetail, String>((ref, scheduleId) async {
  final shiftRepo = ref.watch(scheduleRepositoryProvider);
  final shifts = await shiftRepo.getShiftsBySchedule(scheduleId);
  return _ScheduleDetail(shifts: shifts);
});

class _ScheduleDetail {
  _ScheduleDetail({required this.shifts});
  final List<ShiftModel> shifts;
}

class ScheduleVersionDetailScreen extends ConsumerWidget {
  const ScheduleVersionDetailScreen({
    super.key,
    required this.teamId,
    required this.scheduleId,
  });
  final String teamId;
  final String scheduleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final versionsAsync = ref.watch(scheduleVersionsProvider(teamId));
    final detailAsync = ref.watch(_scheduleDetailProvider(scheduleId));
    final membersAsync = ref.watch(teamMembersWithUsersProvider(teamId));
    final shiftTypesAsync = ref.watch(_shiftTypesForTeamProvider(teamId));

    return Scaffold(
      appBar: AppBar(
        title: versionsAsync.when(
          data: (versions) {
            final s = versions.firstWhere(
              (v) => v.id == scheduleId,
              orElse: () => versions.first,
            );
            return Text('v${s.versionNo} 근무표');
          },
          loading: () => const Text('근무표'),
          error: (_, __) => const Text('근무표'),
        ),
      ),
      body: detailAsync.when(
        loading: () => const MoniqLoadingView(),
        error: (e, _) => MoniqErrorView(
          message: '불러올 수 없습니다',
          onRetry: () => ref.invalidate(_scheduleDetailProvider(scheduleId)),
        ),
        data: (detail) => membersAsync.when(
          loading: () => const MoniqLoadingView(),
          error: (e, _) => const MoniqErrorView(message: '멤버 정보 오류'),
          data: (members) => _DetailBody(
            shifts: detail.shifts,
            members: members,
            shiftTypes: shiftTypesAsync.valueOrNull ?? const [],
          ),
        ),
      ),
    );
  }
}

final teamMembersWithUsersProvider =
    FutureProvider.family<List<TeamMemberWithUser>, String>(
        (ref, teamId) async {
  final repo = ref.watch(teamRepositoryProvider);
  return repo.getTeamMembersWithUsers(teamId);
});

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.shifts,
    required this.members,
    required this.shiftTypes,
  });
  final List<ShiftModel> shifts;
  final List<TeamMemberWithUser> members;
  final List<ShiftTypeModel> shiftTypes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MM.dd\n(E)', 'ko');

    // 그리드 구성
    final grid = <DateTime, Map<String, String>>{};
    for (final shift in shifts) {
      final day = DateTime(
        shift.shiftDate.year,
        shift.shiftDate.month,
        shift.shiftDate.day,
      );
      grid.putIfAbsent(day, () => {})[shift.userId] = shift.shiftTypeId;
    }
    final sortedDays = grid.keys.toList()..sort();

    // shiftTypeId → ShiftTypeModel 맵
    final typeMap = {for (final t in shiftTypes) t.id: t};

    Widget buildCell(String? shiftTypeId) {
      if (shiftTypeId == null) {
        return Container(
          width: 44,
          height: 36,
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: AppColors.shiftOff.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Center(
            child: Text('O',
                style: TextStyle(
                    color: AppColors.shiftOff,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
        );
      }
      final st = typeMap[shiftTypeId];
      final code = st?.code ?? '?';
      Color cellColor = AppColors.primary;
      try {
        if (st != null) {
          final hex = st.color.replaceAll('#', '');
          final val = int.parse(
            hex.length == 6 ? 'FF$hex' : hex,
            radix: 16,
          );
          cellColor = Color(val);
        }
      } catch (_) {}
      return Container(
        width: 44,
        height: 36,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: cellColor.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: cellColor.withValues(alpha: 0.45)),
        ),
        child: Center(
          child: Text(
            code,
            style: TextStyle(
              color: cellColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 날짜 고정 열
          Column(
            children: [
              const SizedBox(height: 40),
              ...sortedDays.map(
                (day) => SizedBox(
                  width: 60,
                  height: 44,
                  child: Center(
                    child: Text(
                      dateFormat.format(day),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondaryLight,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          // 멤버별 열
          Flexible(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: members.map((m) {
                      return SizedBox(
                        width: 48,
                        height: 40,
                        child: Center(
                          child: Text(
                            m.displayName.length > 3
                                ? m.displayName.substring(0, 3)
                                : m.displayName,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  ...sortedDays.map(
                    (day) => SizedBox(
                      height: 44,
                      child: Row(
                        children: members.map((m) {
                          return buildCell(grid[day]?[m.userId]);
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _RatingToggle extends StatelessWidget {
  const _RatingToggle({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Chip(
          label: '좋아요',
          icon: Icons.thumb_up_outlined,
          selected: value == 1,
          color: AppColors.success,
          onTap: () => onChanged(value == 1 ? 0 : 1),
        ),
        const SizedBox(width: 6),
        _Chip(
          label: '아쉬워요',
          icon: Icons.thumb_down_outlined,
          selected: value == -1,
          color: AppColors.error,
          onTap: () => onChanged(value == -1 ? 0 : -1),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.1) : Colors.transparent,
          border: Border.all(
            color: selected
                ? color
                : AppColors.textSecondaryLight.withValues(alpha: 0.3),
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 13,
                color: selected ? color : AppColors.textSecondaryLight),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color:
                    selected ? color : AppColors.textSecondaryLight,
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
