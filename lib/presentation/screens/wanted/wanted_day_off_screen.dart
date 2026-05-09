import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moniq/core/utils/color_utils.dart';
import 'package:moniq/data/models/shift_type_model.dart';
import 'package:moniq/data/models/wanted_request_model.dart';
import 'package:moniq/data/providers/shift_providers.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/wanted_viewmodel.dart';
import 'package:moniq/presentation/widgets/common/moniq_app_bar.dart';
import 'package:moniq/presentation/widgets/common/moniq_empty_state.dart';
import 'package:moniq/presentation/widgets/common/moniq_error_view.dart';
import 'package:moniq/presentation/widgets/common/moniq_loading_view.dart';

/// 팀 근무 유형 로더
final _wantedShiftTypesProvider =
    FutureProvider.autoDispose.family<List<ShiftTypeModel>, String>(
  (ref, teamId) =>
      ref.watch(shiftRepositoryProvider).getShiftTypes(teamId),
);

/// 팀원: 원티드 입력 화면 (통합 피커)
class WantedDayOffScreen extends HookConsumerWidget {
  const WantedDayOffScreen({super.key, required this.teamId});

  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 화면 진입 시 최신 활성 요청 재조회
    useEffect(() {
      Future.microtask(
        () => ref.invalidate(wantedMemberViewModelProvider(teamId)),
      );
      return null;
    }, const []);

    final stateAsync = ref.watch(wantedMemberViewModelProvider(teamId));
    // 진입 즉시 shift types 프리로드
    ref.watch(_wantedShiftTypesProvider(teamId));

    return Scaffold(
      appBar: MoniqAppBar(
        title: '원티드 입력',
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            MoniqAppBarAction(
              icon: Icons.history,
              onTap: () => context.push(
                '/teams/$teamId/wanted/history?isAdmin=false',
              ),
            ),
            MoniqAppBarAction(
              icon: Icons.refresh_rounded,
              onTap: () =>
                  ref.invalidate(wantedMemberViewModelProvider(teamId)),
            ),
          ],
        ),
      ),
      body: stateAsync.when(
        loading: () => const MoniqLoadingView(),
        error: (e, _) => MoniqErrorView(
          message: '정보를 불러올 수 없습니다',
          onRetry: () =>
              ref.invalidate(wantedMemberViewModelProvider(teamId)),
        ),
        data: (state) {
          if (state.activeRequests.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(wantedMemberViewModelProvider(teamId)),
              child: ListView(
                children: [
                  const SizedBox(height: 120),
                  MoniqEmptyState.peaceful(
                    title: '진행 중인 원티드 수집이 없어요',
                    message: '관리자가 수집을 시작하면 여기서 입력할 수 있어요',
                  ),
                ],
              ),
            );
          }
          return _EntryView(teamId: teamId, state: state);
        },
      ),
    );
  }
}

// ─── _EntryView ───────────────────────────────────────────────────────────────

class _EntryView extends HookConsumerWidget {
  const _EntryView({required this.teamId, required this.state});

  final String teamId;
  final WantedMemberState state;

  // ── helpers ──

  bool get _isNightView =>
      state.activeRequest?.wantedType == 'night_dedicated';

  bool get _hasUnifiedRequests => state.activeRequests.any(
        (r) =>
            r.wantedType == 'day_off' || r.wantedType == 'preferred_shift',
      );

  bool get _hasNightRequest => state.activeRequests
      .any((r) => r.wantedType == 'night_dedicated');

  WantedRequestModel? get _nightRequest => state.activeRequests
      .where((r) => r.wantedType == 'night_dedicated')
      .cast<WantedRequestModel?>()
      .firstWhere((_) => true, orElse: () => null);

  WantedRequestModel? get _unifiedRequest => state.activeRequests
      .where(
        (r) =>
            r.wantedType == 'day_off' ||
            r.wantedType == 'preferred_shift',
      )
      .cast<WantedRequestModel?>()
      .firstWhere((_) => true, orElse: () => null);

  List<WantedEntryModel> _unifiedEntries() {
    final nightId = _nightRequest?.id;
    return state.myEntries
        .where((e) => e.wantedRequestId != nightId)
        .toList();
  }

  bool _isNightApplied() {
    final nightId = _nightRequest?.id;
    if (nightId == null) return false;
    return state.myEntries.any((e) => e.wantedRequestId == nightId);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dateFormat = DateFormat('yyyy.MM.dd');

    // For banner: use unifiedRequest when not in night view
    final displayRequest = _isNightView
        ? state.activeRequest!
        : (_unifiedRequest ?? state.activeRequest!);

    final isBlocked = displayRequest.status != 'collecting' ||
        (displayRequest.deadline != null &&
            DateTime.now().isAfter(displayRequest.deadline!));

    final daysLeft = displayRequest.deadline
        ?.difference(DateTime.now())
        .inDays;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Column(
          children: [
            // ── 타입 전환 칩 (희망근무 ↔ 나이트전담) ──
            if (_hasUnifiedRequests && _hasNightRequest)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    spacing: AppSpacing.sm,
                    children: [
                      ChoiceChip(
                        label: const Text('원티드'),
                        selected: !_isNightView,
                        onSelected: (_) {
                          ref
                              .read(
                                wantedMemberViewModelProvider(teamId)
                                    .notifier,
                              )
                              .selectType(_unifiedRequest!.wantedType);
                        },
                      ),
                      ChoiceChip(
                        label: const Text('나이트 전담'),
                        selected: _isNightView,
                        onSelected: (_) {
                          ref
                              .read(
                                wantedMemberViewModelProvider(teamId)
                                    .notifier,
                              )
                              .selectType('night_dedicated');
                        },
                      ),
                    ],
                  ),
                ),
              ),

            // ── 안내 배너 ──
            if (isBlocked)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: colorScheme.error.withValues(alpha: 0.06),
                  border: Border(
                    bottom: BorderSide(
                      color: colorScheme.error.withValues(alpha: 0.15),
                    ),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      color: colorScheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '원티드 수집이 마감되었습니다',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colorScheme.error,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            '관리자가 수집을 종료했거나 마감일이 지났습니다.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            '기간: ${dateFormat.format(displayRequest.periodStart)}'
                            ' ~ ${dateFormat.format(displayRequest.periodEnd)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              // P1-1: 활성 배너 재구성
              _ActiveBanner(
                displayRequest: displayRequest,
                daysLeft: daysLeft,
                isNightView: _isNightView,
              ),

            // ── 본문 ──
            Expanded(
              child: _buildBody(context, ref, isBlocked),
            ),

            // ── 하단 액션 버튼 ──
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: _buildActionButton(context, ref, isBlocked),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── body ──────────────────────────────────────────────────────────────────

  String _reasonLabel(String? reason) {
    if (reason == '#생리휴가') return '생리휴가';
    if (reason == '#연차') return '연차';
    if (reason == '#필수교육') return '필수 교육';
    return reason ?? '';
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    bool isBlocked,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // P0-2: 날짜 + 요일 포맷
    final dateFormat = DateFormat('yyyy.MM.dd E', 'ko');

    // 나이트 전담 뷰
    if (_isNightView) {
      final isApplied = _isNightApplied();
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isApplied ? Icons.check_circle : Icons.nightlight_round,
              size: 64,
              color: isApplied
                  ? AppColors.success
                  : colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              isApplied ? '나이트 전담 신청 완료' : '아래 버튼으로 신청하세요',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: isApplied
                    ? AppColors.success
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    // 통합 뷰 — 엔트리 없음
    final unified = _unifiedEntries();
    if (unified.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today,
              size: 48,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '아래 버튼으로 날짜를 추가하세요',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    // shift types for display
    final shiftTypesAsync = ref.watch(_wantedShiftTypesProvider(teamId));
    final shiftTypeMap = {
      for (final t in (shiftTypesAsync.valueOrNull ?? [])) t.id: t,
    };

    return ListView.separated(
      padding: AppSpacing.screenAll,
      itemCount: unified.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final entry = unified[index];
        final shiftType = entry.shiftTypeId != null
            ? shiftTypeMap[entry.shiftTypeId]
            : null;
        final isOff = entry.shiftTypeId == null;

        // 카드 좌측 바·아바타·shadow 용 색상 (기존 유지)
        final Color entryColor;
        if (isOff) {
          entryColor = AppColors.shiftOff;
        } else if (shiftType != null) {
          entryColor = parseHexColor(shiftType.color);
        } else {
          entryColor = AppColors.primary;
        }

        // P0-1: 순위 pill 전용 색상
        final Color priorityColor =
            entry.priority == 1 ? AppColors.error : AppColors.brandOrange;

        final String shiftCode = isOff ? 'O' : (shiftType?.code ?? '?');
        final String shiftName = isOff ? '오프' : (shiftType?.name ?? '');
        final subtitleParts = [
          shiftName,
          if (entry.reason != null && entry.reason!.isNotEmpty)
            _reasonLabel(entry.reason),
        ];

        return Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          elevation: 1,
          shadowColor: entryColor.withValues(alpha: 0.15),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // P0-2: 좌측 컬러바 유지
                Container(width: 4, color: entryColor),
                // P0-2: ListTile 제거 → Padding+Column
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 상단 Row: 날짜+요일 / 순위 pill / X 버튼
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                dateFormat.format(entry.wantedDate),
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            // P0-1: priorityColor 사용
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: priorityColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.full,
                                ),
                              ),
                              child: Text(
                                '${entry.priority}순위',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: priorityColor,
                                ),
                              ),
                            ),
                            // P0-2: X 버튼 44px SizedBox
                            SizedBox(
                              width: 44,
                              child: isBlocked
                                  ? null
                                  : IconButton(
                                      icon: Icon(
                                        Icons.close,
                                        size: 18,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                      onPressed: () => _removeEntry(
                                        context,
                                        ref,
                                        entry.id,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        // 하단 Row: ShiftCodeBadge + subtitle
                        Row(
                          children: [
                            _ShiftCodeBadge(
                              code: shiftCode,
                              color: entryColor,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              subtitleParts.join(' · '),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── action button ──────────────────────────────────────────────────────────

  Widget _buildActionButton(
    BuildContext context,
    WidgetRef ref,
    bool isBlocked,
  ) {
    // 나이트 전담 뷰
    if (_isNightView) {
      final isApplied = _isNightApplied();
      if (isApplied) {
        if (isBlocked) return const SizedBox.shrink();
        final nightEntry = state.myEntries
            .where((e) => e.wantedRequestId == _nightRequest?.id)
            .cast<WantedEntryModel?>()
            .firstWhere((_) => true, orElse: () => null);
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: state.isSubmitting || nightEntry == null
                ? null
                : () => _removeEntry(context, ref, nightEntry.id),
            icon: const Icon(Icons.close),
            label: const Text('나이트 전담 신청 취소'),
          ),
        );
      }
      if (isBlocked) return const SizedBox.shrink();
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: state.isSubmitting
              ? null
              : () => _applyNightDedicated(context, ref),
          icon: state.isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.nightlight_round),
          label: const Text('나이트 전담 신청하기'),
        ),
      );
    }

    // 통합 뷰
    if (isBlocked) return const SizedBox.shrink();

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: state.isSubmitting
            ? null
            : () => _showUnifiedPicker(context, ref),
        icon: state.isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add),
        label: const Text('원티드 추가'),
      ),
    );
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  Future<void> _removeEntry(
    BuildContext context,
    WidgetRef ref,
    String entryId,
  ) async {
    final ok = await ref
        .read(wantedMemberViewModelProvider(teamId).notifier)
        .removeEntry(entryId);
    if (!context.mounted || ok) return;
    final err = ref
        .read(wantedMemberViewModelProvider(teamId))
        .valueOrNull
        ?.error;
    if (err != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err)));
    }
  }

  Future<void> _applyNightDedicated(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final request = _nightRequest;
    if (request == null) return;
    final success = await ref
        .read(wantedMemberViewModelProvider(teamId).notifier)
        .addWantedDates(
          datesWithPriority: {request.periodStart: 1},
          reason: '나이트 전담 신청',
          requestId: request.id,
        );
    if (!context.mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('나이트 전담 신청이 완료되었습니다')),
      );
    } else {
      final err = ref
          .read(wantedMemberViewModelProvider(teamId))
          .valueOrNull
          ?.error;
      if (err != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(err)));
      }
    }
  }

  // ── unified picker ────────────────────────────────────────────────────────

  void _showUnifiedPicker(BuildContext context, WidgetRef ref) {
    final unifiedReq = _unifiedRequest;
    if (unifiedReq == null) return;

    final shiftTypesAsync = ref.read(_wantedShiftTypesProvider(teamId));
    final shiftTypes = shiftTypesAsync.valueOrNull ?? [];

    final hasDayOff = state.activeRequests
        .any((r) => r.wantedType == 'day_off');
    final hasPrefShift = state.activeRequests
        .any((r) => r.wantedType == 'preferred_shift');

    // Existing unified entries (exclude night)
    final nightId = _nightRequest?.id;
    final existingDates = state.myEntries
        .where((e) => e.wantedRequestId != nightId)
        .map(
          (e) => DateTime(
            e.wantedDate.year,
            e.wantedDate.month,
            e.wantedDate.day,
          ),
        )
        .toSet();

    // ── 드롭다운 헬퍼 ──
    String canonicalCode(ShiftTypeModel t) {
      final c = t.code.toUpperCase();
      final n = t.name;
      if (c == 'D' || n.contains('데이') || n.contains('주간')) return 'D';
      if (c == 'E' || n.contains('이브닝') || n.contains('저녁')) return 'E';
      if (c == 'N' || n.contains('야간') || n.contains('나이트')) return 'N';
      return c;
    }

    final dType = shiftTypes
        .where((t) => canonicalCode(t) == 'D')
        .cast<ShiftTypeModel?>()
        .firstWhere((_) => true, orElse: () => null);
    final eType = shiftTypes
        .where((t) => canonicalCode(t) == 'E')
        .cast<ShiftTypeModel?>()
        .firstWhere((_) => true, orElse: () => null);
    final nType = shiftTypes
        .where((t) => canonicalCode(t) == 'N')
        .cast<ShiftTypeModel?>()
        .firstWhere((_) => true, orElse: () => null);
    final canonicalTypeIds = {dType?.id, eType?.id, nType?.id}
        .whereType<String>()
        .toSet();
    // ED(교육) 타입은 D/E/N 바로 다음에 위치
    final edType = shiftTypes
        .cast<ShiftTypeModel?>()
        .firstWhere((t) => t!.code.toUpperCase() == 'ED', orElse: () => null);
    final allPriorityIds = {...canonicalTypeIds, if (edType?.id != null) edType!.id};
    final otherShiftTypes =
        shiftTypes.where((t) => !allPriorityIds.contains(t.id)).toList();

    // State inside sheet
    // null shiftTypeId = OFF
    String? currentShiftTypeId = hasDayOff
        ? null
        : (dType?.id ??
            eType?.id ??
            nType?.id ??
            (shiftTypes.isNotEmpty ? shiftTypes.first.id : null));
    int currentPriority = 1;
    String otherReason = ''; // D/E/N 공통 사유 (선택)
    String? currentOffReason; // P1-4: 오프 사유 인라인 상태
    String? sheetError;

    final selectedDates = <DateTime, _DayOffSel>{};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          // 교육 등 비 D/E/N 근무 유형 선택 여부
          final selectedType = currentShiftTypeId != null
              ? shiftTypes.cast<ShiftTypeModel?>().firstWhere(
                    (t) => t!.id == currentShiftTypeId,
                    orElse: () => null,
                  )
              : null;
          final isEducationSelected =
              selectedType != null && selectedType.code.toUpperCase() == 'ED';

          // P1-2: 타입 셀렉터 아이템 목록 구성
          final typeItems = <_TypeItem>[
            if (hasDayOff)
              const _TypeItem(
                id: null,
                label: '오프',
                code: 'O',
                color: AppColors.shiftOff,
              ),
            if (hasPrefShift && dType != null)
              _TypeItem(
                id: dType.id,
                label: '데이',
                code: 'D',
                color: parseHexColor(dType.color),
              ),
            if (hasPrefShift && eType != null)
              _TypeItem(
                id: eType.id,
                label: '이브닝',
                code: 'E',
                color: parseHexColor(eType.color),
              ),
            if (hasPrefShift && nType != null)
              _TypeItem(
                id: nType.id,
                label: '나이트',
                code: 'N',
                color: parseHexColor(nType.color),
              ),
            if (edType != null)
              _TypeItem(
                id: edType.id,
                label: edType.name,
                code: edType.code,
                color: parseHexColor(edType.color),
              ),
            ...otherShiftTypes.map(
              (t) => _TypeItem(
                id: t.id,
                label: t.name,
                code: t.code,
                color: parseHexColor(t.color),
              ),
            ),
          ];

          return DraggableScrollableSheet(
            initialChildSize: 0.92,
            minChildSize: 0.5,
            maxChildSize: 0.97,
            expand: false,
            builder: (ctx, scrollController) => Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.md),
                  // drag handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(ctx).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    '원티드 추가',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    isEducationSelected
                        ? '근무 유형을 고른 뒤 날짜를 탭하세요.'
                        : '근무 유형과 우선순위를 고른 뒤 날짜를 탭하세요.',
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                          color: Theme.of(ctx)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // ── P1-2: 근무 유형 타일 셀렉터 ──
                  if (typeItems.isNotEmpty)
                    _WantedTypeSelector(
                      items: typeItems,
                      selectedId: currentShiftTypeId,
                      onSelected: (v) => setSheetState(() {
                        currentShiftTypeId = v;
                        if (v != null && !canonicalTypeIds.contains(v)) {
                          currentPriority = 1;
                        }
                      }),
                    ),

                  const SizedBox(height: AppSpacing.md),

                  // ── P1-3: 우선순위 라디오 스타일 (교육 유형은 숨김) ──
                  if (!isEducationSelected) ...[
                    Text(
                      '우선순위',
                      style: Theme.of(ctx).textTheme.labelMedium?.copyWith(
                            color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [1, 2].map((p) {
                        final isSelected = currentPriority == p;
                        final color = p == 1
                            ? AppColors.error
                            : AppColors.brandOrange;
                        final label = p == 1 ? '1순위 필수' : '2순위 희망';
                        return Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                setSheetState(() => currentPriority = p),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.md,
                              ),
                              margin: EdgeInsets.only(
                                right: p == 1 ? AppSpacing.sm : 0,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? color.withValues(alpha: 0.08)
                                    : null,
                                border: Border.all(
                                  color: isSelected
                                      ? color
                                      : Theme.of(ctx)
                                          .colorScheme
                                          .outlineVariant,
                                  width: isSelected ? 1.5 : 1,
                                ),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.sm),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    isSelected
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_unchecked,
                                    size: 16,
                                    color: isSelected
                                        ? color
                                        : Theme.of(ctx)
                                            .colorScheme
                                            .onSurfaceVariant,
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  Text(
                                    label,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                      color: isSelected
                                          ? color
                                          : Theme.of(ctx)
                                              .colorScheme
                                              .onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  // ── P1-4: 오프 사유 인라인 칩 / D·E·N 공통 사유 텍스트 ──
                  if (currentShiftTypeId == null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: [
                        if (currentPriority == 1) ...[
                          _OffReasonChip(
                            label: '생리휴가',
                            value: '#생리휴가',
                            selected: currentOffReason == '#생리휴가',
                            onTap: () => setSheetState(
                              () => currentOffReason =
                                  currentOffReason == '#생리휴가'
                                      ? null
                                      : '#생리휴가',
                            ),
                          ),
                          _OffReasonChip(
                            label: '연차',
                            value: '#연차',
                            selected: currentOffReason == '#연차',
                            onTap: () => setSheetState(
                              () => currentOffReason =
                                  currentOffReason == '#연차'
                                      ? null
                                      : '#연차',
                            ),
                          ),
                        ],
                        _OffReasonChip(
                          label: '직접 입력',
                          value: 'custom',
                          selected: currentOffReason != null &&
                              currentOffReason != '#생리휴가' &&
                              currentOffReason != '#연차',
                          onTap: () => setSheetState(
                            () {
                              // 직접입력 칩 토글: 이미 커스텀이면 해제
                              if (currentOffReason != null &&
                                  currentOffReason != '#생리휴가' &&
                                  currentOffReason != '#연차') {
                                currentOffReason = null;
                              } else {
                                // 빈 문자열로 초기화하여 텍스트필드 노출
                                currentOffReason = '';
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    // 직접입력 선택 시 텍스트필드 인라인
                    if (currentOffReason != null &&
                        currentOffReason != '#생리휴가' &&
                        currentOffReason != '#연차') ...[
                      const SizedBox(height: AppSpacing.sm),
                      TextField(
                        autofocus: true,
                        onChanged: (v) => setSheetState(
                          () => currentOffReason =
                              v.isNotEmpty ? v : '',
                        ),
                        decoration: const InputDecoration(
                          hintText: '사유를 입력하세요',
                          isDense: true,
                        ),
                        textInputAction: TextInputAction.done,
                        textCapitalization: TextCapitalization.none,
                        keyboardType: TextInputType.text,
                      ),
                    ],
                  ] else ...[
                    // D/E/N: 공통 사유 텍스트 (선택)
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      onChanged: (v) =>
                          setSheetState(() => otherReason = v),
                      textCapitalization: TextCapitalization.none,
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        hintText: '사유 (선택)',
                      ),
                      maxLines: 1,
                    ),
                  ],

                  const SizedBox(height: AppSpacing.md),

                  // ── 캘린더 ──
                  Expanded(
                    child: _MultiDateCalendar(
                      periodStart: unifiedReq.periodStart,
                      periodEnd: unifiedReq.periodEnd,
                      selectedDates: selectedDates,
                      shiftTypes: shiftTypes,
                      existingDates: existingDates,
                      onToggle: (date) {
                        // P1-4: OFF 날짜 탭 시 인라인 사유 적용
                        if (currentShiftTypeId == null) {
                          if (selectedDates.containsKey(date)) {
                            setSheetState(
                              () => selectedDates.remove(date),
                            );
                          } else {
                            setSheetState(() {
                              selectedDates[date] = _DayOffSel(
                                priority: currentPriority,
                                reason: (currentOffReason != null &&
                                        currentOffReason!.isNotEmpty)
                                    ? currentOffReason
                                    : null,
                              );
                            });
                          }
                        } else {
                          // D/E/N: 즉시 토글
                          setSheetState(() {
                            final next = _DayOffSel(
                              priority: currentPriority,
                              shiftTypeId: currentShiftTypeId,
                              reason: otherReason.isNotEmpty
                                  ? otherReason
                                  : null,
                            );
                            if (selectedDates[date] == next) {
                              selectedDates.remove(date);
                            } else {
                              selectedDates[date] = next;
                            }
                          });
                        }
                      },
                      scrollController: scrollController,
                    ),
                  ),

                  if (selectedDates.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: Text(
                        '${selectedDates.length}일 선택됨',
                        style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                              color: Theme.of(ctx).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),

                  if (sheetError != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.12),
                        borderRadius:
                            BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: AppColors.error,
                            size: 18,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              sheetError!,
                              style: Theme.of(ctx)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: AppColors.error,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.lg),

                  FilledButton(
                    onPressed: selectedDates.isEmpty
                        ? null
                        : () async {
                            // _DayOffSel 기준으로 그룹핑
                            final grouped =
                                <_DayOffSel, List<DateTime>>{};
                            for (final e in selectedDates.entries) {
                              grouped
                                  .putIfAbsent(e.value, () => [])
                                  .add(e.key);
                            }
                            final notifier = ref.read(
                              wantedMemberViewModelProvider(teamId)
                                  .notifier,
                            );
                            var allOk = true;
                            for (final g in grouped.entries) {
                              final ok = await notifier.addWantedDates(
                                datesWithPriority: {
                                  for (final d in g.value)
                                    d: g.key.priority,
                                },
                                reason: g.key.reason,
                                shiftTypeId: g.key.shiftTypeId,
                              );
                              if (!ok) allOk = false;
                            }
                            if (!ctx.mounted) return;
                            if (allOk) {
                              Navigator.pop(ctx);
                            } else {
                              final err = ref
                                  .read(
                                    wantedMemberViewModelProvider(teamId),
                                  )
                                  .valueOrNull
                                  ?.error;
                              setSheetState(
                                () => sheetError = err ?? '저장에 실패했습니다',
                              );
                            }
                          },
                    child: Text(
                      selectedDates.isEmpty
                          ? '날짜를 선택해주세요'
                          : '${selectedDates.length}일 추가',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── _ActiveBanner (P1-1) ─────────────────────────────────────────────────────

class _ActiveBanner extends StatelessWidget {
  const _ActiveBanner({
    required this.displayRequest,
    required this.daysLeft,
    required this.isNightView,
  });

  final WantedRequestModel displayRequest;
  final int? daysLeft;
  final bool isNightView;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dateFormat = DateFormat('yyyy.MM.dd');
    final bannerColor = (daysLeft != null && daysLeft! <= 3)
        ? AppColors.brandOrange
        : colorScheme.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: bannerColor.withValues(alpha: 0.06),
        border: Border(
          bottom: BorderSide(
            color: bannerColor.withValues(alpha: 0.15),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상단 Row: 수집 중 pill + D-N pill
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '수집 중',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (daysLeft != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: bannerColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    daysLeft == 0 ? 'D-Day' : 'D-$daysLeft',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: bannerColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          // 타이틀
          Text(
            isNightView ? '나이트 전담을 신청해주세요' : '원티드를 입력해주세요',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          // 근무 기간 _InfoRow
          _InfoRow(
            label: '근무 기간',
            value:
                '${dateFormat.format(displayRequest.periodStart)}'
                ' ~ ${dateFormat.format(displayRequest.periodEnd)}',
          ),
          // 마감 _InfoRow
          if (displayRequest.deadline != null)
            _InfoRow(
              label: '마감',
              value: dateFormat.format(displayRequest.deadline!),
              valueColor: (daysLeft != null && daysLeft! <= 3)
                  ? AppColors.brandOrange
                  : null,
            ),
          // 구분선
          if (!isNightView) ...[
            Divider(height: AppSpacing.md),
            // 범례
            const Wrap(
              spacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _PriorityLegendDot(
                  label: '1순위 필수',
                  color: AppColors.error,
                ),
                _PriorityLegendDot(
                  label: '2순위 희망',
                  color: AppColors.brandOrange,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─── _DayOffSel ────────────────────────────────────────────────────────────────

class _DayOffSel {
  const _DayOffSel({
    required this.priority,
    this.reason,
    this.shiftTypeId,
  });
  final int priority;
  final String? reason;
  final String? shiftTypeId; // null = OFF

  @override
  bool operator ==(Object other) =>
      other is _DayOffSel &&
      other.priority == priority &&
      other.reason == reason &&
      other.shiftTypeId == shiftTypeId;

  @override
  int get hashCode => Object.hash(priority, reason, shiftTypeId);
}

// ─── _MultiDateCalendar ────────────────────────────────────────────────────────

class _MultiDateCalendar extends StatefulWidget {
  const _MultiDateCalendar({
    required this.periodStart,
    required this.periodEnd,
    required this.selectedDates,
    required this.shiftTypes,
    required this.existingDates,
    required this.onToggle,
    required this.scrollController,
  });

  final DateTime periodStart;
  final DateTime periodEnd;
  final Map<DateTime, _DayOffSel> selectedDates;
  final List<ShiftTypeModel> shiftTypes;
  final Set<DateTime> existingDates;
  final ValueChanged<DateTime> onToggle;
  final ScrollController scrollController;

  @override
  State<_MultiDateCalendar> createState() => _MultiDateCalendarState();
}

class _MultiDateCalendarState extends State<_MultiDateCalendar> {
  late DateTime _currentMonth;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(
      widget.periodStart.year,
      widget.periodStart.month,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dayLabels = ['월', '화', '수', '목', '금', '토', '일'];
    final typeMap = {for (final t in widget.shiftTypes) t.id: t};

    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final startWeekday = firstDay.weekday;

    final days = <DateTime?>[];
    for (int i = 1; i < startWeekday; i++) {
      days.add(null);
    }
    for (int d = 1; d <= lastDay.day; d++) {
      days.add(DateTime(_currentMonth.year, _currentMonth.month, d));
    }

    return Column(
      children: [
        // 월 네비게이션
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () {
                final prev = DateTime(
                  _currentMonth.year,
                  _currentMonth.month - 1,
                );
                final periodMonth = DateTime(
                  widget.periodStart.year,
                  widget.periodStart.month,
                );
                if (!prev.isBefore(periodMonth)) {
                  setState(() => _currentMonth = prev);
                }
              },
            ),
            Text(
              DateFormat('yyyy년 MM월').format(_currentMonth),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () {
                final next = DateTime(
                  _currentMonth.year,
                  _currentMonth.month + 1,
                );
                final periodEndMonth = DateTime(
                  widget.periodEnd.year,
                  widget.periodEnd.month,
                );
                if (!next.isAfter(
                  DateTime(
                    periodEndMonth.year,
                    periodEndMonth.month + 1,
                  ),
                )) {
                  setState(() => _currentMonth = next);
                }
              },
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),

        // 요일 헤더
        Row(
          children: dayLabels.map((label) {
            final isWeekend = label == '토' || label == '일';
            return Expanded(
              child: Center(
                child: Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isWeekend
                        ? colorScheme.error.withValues(alpha: 0.6)
                        : colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.sm),

        // P1-5: 날짜 그리드 childAspectRatio 0.85
        Expanded(
          child: GridView.builder(
            controller: widget.scrollController,
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 0.85,
            ),
            itemCount: days.length,
            itemBuilder: (context, index) {
              final day = days[index];
              if (day == null) return const SizedBox();

              final isInPeriod = !day.isBefore(widget.periodStart) &&
                  !day.isAfter(widget.periodEnd);
              final sel = widget.selectedDates[day];
              final isSelected = sel != null;
              final isExisting = widget.existingDates.contains(day);

              // Cell color: OFF/교육 = gray, D/E/N = shift color
              Color selColor;
              if (sel != null) {
                if (sel.shiftTypeId == null) {
                  selColor = AppColors.shiftOff;
                } else {
                  final t = typeMap[sel.shiftTypeId];
                  selColor = t != null
                      ? parseHexColor(t.color)
                      : colorScheme.primary;
                }
              } else {
                selColor = colorScheme.primary;
              }

              // 우선순위 배지(좌상단) + 근무 유형 배지(우상단) + 사유 배지(우하단)
              final String? priorityBadge =
                  isSelected ? '${sel.priority}' : null;
              final String? typeBadge = isSelected
                  ? (sel.shiftTypeId == null
                      ? (sel.reason == '#필수교육' ? '교' : 'O')
                      : (typeMap[sel.shiftTypeId]?.code ?? '?'))
                  : null;
              final String? reasonBadge =
                  (isSelected && sel.shiftTypeId == null)
                      ? (sel.reason == '#생리휴가'
                          ? '생휴'
                          : sel.reason == '#연차'
                              ? '연차'
                              : null)
                      : null;

              // P1-5: 기간 외 셀 opacity 처리
              Widget cellWidget = Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? selColor
                      : isExisting
                          ? colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.15)
                          : null,
                  borderRadius:
                      BorderRadius.circular(AppRadius.xs),
                  border: isInPeriod && !isSelected && !isExisting
                      ? Border.all(color: colorScheme.outlineVariant)
                      : null,
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Text(
                        '${day.day}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isSelected
                              ? Colors.white
                              : isExisting
                                  ? AppColors.onSurfaceVariant
                                  : isInPeriod
                                      ? null
                                      : colorScheme.onSurface
                                          .withValues(alpha: 0.25),
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : null,
                        ),
                      ),
                    ),
                    if (priorityBadge != null)
                      Positioned(
                        top: 2,
                        left: 2,
                        child: Text(
                          priorityBadge,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    if (typeBadge != null)
                      Positioned(
                        top: 2,
                        right: 2,
                        child: Text(
                          typeBadge,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    if (reasonBadge != null)
                      Positioned(
                        bottom: 2,
                        right: 2,
                        child: Text(
                          reasonBadge,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 7,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              );

              return GestureDetector(
                onTap: isInPeriod && !isExisting
                    ? () => widget.onToggle(day)
                    : null,
                child: isInPeriod
                    ? cellWidget
                    : Opacity(opacity: 0.35, child: cellWidget),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── _PriorityLegendDot ────────────────────────────────────────────────────────

class _PriorityLegendDot extends StatelessWidget {
  const _PriorityLegendDot({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: color.withValues(alpha: 0.85),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ─── _ShiftCodeBadge (P0-2) ───────────────────────────────────────────────────

class _ShiftCodeBadge extends StatelessWidget {
  const _ShiftCodeBadge({required this.code, required this.color});

  final String code;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        code,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
          height: 1,
        ),
      ),
    );
  }
}

// ─── _InfoRow (P1-1) ──────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 52,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: valueColor ?? cs.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── _WantedTypeSelector (P1-2) ───────────────────────────────────────────────

class _TypeItem {
  const _TypeItem({
    required this.id,
    required this.label,
    required this.code,
    required this.color,
  });

  final String? id; // null = 오프
  final String label;
  final String code;
  final Color color;
}

class _WantedTypeSelector extends StatelessWidget {
  const _WantedTypeSelector({
    required this.items,
    required this.selectedId,
    required this.onSelected,
  });

  final List<_TypeItem> items;
  final String? selectedId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final tiles = items.map((item) {
      final isSelected = selectedId == item.id;
      return GestureDetector(
        onTap: () => onSelected(item.id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 68,
          height: 60,
          decoration: BoxDecoration(
            color: isSelected
                ? item.color.withValues(alpha: 0.15)
                : colorScheme.surfaceContainerHigh,
            border: Border.all(
              color: isSelected ? item.color : colorScheme.outlineVariant,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ShiftCodeBadge(code: item.code, color: item.color),
              const SizedBox(height: 4),
              Text(
                item.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                  color: isSelected
                      ? item.color
                      : colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      );
    }).toList();

    if (items.length >= 5) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (int i = 0; i < tiles.length; i++) ...[
              tiles[i],
              if (i < tiles.length - 1)
                const SizedBox(width: AppSpacing.sm),
            ],
          ],
        ),
      );
    }

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: tiles,
    );
  }
}

// ─── _OffReasonChip (P1-4) ────────────────────────────────────────────────────

class _OffReasonChip extends StatelessWidget {
  const _OffReasonChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primary.withValues(alpha: 0.12)
              : colorScheme.surfaceContainerHigh,
          border: Border.all(
            color: selected ? colorScheme.primary : colorScheme.outlineVariant,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            color: selected
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
