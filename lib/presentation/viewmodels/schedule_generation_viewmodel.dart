import 'dart:math';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
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
import 'package:moniq/data/providers/shift_providers.dart';
import 'package:moniq/data/providers/supabase_providers.dart';
import 'package:moniq/data/providers/team_providers.dart';
import 'package:moniq/data/providers/wanted_providers.dart';

part 'schedule_generation_viewmodel.freezed.dart';

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
    @Default({}) Map<String, List<String>> softViolations, // {'NOD':['홍길동 05-03',...], ...}
    @Default([]) List<String> wantedUnsatisfied, // ['홍길동 05-10 (휴무 요청)', ...]
    @Default([]) List<String> customRuleViolations,
    @Default(false) bool isAnalyzing,
    String? aiAnalysis,
    String? error,
  }) = _ScheduleGenerationState;
}

final scheduleGenerationViewModelProvider = AsyncNotifierProvider.family<
    ScheduleGenerationViewModel, ScheduleGenerationState, String>(
  ScheduleGenerationViewModel.new,
);

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
      customRules = await ref.read(customRuleRepositoryProvider).fetchRules(teamId);
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
      final wantedRepo = ref.watch(wantedRepositoryProvider);
      wantedEntries = await wantedRepo.getEntriesForPeriod(
        teamId: teamId,
        periodStart: nextMonth,
        periodEnd: nextMonthEnd,
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

  void setPeriod(DateTime start, DateTime end) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(periodStart: start, periodEnd: end));
  }

  /// 스케줄 자동 생성
  Future<void> generate() async {
    final current = state.valueOrNull;
    if (current == null) return;
    if (current.periodStart == null || current.periodEnd == null) return;

    state = AsyncData(current.copyWith(isGenerating: true, error: null));

    try {
      final scheduleRepo = ref.read(scheduleRepositoryProvider);

      // 1. 스케줄 레코드 생성
      final schedule = await scheduleRepo.createSchedule(
        teamId: current.teamId,
        periodStart: current.periodStart!,
        periodEnd: current.periodEnd!,
      );

      // 2. 자동 배정 알고리즘 실행 (희망 휴무 반영, 제외된 멤버 필터)
      final activeMembers = current.members
          .where((m) => !current.excludedMemberIds.contains(m.userId))
          .toList();
      // 2. 자동 배정 알고리즘 실행 (희망 휴무 반영)
      final result = _generateShifts(
        members: activeMembers,
        shiftTypes: current.shiftTypes,
        rules: current.rules,
        customRules: current.customRules,
        start: current.periodStart!,
        end: current.periodEnd!,
        scheduleId: schedule.id,
        teamId: current.teamId,
        wantedEntries: current.wantedEntries,
      );

      // 3. shifts 삽입
      await scheduleRepo.insertShifts(result.shifts);

      // 4. 미리보기 조회
      final previewShifts =
          await scheduleRepo.getShiftsBySchedule(schedule.id);

      final stateAfterGen = current.copyWith(
        isGenerating: false,
        generatedSchedule: schedule,
        previewShifts: previewShifts,
        validationWarnings: result.warnings,
        understaffedCount: result.understaffedCount,
        wantedTotal: result.wantedTotal,
        wantedSatisfied: result.wantedSatisfied,
        softViolations: result.softViolations,
        wantedUnsatisfied: result.wantedUnsatisfied,
        customRuleViolations: [],
      );
      final customViolations = _computeCustomRuleViolations(stateAfterGen);
      state = AsyncData(stateAfterGen.copyWith(
        customRuleViolations: customViolations,
      ));
    } catch (e) {
      state = AsyncData(current.copyWith(
        isGenerating: false,
        error: '스케줄 생성 중 오류가 발생했습니다: $e',
      ));
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
      return true;
    } catch (e) {
      state = AsyncData(current.copyWith(
        isPublishing: false,
        error: '발행 중 오류가 발생했습니다: $e',
      ));
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
      state = AsyncData(current.copyWith(
        generatedSchedule: null,
        previewShifts: null,
        validationWarnings: null,
      ));
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

      String mName(String uid) =>
          current.members.firstWhere((m) => m.userId == uid,
              orElse: () => current.members.first).displayName;

      String? shiftCodeFor(String shiftTypeId) {
        final st = current.shiftTypes.where((t) => t.id == shiftTypeId).firstOrNull;
        if (st == null) return null;
        if (st.code.toUpperCase() == 'N' || st.name.contains('나이트') || st.name.contains('야간')) return 'N';
        if (st.code.toUpperCase() == 'E' || st.name.contains('이브닝') || st.name.contains('저녁')) return 'E';
        if (st.code.toUpperCase() == 'D' || st.name.contains('데이') || st.name.contains('주간')) return 'D';
        return st.code.toUpperCase();
      }

      // ── 하드 위반: 알고리즘 warnings 전부 포함 ──
      final hardViolations = List<String>.from(current.validationWarnings ?? []);

      // ── 하드 위반: 멤버 속성 사후 검증 ──
      for (final m in current.members) {
        final uid = m.userId;
        if (m.member.nightExempt) {
          final hasN = shifts.any((s) => s.userId == uid && shiftCodeFor(s.shiftTypeId) == 'N');
          if (hasN) hardViolations.add('${m.displayName}: 야간제외 멤버에게 나이트 배정됨');
        }
        if (m.member.dayOnly) {
          final hasNonD = shifts.any((s) => s.userId == uid && shiftCodeFor(s.shiftTypeId) != 'D');
          if (hasNonD) hardViolations.add('${m.displayName}: 데이전용 멤버에게 비데이 배정됨');
        }
        if (m.member.nightDedicated) {
          final hasNonN = shifts.any((s) => s.userId == uid && shiftCodeFor(s.shiftTypeId) != 'N');
          if (hasNonN) hardViolations.add('${m.displayName}: 나이트전담 멤버에게 비나이트 배정됨');
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
          final sorted = entry.value..sort((a, b) => a.shiftDate.compareTo(b.shiftDate));
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
              hardViolations.add('${mName(uid)}: N→D 시퀀스 위반 (${dateFmt(d.subtract(const Duration(days: 1)))}나이트→${dateFmt(d)}데이)');
            }
            // NOD: 2일전=N, 어제=Off(없음), 오늘=D
            if (code == 'D' && prev1 == null && prev2 == 'N') {
              hardViolations.add('${mName(uid)}: NOD 패턴 위반 (${dateFmt(d.subtract(const Duration(days: 2)))}나이트→오프→${dateFmt(d)}데이)');
            }
          }
        }
      }

      // ── 커스텀 룰 위반 감지 (이미 generate()에서 계산됨) ──
      final customRuleViolations = current.customRuleViolations;

      // 특별 속성 멤버
      final members = current.members.map((m) {
        final attrs = <String>[];
        if (m.member.nightDedicated) attrs.add('나이트전담');
        if (m.member.nightExempt) attrs.add('야간제외');
        if (m.member.dayOnly) attrs.add('데이전용');
        return {'name': m.displayName, 'attributes': attrs};
      }).toList();

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
      final ruleMap = {
        for (final r in current.rules) r.ruleType: r.ruleValue,
      };
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
      for (final cr in current.customRules.where((r) => r.isActive && r.priority == 'hard')) {
        hardRuleLines.add('커스텀(하드): ${cr.originalText}');
      }

      final periodLabel = current.periodStart != null
          ? '${current.periodStart!.year}년 ${current.periodStart!.month}월'
          : '';

      final response = await client.functions.invoke(
        'schedule-analyze',
        body: {
          'teamName': teamName,
          'periodLabel': periodLabel,
          'hardViolations': hardViolations,
          'understaffedCount': current.understaffedCount,
          'wantedTotal': current.wantedTotal,
          'wantedSatisfied': current.wantedSatisfied,
          'softViolations': current.softViolations.map((k, v) => MapEntry(k, v.length)),
          'customRuleViolations': customRuleViolations,
          'members': members,
          'activeRules': activeRules,
          'memberSchedules': memberScheduleMap,
          'hardRules': hardRuleLines,
        },
      );

      final analysis = (response.data as Map<String, dynamic>)['analysis']
          as String? ??
          '분석 결과를 가져올 수 없습니다.';

      state = AsyncData(
        current.copyWith(isAnalyzing: false, aiAnalysis: analysis),
      );
    } catch (e) {
      state = AsyncData(
        current.copyWith(
          isAnalyzing: false,
          aiAnalysis: 'AI 분석 중 오류가 발생했습니다.',
        ),
      );
    }
  }

  /// 커스텀 룰 위반 감지 (generate 완료 후 즉시 호출)
  List<String> _computeCustomRuleViolations(ScheduleGenerationState s) {
    final shifts = s.previewShifts ?? [];
    final violations = <String>[];

    String dateFmt(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    String mName(String uid) =>
        s.members.firstWhere((m) => m.userId == uid,
            orElse: () => s.members.first).displayName;

    String? shiftCodeFor(String shiftTypeId) {
      final st = s.shiftTypes.where((t) => t.id == shiftTypeId).firstOrNull;
      if (st == null) return null;
      if (st.code.toUpperCase() == 'N' || st.name.contains('나이트') || st.name.contains('야간')) return 'N';
      if (st.code.toUpperCase() == 'E' || st.name.contains('이브닝') || st.name.contains('저녁')) return 'E';
      if (st.code.toUpperCase() == 'D' || st.name.contains('데이') || st.name.contains('주간')) return 'D';
      return st.code.toUpperCase();
    }

    for (final rule in s.customRules.where((r) => r.isActive)) {
      final rv = rule.ruleValue;
      switch (rule.ruleType) {
        case 'member_shift_ban':
          final uid = rv['member_id'] as String?;
          final code = (rv['shift_code'] as String?)?.toUpperCase();
          if (uid == null || code == null) break;
          final banViolDates = shifts
              .where((sh) => sh.userId == uid && shiftCodeFor(sh.shiftTypeId) == code)
              .map((sh) => dateFmt(sh.shiftDate).substring(5))
              .toList()..sort();
          if (banViolDates.isNotEmpty) {
            violations.add('근무 금지 위반: ${mName(uid)}에게 $code 배정됨 → ${banViolDates.join(', ')} ("${rule.originalText}")');
          }

        case 'anti_pair':
          final uidA = rv['member_id_a'] as String?;
          final uidB = rv['member_id_b'] as String?;
          final code = (rv['shift_code'] as String?)?.toUpperCase();
          if (uidA == null || uidB == null) break;
          final assignedA = {for (final sh in shifts.where((sh) => sh.userId == uidA)) dateFmt(sh.shiftDate): sh.shiftTypeId};
          final assignedB = {for (final sh in shifts.where((sh) => sh.userId == uidB)) dateFmt(sh.shiftDate): sh.shiftTypeId};
          final conflictEntries = assignedA.entries.where((e) {
            if (assignedB[e.key] != e.value) return false;
            if (code != null && shiftCodeFor(e.value) != code) return false;
            return true;
          }).toList()..sort((a, b) => a.key.compareTo(b.key));
          if (conflictEntries.isNotEmpty) {
            final dates = conflictEntries.map((e) => e.key.substring(5)).join(', '); // MM-DD
            violations.add('동시 배정 금지 위반: ${mName(uidA)}, ${mName(uidB)} → ${conflictEntries.length}일 (${dates}) ("${rule.originalText}")');
          }

        case 'require_pair':
          final uidA = rv['member_id_a'] as String?;
          final uidB = rv['member_id_b'] as String?;
          final code = (rv['shift_code'] as String?)?.toUpperCase();
          if (uidA == null || uidB == null) break;
          final assignedA = {for (final sh in shifts.where((sh) => sh.userId == uidA)) dateFmt(sh.shiftDate): sh.shiftTypeId};
          final assignedB = {for (final sh in shifts.where((sh) => sh.userId == uidB)) dateFmt(sh.shiftDate): sh.shiftTypeId};
          final missEntries = assignedA.entries.where((e) {
            if (code != null && shiftCodeFor(e.value) != code) return false;
            return assignedB[e.key] != e.value;
          }).toList()..sort((a, b) => a.key.compareTo(b.key));
          if (missEntries.isNotEmpty) {
            final dates = missEntries.map((e) => e.key.substring(5)).join(', ');
            violations.add('함께 배정 미충족: ${mName(uidA)}, ${mName(uidB)} → ${missEntries.length}일 (${dates}) ("${rule.originalText}")');
          }

        case 'date_off':
          final uid = rv['member_id'] as String?;
          final dates = (rv['dates'] as List?)?.cast<String>() ?? [];
          if (uid == null || dates.isEmpty) break;
          final violated = dates.where((d) => shifts.any((sh) => sh.userId == uid && dateFmt(sh.shiftDate) == d)).toList();
          if (violated.isNotEmpty) {
            violations.add('날짜 오프 위반: ${mName(uid)}이 ${violated.join(', ')} 근무 배정 ("${rule.originalText}")');
          }

        case 'skill_balance':
          final filterCode = (rv['shift_code'] as String?)?.toUpperCase();
          // 날짜 × 근무유형 순회
          final dateSet = shifts.map((sh) => dateFmt(sh.shiftDate)).toSet().toList()..sort();
          for (final dStr in dateSet) {
            for (final st in s.shiftTypes) {
              // D/E/N으로 인식되는 타입만 체크
              final bool isD = st.code.toUpperCase() == 'D' || st.name.contains('데이') || st.name.contains('주간');
              final bool isE = st.code.toUpperCase() == 'E' || st.name.contains('이브닝') || st.name.contains('저녁');
              final bool isN = st.code.toUpperCase() == 'N' || st.name.contains('나이트') || st.name.contains('야간');
              if (!isD && !isE && !isN) continue;

              String? stCode = isN ? 'N' : isE ? 'E' : 'D';

              if (filterCode != null && filterCode != stCode) continue;

              final dayShiftUids = shifts
                  .where((sh) => dateFmt(sh.shiftDate) == dStr && sh.shiftTypeId == st.id)
                  .map((sh) => sh.userId)
                  .toList();
              if (dayShiftUids.isEmpty) continue;

              final dayMembers = dayShiftUids.map((uid) =>
                  s.members.firstWhere((m) => m.userId == uid,
                      orElse: () => s.members.first)).toList();

              // 숙련도 미설정 멤버 있으면 판단 불가 → 건너뜀
              if (dayMembers.any((m) => m.member.skillLevel == null)) continue;

              final hasJunior = dayMembers.any((m) => m.member.skillLevel == 'junior');
              final hasSeniorOrMid = dayMembers.any((m) =>
                  m.member.skillLevel == 'senior' || m.member.skillLevel == 'mid');

              if (hasJunior && !hasSeniorOrMid) {
                violations.add(
                  '숙련도 불균형: $dStr ${st.name} 근무에 신규만 배정되고 올드/중간 없음 ("${rule.originalText}")',
                );
              }
            }
          }
      }
    }

    return violations;
  }

  /// 스케줄 생성 알고리즘 (하드 제약 + 소프트 스코어링)
  _GenerationResult _generateShifts({
    required List<TeamMemberWithUser> members,
    required List<ShiftTypeModel> shiftTypes,
    required List<ShiftRuleModel> rules,
    List<CustomRuleModel> customRules = const [],
    required DateTime start,
    required DateTime end,
    required String scheduleId,
    required String teamId,
    List<WantedEntryModel> wantedEntries = const [],
  }) {
    final shifts = <Map<String, dynamic>>[];
    final warnings = <String>[];
    final understaffedDays = <String>{};
    final random = Random(42);

    if (members.isEmpty) {
      warnings.add('팀 멤버가 없습니다');
      return _GenerationResult(shifts: shifts, warnings: warnings);
    }
    if (shiftTypes.isEmpty) {
      warnings.add('근무 유형이 설정되지 않았습니다');
      return _GenerationResult(shifts: shifts, warnings: warnings);
    }

    // ── 규칙 파싱 ──
    final ruleMap = {for (final r in rules) r.ruleType: r.ruleValue};

    final maxConsecutiveDays =
        (ruleMap['max_consecutive_work_days']?['days'] as num?)?.toInt() ?? 5;
    final maxMonthlyShifts =
        (ruleMap['max_monthly_shifts']?['count'] as num?)?.toInt() ?? 25;
    final maxMonthlyNightShifts =
        (ruleMap['max_monthly_night_shifts']?['count'] as num?)?.toInt() ?? 8;
    final maxConsecutiveNights =
        (ruleMap['max_consecutive_night_shifts']?['days'] as num?)?.toInt() ?? 3;
    final minWeeklyOffDays =
        (ruleMap['min_weekly_off_days']?['days'] as num?)?.toInt() ?? 2;

    // 근무 유형별 최소 인원
    final minStaffing = <String, int>{};
    final rawCounts = (ruleMap['min_staffing']?['counts'] as Map?) ?? {};
    for (final e in rawCounts.entries) {
      minStaffing[e.key as String] = (e.value as num?)?.toInt() ?? 0;
    }

    // 하드 패턴 금지
    const noNightThenDay = true; // 시간상 항상 불가
    final noNightThenEvening =
        (ruleMap['no_night_then_evening']?['enabled'] as bool?) ?? false;
    final noEveningThenDay =
        (ruleMap['no_evening_then_day']?['enabled'] as bool?) ?? true;
    final nodDisabled =
        (ruleMap['nod_disabled']?['enabled'] as bool?) ?? true;

    // 소프트 기피 패턴
    final avoidNood = (ruleMap['avoid_nood']?['enabled'] as bool?) ?? true;
    final avoidNoe = (ruleMap['avoid_noe']?['enabled'] as bool?) ?? false;
    final avoidEod = (ruleMap['avoid_eod']?['enabled'] as bool?) ?? false;

    // 소프트: 숙련도 배치 고려
    final considerSkill =
        (ruleMap['consider_skill_level']?['enabled'] as bool?) ?? false;

    // ── 커스텀 규칙 파싱 (활성화된 것만) ──
    final activeCustomRules =
        customRules.where((r) => r.isActive).toList();

    // member_shift_ban: { member_id, shift_code }
    // userId → set of banned shift codes
    final memberShiftBans = <String, Set<String>>{};
    for (final r in activeCustomRules.where((r) => r.ruleType == 'member_shift_ban')) {
      final memberId = r.ruleValue['member_id'] as String?;
      final shiftCode = (r.ruleValue['shift_code'] as String?)?.toUpperCase();
      if (memberId != null && shiftCode != null) {
        memberShiftBans.putIfAbsent(memberId, () => {}).add(shiftCode);
      }
    }

    // anti_pair: { member_id_a, member_id_b, shift_code? }
    // If both members are eligible for the same shift on the same day,
    // block the later-processed one when the first is already assigned.
    final antiPairs = activeCustomRules
        .where((r) => r.ruleType == 'anti_pair' && r.priority == 'hard')
        .map((r) => (
              a: r.ruleValue['member_id_a'] as String? ?? '',
              b: r.ruleValue['member_id_b'] as String? ?? '',
              code: (r.ruleValue['shift_code'] as String?)?.toUpperCase(),
            ))
        .where((p) => p.a.isNotEmpty && p.b.isNotEmpty)
        .toList();
    final softAntiPairs = activeCustomRules
        .where((r) => r.ruleType == 'anti_pair' && r.priority == 'soft')
        .map((r) => (
              a: r.ruleValue['member_id_a'] as String? ?? '',
              b: r.ruleValue['member_id_b'] as String? ?? '',
              code: (r.ruleValue['shift_code'] as String?)?.toUpperCase(),
            ))
        .where((p) => p.a.isNotEmpty && p.b.isNotEmpty)
        .toList();

    // require_pair: { member_id_a, member_id_b, shift_code? } — soft bonus
    final requirePairs = activeCustomRules
        .where((r) => r.ruleType == 'require_pair')
        .map((r) => (
              a: r.ruleValue['member_id_a'] as String? ?? '',
              b: r.ruleValue['member_id_b'] as String? ?? '',
              code: (r.ruleValue['shift_code'] as String?)?.toUpperCase(),
            ))
        .where((p) => p.a.isNotEmpty && p.b.isNotEmpty)
        .toList();

    // date_off: { member_id, dates: [YYYY-MM-DD, ...] }
    // userId → set of forced-off dates
    final forcedOffDates = <String, Set<String>>{};
    for (final r in activeCustomRules.where((r) => r.ruleType == 'date_off')) {
      final memberId = r.ruleValue['member_id'] as String?;
      final dates = (r.ruleValue['dates'] as List?)?.cast<String>() ?? [];
      if (memberId != null && dates.isNotEmpty) {
        forcedOffDates.putIfAbsent(memberId, () => {}).addAll(dates);
      }
    }

    // post_night_off: { consecutive_nights, min_off_days }
    // Applied per-member: once consecutive nights reached, add mandatory off gap
    final postNightOffRules = activeCustomRules
        .where((r) => r.ruleType == 'post_night_off')
        .map((r) => (
              consecutiveNights:
                  (r.ruleValue['consecutive_nights'] as num?)?.toInt() ?? 3,
              minOffDays:
                  (r.ruleValue['min_off_days'] as num?)?.toInt() ?? 2,
            ))
        .toList();

    // skill_condition: { shift_code, min_skill, min_count }
    // Evaluated post-generation as warning only (can't enforce mid-fill)
    final skillConditions = activeCustomRules
        .where((r) => r.ruleType == 'skill_condition')
        .map((r) => (
              shiftCode:
                  (r.ruleValue['shift_code'] as String?)?.toUpperCase() ?? '',
              minSkill: (r.ruleValue['min_skill'] as num?)?.toInt() ?? 1,
              minCount: (r.ruleValue['min_count'] as num?)?.toInt() ?? 1,
            ))
        .where((c) => c.shiftCode.isNotEmpty)
        .toList();

    // skill_balance: { shift_code? }
    // "신규가 있으면 올드 한명은 있어야 한다" — soft/hard 모두 지원
    // hard: 배정 후 위반 시 warning
    // soft: 스코어링으로 유도
    final skillBalanceRules = activeCustomRules
        .where((r) => r.ruleType == 'skill_balance')
        .map((r) => (
              shiftCode: (r.ruleValue['shift_code'] as String?)?.toUpperCase(),
              isHard: r.priority == 'hard',
            ))
        .toList();

    // 소프트: 원티드 우선순위 (1번 인덱스가 최고 우선순위)
    final priorityOrder = List<String>.from(
      (ruleMap['wanted_priority_order']?['order'] as List?) ??
          ['annual_leave', 'night_dedicated', 'fairness_rest', 'fairness_equal'],
    );
    int priorityWeight(String key) {
      final idx = priorityOrder.indexOf(key);
      if (idx < 0) return 0;
      return (priorityOrder.length - idx) * 20; // 1위=80, 2위=60, 3위=40, 4위=20
    }

    // ── 근무유형 분류 헬퍼 ──
    bool isNightType(ShiftTypeModel t) =>
        t.code.toUpperCase() == 'N' ||
        t.name.contains('야간') ||
        t.name.contains('나이트');
    bool isDayType(ShiftTypeModel t) =>
        t.code.toUpperCase() == 'D' ||
        t.name.contains('데이') ||
        t.name.contains('주간');
    bool isEveningType(ShiftTypeModel t) =>
        t.code.toUpperCase() == 'E' ||
        t.name.contains('이브닝') ||
        t.name.contains('저녁');
    // 희망 휴무 날짜 맵 (userId -> Set<dateStr>)
    final wantedDaysOff = <String, Set<String>>{};
    for (final entry in wantedEntries) {
      final dateStr =
          '${entry.wantedDate.year}-${entry.wantedDate.month.toString().padLeft(2, '0')}-${entry.wantedDate.day.toString().padLeft(2, '0')}';
      wantedDaysOff.putIfAbsent(entry.userId, () => {}).add(dateStr);
    }

    // D/E/N으로 인식되는 타입만 포함 (알 수 없는 추가 타입, OFF 타입 제외)
    final workShiftTypes = shiftTypes
        .where((t) => isDayType(t) || isEveningType(t) || isNightType(t))
        .toList();

    // ── 날짜 포맷 ──
    String fmt(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    // ── 희망 휴무 맵 (userId → Set<dateStr>) ──
    final wantedOff = <String, Set<String>>{};
    for (final e in wantedEntries) {
      wantedOff.putIfAbsent(e.userId, () => {}).add(fmt(e.wantedDate));
    }

    // ── 멤버별 상태 ──
    final shiftCount = <String, int>{for (final m in members) m.userId: 0};
    final nightCount = <String, int>{for (final m in members) m.userId: 0};
    final consecutiveWork = <String, int>{for (final m in members) m.userId: 0};
    final consecutiveNight = <String, int>{for (final m in members) m.userId: 0};
    // 최근 7일 근무 날짜 목록 (주간 오프 계산용)
    final recentWorkDates = <String, List<DateTime>>{
      for (final m in members) m.userId: [],
    };
    // 이전 3일 근무 코드: index 0=어제, 1=2일전, 2=3일전
    // NOOD(N→O→O→D) 검사에 3슬롯 필요
    final prevCodes = <String, List<String?>>{
      for (final m in members) m.userId: [null, null, null],
    };
    // 소프트 기피 패턴 위반 상세 (멤버 + 날짜)
    final softViolCounts = <String, List<String>>{
      'NOD': [], 'NOOD': [], 'NOE': [], 'EOD': [], '신규단독': [],
    };
    final lastWorkedDate = <String, DateTime?>{
      for (final m in members) m.userId: null,
    };

    // ── 날짜 순회 ──
    final dayCount = end.difference(start).inDays + 1;

    for (int d = 0; d < dayCount; d++) {
      final date = start.add(Duration(days: d));
      final dateStr = fmt(date);
      // 오늘까지 진행된 비율 (0.0 ~ 1.0)
      final progressRatio = (d + 1) / dayCount;

      for (final shiftType in workShiftTypes) {
        final isNight = isNightType(shiftType);
        final isDay = isDayType(shiftType);
        final isEvening = isEveningType(shiftType);
        final shiftCode = isNight ? 'N' : isEvening ? 'E' : isDay ? 'D' : shiftType.code.toUpperCase();
        final minStaff = max(1, minStaffing[shiftType.id] ?? 1);

        // ── eligible 필터링 (하드 제약) ──
        // 배정 가능한 멤버 필터링 (희망 휴무일 제외)
        final eligible = members.where((m) {
          final uid = m.userId;

          // 오늘 이미 다른 근무에 배정됐으면 제외 (하루 1근무 원칙)
          if (shifts.any((s) => s['user_id'] == uid && s['shift_date'] == dateStr)) {
            return false;
          }

          final prev = lastWorkedDate[uid];
          final isYesterday = prev != null && date.difference(prev).inDays == 1;
          final prevCode0 = prevCodes[uid]![0]; // 어제
          final prevCode1 = prevCodes[uid]![1]; // 2일전

          // 멤버 속성
          if (m.member.nightDedicated && !isNight) return false;
          if (m.member.nightExempt && isNight) return false;
          if (m.member.dayOnly && !isDay) return false;

          final prevCode2 = prevCodes[uid]![2]; // 3일전

          // N→D 항상 금지 (시간상 불가)
          if (noNightThenDay && isDay && isYesterday && prevCode0 == 'N') return false;
          // N→E 금지
          if (noNightThenEvening && isEvening && isYesterday && prevCode0 == 'N') return false;
          // E→D 금지
          if (noEveningThenDay && isDay && isYesterday && prevCode0 == 'E') return false;
          // NOD 하드 금지: 2일전=N, 어제=O, 오늘=D
          if (nodDisabled && isDay && prevCode0 == null && prevCode1 == 'N') return false;
          // NOOD 하드 금지: 3일전=N, 2일전=O, 어제=O, 오늘=D
          // avoidNood가 On이면 하드 규칙으로 격상
          if (avoidNood && isDay && prevCode0 == null && prevCode1 == null && prevCode2 == 'N') return false;

          // 월 최대 근무
          if ((shiftCount[uid] ?? 0) >= maxMonthlyShifts) return false;
          // 월 최대 야간
          if (isNight && (nightCount[uid] ?? 0) >= maxMonthlyNightShifts) return false;
          // 최대 연속 근무일
          if ((consecutiveWork[uid] ?? 0) >= maxConsecutiveDays) return false;
          // 최대 연속 야간
          if (isNight && (consecutiveNight[uid] ?? 0) >= maxConsecutiveNights) return false;

          // 주간 최소 오프: 최근 7일 중 근무일이 (7 - minWeeklyOffDays) 이상이면 오프 필요
          final recentDates = recentWorkDates[uid]!;
          final sevenDaysAgo = date.subtract(const Duration(days: 7));
          final recentCount = recentDates.where((dt) => dt.isAfter(sevenDaysAgo)).length;
          if (recentCount >= 7 - minWeeklyOffDays) return false;

          // 희망 휴무일
          if (wantedOff[uid]?.contains(dateStr) == true) return false;

          // ── 커스텀 하드 룰 ──

          // member_shift_ban: 특정 멤버 특정 근무 금지
          final bannedCodes = memberShiftBans[uid];
          if (bannedCodes != null && bannedCodes.contains(shiftCode)) return false;

          // date_off: 날짜 강제 오프
          if (forcedOffDates[uid]?.contains(dateStr) == true) return false;

          // post_night_off: 나이트 N연속 후 최소 오프 강제
          for (final rule in postNightOffRules) {
            if ((consecutiveNight[uid] ?? 0) >= rule.consecutiveNights) {
              // consecutive nights reached — need minOffDays off
              // block all work shifts until off gap met
              return false;
            }
          }

          // anti_pair (hard): 같은 날 같은 근무에 쌍 배정 금지
          for (final pair in antiPairs) {
            final partner = uid == pair.a
                ? pair.b
                : uid == pair.b
                    ? pair.a
                    : null;
            if (partner == null) continue;
            // shiftCode 제한이 있으면 해당 코드만 체크
            if (pair.code != null && pair.code != shiftCode) continue;
            // 파트너가 오늘 동일 shiftType에 이미 배정됐으면 이 멤버 제외
            final partnerAlreadyAssigned = shifts.any((s) =>
                s['user_id'] == partner &&
                s['shift_date'] == dateStr &&
                s['shift_type_id'] == shiftType.id);
            if (partnerAlreadyAssigned) return false;
          }

          // 희망 휴무일이면 제외
          final userWanted = wantedDaysOff[m.userId];
          if (userWanted != null && userWanted.contains(dateStr)) return false;

          return true;
        }).toList();

        if (eligible.isEmpty) {
          warnings.add('$dateStr ${shiftType.name}: 배정 가능한 멤버가 없습니다');
          continue;
        }

        // ── 소프트 스코어링 ──
        int score(TeamMemberWithUser m) {
          int s = 0;
          final uid = m.userId;
          final prev = lastWorkedDate[uid];
          final isYesterday = prev != null && date.difference(prev).inDays == 1;
          final prevCode0 = prevCodes[uid]![0];
          final prevCode1 = prevCodes[uid]![1];
          final prevCode2 = prevCodes[uid]![2];

          // ── 페이싱 기반 공평 배분 ──
          // 목표값 = 실제 1인당 예상 근무수 (max_monthly_shifts가 아님!)
          // 예: 31일 × 3유형 × 1명 / 멤버10명 = 9.3회
          // max를 쓰면 빈 멤버 부채가 폭발해서 초반 일한 멤버가 한달 내내 밀림.
          final totalSlotsNeeded =
              dayCount * workShiftTypes.length.toDouble();
          final targetPerMember = totalSlotsNeeded / members.length;
          final expectedShifts = targetPerMember * progressRatio;
          final shiftDebt = expectedShifts - (shiftCount[uid] ?? 0);
          s += (shiftDebt * 20).round();

          // 야간 페이싱 균등 (나이트 전용 목표)
          if (isNight) {
            final nightSlots = dayCount * progressRatio;
            final nightTarget = nightSlots / members.length;
            final nightDebt = nightTarget - (nightCount[uid] ?? 0);
            s += (nightDebt * 25).round();
          }

          // ── 생체리듬 흐름 보너스 (D→E→N 순방향 선호) ──
          // D→E: 순방향
          if (isEvening && isYesterday && prevCode0 == 'D') s += 30;
          // E→N: 순방향
          if (isNight && isYesterday && prevCode0 == 'E') s += 30;
          // N→O→E: N 후 하루 쉬고 E (완충)
          if (isEvening && !isYesterday && prevCode0 == null && prevCode1 == 'N') s += 20;

          // 역방향 패널티
          // D→N 직접: E 건너뜀
          if (isNight && isYesterday && prevCode0 == 'D') s -= 35;
          // N→O→D: (NOD 소프트 — 하드는 위에서 차단)
          if (isDay && !isYesterday && prevCode0 == null && prevCode1 == 'N') s -= 50;

          // 나이트 전담 우선순위 보너스
          if (m.member.nightDedicated && isNight) {
            s += priorityWeight('night_dedicated');
          }

          // 숙련도 배치 고려 (나이트 근무에 중급 이상 우선)
          if (considerSkill && isNight) {
            final skill = m.member.skillLevel;
            if (skill == 'mid' || skill == 'senior') s += 30;
          }

          // 소프트 기피 패턴 페널티 (페이싱 보너스 압도할 만큼 강하게)
          // NOE: 2일전=N, 어제=O, 오늘=E  (N→O→E)
          if (avoidNoe && isEvening && prevCode0 == null && prevCode1 == 'N') s -= 150;
          // EOD: 2일전=E, 어제=O, 오늘=D  (E→O→D)
          if (avoidEod && isDay && prevCode0 == null && prevCode1 == 'E') s -= 120;
          // NOOD (하드로 격상했으니 여기는 NOD 소프트 페널티: 2일전=N, 어제=O, 오늘=D)
          if (!avoidNood && isDay && prevCode0 == null && prevCode1 == 'N') s -= 150;
          // NOOE: 3일전=N, 2일전=O, 어제=O, 오늘=E
          if (isEvening && prevCode0 == null && prevCode1 == null && prevCode2 == 'N') s -= 120;

          // ── 커스텀 소프트 룰 ──

          // soft anti_pair: 쌍 배정 기피 패널티
          for (final pair in softAntiPairs) {
            final partner = uid == pair.a
                ? pair.b
                : uid == pair.b
                    ? pair.a
                    : null;
            if (partner == null) continue;
            if (pair.code != null && pair.code != shiftCode) continue;
            final partnerAssigned = shifts.any((s) =>
                s['user_id'] == partner &&
                s['shift_date'] == dateStr &&
                s['shift_type_id'] == shiftType.id);
            if (partnerAssigned) s -= 100;
          }

          // require_pair: 쌍 배정 선호 보너스
          for (final pair in requirePairs) {
            final partner = uid == pair.a
                ? pair.b
                : uid == pair.b
                    ? pair.a
                    : null;
            if (partner == null) continue;
            if (pair.code != null && pair.code != shiftCode) continue;
            final partnerAssigned = shifts.any((s) =>
                s['user_id'] == partner &&
                s['shift_date'] == dateStr &&
                s['shift_type_id'] == shiftType.id);
            if (partnerAssigned) s += 80;
          }

          // ── 기본 소프트: 신규끼리만 같은 근무 방지 ──
          // 신규가 이미 배정된 근무에 또 신규를 배정하면 페널티 (올드 없을 시)
          {
            final alreadyJuniors = shifts.where((sh) =>
                sh['shift_date'] == dateStr &&
                sh['shift_type_id'] == shiftType.id &&
                members.firstWhere(
                  (mm) => mm.userId == sh['user_id'],
                  orElse: () => members.first,
                ).member.skillLevel == 'junior').length;
            final alreadySeniors = shifts.where((sh) =>
                sh['shift_date'] == dateStr &&
                sh['shift_type_id'] == shiftType.id &&
                members.firstWhere(
                  (mm) => mm.userId == sh['user_id'],
                  orElse: () => members.first,
                ).member.skillLevel == 'senior').length;

            if (m.member.skillLevel == 'junior' &&
                alreadyJuniors >= 1 &&
                alreadySeniors == 0) {
              s -= 90; // 신규끼리 뭉치기 방지
            }
            if (m.member.skillLevel == 'senior' && alreadyJuniors >= 1) {
              s += 60; // 신규 있는 근무에 올드 선호
            }
          }

          // ── skill_balance 커스텀 룰 ──
          for (final sr in skillBalanceRules) {
            if (sr.shiftCode != null && sr.shiftCode != shiftCode) continue;
            final alreadyJuniors = shifts.where((sh) =>
                sh['shift_date'] == dateStr &&
                sh['shift_type_id'] == shiftType.id &&
                members.firstWhere(
                  (mm) => mm.userId == sh['user_id'],
                  orElse: () => members.first,
                ).member.skillLevel == 'junior').length;
            final alreadySeniors = shifts.where((sh) =>
                sh['shift_date'] == dateStr &&
                sh['shift_type_id'] == shiftType.id &&
                members.firstWhere(
                  (mm) => mm.userId == sh['user_id'],
                  orElse: () => members.first,
                ).member.skillLevel == 'senior').length;
            // 신규 있고 올드 없으면 올드에 강한 보너스
            if (m.member.skillLevel == 'senior' &&
                alreadyJuniors >= 1 &&
                alreadySeniors == 0) {
              s += 120;
            }
            // 신규가 있고 올드도 없는데 또 신규 배정 시 강한 페널티
            if (m.member.skillLevel == 'junior' &&
                alreadyJuniors >= 1 &&
                alreadySeniors == 0) {
              s -= 130;
            }
          }

          return s;
        }

        eligible.sort((a, b) {
          final diff = score(b).compareTo(score(a)); // 높은 점수 우선
          return diff != 0 ? diff : (random.nextBool() ? 1 : -1);
        });

        final assignCount = min(minStaff, eligible.length);
        for (int i = 0; i < assignCount; i++) {
          final m = eligible[i];
          final uid = m.userId;

          shifts.add({
            'schedule_id': scheduleId,
            'team_id': teamId,
            'user_id': uid,
            'shift_date': dateStr,
            'shift_type_id': shiftType.id,
          });

          shiftCount[uid] = (shiftCount[uid] ?? 0) + 1;
          if (isNight) {
            nightCount[uid] = (nightCount[uid] ?? 0) + 1;
            consecutiveNight[uid] = (consecutiveNight[uid] ?? 0) + 1;
          } else {
            consecutiveNight[uid] = 0;
          }
          final prevDate = lastWorkedDate[uid];
          if (prevDate != null && date.difference(prevDate).inDays == 1) {
            consecutiveWork[uid] = (consecutiveWork[uid] ?? 0) + 1;
          } else {
            consecutiveWork[uid] = 1;
          }
          lastWorkedDate[uid] = date;
          recentWorkDates[uid]!.add(date);

          // prevCodes는 날짜 루프 끝에서 한 번만 슬라이딩 (shiftType별 X)
        }

        if (assignCount < minStaff) {
          warnings.add(
            '$dateStr ${shiftType.name}: 최소 인원($minStaff명) 미충족 — $assignCount명 배정',
          );
          understaffedDays.add(dateStr);
        }
      }

      // ── 하루 끝: prevCodes 슬라이딩 (날짜당 1회, 모든 멤버) ──
      // 버그 수정: 이전엔 오프 멤버만 처리. 이제 모든 멤버 업데이트.
      for (final m in members) {
        final uid = m.userId;
        final todayShift = shifts.lastWhere(
          (s) => s['user_id'] == uid && s['shift_date'] == dateStr,
          orElse: () => {},
        );
        String? todayCode;
        if (todayShift.isNotEmpty) {
          final assignedType = shiftTypes.firstWhere(
            (t) => t.id == todayShift['shift_type_id'],
            orElse: () => shiftTypes.first,
          );
          todayCode = isNightType(assignedType)
              ? 'N'
              : isEveningType(assignedType)
                  ? 'E'
                  : isDayType(assignedType)
                      ? 'D'
                      : assignedType.code.toUpperCase();

          // 소프트 기피 패턴 상세 기록 (멤버 + 날짜)
          final p0 = prevCodes[uid]![0]; // 어제
          final p1 = prevCodes[uid]![1]; // 2일전
          final p2 = prevCodes[uid]![2]; // 3일전
          final mmdd = dateStr.substring(5); // MM-DD
          final mLabel = m.displayName;
          if (todayCode == 'D' && p0 == null && p1 == 'N') {
            softViolCounts['NOD']!.add('$mLabel $mmdd');
          }
          if (todayCode == 'D' && p0 == null && p1 == null && p2 == 'N') {
            softViolCounts['NOOD']!.add('$mLabel $mmdd');
          }
          if (todayCode == 'E' && p0 == null && p1 == 'N') {
            softViolCounts['NOE']!.add('$mLabel $mmdd');
          }
          if (todayCode == 'D' && p0 == null && p1 == 'E') {
            softViolCounts['EOD']!.add('$mLabel $mmdd');
          }
        }
        // [어제, 2일전, 3일전] 슬라이딩
        prevCodes[uid] = [todayCode, prevCodes[uid]![0], prevCodes[uid]![1]];
      }
    }

    // ── skill_condition 사후 검증 ──
    if (skillConditions.isNotEmpty) {
      for (int d = 0; d < dayCount; d++) {
        final date = start.add(Duration(days: d));
        final dateStr = fmt(date);
        for (final cond in skillConditions) {
          // 해당 shiftType 찾기
          final st = shiftTypes.where((t) {
            final code = isNightType(t) ? 'N' : isEveningType(t) ? 'E' : isDayType(t) ? 'D' : t.code.toUpperCase();
            return code == cond.shiftCode;
          }).toList();
          if (st.isEmpty) continue;
          final stId = st.first.id;
          // 해당 날짜·근무에 배정된 멤버 중 min_skill 이상인 수
          final assignedMemberIds = shifts
              .where((s) => s['shift_date'] == dateStr && s['shift_type_id'] == stId)
              .map((s) => s['user_id'] as String)
              .toList();
          final qualifiedCount = assignedMemberIds.where((uid) {
            final member = members.firstWhere(
              (m) => m.userId == uid,
              orElse: () => members.first,
            );
            final skill = _skillLevelNum(member.member.skillLevel);
            return skill >= cond.minSkill;
          }).length;
          if (qualifiedCount < cond.minCount) {
            final skillLabel = _skillLevelLabel(cond.minSkill);
            warnings.add(
              '$dateStr ${cond.shiftCode} 근무: $skillLabel 이상 ${cond.minCount}명 조건 미충족 ($qualifiedCount명)',
            );
          }
        }
      }
    }

    // ── 사후 검증: 신규 단독 근무 (기본 소프트 체크) ──
    // 숙련도가 모두 설정된 경우에만 체크 (미설정 멤버 있으면 판단 불가 → 건너뜀)
    for (int d = 0; d < dayCount; d++) {
      final date = start.add(Duration(days: d));
      final dateStr = fmt(date);
      for (final shiftType in workShiftTypes) {
        final assignedUids = shifts
            .where((s) =>
                s['shift_date'] == dateStr && s['shift_type_id'] == shiftType.id)
            .map((s) => s['user_id'] as String)
            .toList();
        if (assignedUids.isEmpty) continue;

        final assignedMembers = assignedUids
            .map((uid) => members.firstWhere(
                  (m) => m.userId == uid,
                  orElse: () => members.first,
                ))
            .toList();

        // 숙련도 미설정 멤버가 한 명이라도 있으면 판단 불가 → 건너뜀
        final hasUnknownSkill =
            assignedMembers.any((m) => m.member.skillLevel == null);
        if (hasUnknownSkill) continue;

        final hasJunior =
            assignedMembers.any((m) => m.member.skillLevel == 'junior');
        final hasSeniorOrMid = assignedMembers.any((m) =>
            m.member.skillLevel == 'senior' || m.member.skillLevel == 'mid');

        if (hasJunior && !hasSeniorOrMid) {
          final mmdd = dateStr.substring(5);
          final juniorNames = assignedMembers
              .where((m) => m.member.skillLevel == 'junior')
              .map((m) => m.displayName)
              .join(', ');
          softViolCounts['신규단독']!.add('${shiftType.name} $mmdd ($juniorNames)');
        }
      }
    }

    // ── 원티드 반영률 + 미반영 목록 ──
    final wantedTotal = wantedOff.values.fold(0, (sum, s) => sum + s.length);
    int wantedSatisfied = 0;
    final wantedUnsatisfied = <String>[];

    // userId → displayName 맵
    final uidToName = {for (final m in members) m.userId: m.displayName};

    for (final entry in wantedOff.entries) {
      final uid = entry.key;
      final name = uidToName[uid] ?? uid;
      for (final dateStr in entry.value) {
        final hasShift = shifts.any(
          (s) => s['user_id'] == uid && s['shift_date'] == dateStr,
        );
        if (!hasShift) {
          wantedSatisfied++;
        } else {
          wantedUnsatisfied.add('$name ${dateStr.substring(5)}');
        }
      }
    }

    return _GenerationResult(
      shifts: shifts,
      warnings: warnings,
      understaffedCount: understaffedDays.length,
      wantedTotal: wantedTotal,
      wantedSatisfied: wantedSatisfied,
      softViolations: Map<String, List<String>>.from(softViolCounts)
        ..removeWhere((_, v) => v.isEmpty),
      wantedUnsatisfied: wantedUnsatisfied,
    );
  }

  /// 'junior'/'mid'/'senior' 문자열 → 숫자 (1/2/3)
  static int _skillLevelNum(String? level) {
    switch (level) {
      case 'junior': return 1;
      case 'mid': return 2;
      case 'senior': return 3;
      default: return 0;
    }
  }

  /// 숙련도 숫자 → 한국어 라벨
  static String _skillLevelLabel(int num) {
    switch (num) {
      case 1: return '신규';
      case 2: return '중간';
      case 3: return '올드';
      default: return '숙련도 $num';
    }
  }
}

class _GenerationResult {
  _GenerationResult({
    required this.shifts,
    required this.warnings,
    this.understaffedCount = 0,
    this.wantedTotal = 0,
    this.wantedSatisfied = 0,
    Map<String, List<String>>? softViolations,
    List<String>? wantedUnsatisfied,
  })  : softViolations = softViolations ?? {},
        wantedUnsatisfied = wantedUnsatisfied ?? [];
  final List<Map<String, dynamic>> shifts;
  final List<String> warnings;
  final int understaffedCount;
  final int wantedTotal;
  final int wantedSatisfied;
  // {'NOD': ['홍길동 05-03', ...], 'NOOD': [...], ...}
  final Map<String, List<String>> softViolations;
  // ['홍길동 05-10 (휴무 요청)', ...]
  final List<String> wantedUnsatisfied;
}
