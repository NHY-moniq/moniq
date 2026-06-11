import 'dart:math';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/datasources/push_service.dart';
import 'package:moniq/data/models/custom_rule_model.dart';
import 'package:moniq/data/models/schedule_model.dart';
import 'package:moniq/data/models/shift_model.dart';
import 'package:moniq/data/models/shift_rule_model.dart';
import 'package:moniq/data/models/shift_type_model.dart';
import 'package:moniq/data/models/team_member_with_user.dart';
import 'package:moniq/data/models/wanted_request_model.dart';
import 'package:moniq/data/providers/custom_rule_providers.dart';
import 'package:moniq/data/providers/feedback_providers.dart';
import 'package:moniq/data/providers/schedule_providers.dart';
import 'package:moniq/data/providers/settings_providers.dart';
import 'package:moniq/data/providers/shift_providers.dart';
import 'package:moniq/data/providers/supabase_providers.dart';
import 'package:moniq/data/providers/team_providers.dart';
import 'package:moniq/data/providers/wanted_providers.dart';

part 'schedule_generation_viewmodel.freezed.dart';
part 'schedule_solver.dart';

@freezed
class ScheduleGenerationState with _$ScheduleGenerationState {
  const factory ScheduleGenerationState({
    required String teamId,
    required List<ShiftTypeModel> shiftTypes,
    required List<TeamMemberWithUser> members,
    required List<ShiftRuleModel> rules,
    @Default([]) List<CustomRuleModel> customRules,
    DateTime? periodStart,
    DateTime? periodEnd,
    @Default([]) List<WantedEntryModel> wantedEntries,
    @Default([]) List<String> excludedMemberIds,
    @Default(false) bool isGenerating,
    @Default(false) bool isPublishing,
    ScheduleModel? generatedSchedule,
    List<ShiftModel>? previewShifts,
    List<String>? validationWarnings,
    @Default(0) int understaffedCount,
    @Default(0) int wantedTotal,
    @Default(0) int wantedSatisfied,
    @Default({})
    Map<String, List<String>> softViolations, // {'NOD':['홍길동 05-03',...], ...}
    @Default([]) List<String> wantedUnsatisfied, // ['홍길동 05-10 (휴무 요청)', ...]
    @Default([]) List<String> customRuleViolations,
    @Default([]) List<String> softCustomViolations,
    @Default(false) bool isAnalyzing,
    String? aiAnalysis,
    String? error,
  }) = _ScheduleGenerationState;
}

final scheduleGenerationViewModelProvider =
    AsyncNotifierProvider.family<
      ScheduleGenerationViewModel,
      ScheduleGenerationState,
      String
    >(ScheduleGenerationViewModel.new);

class ScheduleGenerationViewModel
    extends FamilyAsyncNotifier<ScheduleGenerationState, String> {
  @override
  Future<ScheduleGenerationState> build(String teamId) async {
    final teamRepo = ref.watch(teamRepositoryProvider);
    final shiftRepo = ref.watch(shiftRepositoryProvider);

    final results = await Future.wait([
      teamRepo.getTeamMembersWithUsers(teamId),
      shiftRepo.getShiftTypes(teamId),
    ]);

    List<ShiftRuleModel> rules = [];
    try {
      rules = await shiftRepo.getShiftRules(teamId);
    } catch (_) {}

    List<CustomRuleModel> customRules = [];
    try {
      customRules = await ref
          .read(customRuleRepositoryProvider)
          .fetchRules(teamId);
    } catch (_) {}

    final members = results[0] as List<TeamMemberWithUser>;
    final shiftTypes = results[1] as List<ShiftTypeModel>;

    // 기본 기간: 다음 달
    final now = DateTime.now();
    final nextMonth = DateTime(now.year, now.month + 1, 1);
    final nextMonthEnd = DateTime(now.year, now.month + 2, 0);

    // 희망 휴무 엔트리 로드
    List<WantedEntryModel> wantedEntries = [];
    try {
      wantedEntries = await _loadWantedEntriesForPeriod(
        teamId: teamId,
        periodStart: nextMonth,
        periodEnd: nextMonthEnd,
        currentMemberIds: members.map((m) => m.userId).toSet(),
      );
    } catch (_) {}

    return ScheduleGenerationState(
      teamId: teamId,
      shiftTypes: shiftTypes,
      members: members,
      rules: rules,
      customRules: customRules,
      wantedEntries: wantedEntries,
      periodStart: nextMonth,
      periodEnd: nextMonthEnd,
    );
  }

  Future<void> setPeriod(DateTime start, DateTime end) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final periodStart = DateTime(start.year, start.month, start.day);
    final periodEnd = DateTime(end.year, end.month, end.day);

    state = AsyncData(
      current.copyWith(
        periodStart: periodStart,
        periodEnd: periodEnd,
        wantedEntries: const [],
      ),
    );

    if (periodEnd.isBefore(periodStart)) return;

    try {
      final wantedEntries = await _loadWantedEntriesForPeriod(
        teamId: current.teamId,
        periodStart: periodStart,
        periodEnd: periodEnd,
        currentMemberIds: current.members.map((m) => m.userId).toSet(),
      );
      final latest = state.valueOrNull;
      if (latest == null) return;
      if (latest.periodStart == null || latest.periodEnd == null) return;
      if (!_isSameDate(latest.periodStart!, periodStart) ||
          !_isSameDate(latest.periodEnd!, periodEnd)) {
        return; // 최신 선택 기간이 바뀐 경우(연속 탭) 오래된 응답 무시
      }
      state = AsyncData(latest.copyWith(wantedEntries: wantedEntries));
    } catch (_) {}
  }

  /// 스케줄 자동 생성
  Future<void> generate() async {
    final current = state.valueOrNull;
    if (current == null) return;
    if (current.periodStart == null || current.periodEnd == null) return;

    // 이전 프리뷰가 남아있더라도 생성 시작 시 초기화하여
    // 항상 새 생성 플로우로 진입한다.
    final generatingState = current.copyWith(
      isGenerating: true,
      error: null,
      generatedSchedule: null,
      previewShifts: null,
      validationWarnings: null,
      understaffedCount: 0,
    );
    state = AsyncData(generatingState);

    try {
      final scheduleRepo = ref.read(scheduleRepositoryProvider);
      final feedbackTuning = await _loadFeedbackTuning(generatingState.teamId);

      // 1. 스케줄 레코드 생성
      final schedule = await scheduleRepo.createSchedule(
        teamId: generatingState.teamId,
        periodStart: generatingState.periodStart!,
        periodEnd: generatingState.periodEnd!,
      );

      // 2. 자동 배정 알고리즘 실행 (희망 휴무 반영, 제외된 멤버 필터)
      final activeMembers = generatingState.members
          .where((m) => !generatingState.excludedMemberIds.contains(m.userId))
          .toList();
      // 주 시작요일 (달력 주 기준 주간 제한에 사용)
      final weekStartsSunday = ref.read(calendarStartDayProvider) == 'sunday';

      // 이전 달 마지막 주 시드: periodStart 직전 7일 근무를 불러와 롤링 상태를 채운다.
      // (월 경계에서 주간 최대 근무·연속 근무/야간·N→D 등이 끊기지 않도록)
      List<ShiftModel> priorShifts = const [];
      try {
        priorShifts = await scheduleRepo.getTeamShiftsInRange(
          teamId: generatingState.teamId,
          start: generatingState.periodStart!.subtract(const Duration(days: 7)),
          end: generatingState.periodStart!.subtract(const Duration(days: 1)),
        );
      } catch (_) {
        priorShifts = const [];
      }

      // 2. 자동 배정 알고리즘 실행 (피드백 반영 다중 시도 후 최적안 선택)
      final baseSeed = DateTime.now().microsecondsSinceEpoch;
      final attemptCount = feedbackTuning.hasSignal ? 5 : 3;
      _GenerationResult? bestResult;
      var bestObjective = double.negativeInfinity;
      for (var i = 0; i < attemptCount; i++) {
        final candidate = _generateShifts(
          members: activeMembers,
          shiftTypes: generatingState.shiftTypes,
          rules: generatingState.rules,
          customRules: generatingState.customRules,
          start: generatingState.periodStart!,
          end: generatingState.periodEnd!,
          scheduleId: schedule.id,
          teamId: generatingState.teamId,
          wantedEntries: generatingState.wantedEntries,
          seed: baseSeed + (i * 7919),
          tuning: feedbackTuning,
          priorShifts: priorShifts,
          weekStartsSunday: weekStartsSunday,
        );
        final objective = _generationObjective(
          result: candidate,
          tuning: feedbackTuning,
        );
        if (bestResult == null || objective > bestObjective) {
          bestResult = candidate;
          bestObjective = objective;
        }
      }
      final result = bestResult!;

      // 3. shifts 삽입
      await scheduleRepo.insertShifts(result.shifts);

      // 4. 미리보기 조회
      final previewShifts = await scheduleRepo.getShiftsBySchedule(schedule.id);

      final stateAfterGen = generatingState.copyWith(
        isGenerating: false,
        error: null,
        generatedSchedule: schedule,
        previewShifts: previewShifts,
        validationWarnings: result.warnings,
        understaffedCount: result.understaffedCount,
        wantedTotal: result.wantedTotal,
        wantedSatisfied: result.wantedSatisfied,
        softViolations: result.softViolations,
        wantedUnsatisfied: result.wantedUnsatisfied,
        customRuleViolations: [],
        softCustomViolations: [],
      );
      final (:hard, :soft) = _computeCustomRuleViolations(stateAfterGen);
      state = AsyncData(
        stateAfterGen.copyWith(
          customRuleViolations: hard,
          softCustomViolations: soft,
        ),
      );
    } catch (e) {
      state = AsyncData(
        generatingState.copyWith(
          isGenerating: false,
          error: '스케줄 생성 중 오류가 발생했습니다: $e',
        ),
      );
    }
  }

  Future<bool> updatePreviewDayAssignments({
    required DateTime date,
    required Map<String, String?> assignmentsByUserId,
  }) async {
    final current = state.valueOrNull;
    if (current == null || current.generatedSchedule == null) return false;

    final scheduleRepo = ref.read(scheduleRepositoryProvider);
    final shiftRepo = ref.read(shiftRepositoryProvider);
    final scheduleId = current.generatedSchedule!.id;
    final targetDate = DateTime(date.year, date.month, date.day);
    final dateStr = _dateStr(targetDate);
    final previewShifts = current.previewShifts ?? const <ShiftModel>[];

    final existingByUser = <String, ShiftModel>{};
    for (final shift in previewShifts) {
      if (_isSameDate(shift.shiftDate, targetDate)) {
        existingByUser[shift.userId] = shift;
      }
    }

    var changed = false;

    for (final entry in assignmentsByUserId.entries) {
      final userId = entry.key;
      final nextShiftTypeId = entry.value;
      final existing = existingByUser[userId];

      if (nextShiftTypeId == null) {
        if (existing != null) {
          await shiftRepo.deleteShift(existing.id);
          changed = true;
        }
        continue;
      }

      if (existing != null) {
        if (existing.shiftTypeId != nextShiftTypeId) {
          await shiftRepo.updateShift(
            existing.id,
            shiftTypeId: nextShiftTypeId,
          );
          changed = true;
        }
      } else {
        await scheduleRepo.insertShifts([
          {
            'schedule_id': scheduleId,
            'team_id': current.teamId,
            'user_id': userId,
            'shift_date': dateStr,
            'shift_type_id': nextShiftTypeId,
          },
        ]);
        changed = true;
      }
    }

    if (!changed) return true;

    final updatedPreview = await scheduleRepo.getShiftsBySchedule(scheduleId);
    final updated = current.copyWith(previewShifts: updatedPreview);
    final (:hard, :soft) = _computeCustomRuleViolations(updated);
    state = AsyncData(
      updated.copyWith(customRuleViolations: hard, softCustomViolations: soft),
    );
    return true;
  }

  Future<bool> saveEditedPreviewAsNewVersion() async {
    final current = state.valueOrNull;
    if (current == null || current.generatedSchedule == null) return false;
    if (current.periodStart == null || current.periodEnd == null) return false;

    final previewShifts = current.previewShifts ?? const <ShiftModel>[];
    if (previewShifts.isEmpty) return false;

    state = AsyncData(current.copyWith(isGenerating: true, error: null));

    try {
      final scheduleRepo = ref.read(scheduleRepositoryProvider);
      final newSchedule = await scheduleRepo.createSchedule(
        teamId: current.teamId,
        periodStart: current.periodStart!,
        periodEnd: current.periodEnd!,
      );

      final payload = previewShifts
          .map(
            (s) => {
              'schedule_id': newSchedule.id,
              'team_id': current.teamId,
              'user_id': s.userId,
              'shift_date': _dateStr(s.shiftDate),
              'shift_type_id': s.shiftTypeId,
            },
          )
          .toList();

      await scheduleRepo.insertShifts(payload);
      final refreshed = await scheduleRepo.getShiftsBySchedule(newSchedule.id);
      final nextState = current.copyWith(
        isGenerating: false,
        generatedSchedule: newSchedule,
        previewShifts: refreshed,
      );
      final (:hard, :soft) = _computeCustomRuleViolations(nextState);
      state = AsyncData(
        nextState.copyWith(
          customRuleViolations: hard,
          softCustomViolations: soft,
        ),
      );
      return true;
    } catch (e) {
      state = AsyncData(
        current.copyWith(isGenerating: false, error: '수정본 저장 중 오류가 발생했습니다: $e'),
      );
      return false;
    }
  }

  /// 발행
  Future<bool> publish() async {
    final current = state.valueOrNull;
    if (current == null || current.generatedSchedule == null) return false;

    state = AsyncData(current.copyWith(isPublishing: true));

    try {
      final scheduleRepo = ref.read(scheduleRepositoryProvider);
      await scheduleRepo.publishSchedule(current.generatedSchedule!.id);
      state = AsyncData(current.copyWith(isPublishing: false));

      // 팀원 전체에 새 근무 발행 푸시 (관리자 본인 제외, 실패 침묵)
      try {
        final teamRepo = ref.read(teamRepositoryProvider);
        final team = await teamRepo.getTeamById(current.teamId);
        final start = current.periodStart;
        final end = current.periodEnd;
        final period = (start != null && end != null)
            ? '${start.month}/${start.day}~${end.month}/${end.day}'
            : '';
        await PushService.instance.sendToTeam(
          teamId: current.teamId,
          title: '[${team.name}] 새 근무표가 등록되었습니다',
          body: period.isNotEmpty ? '$period 근무표를 확인해주세요' : '신규 근무표를 확인해주세요',
          data: {
            'type': 'schedule_published',
            'team_id': current.teamId,
            'schedule_id': current.generatedSchedule!.id,
            if (start != null)
              'change_date':
                  '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}',
          },
        );
      } catch (_) {}

      return true;
    } catch (e) {
      state = AsyncData(
        current.copyWith(isPublishing: false, error: '발행 중 오류가 발생했습니다: $e'),
      );
      return false;
    }
  }

  /// 초안 삭제
  Future<void> discardDraft() async {
    final current = state.valueOrNull;
    if (current == null || current.generatedSchedule == null) return;

    try {
      final scheduleRepo = ref.read(scheduleRepositoryProvider);
      await scheduleRepo.deleteSchedule(current.generatedSchedule!.id);
      state = AsyncData(
        current.copyWith(
          generatedSchedule: null,
          previewShifts: null,
          validationWarnings: null,
        ),
      );
    } catch (_) {}
  }

  /// 멤버 포함/제외 토글
  void toggleMemberExclusion(String userId) {
    final current = state.valueOrNull;
    if (current == null) return;
    final excluded = List<String>.from(current.excludedMemberIds);
    if (excluded.contains(userId)) {
      excluded.remove(userId);
    } else {
      excluded.add(userId);
    }
    state = AsyncData(current.copyWith(excludedMemberIds: excluded));
  }

  /// 피드백 저장
  Future<void> saveFeedback({
    required int overallRating,
    required Map<String, int> ruleRatings,
    String? notes,
  }) async {
    final current = state.valueOrNull;
    if (current == null || current.generatedSchedule == null) return;

    final feedbackRepo = ref.read(feedbackRepositoryProvider);
    await feedbackRepo.saveFeedback(
      scheduleId: current.generatedSchedule!.id,
      teamId: current.teamId,
      overallRating: overallRating,
      ruleRatings: ruleRatings,
      notes: notes,
    );
  }

  Future<List<WantedEntryModel>> _loadWantedEntriesForPeriod({
    required String teamId,
    required DateTime periodStart,
    required DateTime periodEnd,
    Set<String> currentMemberIds = const {},
  }) async {
    final wantedRepo = ref.read(wantedRepositoryProvider);
    final allRequests = await wantedRepo.getWantedRequests(teamId);

    final requestsForPeriod = allRequests
        .where(
          (r) =>
              _isSameDate(r.periodStart, periodStart) &&
              _isSameDate(r.periodEnd, periodEnd),
        )
        .toList();

    // 구버전 데이터 등으로 요청 메타가 안 맞는 경우 기존 기간 조회로 폴백
    if (requestsForPeriod.isEmpty) {
      return wantedRepo.getEntriesForPeriod(
        teamId: teamId,
        periodStart: periodStart,
        periodEnd: periodEnd,
      );
    }

    const wantedTypes = ['day_off', 'preferred_shift'];
    final selectedRequestIds = <String>{};

    // 원티드 수집 화면과 동일 기준: collecting 우선
    for (final wantedType in wantedTypes) {
      final req = _latestRequestByTypeAndStatus(
        requestsForPeriod,
        wantedType: wantedType,
        status: 'collecting',
      );
      if (req != null) selectedRequestIds.add(req.id);
    }

    // collecting이 없으면 최근 closed 사용
    if (selectedRequestIds.isEmpty) {
      for (final wantedType in wantedTypes) {
        final req = _latestRequestByTypeAndStatus(
          requestsForPeriod,
          wantedType: wantedType,
          status: 'closed',
        );
        if (req != null) selectedRequestIds.add(req.id);
      }
    }

    if (selectedRequestIds.isEmpty) return const [];

    final entries = await wantedRepo.getEntriesByRequestIds(
      selectedRequestIds.toList(),
    );
    entries.sort((a, b) {
      final dateDiff = a.wantedDate.compareTo(b.wantedDate);
      if (dateDiff != 0) return dateDiff;
      final at = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bt = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return at.compareTo(bt);
    });
    // Filter out departed members
    if (currentMemberIds.isEmpty) return entries;
    return entries.where((e) => currentMemberIds.contains(e.userId)).toList();
  }

  WantedRequestModel? _latestRequestByTypeAndStatus(
    List<WantedRequestModel> requests, {
    required String wantedType,
    required String status,
  }) {
    final candidates = requests
        .where((r) => r.wantedType == wantedType && r.status == status)
        .toList();
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) {
      final at = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bt = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bt.compareTo(at);
    });
    return candidates.first;
  }

  bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _dateStr(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  Future<_FeedbackGenerationTuning> _loadFeedbackTuning(String teamId) async {
    try {
      final feedbackRepo = ref.read(feedbackRepositoryProvider);
      final rows = await feedbackRepo.getTeamFeedback(
        teamId: teamId,
        limit: 20,
      );
      if (rows.isEmpty) return const _FeedbackGenerationTuning();

      double wantedSignal = 0;
      double patternSignal = 0;
      double skillSignal = 0;
      double totalWeight = 0;

      for (var i = 0; i < rows.length; i++) {
        final row = rows[i];
        final recencyWeight = pow(0.86, i).toDouble();
        final overallNeed =
            3 - ((row['overall_rating'] as num?)?.toDouble() ?? 3); // -2 ~ +2
        final ratingRaw = row['rule_ratings'];
        final ratings = ratingRaw is Map
            ? Map<String, dynamic>.from(ratingRaw)
            : const <String, dynamic>{};

        int getRuleScore(String key) => (ratings[key] as num?)?.toInt() ?? 0;

        wantedSignal +=
            recencyWeight * ((-getRuleScore('wanted')) + (overallNeed * 0.35));
        patternSignal +=
            recencyWeight *
            ((-getRuleScore('avoid_pattern')) + (overallNeed * 0.35));
        skillSignal +=
            recencyWeight *
            ((-getRuleScore('skill_balance')) + (overallNeed * 0.35));
        totalWeight += recencyWeight;
      }

      if (totalWeight <= 0) return const _FeedbackGenerationTuning();

      double toBoost(double signal, {required double strength}) {
        final normalized = signal / totalWeight;
        return (1.0 + normalized * strength).clamp(0.70, 1.40).toDouble();
      }

      return _FeedbackGenerationTuning(
        wantedBoost: toBoost(wantedSignal, strength: 0.22),
        patternPenaltyBoost: toBoost(patternSignal, strength: 0.18),
        skillBalanceBoost: toBoost(skillSignal, strength: 0.18),
        feedbackCount: rows.length,
      );
    } catch (_) {
      return const _FeedbackGenerationTuning();
    }
  }

  double _generationObjective({
    required _GenerationResult result,
    required _FeedbackGenerationTuning tuning,
  }) {
    final wantedRatio = result.wantedTotal > 0
        ? result.wantedSatisfied / result.wantedTotal
        : 1.0;

    final patternViolations =
        (result.softViolations['NOD']?.length ?? 0) +
        (result.softViolations['NOOD']?.length ?? 0) +
        (result.softViolations['NOE']?.length ?? 0) +
        (result.softViolations['EOD']?.length ?? 0);
    final skillViolations = result.softViolations['신규단독']?.length ?? 0;

    final wantedScore = wantedRatio * (250 * tuning.wantedBoost);
    final understaffPenalty = result.understaffedCount * 1000;
    final warningPenalty = result.warnings.length * 80;
    final patternPenalty =
        patternViolations * (35 * tuning.patternPenaltyBoost);
    final skillPenalty = skillViolations * (45 * tuning.skillBalanceBoost);

    return wantedScore -
        understaffPenalty -
        warningPenalty -
        patternPenalty -
        skillPenalty;
  }

  /// AI 위반 분석 (Edge Function 호출)
  Future<void> analyzeViolations(String teamName) async {
    final current = state.valueOrNull;
    if (current == null) return;

    state = AsyncData(current.copyWith(isAnalyzing: true, aiAnalysis: null));

    try {
      final client = ref.read(supabaseClientProvider);

      // 활성 규칙 요약 (사람이 읽을 수 있는 형태)
      const ruleLabels = {
        'nod_disabled': 'NOD(나이트→오프→데이) 금지',
        'avoid_nood': 'NOOD(나이트→오프×2→데이) 기피',
        'avoid_noe': 'NOE(나이트→오프→이브닝) 기피',
        'avoid_eod': 'EOD(이브닝→오프→데이) 기피',
        'no_night_then_evening': 'N→E 금지',
        'no_evening_then_day': 'E→D 금지',
        'consider_skill_level': '숙련도 균형 배치',
        'max_consecutive_work_days': '최대 연속 근무일 제한',
        'max_monthly_shifts': '월 최대 근무 횟수 제한',
        'max_monthly_night_shifts': '월 최대 야간 횟수 제한',
        'max_consecutive_night_shifts': '최대 연속 야간 제한',
        'min_weekly_off_days': '주 최소 오프일 보장',
        'min_staffing': '근무 유형별 최소 인원',
      };
      final activeRules = current.rules
          .where((r) {
            final enabled = r.ruleValue['enabled'];
            return enabled == null || enabled == true;
          })
          .map((r) => ruleLabels[r.ruleType] ?? r.ruleType)
          .toList();

      // ── 공통 헬퍼 ──
      final shifts = current.previewShifts ?? [];

      String dateFmt(DateTime d) =>
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

      String mName(String uid) => current.members
          .firstWhere(
            (m) => m.userId == uid,
            orElse: () => current.members.first,
          )
          .displayName;

      String? shiftCodeFor(String shiftTypeId) {
        final st = current.shiftTypes
            .where((t) => t.id == shiftTypeId)
            .firstOrNull;
        if (st == null) return null;
        if (st.code.toUpperCase() == 'N' ||
            st.name.contains('나이트') ||
            st.name.contains('야간'))
          return 'N';
        if (st.code.toUpperCase() == 'E' ||
            st.name.contains('이브닝') ||
            st.name.contains('저녁'))
          return 'E';
        if (st.code.toUpperCase() == 'D' ||
            st.name.contains('데이') ||
            st.name.contains('주간'))
          return 'D';
        return st.code.toUpperCase();
      }

      // ── 하드 위반: 알고리즘 warnings 전부 포함 ──
      final hardViolations = List<String>.from(
        current.validationWarnings ?? [],
      );

      // ── 하드 위반: 멤버 속성 사후 검증 ──
      for (final m in current.members) {
        final uid = m.userId;
        if (m.member.nightExempt) {
          final hasN = shifts.any(
            (s) => s.userId == uid && shiftCodeFor(s.shiftTypeId) == 'N',
          );
          if (hasN) hardViolations.add('${m.displayName}: 야간제외 멤버에게 나이트 배정됨');
        }
        if (m.member.dayOnly) {
          // 교육 등 D/E/N 외 근무는 위반 제외 — E·N 배정만 위반으로 간주
          final hasEveningOrNight = shifts.any((s) {
            final code = shiftCodeFor(s.shiftTypeId);
            return s.userId == uid && (code == 'E' || code == 'N');
          });
          if (hasEveningOrNight)
            hardViolations.add('${m.displayName}: 데이전용 멤버에게 비데이 배정됨');
        }
        if (m.member.nightDedicated) {
          // 교육 등 D/E/N 외 근무는 위반 제외 — D·E 배정만 위반으로 간주
          final hasDayOrEvening = shifts.any((s) {
            final code = shiftCodeFor(s.shiftTypeId);
            return s.userId == uid && (code == 'D' || code == 'E');
          });
          if (hasDayOrEvening)
            hardViolations.add('${m.displayName}: 나이트전담 멤버에게 비나이트 배정됨');
        }
      }

      // ── 하드 위반: 시퀀스 룰 사후 검증 ──
      {
        final shiftsByMember = <String, List<ShiftModel>>{};
        for (final s in shifts) {
          shiftsByMember.putIfAbsent(s.userId, () => []).add(s);
        }
        for (final entry in shiftsByMember.entries) {
          final uid = entry.key;
          final sorted = entry.value
            ..sort((a, b) => a.shiftDate.compareTo(b.shiftDate));
          final dateCode = <DateTime, String>{};
          for (final s in sorted) {
            final c = shiftCodeFor(s.shiftTypeId);
            if (c != null) dateCode[s.shiftDate] = c;
          }
          for (final s in sorted) {
            final code = shiftCodeFor(s.shiftTypeId);
            if (code == null) continue;
            final d = s.shiftDate;
            final prev1 = dateCode[d.subtract(const Duration(days: 1))];
            final prev2 = dateCode[d.subtract(const Duration(days: 2))];
            // N→D
            if (code == 'D' && prev1 == 'N') {
              hardViolations.add(
                '${mName(uid)}: N→D 시퀀스 위반 (${dateFmt(d.subtract(const Duration(days: 1)))}나이트→${dateFmt(d)}데이)',
              );
            }
            // NOD: 2일전=N, 어제=Off(없음), 오늘=D
            if (code == 'D' && prev1 == null && prev2 == 'N') {
              hardViolations.add(
                '${mName(uid)}: NOD 패턴 위반 (${dateFmt(d.subtract(const Duration(days: 2)))}나이트→오프→${dateFmt(d)}데이)',
              );
            }
          }
        }
      }

      // ── 커스텀 룰 위반 감지 (이미 generate()에서 계산됨) ──
      final customRuleViolations = current.customRuleViolations;

      // 특별 속성 멤버 (속성이 있는 멤버만 포함하여 토큰 절약)
      final members = current.members
          .map((m) {
            final attrs = <String>[];
            if (m.member.nightDedicated) attrs.add('나이트전담');
            if (m.member.nightExempt) attrs.add('야간제외');
            if (m.member.dayOnly) attrs.add('데이전용');
            return {'name': m.displayName, 'attributes': attrs};
          })
          .where((m) => (m['attributes'] as List).isNotEmpty)
          .toList();

      // ── 전체 근무 배정표 (compact) ──
      // { memberName: { "YYYY-MM-DD": "D"|"E"|"N"|"O" } }
      final memberScheduleMap = <String, Map<String, String>>{};
      for (final m in current.members) {
        memberScheduleMap[m.displayName] = {};
      }
      for (final s in shifts) {
        final m = current.members
            .where((m) => m.userId == s.userId)
            .firstOrNull;
        if (m == null) continue;
        final code = shiftCodeFor(s.shiftTypeId) ?? 'O';
        memberScheduleMap[m.displayName]![dateFmt(s.shiftDate)] = code;
      }

      // ── 활성 하드룰 목록 (AI 검증용) ──
      final ruleMap = {for (final r in current.rules) r.ruleType: r.ruleValue};
      final hardRuleLines = <String>[];
      hardRuleLines.add('N→D 금지: 나이트 다음날 데이 배정 불가');
      if ((ruleMap['nod_disabled']?['enabled'] as bool?) ?? true) {
        hardRuleLines.add('NOD 금지: 나이트→오프→데이 패턴 불가');
      }
      if ((ruleMap['no_night_then_evening']?['enabled'] as bool?) ?? false) {
        hardRuleLines.add('N→E 금지: 나이트 다음날 이브닝 불가');
      }
      if ((ruleMap['no_evening_then_day']?['enabled'] as bool?) ?? true) {
        hardRuleLines.add('E→D 금지: 이브닝 다음날 데이 불가');
      }
      final maxConsec = ruleMap['max_consecutive_work_days']?['days'];
      if (maxConsec != null) {
        hardRuleLines.add('최대 $maxConsec일 연속 근무');
      }
      for (final cr in current.customRules.where(
        (r) => r.isActive && r.priority == 'hard',
      )) {
        hardRuleLines.add('커스텀(하드): ${cr.originalText}');
      }

      // ── 자유형(freeform) 규칙: 스케줄링에 자동 반영되지 않으므로
      // AI가 적용 방안을 제안하도록 별도 전달 ──
      final freeformRules = current.customRules
          .where((r) => r.isActive && r.ruleType == 'freeform')
          .map((r) => r.originalText)
          .toList();

      final periodLabel =
          current.periodStart != null && current.periodEnd != null
          ? '${current.periodStart!.year}년 ${current.periodStart!.month}월 ${current.periodStart!.day}일 ~ ${current.periodEnd!.month}월 ${current.periodEnd!.day}일'
          : current.periodStart != null
          ? '${current.periodStart!.year}년 ${current.periodStart!.month}월'
          : '기간 미지정';

      final response = await client.functions.invoke(
        'schedule-analyze',
        body: {
          'teamName': teamName,
          'periodLabel': periodLabel,
          'hardViolations': hardViolations,
          'understaffedCount': current.understaffedCount,
          'wantedTotal': current.wantedTotal,
          'wantedSatisfied': current.wantedSatisfied,
          'softViolations': current.softViolations.map(
            (k, v) => MapEntry(k, v.length),
          ),
          'customRuleViolations': customRuleViolations,
          'members': members,
          'activeRules': activeRules,
          'memberSchedules': memberScheduleMap,
          'hardRules': hardRuleLines,
          'freeformRules': freeformRules,
        },
      );

      final analysis =
          (response.data as Map<String, dynamic>)['analysis'] as String? ??
          '분석 결과를 가져올 수 없습니다.';

      state = AsyncData(
        current.copyWith(isAnalyzing: false, aiAnalysis: analysis),
      );
    } catch (e) {
      state = AsyncData(
        current.copyWith(
          isAnalyzing: false,
          aiAnalysis: 'AI 분석 중 오류가 발생했습니다: $e',
        ),
      );
    }
  }
}
