part of 'schedule_generation_viewmodel.dart';

/// 커스텀 룰 위반 감지 (generate 완료 후 즉시 호출)
/// hard 룰 위반 → customRuleViolations; soft 룰 위반 → softCustomViolations
({List<String> hard, List<String> soft}) _computeCustomRuleViolations(
  ScheduleGenerationState s,
) {
  final shifts = s.previewShifts ?? [];
  final hardViolations = <String>[];
  final softViolations = <String>[];

  String dateFmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String mName(String uid) => s.members
      .firstWhere((m) => m.userId == uid, orElse: () => s.members.first)
      .displayName;

  String? shiftCodeFor(String shiftTypeId) {
    final st = s.shiftTypes.where((t) => t.id == shiftTypeId).firstOrNull;
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

  void addViolation(String message, String priority) {
    (priority == 'hard' ? hardViolations : softViolations).add(message);
  }

  for (final rule in s.customRules.where((r) => r.isActive)) {
    final rv = rule.ruleValue;
    switch (rule.ruleType) {
      case 'member_shift_ban':
        final uid = rv['member_id'] as String?;
        final rawCode = (rv['shift_code'] as String?)?.toUpperCase();
        if (uid == null) break;
        // null/빈값/'ALL' → 전체 근무 금지
        final banAll = rawCode == null || rawCode.isEmpty || rawCode == 'ALL';
        final banViolDates =
            shifts
                .where(
                  (sh) =>
                      sh.userId == uid &&
                      (banAll || shiftCodeFor(sh.shiftTypeId) == rawCode),
                )
                .map((sh) => dateFmt(sh.shiftDate).substring(5))
                .toList()
              ..sort();
        if (banViolDates.isNotEmpty) {
          final codeLabel = banAll ? '근무' : rawCode;
          addViolation(
            '근무 금지 위반: ${mName(uid)}에게 $codeLabel 배정됨 → ${banViolDates.join(', ')} ("${rule.originalText}")',
            rule.priority,
          );
        }

      case 'anti_pair':
        final uidA = rv['member_id_a'] as String?;
        final uidB = rv['member_id_b'] as String?;
        final code = (rv['shift_code'] as String?)?.toUpperCase();
        if (uidA == null || uidB == null) break;
        final assignedA = {
          for (final sh in shifts.where((sh) => sh.userId == uidA))
            dateFmt(sh.shiftDate): sh.shiftTypeId,
        };
        final assignedB = {
          for (final sh in shifts.where((sh) => sh.userId == uidB))
            dateFmt(sh.shiftDate): sh.shiftTypeId,
        };
        final conflictEntries = assignedA.entries.where((e) {
          if (assignedB[e.key] != e.value) return false;
          if (code != null && shiftCodeFor(e.value) != code) return false;
          return true;
        }).toList()..sort((a, b) => a.key.compareTo(b.key));
        if (conflictEntries.isNotEmpty) {
          final dates = conflictEntries
              .map((e) => e.key.substring(5))
              .join(', '); // MM-DD
          addViolation(
            '동시 배정 금지 위반: ${mName(uidA)}, ${mName(uidB)} → ${conflictEntries.length}일 (${dates}) ("${rule.originalText}")',
            rule.priority,
          );
        }

      case 'require_pair':
        final uidA = rv['member_id_a'] as String?;
        final uidB = rv['member_id_b'] as String?;
        final code = (rv['shift_code'] as String?)?.toUpperCase();
        if (uidA == null || uidB == null) break;
        final assignedA = {
          for (final sh in shifts.where((sh) => sh.userId == uidA))
            dateFmt(sh.shiftDate): sh.shiftTypeId,
        };
        final assignedB = {
          for (final sh in shifts.where((sh) => sh.userId == uidB))
            dateFmt(sh.shiftDate): sh.shiftTypeId,
        };
        final missEntries = assignedA.entries.where((e) {
          if (code != null && shiftCodeFor(e.value) != code) return false;
          return assignedB[e.key] != e.value;
        }).toList()..sort((a, b) => a.key.compareTo(b.key));
        if (missEntries.isNotEmpty) {
          final dates = missEntries.map((e) => e.key.substring(5)).join(', ');
          addViolation(
            '함께 배정 미충족: ${mName(uidA)}, ${mName(uidB)} → ${missEntries.length}일 (${dates}) ("${rule.originalText}")',
            rule.priority,
          );
        }

      case 'date_off':
        final uid = rv['member_id'] as String?;
        final dates = (rv['dates'] as List?)?.cast<String>() ?? [];
        if (uid == null || dates.isEmpty) break;
        final violated = dates
            .where(
              (d) => shifts.any(
                (sh) => sh.userId == uid && dateFmt(sh.shiftDate) == d,
              ),
            )
            .toList();
        if (violated.isNotEmpty) {
          addViolation(
            '날짜 오프 위반: ${mName(uid)}이 ${violated.join(', ')} 근무 배정 ("${rule.originalText}")',
            rule.priority,
          );
        }

      case 'skill_condition':
        // hard는 validationWarnings에서 처리, soft는 여기서 소프트 위반으로 수집
        if (rule.priority == 'hard') break;
        final shiftCodeFilter =
            (rv['shift_code'] as String?)?.toUpperCase() ?? '';
        final minSkill = (rv['min_skill'] as num?)?.toInt() ?? 1;
        final minCount = (rv['min_count'] as num?)?.toInt() ?? 1;
        if (shiftCodeFilter.isEmpty) break;
        final dateSet =
            shifts.map((sh) => dateFmt(sh.shiftDate)).toSet().toList()..sort();
        for (final dStr in dateSet) {
          final stList = s.shiftTypes.where((t) {
            final bool isD =
                t.code.toUpperCase() == 'D' ||
                t.name.contains('데이') ||
                t.name.contains('주간');
            final bool isE =
                t.code.toUpperCase() == 'E' ||
                t.name.contains('이브닝') ||
                t.name.contains('저녁');
            final bool isN =
                t.code.toUpperCase() == 'N' ||
                t.name.contains('나이트') ||
                t.name.contains('야간');
            final code = isN
                ? 'N'
                : isE
                ? 'E'
                : isD
                ? 'D'
                : t.code.toUpperCase();
            return code == shiftCodeFilter;
          }).toList();
          if (stList.isEmpty) continue;
          final stId = stList.first.id;
          final assignedUids = shifts
              .where(
                (sh) => dateFmt(sh.shiftDate) == dStr && sh.shiftTypeId == stId,
              )
              .map((sh) => sh.userId)
              .toList();
          final qualifiedCount = assignedUids.where((uid) {
            final member = s.members.firstWhere(
              (m) => m.userId == uid,
              orElse: () => s.members.first,
            );
            return _skillLevelNum(member.member.skillLevel) >= minSkill;
          }).length;
          if (qualifiedCount < minCount) {
            final skillLabel = _skillLevelLabel(minSkill);
            softViolations.add(
              '$dStr $shiftCodeFilter 근무: $skillLabel 이상 ${minCount}명 조건 미충족 ($qualifiedCount명) ("${rule.originalText}")',
            );
          }
        }

      case 'skill_balance':
        final filterCode = (rv['shift_code'] as String?)?.toUpperCase();
        // 날짜 × 근무유형 순회
        final dateSet =
            shifts.map((sh) => dateFmt(sh.shiftDate)).toSet().toList()..sort();
        for (final dStr in dateSet) {
          for (final st in s.shiftTypes) {
            // D/E/N으로 인식되는 타입만 체크
            final bool isD =
                st.code.toUpperCase() == 'D' ||
                st.name.contains('데이') ||
                st.name.contains('주간');
            final bool isE =
                st.code.toUpperCase() == 'E' ||
                st.name.contains('이브닝') ||
                st.name.contains('저녁');
            final bool isN =
                st.code.toUpperCase() == 'N' ||
                st.name.contains('나이트') ||
                st.name.contains('야간');
            if (!isD && !isE && !isN) continue;

            String? stCode = isN
                ? 'N'
                : isE
                ? 'E'
                : 'D';

            if (filterCode != null && filterCode != stCode) continue;

            final dayShiftUids = shifts
                .where(
                  (sh) =>
                      dateFmt(sh.shiftDate) == dStr && sh.shiftTypeId == st.id,
                )
                .map((sh) => sh.userId)
                .toList();
            if (dayShiftUids.isEmpty) continue;

            final dayMembers = dayShiftUids
                .map(
                  (uid) => s.members.firstWhere(
                    (m) => m.userId == uid,
                    orElse: () => s.members.first,
                  ),
                )
                .toList();

            // 숙련도 미설정 멤버 있으면 판단 불가 → 건너뜀
            if (dayMembers.any((m) => m.member.skillLevel == null)) continue;

            final hasJunior = dayMembers.any(
              (m) => m.member.skillLevel == 'junior',
            );
            final hasSeniorOrMid = dayMembers.any(
              (m) =>
                  m.member.skillLevel == 'senior' ||
                  m.member.skillLevel == 'mid',
            );

            if (hasJunior && !hasSeniorOrMid) {
              addViolation(
                '숙련도 불균형: $dStr ${st.name} 근무에 신규만 배정되고 올드/중간 없음 ("${rule.originalText}")',
                rule.priority,
              );
            }
          }
        }
    }
  }

  return (hard: hardViolations, soft: softViolations);
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
  required int seed,
  _FeedbackGenerationTuning tuning = const _FeedbackGenerationTuning(),
  List<ShiftModel> priorShifts = const [],
}) {
  final shifts = <Map<String, dynamic>>[];
  final warnings = <String>[];
  final understaffedDays = <String>{};
  final random = Random(seed);

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
  final nodDisabled = (ruleMap['nod_disabled']?['enabled'] as bool?) ?? true;

  // 나이트 전담 월간 목표 나이트 수 (기본 14)
  final nightDedicatedMonthlyTarget =
      (ruleMap['max_night_dedicated_shifts']?['count'] as num?)?.toInt() ?? 14;
  // 나이트 전담 전용 휴식 규칙 (팀 설정에서 조정 가능)
  final nightDedicatedMaxConsecutive =
      (ruleMap['night_dedicated_max_consecutive']?['count'] as num?)?.toInt() ??
      3;
  final nightDedicatedMinOffAfter =
      (ruleMap['night_dedicated_min_off_after']?['count'] as num?)?.toInt() ?? 2;
  final nightDedicatedWeeklyMax =
      (ruleMap['night_dedicated_weekly_max']?['count'] as num?)?.toInt() ?? 5;

  // 소프트 기피 패턴 (기본 false — 팀 설정에서 켜야 활성화)
  // avoidNood=true(하드 시): NOOD 차단 시 실제 스케줄 재현이 어려울 수 있음
  final avoidNood = (ruleMap['avoid_nood']?['enabled'] as bool?) ?? false;
  final avoidNoe = (ruleMap['avoid_noe']?['enabled'] as bool?) ?? false;
  final avoidEod = (ruleMap['avoid_eod']?['enabled'] as bool?) ?? false;

  // 숙련도 배치 고려 — 항상 활성화
  const considerSkill = true;

  // ── 커스텀 규칙 파싱 (활성화된 것만) ──
  final activeCustomRules = customRules.where((r) => r.isActive).toList();

  // member_shift_ban: { member_id, shift_code }
  // hard → eligibility block; soft → score penalty
  // shift_code가 null/빈값이면 "모든 근무 금지"('*' 센티넬)로 처리한다.
  final hardMemberShiftBans = <String, Set<String>>{};
  final softMemberShiftBans = <String, Set<String>>{};
  for (final r in activeCustomRules.where(
    (r) => r.ruleType == 'member_shift_ban',
  )) {
    final memberId = r.ruleValue['member_id'] as String?;
    final rawCode = (r.ruleValue['shift_code'] as String?)?.toUpperCase();
    // null/빈문자열/'ALL' → 전체 근무 금지
    final shiftCode = (rawCode == null || rawCode.isEmpty || rawCode == 'ALL')
        ? '*'
        : rawCode;
    if (memberId != null) {
      if (r.priority == 'hard') {
        hardMemberShiftBans.putIfAbsent(memberId, () => {}).add(shiftCode);
      } else {
        softMemberShiftBans.putIfAbsent(memberId, () => {}).add(shiftCode);
      }
    }
  }

  // anti_pair: { member_id_a, member_id_b, shift_code? }
  // If both members are eligible for the same shift on the same day,
  // block the later-processed one when the first is already assigned.
  final antiPairs = activeCustomRules
      .where((r) => r.ruleType == 'anti_pair' && r.priority == 'hard')
      .map(
        (r) => (
          a: r.ruleValue['member_id_a'] as String? ?? '',
          b: r.ruleValue['member_id_b'] as String? ?? '',
          code: (r.ruleValue['shift_code'] as String?)?.toUpperCase(),
        ),
      )
      .where((p) => p.a.isNotEmpty && p.b.isNotEmpty)
      .toList();
  final softAntiPairs = activeCustomRules
      .where((r) => r.ruleType == 'anti_pair' && r.priority == 'soft')
      .map(
        (r) => (
          a: r.ruleValue['member_id_a'] as String? ?? '',
          b: r.ruleValue['member_id_b'] as String? ?? '',
          code: (r.ruleValue['shift_code'] as String?)?.toUpperCase(),
        ),
      )
      .where((p) => p.a.isNotEmpty && p.b.isNotEmpty)
      .toList();

  // require_pair: hard → strong bonus (+200); soft → weak bonus (+80)
  final hardRequirePairs = activeCustomRules
      .where((r) => r.ruleType == 'require_pair' && r.priority == 'hard')
      .map(
        (r) => (
          a: r.ruleValue['member_id_a'] as String? ?? '',
          b: r.ruleValue['member_id_b'] as String? ?? '',
          code: (r.ruleValue['shift_code'] as String?)?.toUpperCase(),
        ),
      )
      .where((p) => p.a.isNotEmpty && p.b.isNotEmpty)
      .toList();
  final softRequirePairs = activeCustomRules
      .where((r) => r.ruleType == 'require_pair' && r.priority != 'hard')
      .map(
        (r) => (
          a: r.ruleValue['member_id_a'] as String? ?? '',
          b: r.ruleValue['member_id_b'] as String? ?? '',
          code: (r.ruleValue['shift_code'] as String?)?.toUpperCase(),
        ),
      )
      .where((p) => p.a.isNotEmpty && p.b.isNotEmpty)
      .toList();

  // date_off: { member_id, dates: [YYYY-MM-DD, ...] }
  // hard → eligibility block; soft → score penalty (-200)
  final hardForcedOffDates = <String, Set<String>>{};
  final softForcedOffDates = <String, Set<String>>{};
  for (final r in activeCustomRules.where((r) => r.ruleType == 'date_off')) {
    final memberId = r.ruleValue['member_id'] as String?;
    final dates = (r.ruleValue['dates'] as List?)?.cast<String>() ?? [];
    if (memberId != null && dates.isNotEmpty) {
      if (r.priority == 'hard') {
        hardForcedOffDates.putIfAbsent(memberId, () => {}).addAll(dates);
      } else {
        softForcedOffDates.putIfAbsent(memberId, () => {}).addAll(dates);
      }
    }
  }

  // post_night_off: { consecutive_nights, min_off_days }
  // hard → eligibility block; soft → score penalty
  final hardPostNightOffRules = activeCustomRules
      .where((r) => r.ruleType == 'post_night_off' && r.priority == 'hard')
      .map(
        (r) => (
          consecutiveNights:
              (r.ruleValue['consecutive_nights'] as num?)?.toInt() ?? 3,
          minOffDays: (r.ruleValue['min_off_days'] as num?)?.toInt() ?? 2,
        ),
      )
      .toList();
  final softPostNightOffRules = activeCustomRules
      .where((r) => r.ruleType == 'post_night_off' && r.priority != 'hard')
      .map(
        (r) => (
          consecutiveNights:
              (r.ruleValue['consecutive_nights'] as num?)?.toInt() ?? 3,
          minOffDays: (r.ruleValue['min_off_days'] as num?)?.toInt() ?? 2,
        ),
      )
      .toList();

  // skill_condition: { shift_code, min_skill, min_count }
  // hard → warning in validationWarnings; soft → soft violation
  final hardSkillConditions = activeCustomRules
      .where((r) => r.ruleType == 'skill_condition' && r.priority == 'hard')
      .map(
        (r) => (
          shiftCode:
              (r.ruleValue['shift_code'] as String?)?.toUpperCase() ?? '',
          minSkill: (r.ruleValue['min_skill'] as num?)?.toInt() ?? 1,
          minCount: (r.ruleValue['min_count'] as num?)?.toInt() ?? 1,
        ),
      )
      .where((c) => c.shiftCode.isNotEmpty)
      .toList();
  // soft skill_condition violations are computed post-gen in _computeCustomRuleViolations

  // skill_condition 배정-시 스코어링용 (하드/소프트 모두): 자격 인원을 우선 확보.
  // "요구(필수 포함)" 계열이라 하드여도 강제할 수 없어 베스트 에포트로 유도한다.
  final skillConditionRules = activeCustomRules
      .where((r) => r.ruleType == 'skill_condition')
      .map(
        (r) => (
          shiftCode:
              (r.ruleValue['shift_code'] as String?)?.toUpperCase() ?? '',
          minSkill: (r.ruleValue['min_skill'] as num?)?.toInt() ?? 1,
          minCount: (r.ruleValue['min_count'] as num?)?.toInt() ?? 1,
          isHard: r.priority == 'hard',
        ),
      )
      .where((c) => c.shiftCode.isNotEmpty)
      .toList();

  // skill_balance: { shift_code? }
  // "신규가 있으면 올드 한명은 있어야 한다" — soft/hard 모두 지원
  // hard: 배정 후 위반 시 warning
  // soft: 스코어링으로 유도
  final skillBalanceRules = activeCustomRules
      .where((r) => r.ruleType == 'skill_balance')
      .map(
        (r) => (
          shiftCode: (r.ruleValue['shift_code'] as String?)?.toUpperCase(),
          isHard: r.priority == 'hard',
        ),
      )
      .toList();

  // 소프트: 원티드 우선순위 (1번 인덱스가 최고 우선순위)
  // ── 스코어링 우선순위 (scheduling_priority_order, 구버전 호환) ──
  // 순위별 multiplier: 1위=1.6, 2위=1.2, 3위=0.85, 4위=0.55
  // 피드백 튜닝 boost와 곱산하여 실제 스코어에 반영
  const _rankMultipliers = [1.6, 1.2, 0.85, 0.55];
  final scoringOrder = List<String>.from(
    (ruleMap['scheduling_priority_order']?['order'] as List?) ??
        (ruleMap['wanted_priority_order']?['order'] as List?) ??
        ['wanted', 'avoid_pattern', 'preferred_shift', 'skill_placement'],
  );
  double scoringMultiplier(String key) {
    final idx = scoringOrder.indexOf(key);
    if (idx < 0 || idx >= _rankMultipliers.length) return 1.0;
    return _rankMultipliers[idx];
  }

  final wantedBoost = tuning.wantedBoost * scoringMultiplier('wanted');
  final patternPenaltyBoost =
      tuning.patternPenaltyBoost * scoringMultiplier('avoid_pattern');
  final preferredShiftBoost = scoringMultiplier('preferred_shift');
  final skillBalanceBoost =
      tuning.skillBalanceBoost * scoringMultiplier('skill_placement');

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

  // 교육 등 비D/E/N 근무 유형 ID 집합 (wantedEntries 처리 전 필요)
  final educationShiftTypeIds = shiftTypes
      .where((t) => !isDayType(t) && !isEveningType(t) && !isNightType(t))
      .map((t) => t.id)
      .toSet();

  // 원티드 날짜 맵
  // wantedDaysOff: day_off (hard) — 하드 제약 (D/E/N 배정 완전 차단)
  // wantedPriority: day_off (soft) — 소프트 페널티 계산용
  // preferredShiftMap: preferred_shift (D/E/N) — 희망 근무 유형 보너스/페널티용
  // preferredShiftPriority: preferred_shift 우선순위 — 보너스 강도 조절
  // educationWantedByUserDate: preferred_shift (교육 등 비D/E/N) — 무조건 반영
  final wantedDaysOff = <String, Set<String>>{};
  final wantedPriority = <String, Map<String, int>>{};
  final preferredShiftMap = <String, Map<String, String>>{};
  final preferredShiftPriority = <String, Map<String, int>>{};
  final educationWantedByUserDate =
      <String, Map<String, String>>{}; // userId → dateStr → shiftTypeId
  for (final entry in wantedEntries) {
    final dateStr =
        '${entry.wantedDate.year}-${entry.wantedDate.month.toString().padLeft(2, '0')}-${entry.wantedDate.day.toString().padLeft(2, '0')}';
    final p = entry.priority;
    if (entry.shiftTypeId != null) {
      if (educationShiftTypeIds.contains(entry.shiftTypeId)) {
        // 교육 등 비D/E/N preferred_shift: 우선순위 무관 무조건 반영
        educationWantedByUserDate.putIfAbsent(entry.userId, () => {})[dateStr] =
            entry.shiftTypeId!;
      } else {
        // D/E/N preferred_shift 엔트리: 희망 근무 유형 매핑
        preferredShiftMap.putIfAbsent(entry.userId, () => {})[dateStr] =
            entry.shiftTypeId!;
        preferredShiftPriority.putIfAbsent(entry.userId, () => {})[dateStr] = p;
      }
    } else {
      // day_off 엔트리: 오프 희망
      // 생리휴가/연차/필수교육 → 우선순위 무관 하드 제약 (D/E/N 배정 차단)
      // P1 custom(직접 입력) → 강한 소프트 페널티 (-200)
      // P2 → 중간 소프트 페널티 (-150)
      const hardReasons = {'#생리휴가', '#연차', '#필수교육'};
      final isHard = hardReasons.contains(entry.reason);
      if (isHard) {
        wantedDaysOff.putIfAbsent(entry.userId, () => {}).add(dateStr);
      } else {
        wantedPriority.putIfAbsent(entry.userId, () => {})[dateStr] = p;
      }
    }
  }

  // D/E/N으로 인식되는 타입만 포함 (알 수 없는 추가 타입, OFF 타입 제외)
  // 나이트를 먼저 배정해야 D/E 배정 시 정확한 제약 반영 가능 — N 타입 우선 정렬
  final workShiftTypes =
      shiftTypes
          .where((t) => isDayType(t) || isEveningType(t) || isNightType(t))
          .toList()
        ..sort((a, b) {
          final aN = isNightType(a) ? 0 : 1;
          final bN = isNightType(b) ? 0 : 1;
          return aN.compareTo(bN);
        });

  // ── 날짜 포맷 ──
  String fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ── 멤버별 상태 ──
  final shiftCount = <String, int>{for (final m in members) m.userId: 0};
  final nightCount = <String, int>{for (final m in members) m.userId: 0};
  final dayShiftCount = <String, int>{for (final m in members) m.userId: 0};
  final eveShiftCount = <String, int>{for (final m in members) m.userId: 0};
  // 나이트 청크 간격 추적: 마지막으로 나이트 근무한 날짜 (일반 멤버 전용)
  final lastNightDate = <String, DateTime?>{
    for (final m in members) m.userId: null,
  };
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
    'NOD': [],
    'NOOD': [],
    'NOE': [],
    'EOD': [],
    '신규단독': [],
  };
  final lastWorkedDate = <String, DateTime?>{
    for (final m in members) m.userId: null,
  };

  // 주간 근무 제약은 항상 월요일 시작 주(월~일)를 기준으로 한다.
  // (앱의 달력 시작 요일 설정과 무관하게 고정)
  DateTime weekStartOf(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    final wd = day.weekday; // 1=월 .. 7=일
    return day.subtract(Duration(days: wd - 1));
  }

  // ── 이전 달 마지막 주 시드 ──
  // periodStart 직전 7일 근무로 롤링 상태(연속 근무/야간, 주간 근무일, prevCodes)를
  // 채운다. 월 경계에서 주간 최대·연속·N→D 제약이 끊기지 않게 한다.
  final startDay = DateTime(start.year, start.month, start.day);
  if (priorShifts.isNotEmpty) {
    String codeOfType(String shiftTypeId) {
      final st = shiftTypes.where((t) => t.id == shiftTypeId).firstOrNull;
      if (st == null) return 'O';
      if (isNightType(st)) return 'N';
      if (isEveningType(st)) return 'E';
      if (isDayType(st)) return 'D';
      return st.code.toUpperCase();
    }

    final priorByUser = <String, Map<DateTime, String>>{};
    for (final s in priorShifts) {
      final d = DateTime(s.shiftDate.year, s.shiftDate.month, s.shiftDate.day);
      if (!d.isBefore(startDay)) continue; // 이번 달 이후는 무시
      // 같은 (유저,날짜) 중복은 마지막 값 사용
      priorByUser.putIfAbsent(s.userId, () => {})[d] = codeOfType(
        s.shiftTypeId,
      );
    }

    for (final m in members) {
      final byDate = priorByUser[m.userId];
      if (byDate == null) continue;

      final workedDates =
          byDate.entries.where((e) => e.value != 'O').map((e) => e.key).toList()
            ..sort();
      recentWorkDates[m.userId]!.addAll(workedDates);
      if (workedDates.isNotEmpty) {
        lastWorkedDate[m.userId] = workedDates.last;
      }
      final nightDates =
          byDate.entries.where((e) => e.value == 'N').map((e) => e.key).toList()
            ..sort();
      if (nightDates.isNotEmpty) lastNightDate[m.userId] = nightDates.last;

      // prevCodes [어제, 2일전, 3일전]
      for (var k = 0; k < 3; k++) {
        final day = startDay.subtract(Duration(days: k + 1));
        final code = byDate[day];
        prevCodes[m.userId]![k] = (code == null || code == 'O') ? null : code;
      }

      // 직전부터 연속 근무일 / 연속 야간
      var cw = 0;
      for (var k = 1; k <= 7; k++) {
        final code = byDate[startDay.subtract(Duration(days: k))];
        if (code != null && code != 'O') {
          cw++;
        } else {
          break;
        }
      }
      consecutiveWork[m.userId] = cw;
      var cn = 0;
      for (var k = 1; k <= 7; k++) {
        final code = byDate[startDay.subtract(Duration(days: k))];
        if (code == 'N') {
          cn++;
        } else {
          break;
        }
      }
      consecutiveNight[m.userId] = cn;
    }
  }

  // ── 날짜 순회 ──
  final dayCount = end.difference(start).inDays + 1;

  for (int d = 0; d < dayCount; d++) {
    final date = start.add(Duration(days: d));
    final dateStr = fmt(date);
    // 오늘까지 진행된 비율 (0.0 ~ 1.0)
    final progressRatio = (d + 1) / dayCount;

    // ── 교육 선배정: 원티드에 교육 근무 유형 등록 시 무조건 먼저 배정 ──
    for (final entry in educationWantedByUserDate.entries) {
      final userId = entry.key;
      final eduShiftId = entry.value[dateStr];
      if (eduShiftId == null) continue;
      // 이미 오늘 배정된 멤버 제외
      if (shifts.any(
        (s) => s['user_id'] == userId && s['shift_date'] == dateStr,
      ))
        continue;
      // active members에 없는 멤버 제외 (제외 멤버 처리)
      if (!members.any((m) => m.userId == userId)) continue;
      shifts.add({
        'schedule_id': scheduleId,
        'team_id': teamId,
        'user_id': userId,
        'shift_date': dateStr,
        'shift_type_id': eduShiftId,
      });
      shiftCount[userId] = (shiftCount[userId] ?? 0) + 1;
      final prevDateEdu = lastWorkedDate[userId];
      if (prevDateEdu != null && date.difference(prevDateEdu).inDays == 1) {
        consecutiveWork[userId] = (consecutiveWork[userId] ?? 0) + 1;
      } else {
        consecutiveWork[userId] = 1;
      }
      lastWorkedDate[userId] = date;
      recentWorkDates[userId]!.add(date);
    }

    // 배정 가능 여부(하드 제약)를 근무 유형별로 판정하는 함수.
    // 최소 인원 미충족을 막기 위해 처리 순서 결정과 실제 배정에 함께 쓴다.
    bool eligibleFor(
      TeamMemberWithUser m,
      ShiftTypeModel shiftType, {
      bool relaxWeeklyOff = false,
      bool relaxConsecutive = false,
    }) {
      final isNight = isNightType(shiftType);
      final isDay = isDayType(shiftType);
      final isEvening = isEveningType(shiftType);
      final shiftCode = isNight
          ? 'N'
          : isEvening
          ? 'E'
          : isDay
          ? 'D'
          : shiftType.code.toUpperCase();
      final uid = m.userId;

      // 오늘 이미 다른 근무에 배정됐으면 제외 (하루 1근무 원칙)
      if (shifts.any(
        (s) => s['user_id'] == uid && s['shift_date'] == dateStr,
      )) {
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
      if (noNightThenDay && isDay && isYesterday && prevCode0 == 'N')
        return false;
      // N→E 금지
      if (noNightThenEvening && isEvening && isYesterday && prevCode0 == 'N')
        return false;
      // E→D 금지
      if (noEveningThenDay && isDay && isYesterday && prevCode0 == 'E')
        return false;
      // NOD 하드 금지: 2일전=N, 어제=O, 오늘=D
      if (nodDisabled && isDay && prevCode0 == null && prevCode1 == 'N')
        return false;
      // NOE 하드 금지: 2일전=N, 어제=O, 오늘=E (NOD와 동일 원리 — 이브닝도 1일 오프 불충분)
      if (nodDisabled && isEvening && prevCode0 == null && prevCode1 == 'N')
        return false;
      // NOOD 하드 금지: 3일전=N, 2일전=O, 어제=O, 오늘=D (avoidNood 설정 시)
      if (avoidNood &&
          isDay &&
          prevCode0 == null &&
          prevCode1 == null &&
          prevCode2 == 'N')
        return false;

      // 월 최대 근무 (나이트 전담은 면제 — 14나이트 전용 목표 적용)
      if (!m.member.nightDedicated &&
          (shiftCount[uid] ?? 0) >= maxMonthlyShifts)
        return false;
      // 월 최대 야간 (나이트 전담은 별도 목표 14으로 관리, 일반 멤버만 적용)
      if (isNight &&
          !m.member.nightDedicated &&
          (nightCount[uid] ?? 0) >= maxMonthlyNightShifts)
        return false;
      // 나이트 전담 월간 나이트 상한 (기본 14)
      if (m.member.nightDedicated &&
          isNight &&
          (nightCount[uid] ?? 0) >= nightDedicatedMonthlyTarget)
        return false;

      // 최대 연속 근무일
      // isYesterday=true일 때만 체크: 어제 쉬었으면 스트릭이 이미 끊긴 것이므로
      // (consecutiveWork는 배정 시에만 갱신되어, 쉰 날 이후에도 이전 값 유지 — 직접 계산)
      // relaxConsecutive: 미충족 보정 시 연속 한도를 1단계 완화 (이전 달 시드로
      // 첫날 전원이 연속근무 상한에 걸려 비는 문제 등).
      if (isYesterday &&
          (consecutiveWork[uid] ?? 0) >=
              (relaxConsecutive ? maxConsecutiveDays + 1 : maxConsecutiveDays))
        return false;
      // 최대 연속 야간 (나이트 전담은 제외 — 주간 5나이트 상한으로 관리됨)
      // 어제가 나이트였을 때만 체크: 오프 후 복귀 시에는 스트릭 초기화
      if (isNight &&
          !m.member.nightDedicated &&
          isYesterday &&
          prevCode0 == 'N' &&
          (consecutiveNight[uid] ?? 0) >=
              (relaxConsecutive
                  ? maxConsecutiveNights + 1
                  : maxConsecutiveNights))
        return false;

      // ── 나이트 전담 전용 하드 규칙 (팀 설정값 적용) ──
      // 0) 최대 연속 야간
      if (m.member.nightDedicated &&
          isNight &&
          isYesterday &&
          prevCode0 == 'N' &&
          (consecutiveNight[uid] ?? 0) >= nightDedicatedMaxConsecutive)
        return false;
      // 1) 나이트 블록 후 최소 N오프: 어제부터 연속 오프 일수가 설정값 미만이고
      //    그 오프 직전이 나이트였으면 오늘도 오프(=N 배정 불가).
      if (m.member.nightDedicated && isNight && prevCode0 == null) {
        var offRun = 0;
        for (var i = 0; i < 3; i++) {
          if (prevCodes[uid]![i] == null) {
            offRun++;
          } else {
            break;
          }
        }
        final beforeOff = offRun < 3 ? prevCodes[uid]![offRun] : null;
        if (beforeOff == 'N' && offRun < nightDedicatedMinOffAfter) return false;
      }
      // 2) 주간 최대 야간 (7일 롤링 윈도우)
      if (m.member.nightDedicated && isNight) {
        final recentDates7 = recentWorkDates[uid]!;
        final sevenDaysAgoNd = date.subtract(const Duration(days: 7));
        final recentNights = recentDates7
            .where((dt) => dt.isAfter(sevenDaysAgoNd))
            .length;
        if (recentNights >= nightDedicatedWeeklyMax) return false;
      }

      // 주간 최소 오프: 달력 주(주 시작요일 기준) 근무일이
      // (7 - minWeeklyOffDays) 이상이면 오늘은 오프 필요.
      final recentDates = recentWorkDates[uid]!;
      // 달력 주 내 이미 근무한 일수 — 이전 달 시드 포함.
      final ws = weekStartOf(date);
      final weekWorkCount = recentDates
          .where((dt) => !dt.isBefore(ws) && dt.isBefore(date))
          .length;
      // 종료 임박 보정 시(relaxWeeklyOff) 주간 최소 오프를 1단계 완화한다.
      final weeklyWorkLimit = relaxWeeklyOff
          ? 7 - (minWeeklyOffDays - 1)
          : 7 - minWeeklyOffDays;
      if (weekWorkCount >= weeklyWorkLimit) return false;

      // 원티드 1순위(최우선) — 하드 제약: 배정 불가
      if (wantedDaysOff[uid]?.contains(dateStr) == true) return false;

      // 원티드 오프 전날 나이트 금지 — N 근무 다음날 오프가 보장돼야 함
      if (isNight) {
        final tomorrowStr = fmt(date.add(const Duration(days: 1)));
        if (wantedDaysOff[uid]?.contains(tomorrowStr) == true) return false;
      }

      // ── 커스텀 하드 룰 ──

      // member_shift_ban (hard only): 특정 멤버 특정 근무 금지
      // '*'는 전체 근무 금지.
      final bannedCodes = hardMemberShiftBans[uid];
      if (bannedCodes != null &&
          (bannedCodes.contains('*') || bannedCodes.contains(shiftCode)))
        return false;

      // date_off (hard only): 날짜 강제 오프
      if (hardForcedOffDates[uid]?.contains(dateStr) == true) return false;

      // post_night_off (hard only): 나이트 N연속 후 최소 오프 강제
      // 나이트 전담은 자체 최소 2오프 규칙으로 관리되므로 이 커스텀 룰 적용 제외
      if (!m.member.nightDedicated) {
        for (final rule in hardPostNightOffRules) {
          if ((consecutiveNight[uid] ?? 0) >= rule.consecutiveNights) {
            return false;
          }
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
        final partnerAlreadyAssigned = shifts.any(
          (s) =>
              s['user_id'] == partner &&
              s['shift_date'] == dateStr &&
              s['shift_type_id'] == shiftType.id,
        );
        if (partnerAlreadyAssigned) return false;
      }

      // 희망 휴무일이면 제외
      final userWanted = wantedDaysOff[m.userId];
      if (userWanted != null && userWanted.contains(dateStr)) return false;

      return true;
    }

    // ── 근무 유형 처리 순서: 최소 인원 대비 여유가 가장 적은 근무부터 ──
    // (eligible 인원 − 최소 인원)이 작을수록 미충족 위험이 크므로 먼저 배정해
    // 공용 인력 풀을 우선 확보한다. 동률이면 원래 순서 유지.
    final orderedShiftTypes = [...workShiftTypes];
    final daySlack = <String, int>{
      for (final st in workShiftTypes)
        st.id:
            members.where((m) => eligibleFor(m, st)).length -
            max(1, minStaffing[st.id] ?? 1),
    };
    orderedShiftTypes.sort(
      (a, b) => (daySlack[a.id] ?? 0).compareTo(daySlack[b.id] ?? 0),
    );

    for (final shiftType in orderedShiftTypes) {
      final isNight = isNightType(shiftType);
      final isDay = isDayType(shiftType);
      final isEvening = isEveningType(shiftType);
      final shiftCode = isNight
          ? 'N'
          : isEvening
          ? 'E'
          : isDay
          ? 'D'
          : shiftType.code.toUpperCase();
      final minStaff = max(1, minStaffing[shiftType.id] ?? 1);

      // ── eligible 필터링 (하드 제약) ──
      // 배정 가능한 멤버가 없으면 그 칸은 비운 채로 둔다(아래 미충족 카운트로 노출).
      // 피로도(연속근무·연속야간·주간오프)를 깨서까지 채우지는 않는다 —
      // "피로도 위반보다 미충원이 낫다"는 방침.
      final eligible = members.where((m) => eligibleFor(m, shiftType)).toList();

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
        if (m.member.nightDedicated) {
          // 나이트 전담: 월 14나이트 목표로만 페이싱 (야간 페이싱 섹션에서 처리)
          // 여기서는 제외 (별도 야간 섹션에서 강한 보너스 적용)
        } else {
          // 일반 멤버: 전체 슬롯 기반 목표
          // 목표값 = 실제 1인당 예상 근무수 (max_monthly_shifts가 아님!)
          final nonDedicatedMembers = members
              .where((m) => !m.member.nightDedicated)
              .length;
          final totalSlotsNeeded = dayCount * workShiftTypes.length.toDouble();
          final targetPerMember = nonDedicatedMembers > 0
              ? totalSlotsNeeded / nonDedicatedMembers
              : totalSlotsNeeded / members.length;
          final expectedShifts = targetPerMember * progressRatio;
          final shiftDebt = expectedShifts - (shiftCount[uid] ?? 0);
          s += (shiftDebt * 20).round();

          // 유형별 균형 (일반 멤버 전용 — nightDedicated/dayOnly/nightExempt 속성자는 별도 처리됨)
          if (!m.member.nightDedicated &&
              !m.member.dayOnly &&
              !m.member.nightExempt) {
            final dTypeCount = workShiftTypes.where(isDayType).length;
            final eTypeCount = workShiftTypes.where(isEveningType).length;
            final nTypeCount = workShiftTypes.where(isNightType).length;
            final totalTypes = (dTypeCount + eTypeCount + nTypeCount)
                .toDouble();
            if (totalTypes > 0) {
              final dRatio = dTypeCount / totalTypes;
              final eRatio = eTypeCount / totalTypes;
              final nRatio = nTypeCount / totalTypes;
              final nonDedicated = members
                  .where((m) => !m.member.nightDedicated)
                  .length;
              final totalExpected = nonDedicated > 0
                  ? (dayCount * totalTypes * progressRatio) / nonDedicated
                  : 0.0;
              if (isDay) {
                final dDebt =
                    (totalExpected * dRatio) - (dayShiftCount[uid] ?? 0);
                s += (dDebt * 32).round();
              }
              if (isEvening) {
                final eDebt =
                    (totalExpected * eRatio) - (eveShiftCount[uid] ?? 0);
                s += (eDebt * 32).round();
              }
              if (isNight) {
                final nDebt = (totalExpected * nRatio) - (nightCount[uid] ?? 0);
                s += (nDebt * 32).round();
              }
            }
          }

          // 나이트 청크 간격 균등화 (일반 멤버 전용, 나이트 블록 시작 시점에서만 평가)
          // 연속 나이트 중간은 제외 — 새 블록 시작(consecutiveNight==0)일 때만 적용
          // D/E 블록 진행 중이면 억제 — 블록 중간에 N이 끼어드는 것 방지
          if (isNight && (consecutiveNight[uid] ?? 0) == 0) {
            final inActiveDEBlock =
                isYesterday && (prevCode0 == 'D' || prevCode0 == 'E');
            if (!inActiveDEBlock) {
              final lastN = lastNightDate[uid];
              final daysSince = lastN != null
                  ? date.difference(lastN).inDays
                  : dayCount; // 이번 달 첫 나이트 → 최대 우선순위
              s += (daysSince * 6).clamp(0, 120).round();
              if (daysSince < 7) s -= 100;
            }
          }
        }

        // 야간 페이싱
        if (isNight) {
          if (m.member.nightDedicated) {
            // 나이트 전담: 월 14나이트 고정 목표로 페이싱
            final targetByNow = nightDedicatedMonthlyTarget * progressRatio;
            final nightDebt = targetByNow - (nightCount[uid] ?? 0);
            s += (nightDebt * 40).round();

            // 오프 과다 방지: 실제 오프 일수로 N 복귀 유도 (최대 6오프 기준)
            // prevCode 3슬롯 범위를 넘는 4~6일 오프도 lastWorkedDate로 감지
            final daysSinceLastN = lastWorkedDate[uid] != null
                ? date.difference(lastWorkedDate[uid]!).inDays
                : 0;
            if (daysSinceLastN >= 6) {
              s += 100; // 6일 오프 → 매우 강하게 N 유도 (상한선 도달)
            } else if (daysSinceLastN >= 4) {
              s += 60; // 4~5일 오프 → 강하게 유도
            } else if (daysSinceLastN >= 3) {
              s += 30; // 3일 오프 (최소 2오프 직후) → 복귀 유도
            }
          } else {
            // 일반 멤버: 전체 슬롯 기반 목표
            final nightSlots = dayCount * progressRatio;
            final nightTarget = nightSlots / members.length;
            final nightDebt = nightTarget - (nightCount[uid] ?? 0);
            s += (nightDebt * 25).round();
          }
        }

        // ── 블록 연속성 보너스 (실제 병동의 핵심 패턴) ──
        // 3~4일 블록이 표준, 5일은 인원 부족 시 부득이하게만 허용
        if (isYesterday && prevCode0 == shiftCode) {
          final consec = consecutiveWork[uid] ?? 0;
          if (consec < 3) {
            s += 70; // 1~2일 연속 → 3일 블록 완성 강한 유도
          } else if (consec < 4) {
            s += 20; // 3일 연속 → 4일까지는 허용 (약한 보너스)
          } else {
            s -= 60; // 4일 이후 → 5일 연장은 강하게 억제 (최후의 수단)
          }
        }
        // 1일 오프 후 같은 유형 복귀 (O 삽입 블록: D D O D 등) — 부드러운 보너스
        if (!isYesterday && prevCode0 == null && prevCode1 == shiftCode) {
          s += 20;
        }
        // 오프 없이 다른 근무 유형으로 바로 전환 시 패널티 (D→E, E→N 직접 전환 등)
        if (isYesterday && prevCode0 != null && prevCode0 != shiftCode) {
          s -= 40; // 오프 없는 유형 전환 억제
        }

        // N 블록 2~3야 연속 강하게 유도 (일반 멤버)
        // 기존 블록 연속 보너스(+70)와 합산: 2야 +200, 3야 +150 → 경쟁자(최대 ~170) 압도
        if (isNight &&
            !m.member.nightDedicated &&
            isYesterday &&
            prevCode0 == 'N') {
          final consecN = consecutiveNight[uid] ?? 0;
          if (consecN == 1)
            s += 130; // 2야 → 합계 +200
          else if (consecN == 2)
            s += 80; // 3야까지 허용 → 합계 +150
        }
        // D/E 블록 진행 중 N 삽입 억제 (DDDN, EEEN 패턴 방지)
        // 2일 이상 연속 D/E 블록 중에는 N 시작 강하게 차단
        if (isNight &&
            !m.member.nightDedicated &&
            isYesterday &&
            (prevCode0 == 'D' || prevCode0 == 'E') &&
            (consecutiveWork[uid] ?? 0) > 1) {
          s -= 180;
        }

        // ── 생체리듬 흐름 보너스 (D→E→N 순방향 선호) ──
        // D→E: 순방향
        if (isEvening && isYesterday && prevCode0 == 'D') s += 30;
        // E→N 직접 전환 보너스 제거 — 오프 없는 E→N은 EEEN 패턴 유발
        // N→O→O→D/E: 표준 회복 후 복귀 (NOOD/NOOE) — 약한 보너스
        if ((isDay || isEvening) &&
            prevCode0 == null &&
            prevCode1 == null &&
            prevCode2 == 'N')
          s += 15;

        // 역방향 패널티
        // D→N 직접: E 건너뜀
        if (isNight && isYesterday && prevCode0 == 'D') s -= 35;
        // N→O→D: (NOD 소프트 — 하드는 위에서 차단)
        if (isDay && !isYesterday && prevCode0 == null && prevCode1 == 'N') {
          s -= (50 * patternPenaltyBoost).round();
        }

        // day_off 소프트 페널티
        // P1 custom(직접입력): 하드에 준하는 강한 소프트 (-200)
        // P2: 중간 소프트 (-150)
        // (P1 특수 타입은 hard로 이미 차단됨)
        final wPrio = wantedPriority[uid]?[dateStr];
        if (wPrio == 1) {
          s -= (200 * wantedBoost).round(); // P1 custom — 하드에 준하는 강한 소프트
        } else if (wPrio == 2) {
          s -= (150 * wantedBoost).round(); // P2 — 중간 소프트
        }

        // preferred_shift 보너스/페널티: 희망 근무 유형 반영
        final prefShiftId = preferredShiftMap[uid]?[dateStr];
        if (prefShiftId != null) {
          final prefPrio = preferredShiftPriority[uid]?[dateStr] ?? 3;
          if (prefShiftId == shiftType.id) {
            // 희망 유형 일치 — 우선 배정 (우선순위가 높을수록 강한 보너스)
            final bonus = prefPrio == 1
                ? 200
                : prefPrio == 2
                ? 150
                : 80;
            s += (bonus * wantedBoost).round();
          } else {
            // 희망 유형 불일치 — 다른 유형 배정 억제
            final penalty = prefPrio == 1
                ? 180
                : prefPrio == 2
                ? 100
                : 40;
            s -= (penalty * wantedBoost).round();
          }
        }

        // 상시 선호 근무 보너스/페널티 (preferredShifts: ['D','E','N'] 중 최대 2개)
        // preferredShiftBoost = scoringMultiplier('preferred_shift')로 우선순위 반영
        if (m.member.preferredShifts.isNotEmpty) {
          final liked = m.member.preferredShifts.contains(shiftCode);
          if (liked) {
            s += (80 * preferredShiftBoost).round();
          } else {
            s -= (50 * preferredShiftBoost).round();
          }
        }

        // 숙련도 배치 고려 (나이트 근무에 중급 이상 우선)
        // skillBalanceBoost = tuning.skillBalanceBoost * scoringMultiplier('skill_placement')
        if (considerSkill && isNight) {
          final skill = m.member.skillLevel;
          if (skill == 'mid' || skill == 'senior')
            s += (30 * skillBalanceBoost).round();
        }

        // 소프트 기피 패턴 페널티 (동일 가중치 -150, 우선순위는 사용자 설정 예정)
        // NOD (N→O→D, avoidNood=false일 때만; true이면 이미 하드 차단)
        if (!avoidNood && isDay && prevCode0 == null && prevCode1 == 'N') {
          s -= (150 * patternPenaltyBoost).round();
        }
        // NOOD (N→O→O→D, avoidNood=false일 때 소프트 페널티)
        if (!avoidNood &&
            isDay &&
            prevCode0 == null &&
            prevCode1 == null &&
            prevCode2 == 'N') {
          s -= (150 * patternPenaltyBoost).round();
        }
        // NOE (N→O→E, avoidNoe 설정 시; nodDisabled=true이면 이미 하드 차단됨)
        if (avoidNoe && isEvening && prevCode0 == null && prevCode1 == 'N') {
          s -= (150 * patternPenaltyBoost).round();
        }
        // NOOE (N→O→O→E)
        if (avoidNoe &&
            isEvening &&
            prevCode0 == null &&
            prevCode1 == null &&
            prevCode2 == 'N') {
          s -= (150 * patternPenaltyBoost).round();
        }
        // EOD (E→O→D)
        if (avoidEod && isDay && prevCode0 == null && prevCode1 == 'E') {
          s -= (150 * patternPenaltyBoost).round();
        }

        // ── 커스텀 소프트 룰 ──

        // soft member_shift_ban: 특정 멤버 특정 근무 기피 패널티 ('*'=전체)
        final softBannedCodes = softMemberShiftBans[uid];
        if (softBannedCodes != null &&
            (softBannedCodes.contains('*') ||
                softBannedCodes.contains(shiftCode))) {
          s -= 200;
        }

        // soft date_off: 날짜 오프 기피 패널티
        if (softForcedOffDates[uid]?.contains(dateStr) == true) s -= 200;

        // soft post_night_off: 나이트 N연속 후 오프 기피 패널티
        if (!m.member.nightDedicated) {
          for (final rule in softPostNightOffRules) {
            if ((consecutiveNight[uid] ?? 0) >= rule.consecutiveNights) {
              s -= 150;
            }
          }
        }

        // soft anti_pair: 쌍 배정 기피 패널티
        for (final pair in softAntiPairs) {
          final partner = uid == pair.a
              ? pair.b
              : uid == pair.b
              ? pair.a
              : null;
          if (partner == null) continue;
          if (pair.code != null && pair.code != shiftCode) continue;
          final partnerAssigned = shifts.any(
            (s) =>
                s['user_id'] == partner &&
                s['shift_date'] == dateStr &&
                s['shift_type_id'] == shiftType.id,
          );
          if (partnerAssigned) s -= 100;
        }

        // require_pair (hard): 강한 쌍 배정 선호 보너스
        for (final pair in hardRequirePairs) {
          final partner = uid == pair.a
              ? pair.b
              : uid == pair.b
              ? pair.a
              : null;
          if (partner == null) continue;
          if (pair.code != null && pair.code != shiftCode) continue;
          final partnerAssigned = shifts.any(
            (s) =>
                s['user_id'] == partner &&
                s['shift_date'] == dateStr &&
                s['shift_type_id'] == shiftType.id,
          );
          if (partnerAssigned) s += 200;
        }

        // require_pair (soft): 약한 쌍 배정 선호 보너스
        for (final pair in softRequirePairs) {
          final partner = uid == pair.a
              ? pair.b
              : uid == pair.b
              ? pair.a
              : null;
          if (partner == null) continue;
          if (pair.code != null && pair.code != shiftCode) continue;
          final partnerAssigned = shifts.any(
            (s) =>
                s['user_id'] == partner &&
                s['shift_date'] == dateStr &&
                s['shift_type_id'] == shiftType.id,
          );
          if (partnerAssigned) s += 80;
        }

        // ── 기본 소프트: 신규끼리만 같은 근무 방지 ──
        // 신규가 이미 배정된 근무에 또 신규를 배정하면 페널티 (올드 없을 시)
        {
          final alreadyJuniors = shifts
              .where(
                (sh) =>
                    sh['shift_date'] == dateStr &&
                    sh['shift_type_id'] == shiftType.id &&
                    members
                            .firstWhere(
                              (mm) => mm.userId == sh['user_id'],
                              orElse: () => members.first,
                            )
                            .member
                            .skillLevel ==
                        'junior',
              )
              .length;
          final alreadySeniors = shifts
              .where(
                (sh) =>
                    sh['shift_date'] == dateStr &&
                    sh['shift_type_id'] == shiftType.id &&
                    members
                            .firstWhere(
                              (mm) => mm.userId == sh['user_id'],
                              orElse: () => members.first,
                            )
                            .member
                            .skillLevel ==
                        'senior',
              )
              .length;

          if (m.member.skillLevel == 'junior' &&
              alreadyJuniors >= 1 &&
              alreadySeniors == 0) {
            s -= (90 * skillBalanceBoost).round(); // 신규끼리 뭉치기 방지
          }
          if (m.member.skillLevel == 'senior' && alreadyJuniors >= 1) {
            s += (60 * skillBalanceBoost).round(); // 신규 있는 근무에 올드 선호
          }
        }

        // ── skill_balance 커스텀 룰 ──
        for (final sr in skillBalanceRules) {
          if (sr.shiftCode != null && sr.shiftCode != shiftCode) continue;
          final alreadyJuniors = shifts
              .where(
                (sh) =>
                    sh['shift_date'] == dateStr &&
                    sh['shift_type_id'] == shiftType.id &&
                    members
                            .firstWhere(
                              (mm) => mm.userId == sh['user_id'],
                              orElse: () => members.first,
                            )
                            .member
                            .skillLevel ==
                        'junior',
              )
              .length;
          final alreadySeniors = shifts
              .where(
                (sh) =>
                    sh['shift_date'] == dateStr &&
                    sh['shift_type_id'] == shiftType.id &&
                    members
                            .firstWhere(
                              (mm) => mm.userId == sh['user_id'],
                              orElse: () => members.first,
                            )
                            .member
                            .skillLevel ==
                        'senior',
              )
              .length;
          // 신규 있고 올드 없으면 올드에 강한 보너스
          if (m.member.skillLevel == 'senior' &&
              alreadyJuniors >= 1 &&
              alreadySeniors == 0) {
            s += (120 * skillBalanceBoost).round();
          }
          // 신규가 있고 올드도 없는데 또 신규 배정 시 강한 페널티
          if (m.member.skillLevel == 'junior' &&
              alreadyJuniors >= 1 &&
              alreadySeniors == 0) {
            s -= (130 * skillBalanceBoost).round();
          }
        }

        // ── skill_condition 커스텀 룰 (베스트 에포트) ──
        // 해당 근무에 min_skill 이상 인원이 min_count 미만이면, 자격 있는
        // 후보에게 보너스를 줘 우선 배정한다. (하드는 강하게, 소프트는 약하게)
        for (final sc in skillConditionRules) {
          if (sc.shiftCode != shiftCode) continue;
          final qualifiedAssigned = shifts.where((sh) {
            if (sh['shift_date'] != dateStr ||
                sh['shift_type_id'] != shiftType.id) {
              return false;
            }
            final assignedMember = members.firstWhere(
              (mm) => mm.userId == sh['user_id'],
              orElse: () => members.first,
            );
            return _skillLevelNum(assignedMember.member.skillLevel) >=
                sc.minSkill;
          }).length;
          if (qualifiedAssigned >= sc.minCount) continue; // 이미 충족
          if (_skillLevelNum(m.member.skillLevel) >= sc.minSkill) {
            s += sc.isHard ? 220 : 90;
          }
        }

        return s;
      }

      eligible.sort((a, b) {
        final diff = score(b).compareTo(score(a)); // 높은 점수 우선
        return diff != 0 ? diff : (random.nextBool() ? 1 : -1);
      });

      // 실제 배정 + 카운터 갱신 (메인/보정 패스 공용)
      void assignMember(String uid) {
        shifts.add({
          'schedule_id': scheduleId,
          'team_id': teamId,
          'user_id': uid,
          'shift_date': dateStr,
          'shift_type_id': shiftType.id,
        });
        shiftCount[uid] = (shiftCount[uid] ?? 0) + 1;
        if (isDay) dayShiftCount[uid] = (dayShiftCount[uid]! + 1);
        if (isEvening) eveShiftCount[uid] = (eveShiftCount[uid]! + 1);
        if (isNight) {
          nightCount[uid] = (nightCount[uid] ?? 0) + 1;
          consecutiveNight[uid] = (consecutiveNight[uid] ?? 0) + 1;
          lastNightDate[uid] = date;
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
      }

      // 짝(anti_pair 하드)이 이미 오늘 같은 근무에 배정됐는지
      bool antiPairConflict(String uid) => antiPairs.any((pair) {
        final partner = uid == pair.a
            ? pair.b
            : (uid == pair.b ? pair.a : null);
        if (partner == null) return false;
        if (pair.code != null && pair.code != shiftCode) return false;
        return shifts.any(
          (s) =>
              s['user_id'] == partner &&
              s['shift_date'] == dateStr &&
              s['shift_type_id'] == shiftType.id,
        );
      });

      final target = min(minStaff, eligible.length);
      var assigned = 0;
      for (final m in eligible) {
        if (assigned >= target) break;
        final uid = m.userId;
        // 하드 anti_pair 동시 배정 방지: 짝이 이미 있으면 건너뛰고 다른 멤버로 채움.
        if (antiPairConflict(uid)) continue;
        assignMember(uid);
        assigned++;
        // prevCodes는 날짜 루프 끝에서 한 번만 슬라이딩 (shiftType별 X)
      }

      // ── 미충족 노출 ──
      // 최소 인원을 못 채워도 피로도(연속근무·연속야간·주간오프)를 완화하지 않는다.
      // 비는 칸은 그대로 두고 경고/미충원 일자로 노출만 한다.
      // (이전 달 시드로 첫날들이 연속근무·주간오프에 묶여 비는 건 의도된 동작 —
      //  피로도 위반보다 미충원이 낫다는 방침.)
      if (assigned < minStaff) {
        warnings.add(
          '$dateStr ${shiftType.name}: 최소 인원($minStaff명) 미충족 — $assigned명 배정',
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
      // 오프 멤버의 consecutiveNight 리셋 (assignment 루프에서 D/E는 이미 0 처리,
      // 오프(null)는 누락돼 카운터가 비정상 유지되는 버그 수정)
      if (todayCode != 'N') {
        consecutiveNight[uid] = 0;
      }
      // [어제, 2일전, 3일전] 슬라이딩
      prevCodes[uid] = [todayCode, prevCodes[uid]![0], prevCodes[uid]![1]];
    }
  }

  // ── skill_condition 사후 검증 (하드만 warning에 추가) ──
  if (hardSkillConditions.isNotEmpty) {
    for (int d = 0; d < dayCount; d++) {
      final date = start.add(Duration(days: d));
      final dateStr = fmt(date);
      for (final cond in hardSkillConditions) {
        // 해당 shiftType 찾기
        final st = shiftTypes.where((t) {
          final code = isNightType(t)
              ? 'N'
              : isEveningType(t)
              ? 'E'
              : isDayType(t)
              ? 'D'
              : t.code.toUpperCase();
          return code == cond.shiftCode;
        }).toList();
        if (st.isEmpty) continue;
        final stId = st.first.id;
        // 해당 날짜·근무에 배정된 멤버 중 min_skill 이상인 수
        final assignedMemberIds = shifts
            .where(
              (s) => s['shift_date'] == dateStr && s['shift_type_id'] == stId,
            )
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
          .where(
            (s) =>
                s['shift_date'] == dateStr &&
                s['shift_type_id'] == shiftType.id,
          )
          .map((s) => s['user_id'] as String)
          .toList();
      if (assignedUids.isEmpty) continue;

      final assignedMembers = assignedUids
          .map(
            (uid) => members.firstWhere(
              (m) => m.userId == uid,
              orElse: () => members.first,
            ),
          )
          .toList();

      // 숙련도 미설정 멤버가 한 명이라도 있으면 판단 불가 → 건너뜀
      final hasUnknownSkill = assignedMembers.any(
        (m) => m.member.skillLevel == null,
      );
      if (hasUnknownSkill) continue;

      final hasJunior = assignedMembers.any(
        (m) => m.member.skillLevel == 'junior',
      );
      final hasSeniorOrMid = assignedMembers.any(
        (m) => m.member.skillLevel == 'senior' || m.member.skillLevel == 'mid',
      );

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
  final shiftTypeCodeMap = {for (final t in shiftTypes) t.id: t.code};
  // userId → displayName 맵
  final uidToName = {for (final m in members) m.userId: m.displayName};

  int wantedSatisfied = 0;
  // name → 미반영 항목 목록 (삽입 순서 유지)
  final unsatisfiedByName = <String, List<String>>{};

  for (final e in wantedEntries) {
    final uid = e.userId;
    final name = uidToName[uid] ?? uid;
    final dateStr = fmt(e.wantedDate);
    final mmdd = dateStr.substring(5);
    final prioLabel = e.priority == 1 ? '1순위' : '2순위';

    if (e.shiftTypeId != null) {
      // preferred_shift: 해당 날짜에 희망 근무 유형으로 배정됐으면 만족
      final assignedShiftId = shifts
          .where((s) => s['user_id'] == uid && s['shift_date'] == dateStr)
          .map((s) => s['shift_type_id'] as String?)
          .firstOrNull;
      if (assignedShiftId == e.shiftTypeId) {
        wantedSatisfied++;
      } else {
        final typeLabel = shiftTypeCodeMap[e.shiftTypeId] ?? '근무';
        unsatisfiedByName
            .putIfAbsent(name, () => [])
            .add('$mmdd ($typeLabel·$prioLabel)');
      }
    } else {
      // day_off: 해당 날짜에 시프트 없으면(오프) 만족
      final hasShift = shifts.any(
        (s) => s['user_id'] == uid && s['shift_date'] == dateStr,
      );
      if (!hasShift) {
        wantedSatisfied++;
      } else {
        unsatisfiedByName
            .putIfAbsent(name, () => [])
            .add('$mmdd (오프·$prioLabel)');
      }
    }
  }

  // 이름\t항목1, 항목2, ... 형식으로 직렬화 (UI에서 탭으로 분리해 표시)
  final wantedUnsatisfied = unsatisfiedByName.entries
      .map((entry) => '${entry.key}\t${entry.value.join(', ')}')
      .toList();
  final wantedTotal = wantedEntries.length;

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
int _skillLevelNum(String? level) {
  switch (level) {
    case 'junior':
      return 1;
    case 'mid':
      return 2;
    case 'senior':
      return 3;
    default:
      return 0;
  }
}

/// 숙련도 숫자 → 한국어 라벨
String _skillLevelLabel(int num) {
  switch (num) {
    case 1:
      return '신규';
    case 2:
      return '중간';
    case 3:
      return '올드';
    default:
      return '숙련도 $num';
  }
}

class _FeedbackGenerationTuning {
  const _FeedbackGenerationTuning({
    this.wantedBoost = 1.0,
    this.patternPenaltyBoost = 1.0,
    this.skillBalanceBoost = 1.0,
    this.feedbackCount = 0,
  });

  final double wantedBoost;
  final double patternPenaltyBoost;
  final double skillBalanceBoost;
  final int feedbackCount;

  bool get hasSignal => feedbackCount > 0;
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
  }) : softViolations = softViolations ?? {},
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
