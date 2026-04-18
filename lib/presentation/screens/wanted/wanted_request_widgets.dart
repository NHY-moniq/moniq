import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moniq/data/models/wanted_request_model.dart';
import 'package:moniq/presentation/layout/adaptive_layout.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/wanted_viewmodel.dart';

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
    _deadline = DateTime(now.year, now.month, now.day)
        .add(const Duration(days: 7));
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
                  Icon(
                    Icons.info_outline,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      '근무표 생성 전 팀원들의 희망사항을 수집합니다.\n요청을 생성하면 팀원들에게 알림이 발송됩니다.',
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
          Text('근무 생성 예정 기간',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
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
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _periodStart ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate:
                            DateTime.now().add(const Duration(days: 365)),
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
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _periodEnd ??
                            (_periodStart ?? DateTime.now())
                                .add(const Duration(days: 30)),
                        firstDate: DateTime.now(),
                        lastDate:
                            DateTime.now().add(const Duration(days: 365)),
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
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppColors.error),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xxl),

          // 입력 마감일
          Text('입력 마감일',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.md),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: WantedRequestDatePickerRow(
                label: '마감일',
                date: _deadline,
                dateFormat: dateFormat,
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _deadline ?? DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate:
                        DateTime.now().add(const Duration(days: 365)),
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
                final stateAsync =
                    ref.watch(wantedAdminViewModelProvider(widget.teamId));
                final isCreating =
                    stateAsync.valueOrNull?.isCreating ?? false;

                return ElevatedButton.icon(
                  onPressed: isCreating ||
                          _periodStart == null ||
                          _periodEnd == null ||
                          _hasValidationError
                      ? null
                      : () async {
                          final notifier = ref.read(
                              wantedAdminViewModelProvider(widget.teamId)
                                  .notifier);
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
                                    '전체 수집 유형 요청이 생성되고 알림이 발송되었습니다'),
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
                  label: Text(isCreating ? '생성 중...' : '희망 근무 요청 생성'),
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

/// 활성 수집 요청 현황
class WantedRequestActiveView extends HookConsumerWidget {
  const WantedRequestActiveView({
    super.key,
    required this.teamId,
    required this.teamName,
    required this.state,
  });

  final String teamId;
  final String teamName;
  final WantedAdminState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final dateFormat = DateFormat('MM.dd');
    final request = state.activeRequest!;

    // 팀원별 엔트리 그루핑
    final groupedByUser = <String, WantedRequestUserEntryGroup>{};
    for (final ew in state.allEntries) {
      final uid = ew.entry.userId;
      groupedByUser.putIfAbsent(
        uid,
        () => WantedRequestUserEntryGroup(
          displayName: ew.displayName,
          dates: [],
        ),
      );
      groupedByUser[uid]!.dates.add(ew.entry.wantedDate);
    }
    // 날짜 정렬
    for (final group in groupedByUser.values) {
      group.dates.sort();
    }
    final userGroups = groupedByUser.values.toList();

    // 상태 배너 (공통)
    Widget statusBanner() => Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          color: colorScheme.primary.withValues(alpha: 0.08),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.event_note, color: colorScheme.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '${WantedType.fromString(request.wantedType).label} 수집 진행중',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '기간: ${dateFormat.format(request.periodStart)} ~ ${dateFormat.format(request.periodEnd)}',
                style: theme.textTheme.bodySmall,
              ),
              if (request.deadline != null)
                Text(
                  '마감: ${DateFormat('yyyy.MM.dd').format(request.deadline!)}',
                  style: theme.textTheme.bodySmall,
                ),
              Text(
                '응답: ${userGroups.length}명 / ${state.allEntries.length}건',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        );

    // 하단 버튼 (공통)
    Widget bottomButtons() => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('수집 마감'),
                          content: const Text('희망 휴무 수집을 마감하시겠습니까?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('취소'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('마감'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await ref
                            .read(wantedAdminViewModelProvider(teamId).notifier)
                            .closeRequest();
                      }
                    },
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('수집 마감'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        context.push('/teams/$teamId/schedule/generate'),
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('스케줄 생성'),
                  ),
                ),
              ],
            ),
          ),
        );

    // ── 웹: 2-column (좌: 상태+버튼, 우: DataTable) ──
    if (AdaptiveLayout.isWide(context)) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 왼쪽: 상태 + 버튼
          Container(
            width: 320,
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: colorScheme.outlineVariant, width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                statusBanner(),
                const Spacer(),
                bottomButtons(),
              ],
            ),
          ),
          // 오른쪽: 응답 목록 DataTable
          Expanded(
            child: state.allEntries.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.hourglass_empty,
                            size: 48,
                            color: colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.3)),
                        const SizedBox(height: AppSpacing.md),
                        Text('아직 입력된 희망 휴무일이 없습니다',
                            style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      children: userGroups.map((group) {
                        return Padding(
                          padding:
                              const EdgeInsets.only(bottom: AppSpacing.md),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 100,
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                      top: AppSpacing.xs),
                                  child: Text(
                                    group.displayName,
                                    style: theme.textTheme.bodyMedium
                                        ?.copyWith(
                                            fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Wrap(
                                  spacing: AppSpacing.xs,
                                  runSpacing: AppSpacing.xs,
                                  children: group.dates.map((d) {
                                    return Chip(
                                      label: Text(dateFormat.format(d),
                                          style: theme.textTheme.bodySmall),
                                      visualDensity: VisualDensity.compact,
                                      backgroundColor: colorScheme.primary
                                          .withValues(alpha: 0.08),
                                      side: BorderSide.none,
                                    );
                                  }).toList(),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(
                                    top: AppSpacing.xs, left: AppSpacing.sm),
                                child: Text(
                                  '${group.dates.length}일',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ],
      );
    }

    // ── 모바일 레이아웃 (기존) ──
    return Column(
      children: [
        statusBanner(),

        // 엔트리 목록 (항상 RefreshIndicator로 감싸 새로고침 가능)
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref
                .read(wantedAdminViewModelProvider(teamId).notifier)
                .refresh(),
            child: state.allEntries.isEmpty
                ? ListView(
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.4,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.hourglass_empty,
                                size: 48,
                                color: colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.3),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                '아직 입력된 희망 휴무일이 없습니다',
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(
                                  color:
                                      colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                '아래로 당겨 새로고침',
                                style:
                                    theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: AppSpacing.screenAll,
                    itemCount: userGroups.length,
                    itemBuilder: (context, index) {
                      final group = userGroups[index];

                      return Card(
                        margin:
                            const EdgeInsets.only(bottom: AppSpacing.md),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: colorScheme.primary
                                          .withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.person,
                                      color: colorScheme.primary,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Text(
                                      group.displayName,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${group.dates.length}일',
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Wrap(
                                spacing: AppSpacing.sm,
                                runSpacing: AppSpacing.sm,
                                children: group.dates.map((d) {
                                  return Chip(
                                    label: Text(
                                      dateFormat.format(d),
                                      style:
                                          theme.textTheme.bodySmall,
                                    ),
                                    visualDensity:
                                        VisualDensity.compact,
                                    backgroundColor:
                                        colorScheme.primary
                                            .withValues(alpha: 0.08),
                                    side: BorderSide.none,
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),

        bottomButtons(),
      ],
    );
  }
}

class WantedRequestUserEntryGroup {
  WantedRequestUserEntryGroup(
      {required this.displayName, required this.dates});
  final String displayName;
  final List<DateTime> dates;
}

class WantedRequestDatePickerRow extends StatelessWidget {
  const WantedRequestDatePickerRow({
    super.key,
    required this.label,
    this.date,
    required this.dateFormat,
    required this.onTap,
  });

  final String label;
  final DateTime? date;
  final DateFormat dateFormat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = Theme.of(context).colorScheme;

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
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(
                Icons.calendar_today,
                size: 18,
                color: colorScheme.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
