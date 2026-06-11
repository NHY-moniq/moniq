import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moniq/core/utils/color_utils.dart';
import 'package:moniq/data/datasources/push_service.dart';
import 'package:moniq/data/models/shift_type_model.dart';
import 'package:moniq/data/models/team_member_with_user.dart';
import 'package:moniq/data/models/wanted_request_model.dart';
import 'package:moniq/data/providers/shift_providers.dart';
import 'package:moniq/data/providers/team_providers.dart';
import 'package:moniq/presentation/layout/adaptive_layout.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/wanted_viewmodel.dart';
import 'package:moniq/presentation/widgets/common/moniq_bottom_sheet.dart';
import 'package:moniq/presentation/widgets/common/moniq_date_picker_sheet.dart';

part 'wanted_request_views.dart';
part 'wanted_request_shared.dart';

final _requestWidgetsShiftTypesProvider = FutureProvider.autoDispose
    .family<List<ShiftTypeModel>, String>(
      (ref, teamId) => ref.watch(shiftRepositoryProvider).getShiftTypes(teamId),
    );

final _requestWidgetsTeamMembersProvider = FutureProvider.autoDispose
    .family<List<TeamMemberWithUser>, String>(
      (ref, teamId) =>
          ref.watch(teamRepositoryProvider).getTeamMembersWithUsers(teamId),
    );

/// 새 수집 요청 생성 폼
class WantedRequestCreateView extends StatefulWidget {
  const WantedRequestCreateView({
    super.key,
    required this.teamId,
    required this.teamName,
  });

  final String teamId;
  final String teamName;

  @override
  State<WantedRequestCreateView> createState() =>
      _WantedRequestCreateViewState();
}

class _WantedRequestCreateViewState extends State<WantedRequestCreateView> {
  DateTime? _periodStart;
  DateTime? _periodEnd;
  DateTime? _deadline;

  String? get _periodRangeError {
    if (_periodStart == null || _periodEnd == null) return null;
    if (_periodEnd!.isBefore(_periodStart!)) {
      return '시작 일자가 마감 일자 이후입니다';
    }
    return null;
  }

  bool get _hasValidationError => _periodRangeError != null;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _periodStart = DateTime(now.year, now.month + 1, 1);
    _periodEnd = DateTime(now.year, now.month + 2, 0);
    _deadline = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 7));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final dateFormat = DateFormat('yyyy년 MM월 dd일');

    return SingleChildScrollView(
      padding: AppSpacing.screenAll,
      child: MaxWidthLayout(
        maxWidth: 640,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 안내 카드
            Card(
              color: colorScheme.primary.withValues(alpha: 0.08),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: colorScheme.primary),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        '근무표 생성 전 팀원들의 원티드를 수집합니다.\n요청을 생성하면 팀원들에게 알림이 발송됩니다.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),

            // 근무 생성 예정 기간
            Text(
              '근무 생성 예정 기간',
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
                    WantedRequestDatePickerRow(
                      label: '시작일',
                      date: _periodStart,
                      dateFormat: dateFormat,
                      onTap: () async {
                        final picked = await showMoniqDatePickerSheet(
                          context: context,
                          initialDate: _periodStart ?? DateTime.now(),
                          title: '시작일 선택',
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );
                        if (picked != null) {
                          setState(() => _periodStart = picked);
                        }
                      },
                    ),
                    const Divider(height: AppSpacing.xxl),
                    WantedRequestDatePickerRow(
                      label: '종료일',
                      date: _periodEnd,
                      dateFormat: dateFormat,
                      onTap: () async {
                        final picked = await showMoniqDatePickerSheet(
                          context: context,
                          initialDate:
                              _periodEnd ??
                              (_periodStart ?? DateTime.now()).add(
                                const Duration(days: 30),
                              ),
                          title: '종료일 선택',
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );
                        if (picked != null) {
                          setState(() => _periodEnd = picked);
                        }
                      },
                    ),
                    if (_periodRangeError != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _periodRangeError!,
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

            // 입력 마감일
            Text(
              '입력 마감일',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '마감일 이후 또는 수집 마감 시 팀원 입력이 자동 차단됩니다',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: WantedRequestDatePickerRow(
                  label: '마감일',
                  date: _deadline,
                  dateFormat: dateFormat,
                  onTap: () async {
                    final picked = await showMoniqDatePickerSheet(
                      context: context,
                      initialDate: _deadline ?? DateTime.now(),
                      title: '마감일 선택',
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setState(() => _deadline = picked);
                    }
                  },
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.xxxl),

            // 생성 버튼
            SizedBox(
              width: double.infinity,
              child: Consumer(
                builder: (context, ref, _) {
                  final stateAsync = ref.watch(
                    wantedAdminViewModelProvider(widget.teamId),
                  );
                  final isCreating =
                      stateAsync.valueOrNull?.isCreating ?? false;

                  return ElevatedButton.icon(
                    onPressed:
                        isCreating ||
                            _periodStart == null ||
                            _periodEnd == null ||
                            _hasValidationError
                        ? null
                        : () async {
                            final notifier = ref.read(
                              wantedAdminViewModelProvider(
                                widget.teamId,
                              ).notifier,
                            );
                            var allOk = true;
                            for (final type in WantedType.values) {
                              final ok = await notifier.createWantedRequest(
                                periodStart: _periodStart!,
                                periodEnd: _periodEnd!,
                                deadline: _deadline,
                                teamName: widget.teamName,
                                wantedType: type.value,
                              );
                              if (!ok) allOk = false;
                            }
                            if (allOk && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    '전체 수집 유형 요청이 생성되고 알림이 발송되었습니다',
                                  ),
                                ),
                              );
                            }
                          },
                    icon: isCreating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    label: Text(isCreating ? '생성 중...' : '원티드 수집 생성'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
