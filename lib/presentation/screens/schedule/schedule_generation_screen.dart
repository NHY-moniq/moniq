import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moniq/core/utils/color_utils.dart';
import 'package:moniq/data/models/custom_rule_model.dart';
import 'package:moniq/data/models/shift_type_model.dart';
import 'package:moniq/data/models/shift_rule_model.dart';
import 'package:moniq/data/models/team_member_with_user.dart';
import 'package:moniq/presentation/layout/adaptive_layout.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/schedule_generation_viewmodel.dart';
import 'package:moniq/presentation/widgets/common/moniq_app_bar.dart';
import 'package:moniq/presentation/widgets/common/moniq_bottom_sheet.dart';
import 'package:moniq/presentation/widgets/common/moniq_error_view.dart';
import 'package:moniq/presentation/widgets/common/moniq_loading_view.dart';

import '../wanted/wanted_request_widgets.dart';
import 'widgets/schedule_common_widgets.dart';
import 'widgets/schedule_preview_widgets.dart';

part 'schedule_generation_dialogs.dart';
part 'schedule_generation_widgets.dart';

/// 스케줄 생성 4단계 플로우
///
/// Step 1 — 생성 규칙 설정
/// Step 2 — 기간·규칙 요약 확인 + 생성 실행
/// Step 3 — 미리보기 (날짜별 그룹)
/// Step 4 — 발행 완료 (피드백 바텀시트)
class ScheduleGenerationScreen extends HookConsumerWidget {
  const ScheduleGenerationScreen({super.key, required this.teamId});

  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrapping = useState(true);

    // 화면 진입 시마다 항상 fresh state로 시작
    useEffect(() {
      bootstrapping.value = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          final _ = await ref.refresh(
            scheduleGenerationViewModelProvider(teamId).future,
          );
        } finally {
          if (context.mounted) {
            bootstrapping.value = false;
          }
        }
      });
      return null;
    }, [teamId]);

    final stateAsync = ref.watch(scheduleGenerationViewModelProvider(teamId));

    return Scaffold(
      appBar: MoniqAppBar(
        title: '스케줄 생성',
        trailing: MoniqAppBarAction(
          icon: Icons.history_rounded,
          onTap: () => context.push('/teams/$teamId/schedule/history'),
        ),
      ),
      body: bootstrapping.value
          ? const MoniqLoadingView()
          : stateAsync.when(
              skipLoadingOnRefresh: false,
              skipLoadingOnReload: false,
              loading: () => const MoniqLoadingView(),
              error: (e, _) => MoniqErrorView(
                message: '정보를 불러올 수 없습니다',
                onRetry: () =>
                    ref.invalidate(scheduleGenerationViewModelProvider(teamId)),
              ),
              data: (state) {
                if (state.generatedSchedule != null &&
                    state.previewShifts != null) {
                  return PreviewView(teamId: teamId, state: state);
                }
                return _SetupView(teamId: teamId, state: state);
              },
            ),
    );
  }
}

// ────────────────────────────────────────
// Step 2: 기간 설정 & 생성
// ────────────────────────────────────────

class _SetupView extends HookConsumerWidget {
  const _SetupView({required this.teamId, required this.state});

  final String teamId;
  final ScheduleGenerationState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final notifier = ref.read(
      scheduleGenerationViewModelProvider(teamId).notifier,
    );
    final defaultShiftTypes = _defaultShiftTypes(state.shiftTypes);
    final hasDefaultShiftTypes = defaultShiftTypes.isNotEmpty;

    return SingleChildScrollView(
      padding: AppSpacing.screenAll,
      child: MaxWidthLayout(
        maxWidth: 640,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // -- 단계 표시 --
            const ScheduleStepIndicator(currentStep: 1, totalSteps: 4),
            const SizedBox(height: AppSpacing.xl),

            // -- 기간 설정 --
            Text(
              '생성 기간',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  children: [
                    ScheduleDatePickerRow(
                      label: '시작일',
                      date: state.periodStart,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      onPicked: (picked) =>
                          notifier.setPeriod(picked, state.periodEnd ?? picked),
                    ),
                    const Divider(height: AppSpacing.xxl),
                    ScheduleDatePickerRow(
                      label: '종료일',
                      date: state.periodEnd,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      onPicked: (picked) => notifier.setPeriod(
                        state.periodStart ?? picked,
                        picked,
                      ),
                    ),
                    if (state.periodStart != null &&
                        state.periodEnd != null &&
                        state.periodEnd!.isBefore(state.periodStart!)) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '시작 일자가 마감 일자 이후입니다',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),

            // -- 적용 규칙 요약 --
            Text(
              '적용 규칙 요약',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ScheduleTappableInfoRow(
                      icon: Icons.people,
                      label: '멤버',
                      value:
                          '${state.members.length - state.excludedMemberIds.length}명 참여',
                      onTap: state.members.isEmpty
                          ? null
                          : () =>
                                _showMembersDialog(context, ref, state, teamId),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ScheduleTappableInfoRow(
                      icon: Icons.schedule,
                      label: '근무 유형',
                      value: '${defaultShiftTypes.length}개',
                      onTap: () => _showShiftTypesDialog(context, state),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ScheduleTappableInfoRow(
                      icon: Icons.rule,
                      label: '규칙',
                      value: state.rules.isEmpty
                          ? '기본 규칙 적용'
                          : '${state.rules.length}개 규칙',
                      onTap: state.rules.isEmpty
                          ? null
                          : () => _showRulesDialog(context, state),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ScheduleTappableInfoRow(
                      icon: Icons.tune_rounded,
                      label: '커스텀 규칙',
                      value: state.customRules.isEmpty
                          ? '없음'
                          : state.customRules.where((r) => r.isActive).isEmpty
                          ? '${state.customRules.length}개 (모두 비활성)'
                          : '${state.customRules.where((r) => r.isActive).length}개 적용 중',
                      onTap: state.customRules.isEmpty
                          ? null
                          : () => _showCustomRulesDialog(context, state),
                    ),
                    if (hasDefaultShiftTypes) ...[
                      const Divider(height: AppSpacing.xxl),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: defaultShiftTypes
                            .map(
                              (t) => Chip(
                                avatar: CircleAvatar(
                                  backgroundColor: parseHexColor(t.color),
                                  radius: 8,
                                ),
                                label: Text(t.name),
                                visualDensity: VisualDensity.compact,
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // 원티드 현황
            if (state.wantedEntries.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xxl),
              Text(
                '원티드 현황',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _showWantedDetailSheet(context, state),
                child: Card(
                  color: colorScheme.primary.withValues(alpha: 0.05),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ScheduleInfoRow(
                                    icon: Icons.event_note,
                                    label: '수집된 원티드',
                                    value: '${state.wantedEntries.length}건',
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  ScheduleInfoRow(
                                    icon: Icons.people,
                                    label: '입력 인원',
                                    value:
                                        '${state.wantedEntries.map((e) => e.userId).toSet().length}명',
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              color: colorScheme.primary.withValues(alpha: 0.6),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          '생성 시 원티드가 자동 반영됩니다',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],

            // -- 에러 표시 --
            if (state.error != null) ...[
              const SizedBox(height: AppSpacing.lg),
              SelectableText.rich(
                TextSpan(
                  text: state.error,
                  style: TextStyle(color: colorScheme.error),
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.xxxl),

            // -- 생성 버튼 --
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed:
                    state.isGenerating ||
                        state.members.isEmpty ||
                        !hasDefaultShiftTypes ||
                        state.periodStart == null ||
                        state.periodEnd == null ||
                        state.periodEnd!.isBefore(state.periodStart!)
                    ? null
                    : () => ref
                          .read(
                            scheduleGenerationViewModelProvider(
                              teamId,
                            ).notifier,
                          )
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

            if (state.members.isEmpty || !hasDefaultShiftTypes) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                state.members.isEmpty ? '멤버를 먼저 추가해주세요' : '기본 근무 유형을 먼저 설정해주세요',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.error,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// -- 다이얼로그 헬퍼 --
