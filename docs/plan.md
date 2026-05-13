# Moniq 듀티 규칙 & 스케줄 생성 구현 계획

> 최종 업데이트: 2026-03-29
> 상세 규칙 레퍼런스: `docs/duty_rules.md`

---

## 핵심 문제

**대부분의 UI 규칙이 알고리즘에 전혀 반영되지 않음.**
현재 `_generateShifts()`에서 실제로 사용하는 규칙:
- `max_consecutive_days` — 키 불일치 버그 (`max_consecutive_work_days`로 저장됨)
- `max_monthly_shifts`
- `max_monthly_night_shifts`
- 하드코딩된 min_staff=1

나머지 모든 규칙(ND/NE/ED, NOD, 숙련도, 원티드, 나이트 전담 등)은 **저장만 되고 생성에 미반영**.

---

## 구현 우선순위

```
Phase A: DB migration
Phase B: 알고리즘 강화 — 하드 제약
Phase C: 알고리즘 강화 — 소프트 스코어링 + 피드백 가중치
Phase D: 팀 규칙 UI 보완 (min_staffing 화면 접근성 개선)
Phase E: 멤버 속성 UI (night_exempt, day_only, night_dedicated, skill_level int 등)
Phase F: 기피/원티드 우선순위 UI 개선 (drag-to-reorder) ← 이전 Phase G
Phase G: 커스텀 룰 UI (자연어 입력 → AI 파싱) [추후]
Phase H: AI freeform 룰 평가 + 충돌 리포트 [추후]

> ~~Phase F: 원티드 제출 화면~~ → 이미 구현됨, 제외
```

---

## Phase A — DB Migration

**파일:** `supabase/migrations/[timestamp]_duty_rules_v2.sql`

```sql
-- team_members 컬럼 추가
ALTER TABLE team_members
  ADD COLUMN IF NOT EXISTS night_exempt BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS day_only BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS night_dedicated BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS sub_team TEXT,
  ADD COLUMN IF NOT EXISTS role_type TEXT DEFAULT 'staff',
  ADD COLUMN IF NOT EXISTS skill_level_num INT;
-- ↑ 기존 skill_level(text)은 유지, 숫자용 컬럼 별도 추가

-- custom_rules 테이블
CREATE TABLE IF NOT EXISTS custom_rules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
  member_id UUID REFERENCES team_members(id) ON DELETE SET NULL,
  rule_type TEXT NOT NULL,        -- 'member_shift_ban', 'anti_pair', 'freeform' 등
  rule_value JSONB NOT NULL,      -- DSL 구조체
  original_text TEXT,             -- 유저가 입력한 자연어 원문
  parsed_dsl JSONB,               -- AI 파싱 결과 (null이면 freeform)
  priority TEXT DEFAULT 'soft' CHECK (priority IN ('hard', 'soft')),
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- schedule_feedback 테이블
CREATE TABLE IF NOT EXISTS schedule_feedback (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  schedule_id UUID NOT NULL REFERENCES schedules(id) ON DELETE CASCADE,
  team_id UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
  overall_rating INT CHECK (overall_rating BETWEEN 1 AND 5),
  rule_ratings JSONB,
  -- { "wanted": 1/-1, "avoid_pattern": 1/-1, "skill_balance": 1/-1 }
  notes TEXT,
  created_by UUID REFERENCES users(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(schedule_id)
);
```

---

## Phase B — 알고리즘 강화: 하드 제약

**파일:** `lib/presentation/viewmodels/schedule_generation_viewmodel.dart`

`_generateShifts()` 전면 재작성. 추가할 하드 제약 체크:

```
[사전처리]
- 규칙 키 로딩 통일 (max_consecutive_work_days 키 불일치 수정)
- night_dedicated 멤버 (member 속성) → 나이트만 eligible
- night_exempt 멤버 → 나이트 eligible 제외
- day_only 멤버 → 데이만 eligible

[날짜별 eligible 필터링]
1. ND: 전날 나이트 → 오늘 데이 불가 (no_night_then_day=true 시)
2. NE: 전날 나이트 → 오늘 이브닝 불가 (no_night_then_evening=true 시)
3. ED: 전날 이브닝 → 오늘 데이 불가 (no_evening_then_day=true 시)
4. NOD: 2일 전 나이트 + 전날 오프 → 오늘 데이 불가 (nod_disabled=true 시)
5. max_consecutive_work_days: 연속 근무 >= max → 제외
6. max_consecutive_night_shifts: 연속 나이트 >= max → 나이트 제외
7. min_weekly_off_days: 최근 7일 오프 < min → 근무 제외 (강제 오프)
8. 커스텀 하드 룰: member_shift_ban, anti_pair 등

[배정 수량 결정]
- min_staffing[shift_type_id] 적용 (하드코딩 1 대신 실제 규칙 사용)
- max_staffing[shift_type_id] 적용
- skill_level_staffing 커스텀 룰: 고숙련 멤버 우선 포함
```

---

## Phase C — 알고리즘 강화: 소프트 스코어링

```dart
int _calcScore(member, date, shiftType, rules, wantedRequests, feedback) {
  int score = 0;

  // Priority 1: 원티드/오프 요청
  if (wantedRequests[member.id]?[date]?.shiftType == shiftType) score += 100;
  if (wantedRequests[member.id]?[date]?.type == 'annual_leave') score += 90;

  // Priority 2: 기피 패턴 회피
  if (_isNOOD(member, date)) score -= 60 * avoidWeight;
  if (_isNOE(member, date))  score -= 50 * avoidWeight;
  if (_isEOD(member, date))  score -= 40 * avoidWeight;

  // Priority 3: 숙련도 밸런싱 (고숙련 부족한 근무에 고숙련 배정)
  if (considerSkill && _needsSkill(shiftType) && member.skillLevelNum >= 4) score += 30;

  // Priority 4: 공평 배분
  score += (maxShifts - member.currentShiftCount) * 2;  // 근무 적을수록 가산

  // Priority 5: 커스텀 소프트 룰
  for (var rule in softCustomRules) score += _evalCustomRule(rule, member, date);

  // 피드백 보정 (이전 달)
  score = _applyFeedbackAdjustment(score, category, feedback);

  return score;
}
```

---

## Phase D — 팀 규칙 UI 통합

**문제:** `rules_screen.dart` (`/teams/:teamId/rules`)는 라우터에 등록돼 있으나 `team_detail_screen.dart`에서 진입할 수 없는 **데드 스크린**. `team_detail_screen`은 `schedule-rules`만 연결하고 있음.

**해결:** `rules_screen.dart`의 내용(min/max staffing, 월간 제약, 야간 후 휴식)을 `team_settings_screen.dart`의 고정 규칙 섹션에 통합. `rules_screen.dart` 제거.

**수정 파일:**
- `lib/presentation/screens/team/team_settings_screen.dart` — 아래 항목 추가:
  - 근무 유형별 최소 인원 (shift_type별 NumberInput)
  - 근무 유형별 최대 인원 (shift_type별 NumberInput, 0=무제한)
  - 월 최대 근무 횟수
  - 월 최대 야간 횟수
- `lib/presentation/router/app_router.dart` — `/teams/:teamId/rules` 라우트 제거
- `lib/presentation/screens/team/rules_screen.dart` — 파일 삭제

---

## Phase E — 멤버 속성 UI

**파일:** `lib/presentation/screens/team/members_screen.dart`

멤버 편집 bottom sheet에 추가:
- 숙련도 (int 입력, 0=미설정)
- 야간 제외 토글 (`night_exempt`) — 나이트 완전 제외
- 데이 전담 토글 (`day_only`) — 데이만 배정
- 나이트 전담 토글 (`night_dedicated`) — 나이트만 배정 (이전: schedule_rules_screen의 목록에서 이동)
- 서브팀 텍스트 (`sub_team`)
- 역할 구분 드롭다운 (staff/charge/acting)

---

## Phase F — 기피/원티드 우선순위 UI

**파일:** `lib/presentation/screens/team/schedule_rules_screen.dart`

- 기피 패턴: NOOD/NOE/EOD 각각 On/Off 토글 + drag-to-reorder
- 원티드 우선순위: drag-to-reorder (법정휴가/나이트전담/휴무배려/균등배분)
- **나이트 인터벌 항목 제거**
- **나이트 전담 간호사 목록 제거** (멤버 속성 `night_dedicated`로 이동)

---

## Phase G — 커스텀 룰 UI (추후)

**신규 파일:** `lib/presentation/screens/team/custom_rules_screen.dart`

- 자연어 텍스트 입력창 (최대 200자)
- 저장 → Claude API 호출 → DSL 변환 → DB 저장
- DSL 변환 실패 시 freeform으로 저장
- 저장된 룰 목록 표시 (수정/삭제, active 토글)

---

## Phase H — AI 연동 (추후)

- 커스텀 룰 파싱 (자연어 → DSL, 룰 저장 시 1회)
- freeform 룰 배치 평가 (생성 시, 관련 배정만 전달)
- 충돌 리포트 (hard violation 심각 시)

---

## 핵심 수정 파일

| 파일 | 변경 |
|---|---|
| `supabase/migrations/` | 신규 migration |
| `lib/data/models/team_member_model.dart` | night_exempt, day_only, night_dedicated, sub_team, role_type, skill_level_num(int) |
| `lib/data/models/custom_rule_model.dart` | 신규 Freezed |
| `lib/data/models/schedule_feedback_model.dart` | 신규 Freezed |
| `lib/data/datasources/shift_remote_data_source.dart` | wanted/custom_rules/feedback CRUD 추가 |
| `lib/data/repositories/shift_repository.dart` | 새 메서드 |
| `lib/presentation/viewmodels/schedule_generation_viewmodel.dart` | **`_generateShifts` 전면 재작성** |
| `lib/presentation/screens/team/rules_screen.dart` | min_staffing 접근성 개선 |
| `lib/presentation/screens/team/members_screen.dart` | 멤버 속성 UI (night_dedicated 포함) |
| `lib/presentation/screens/team/schedule_rules_screen.dart` | 나이트 인터벌 제거, 나이트전담 목록 제거, drag-to-reorder |

---

## AI 사용 범위 (기술 상세)

| 기능 | AI 사용 | 시점 | 토큰 예상 |
|---|---|---|---|
| A~E 규칙 평가 | ❌ 미사용 | — | — |
| 커스텀 룰 DSL 변환 (성공) | 🤖 1회 | 룰 저장 시 | ~400 토큰/룰 |
| 커스텀 룰 freeform 평가 | 🤖 매 생성 | 스케줄 생성 시 | ~700 토큰 (freeform 3개 기준) |
| violation 리포트 | ❌ 미사용 | — | — |
| 피드백 가중치 보정 | ❌ 미사용 | — | — |

**근무표 생성을 AI로 하지 않는 이유:**
- 하드 룰(ND 금지, min_staffing 등) 준수를 보장할 수 없음 (LLM 할루시네이션)
- 위반 발생 시 수정 방법 없음 — 코드 알고리즘은 하드 룰을 100% 보장
- 비용: 간호사 20명 × 30일 기준 ~$0.05~0.15/회로 저렴하나, 신뢰성 문제로 채택 불가

**freeform 룰의 구조적 제약:**
- freeform은 생성 도중 제약 조건으로 사용 불가 (코드 평가 불가)
- 생성 완료 후 AI가 위반 판단 → 위반 발견 시 재생성해도 알고리즘이 룰을 모름
- **결론: freeform은 소프트 전용 강제.** `priority` 필드는 freeform일 때 `'soft'` 고정, UI에서 hard 선택 비활성화

**freeform 토큰 최소화 전략:**
- 전체 스케줄 전송 X → 해당 룰 관련 멤버의 배정만 (1~3명 × 30일)
- 여러 freeform 룰을 단일 API 호출로 배치 평가

---

## Phase 스케줄 버저닝 & 피드백 반영

스케줄은 버전별로 관리됩니다 (spec.md 기준).

### 버전 관리 (schedules 테이블)
- `version_no`: v1 = 최초 퍼블리시, v2+ = 재퍼블리시
- `previous_version_id`: 이전 버전 참조 (롤백용)
- `status`: draft(생성 완료, 미퍼블리시) / published

### Violation 리포트 (생성 완료 후 즉시 표시)

```dart
class ViolationReport {
  final List<HardViolation> hardViolations;    // 날짜/멤버 경고
  final SoftViolationSummary softSummary;      // % 요약
}

class HardViolation {
  final DateTime date;
  final String? memberId;
  final String ruleType;    // 'min_staffing', 'nd_disabled', 'night_exempt', ...
  final String message;     // 한국어 설명
}

class SoftViolationSummary {
  final int wantedTotal;
  final int wantedSatisfied;         // 원티드 반영률
  final Map<String, int> avoidPatternUnsatisfied;  // NOOD/NOE/EOD 미해결 수
  final int skillBalanceUnsatisfied; // 숙련도 조건 미충족 일수
  final int customSoftUnsatisfied;   // 커스텀 소프트 룰 미반영 수
}
```

### 피드백 반영 (`schedule_feedback` 테이블)

피드백은 퍼블리시된 버전당 1건 수집. 다음 달 생성 시 `_applyFeedbackAdjustments()` 호출.

```dart
Map<String, double> _applyFeedbackAdjustments(
  Map<String, double> baseWeights,
  ScheduleFeedback? feedback,
) {
  if (feedback == null) return baseWeights;
  final ratings = feedback.ruleRatings;
  // rating: 1(만족), 0(미평가), -1(불만)
  // 불만 시 해당 가중치 ×1.2, 만족 시 유지
  return {
    'wanted':        baseWeights['wanted']!        * (ratings['wanted']        == -1 ? 1.2 : 1.0),
    'avoid_pattern': baseWeights['avoid_pattern']! * (ratings['avoid_pattern'] == -1 ? 1.2 : 1.0),
    'skill_balance': baseWeights['skill_balance']! * (ratings['skill_balance'] == -1 ? 1.2 : 1.0),
  };
}
```

---

## 검증 체크리스트

- [ ] Phase A: Supabase 대시보드 신규 테이블/컬럼 확인
- [ ] Phase B: 나이트 배정 멤버 → 다음날 데이 미배정 (ND 룰)
- [ ] Phase B: night_exempt 멤버 → 나이트 미배정
- [ ] Phase B: min_staffing 설정값대로 배정 수 적용
- [ ] Phase B: 키 불일치 버그 수정 확인
- [ ] Phase C: 원티드 요청 멤버 우선 배정
- [ ] Phase C: 숙련도 높은 멤버 우선 배정 (consider_skill_level ON 시)
- [ ] Phase D~E: 팀 설정 변경 → 알고리즘 반영 확인
- [ ] Phase E: night_dedicated 멤버 → 나이트만 배정 확인
- [ ] 피드백: 저장 → 다음 달 생성 시 가중치 변경 확인
