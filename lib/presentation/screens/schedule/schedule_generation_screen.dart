import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moniq/core/utils/color_utils.dart';
import 'package:moniq/data/models/shift_model.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/schedule_generation_viewmodel.dart';
import 'package:moniq/presentation/widgets/common/moniq_error_view.dart';
import 'package:moniq/presentation/widgets/common/moniq_loading_view.dart';

class ScheduleGenerationScreen extends HookConsumerWidget {
  const ScheduleGenerationScreen({super.key, required this.teamId});

  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync =
        ref.watch(scheduleGenerationViewModelProvider(teamId));

    return Scaffold(
      appBar: AppBar(title: const Text('스케줄 생성')),
      body: stateAsync.when(
        loading: () => const MoniqLoadingView(),
        error: (e, _) => MoniqErrorView(
          message: '정보를 불러올 수 없습니다',
          onRetry: () =>
              ref.invalidate(scheduleGenerationViewModelProvider(teamId)),
        ),
        data: (state) {
          if (state.generatedSchedule != null && state.previewShifts != null) {
            return _PreviewView(teamId: teamId, state: state);
          }
          return _SetupView(teamId: teamId, state: state);
        },
      ),
    );
  }
}

/// 설정 및 생성 화면
class _SetupView extends HookConsumerWidget {
  const _SetupView({required this.teamId, required this.state});

  final String teamId;
  final ScheduleGenerationState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: AppSpacing.screenAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 기간 설정
          Text('생성 기간',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.md),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  _DateRow(
                    label: '시작일',
                    date: state.periodStart,
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: state.periodStart ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate:
                            DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        ref
                            .read(scheduleGenerationViewModelProvider(teamId)
                                .notifier)
                            .setPeriod(
                                picked, state.periodEnd ?? picked);
                      }
                    },
                  ),
                  const Divider(height: AppSpacing.xxl),
                  _DateRow(
                    label: '종료일',
                    date: state.periodEnd,
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: state.periodEnd ??
                            (state.periodStart ?? DateTime.now())
                                .add(const Duration(days: 30)),
                        firstDate: state.periodStart ?? DateTime.now(),
                        lastDate:
                            DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        ref
                            .read(scheduleGenerationViewModelProvider(teamId)
                                .notifier)
                            .setPeriod(
                                state.periodStart ?? picked, picked);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xxl),

          // 규칙 요약
          Text('적용 규칙',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.md),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoRow(
                      icon: Icons.people,
                      label: '멤버',
                      value: '${state.members.length}명'),
                  const SizedBox(height: AppSpacing.sm),
                  _InfoRow(
                      icon: Icons.schedule,
                      label: '근무 유형',
                      value: '${state.shiftTypes.length}개'),
                  const SizedBox(height: AppSpacing.sm),
                  _InfoRow(
                      icon: Icons.rule,
                      label: '규칙',
                      value: state.rules.isEmpty
                          ? '기본 규칙 적용'
                          : '${state.rules.length}개 규칙'),
                  if (state.shiftTypes.isNotEmpty) ...[
                    const Divider(height: AppSpacing.xxl),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: state.shiftTypes
                          .map((t) => Chip(
                                avatar: CircleAvatar(
                                  backgroundColor: parseHexColor(t.color),
                                  radius: 8,
                                ),
                                label: Text(t.name),
                                visualDensity: VisualDensity.compact,
                              ))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),

          if (state.error != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Card(
              color: AppColors.errorLight,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.error),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(state.error!,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: AppColors.error)),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.xxxl),

          // 생성 버튼
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: state.isGenerating ||
                      state.members.isEmpty ||
                      state.shiftTypes.isEmpty
                  ? null
                  : () => ref
                      .read(scheduleGenerationViewModelProvider(teamId)
                          .notifier)
                      .generate(),
              icon: state.isGenerating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(state.isGenerating ? '생성 중...' : '스케줄 생성'),
            ),
          ),

          if (state.members.isEmpty || state.shiftTypes.isEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              state.members.isEmpty
                  ? '멤버를 먼저 추가해주세요'
                  : '근무 유형을 먼저 설정해주세요',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppColors.error),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// 미리보기 및 발행 화면
class _PreviewView extends HookConsumerWidget {
  const _PreviewView({required this.teamId, required this.state});

  final String teamId;
  final ScheduleGenerationState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MM.dd');
    final shifts = state.previewShifts ?? [];

    // 날짜별 그룹핑
    final grouped = <String, List<ShiftModel>>{};
    for (final shift in shifts) {
      final key = dateFormat.format(shift.shiftDate);
      grouped.putIfAbsent(key, () => []).add(shift);
    }

    // 멤버 이름 매핑
    final memberNames = <String, String>{};
    for (final m in state.members) {
      memberNames[m.userId] = m.displayName;
    }

    // 근무 유형 매핑
    final shiftTypeMap = <String, String>{};
    final shiftColorMap = <String, String>{};
    for (final t in state.shiftTypes) {
      shiftTypeMap[t.id] = t.name;
      shiftColorMap[t.id] = t.color;
    }

    return Column(
      children: [
        // 상단 요약
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          color: AppColors.successLight,
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: AppColors.success),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '스케줄이 생성되었습니다 (v${state.generatedSchedule!.versionNo})',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),

        // 경고
        if (state.validationWarnings != null &&
            state.validationWarnings!.isNotEmpty) ...[
          ExpansionTile(
            leading:
                const Icon(Icons.warning_amber, color: AppColors.brandOrange),
            title: Text(
              '${state.validationWarnings!.length}건의 알림',
              style: theme.textTheme.bodyMedium,
            ),
            children: state.validationWarnings!
                .map((w) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.info_outline, size: 18),
                      title: Text(w, style: theme.textTheme.bodySmall),
                    ))
                .toList(),
          ),
        ],

        // 미리보기 목록
        Expanded(
          child: ListView.builder(
            padding: AppSpacing.screenAll,
            itemCount: grouped.keys.length,
            itemBuilder: (context, index) {
              final dateKey = grouped.keys.elementAt(index);
              final dayShifts = grouped[dateKey]!;

              return Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(dateKey,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: AppSpacing.xs),
                      ...dayShifts.map((s) => Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.xxs),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: parseHexColor(
                                        shiftColorMap[s.shiftTypeId] ??
                                            '#A0AEC0'),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Text(
                                  shiftTypeMap[s.shiftTypeId] ?? '',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondaryLight,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Text(
                                  memberNames[s.userId] ?? '알 수 없음',
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // 하단 버튼
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: state.isPublishing
                        ? null
                        : () async {
                            await ref
                                .read(
                                    scheduleGenerationViewModelProvider(teamId)
                                        .notifier)
                                .discardDraft();
                          },
                    child: const Text('취소'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: state.isPublishing
                        ? null
                        : () async {
                            final success = await ref
                                .read(
                                    scheduleGenerationViewModelProvider(teamId)
                                        .notifier)
                                .publish();
                            if (success && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('스케줄이 발행되었습니다')),
                              );
                              context.pop();
                            }
                          },
                    icon: state.isPublishing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.publish),
                    label:
                        Text(state.isPublishing ? '발행 중...' : '스케줄 발행'),
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

class _DateRow extends StatelessWidget {
  const _DateRow({required this.label, this.date, required this.onTap});

  final String label;
  final DateTime? date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('yyyy년 MM월 dd일');

    return InkWell(
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Row(
            children: [
              Text(
                date != null ? dateFormat.format(date!) : '선택',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              const Icon(Icons.calendar_today,
                  size: 18, color: AppColors.primary),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondaryLight),
        const SizedBox(width: AppSpacing.sm),
        Text(label, style: theme.textTheme.bodyMedium),
        const Spacer(),
        Text(value,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w500)),
      ],
    );
  }
}
