import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moniq/core/utils/color_utils.dart';
import 'package:moniq/data/models/shift_type_model.dart';
import 'package:moniq/data/models/wanted_request_model.dart';
import 'package:moniq/data/providers/shift_providers.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/wanted_viewmodel.dart';
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
      appBar: AppBar(
        title: const Text('원티드 입력'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '새로고침',
            onPressed: () =>
                ref.invalidate(wantedMemberViewModelProvider(teamId)),
          ),
        ],
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
                children: const [
                  SizedBox(height: 120),
                  MoniqEmptyState(
                    icon: Icons.event_busy,
                    message: '현재 진행 중인 원티드 수집이 없습니다',
                    description: '관리자가 수집을 시작하면 여기서 입력할 수 있습니다',
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
                        label: const Text('희망 근무'),
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
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: (daysLeft != null && daysLeft <= 3
                          ? AppColors.brandOrange
                          : colorScheme.primary)
                      .withValues(alpha: 0.06),
                  border: Border(
                    bottom: BorderSide(
                      color: (daysLeft != null && daysLeft <= 3
                              ? AppColors.brandOrange
                              : colorScheme.primary)
                          .withValues(alpha: 0.15),
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _isNightView
                                ? '나이트 전담을 신청해주세요'
                                : '원티드 정보를 입력해주세요',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (daysLeft != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: (daysLeft <= 3
                                      ? AppColors.brandOrange
                                      : colorScheme.primary)
                                  .withValues(alpha: 0.12),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.full),
                            ),
                            child: Text(
                              daysLeft == 0 ? 'D-Day' : 'D-$daysLeft',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: daysLeft <= 3
                                    ? AppColors.brandOrange
                                    : colorScheme.primary,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '기간: ${dateFormat.format(displayRequest.periodStart)}'
                      ' ~ ${dateFormat.format(displayRequest.periodEnd)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (displayRequest.deadline != null)
                      Text(
                        '마감: ${dateFormat.format(displayRequest.deadline!)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: daysLeft != null && daysLeft <= 3
                              ? AppColors.brandOrange
                              : colorScheme.onSurfaceVariant,
                          fontWeight: daysLeft != null && daysLeft <= 3
                              ? FontWeight.w600
                              : null,
                        ),
                      ),
                    // 우선순위 범례 (비나이트 뷰에서만)
                    if (!_isNightView) ...[
                      const SizedBox(height: AppSpacing.xs),
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
    final dateFormat = DateFormat('yyyy.MM.dd');

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

        // Color determination
        final Color entryColor;
        if (isOff) {
          entryColor = AppColors.shiftOff;
        } else if (shiftType != null) {
          entryColor = parseHexColor(shiftType.color);
        } else {
          entryColor = AppColors.primary;
        }

        final subtitleParts = [
          if (!isOff && shiftType != null) shiftType.name,
          if (isOff) '오프',
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
                Container(width: 4, color: entryColor),
                Expanded(
                  child: ListTile(
                    leading: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: entryColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        isOff ? 'O' : (shiftType?.code ?? '?'),
                        style: TextStyle(
                          color: entryColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            dateFormat.format(entry.wantedDate),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: entryColor.withValues(alpha: 0.12),
                            borderRadius:
                                BorderRadius.circular(AppRadius.full),
                          ),
                          child: Text(
                            '${entry.priority}순위',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: entryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: subtitleParts.isNotEmpty
                        ? Text(
                            subtitleParts.join(' · '),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          )
                        : null,
                    trailing: isBlocked
                        ? null
                        : IconButton(
                            icon: Icon(
                              Icons.close,
                              size: 18,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            onPressed: () =>
                                _removeEntry(context, ref, entry.id),
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

    const canonicalLabels = <String, String>{
      'D': '데이',
      'E': '이브닝',
      'N': '나이트',
    };
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
    final otherShiftTypes =
        shiftTypes.where((t) => !canonicalTypeIds.contains(t.id)).toList();

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
          // ── OFF 사유 다이얼로그 (날짜별 호출) ──
          void showCustomReasonDialog(DateTime date) {
            String customText = '';
            showDialog<bool>(
              context: ctx,
              builder: (dCtx) => AlertDialog(
                title: const Text('사유 직접 입력'),
                content: TextField(
                  autofocus: true,
                  onChanged: (v) => customText = v,
                  decoration: const InputDecoration(hintText: '사유를 입력하세요'),
                  textInputAction: TextInputAction.done,
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dCtx),
                    child: const Text('취소'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(dCtx, true),
                    child: const Text('확인'),
                  ),
                ],
              ),
            ).then((ok) {
              if (ok != true || !ctx.mounted) return;
              setSheetState(() {
                selectedDates[date] = _DayOffSel(
                  priority: currentPriority,
                  reason: customText.isNotEmpty ? customText : null,
                );
              });
            });
          }

          void showOffReasonDialog(DateTime date) {
            final fmt = DateFormat('M월 d일 (E)', 'ko');
            showDialog<String?>(
              context: ctx,
              barrierDismissible: true,
              builder: (dCtx) => AlertDialog(
                title: Text(fmt.format(date)),
                titleTextStyle:
                    Theme.of(dCtx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                contentPadding: EdgeInsets.zero,
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (currentPriority == 1) ...[
                      ListTile(
                        title: const Text('생리휴가',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        onTap: () => Navigator.pop(dCtx, '#생리휴가'),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      ListTile(
                        title: const Text('연차',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        onTap: () => Navigator.pop(dCtx, '#연차'),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                    ],
                    ListTile(
                      leading: const Icon(Icons.edit_outlined,
                          color: Colors.grey),
                      title: const Text('직접 입력',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      onTap: () => Navigator.pop(dCtx, 'custom'),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dCtx),
                    child: const Text('취소'),
                  ),
                ],
              ),
            ).then((result) {
              if (result == null || !ctx.mounted) return;
              if (result == 'custom') {
                showCustomReasonDialog(date);
              } else {
                setSheetState(() {
                  selectedDates[date] = _DayOffSel(
                    priority: currentPriority,
                    reason: result,
                  );
                });
              }
            });
          }

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
                    '근무 유형과 우선순위를 고른 뒤 날짜를 탭하세요.',
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                          color: Theme.of(ctx)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // ── 근무 유형 드롭다운 ──
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: '근무 유형',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: currentShiftTypeId,
                        isDense: true,
                        isExpanded: true,
                        onChanged: (v) =>
                            setSheetState(() => currentShiftTypeId = v),
                        items: [
                      if (hasDayOff)
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: const BoxDecoration(
                                  color: AppColors.shiftOff,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text('오프'),
                            ],
                          ),
                        ),
                      if (hasPrefShift)
                        for (final entry in [
                          ('D', dType),
                          ('E', eType),
                          ('N', nType),
                        ])
                          if (entry.$2 != null)
                            DropdownMenuItem<String?>(
                              value: entry.$2!.id,
                              child: Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color:
                                          parseHexColor(entry.$2!.color),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(canonicalLabels[entry.$1] ??
                                      entry.$2!.name),
                                ],
                              ),
                            ),
                      if (hasPrefShift)
                        for (final t in otherShiftTypes)
                          DropdownMenuItem<String?>(
                            value: t.id,
                            child: Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: parseHexColor(t.color),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(t.name),
                              ],
                            ),
                          ),
                    ],
                  ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // ── 우선순위 선택 ──
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
                      return Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: ChoiceChip(
                          label: Text('$p순위'),
                          selected: currentPriority == p,
                          onSelected: (_) =>
                              setSheetState(() => currentPriority = p),
                        ),
                      );
                    }).toList(),
                  ),

                  // ── 사유 안내 ──
                  if (currentShiftTypeId == null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.touch_app_outlined,
                          size: 14,
                          color: Theme.of(ctx)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            '날짜를 탭하면 사유(생리휴가 · 연차 · 직접입력)를 선택할 수 있어요',
                            style:
                                Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(ctx)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                          ),
                        ),
                      ],
                    ),
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
                        if (currentShiftTypeId == null) {
                          // 오프: 이미 선택됐으면 해제, 아니면 사유 다이얼로그
                          if (selectedDates.containsKey(date)) {
                            setSheetState(() => selectedDates.remove(date));
                          } else {
                            showOffReasonDialog(date);
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

        // 날짜 그리드
        Expanded(
          child: GridView.builder(
            controller: widget.scrollController,
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
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

              // 우선순위 배지(좌상단) + 근무 유형 배지(우상단)
              final String? priorityBadge =
                  isSelected ? '${sel.priority}' : null;
              final String? typeBadge = isSelected
                  ? (sel.shiftTypeId == null
                      ? (sel.reason == '#필수교육' ? '교' : 'O')
                      : (typeMap[sel.shiftTypeId]?.code ?? '?'))
                  : null;

              return GestureDetector(
                onTap: isInPeriod && !isExisting
                    ? () => widget.onToggle(day)
                    : null,
                child: Container(
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
                                        : AppColors.onSurfaceVariant
                                            .withValues(alpha: 0.3),
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
                    ],
                  ),
                ),
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
