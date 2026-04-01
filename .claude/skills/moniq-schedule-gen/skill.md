---
name: moniq-schedule-gen
description: "근무표 자동 생성 알고리즘. 제약 조건 기반 스케줄링, 백트래킹, 공정성 최적화. '근무표 생성', '스케줄 알고리즘' 시 사용."
---

# OnorOff Schedule Gen — 근무표 생성 알고리즘

## 알고리즘 개요

제약 만족 문제(CSP) 기반 근무표 생성. 하드 제약을 만족하면서 소프트 제약(공정성)을 최적화한다.

## 입력 (Input)

```dart
class ScheduleGenerationInput {
  final DateRange period;           // 시작일~종료일
  final List<TeamMember> members;   // 팀 멤버 목록
  final List<ShiftType> shiftTypes; // 활성 근무 유형
  final List<ShiftRule> rules;      // 활성 룰
  final List<DayOffRequest>? dayOffRequests; // 선택: 희망 휴무
}
```

## 출력 (Output)

```dart
class ScheduleGenerationResult {
  final List<ShiftAssignment> assignments;  // 배정 결과
  final ValidationSummary validation;        // 검증 요약
  final bool isComplete;                     // 모든 슬롯 배정 여부
}

class ShiftAssignment {
  final DateTime date;
  final String userId;
  final String shiftTypeId;
}

class ValidationSummary {
  final List<Conflict> conflicts;        // 충돌 목록
  final List<Shortage> shortages;        // 인원 부족
  final List<RuleViolation> violations;  // 룰 위반
}
```

## 하드 제약 (반드시 만족)

1. **최소 인원**: 근무 유형별 최소 인원을 반드시 채운다
2. **최대 연속 근무일**: 초과 불가
3. **야간 후 휴식**: 야간 근무 후 최소 휴식 시간 보장
4. **동시 배정 금지**: 한 사람이 같은 날 두 근무에 배정되지 않음

## 소프트 제약 (가능한 만족, 공정성)

1. **근무 횟수 균등**: 멤버 간 총 근무 횟수 편차 최소화
2. **야간 근무 균등**: 야간 근무 횟수 편차 최소화
3. **주말 근무 균등**: 주말 근무 횟수 편차 최소화
4. **희망 휴무 반영**: 가능하면 희망 휴무를 반영

## 알고리즘 절차

```
1. 초기화
   - 기간 내 모든 날짜 생성
   - 날짜별 필요 슬롯 계산 (근무 유형 × 최소 인원)
   - 멤버별 제약 상태 초기화

2. 그리디 배정 (1차)
   - 날짜 순회 (앞에서부터)
   - 각 날짜의 각 근무 유형에 대해:
     a. 배정 가능한 멤버 필터링 (하드 제약 위반자 제외)
     b. 소프트 제약 기반 점수 계산
     c. 점수가 가장 높은(가장 적게 배정된) 멤버 배정
     d. 멤버 상태 업데이트

3. 백트래킹 (2차, 배정 실패 시)
   - 배정 불가 슬롯 발견 시
   - 이전 배정을 해제하고 다른 조합 시도
   - 최대 시도 횟수 제한 (성능 보장)

4. 검증
   - 모든 배정에 대해 하드 제약 재검증
   - 소프트 제약 위반 사항 보고
   - 미배정 슬롯 보고

5. 결과 생성
   - ShiftAssignment 목록 생성
   - ValidationSummary 생성
```

## 점수 함수

```dart
double calculateScore(TeamMember member, DateTime date, ShiftType type) {
  double score = 100.0;

  // 근무 횟수가 적을수록 높은 점수
  score -= member.totalShiftCount * 5;

  // 야간 근무 횟수가 적을수록 높은 점수 (야간인 경우)
  if (type.isNight) {
    score -= member.nightShiftCount * 10;
  }

  // 희망 휴무일이면 낮은 점수
  if (member.dayOffRequests.contains(date)) {
    score -= 50;
  }

  return score;
}
```

## 파일 구조

```
lib/domain/
├── models/
│   ├── schedule_input.dart
│   ├── schedule_result.dart
│   ├── shift_assignment.dart
│   └── validation_summary.dart
├── usecases/
│   ├── generate_schedule_usecase.dart
│   └── validate_schedule_usecase.dart
├── rules/
│   ├── rule_engine.dart
│   ├── constraints/
│   │   ├── min_staff_constraint.dart
│   │   ├── max_consecutive_days_constraint.dart
│   │   ├── night_rest_constraint.dart
│   │   └── no_double_shift_constraint.dart
│   └── validators/
│       ├── schedule_validator.dart
│       └── fairness_calculator.dart
└── providers/
    └── schedule_providers.dart
```

## 테스트 시나리오

1. **기본 케이스**: 5명 멤버, 7일, Day/Night 2교대 → 정상 배정
2. **인원 부족**: 멤버 수 < 필요 인원 → shortage 보고
3. **제약 충돌**: 모든 멤버가 야간 제한 도달 → 백트래킹 또는 violation 보고
4. **공정성**: 30일 배정 후 멤버 간 근무 횟수 편차 ≤ 2
5. **희망 휴무**: 휴무 요청 반영 확인
