---
name: schedule-engine
description: "교대 근무 스케줄 자동 생성 알고리즘을 구현한다. '스케줄 알고리즘', '자동 배정', '근무표 생성 엔진', '제약 조건 솔버' 요청 시 사용."
---

# Schedule Engine — 스케줄 생성 알고리즘

## 목적
제약 조건 기반으로 교대 근무 스케줄을 자동 생성하고, 결과를 검증한다.

## 워크플로우

### Step 1: 입력 수집
```
- period: { startDate, endDate }
- members: List<Member>         // 대상 근무자
- shiftTypes: List<ShiftType>   // Day, Evening, Night, Off
- rules: ShiftRules             // 제약 조건
  ├── minStaffing: Map<ShiftType, int>    // 유형별 최소 인원
  ├── maxConsecutiveDays: int             // 최대 연속 근무일
  ├── maxMonthlyShifts: int              // 월 최대 근무 횟수
  ├── maxMonthlyNightShifts: int         // 월 최대 야간 횟수
  └── minRestAfterNight: int             // 야간 후 최소 휴식(일)
```

### Step 2: Hard Constraints 적용
반드시 충족해야 하는 조건:
1. **최소 인원**: 각 날짜의 각 근무 유형에 최소 인원 배정
2. **최대 연속 근무**: N일 초과 연속 근무 금지
3. **야간 후 휴식**: 야간 근무 다음날은 최소 N일 Off
4. **월 최대 근무**: 월간 총 근무 횟수 제한
5. **월 최대 야간**: 월간 야간 근무 횟수 제한

### Step 3: 알고리즘 (MVP — Greedy + Backtracking)
```
1. 날짜별 순회 (startDate → endDate)
2. 각 날짜에서 근무 유형별 필요 인원 계산
3. 배정 가능한 근무자 필터링 (hard constraints 기준)
4. 우선순위 정렬:
   - 현재까지 근무 횟수가 적은 사람 우선 (공정성)
   - 동일 근무 유형 연속 선호 (안정성)
5. 배정 시도 → 실패 시 백트래킹
6. 모든 날짜 배정 완료 또는 실패 리포트
```

### Step 4: 검증
생성 결과를 검증하고 리포트 생성:

```dart
class ScheduleValidation {
  final bool isValid;
  final List<Conflict> conflicts;          // 충돌
  final List<UnderstaffedDay> understaffed; // 인력 부족
  final List<RuleViolation> violations;     // 룰 위반
  final FairnessReport fairness;            // 공정성 통계
}
```

### Step 5: 출력 구조
```dart
class GeneratedSchedule {
  final String periodStart;
  final String periodEnd;
  final List<ShiftAssignment> assignments;
  final ScheduleValidation validation;
}

class ShiftAssignment {
  final String userId;
  final DateTime date;
  final String shiftTypeId;
}
```

## 구현 위치
- **Dart (Domain Layer)**: `lib/domain/scheduling/`
  - `schedule_generator.dart` — 메인 알고리즘
  - `schedule_validator.dart` — 검증 로직
  - `scheduling_models.dart` — 입출력 모델
- **Edge Function**: `supabase/functions/generate-schedule/`
  - 서버사이드 실행 버전 (대규모 팀용)

## 출력 규칙
- 생성 실패 시 구체적 실패 원인을 리포트한다
- 알고리즘은 타임아웃을 설정한다 (MVP: 30초)
- 부분 성공 시 성공한 부분 + 실패 원인을 함께 반환한다
- 공정성 통계를 항상 포함한다 (멤버별 근무 횟수, 야간 횟수)
