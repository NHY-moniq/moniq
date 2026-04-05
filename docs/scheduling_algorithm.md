# 스케줄 생성 알고리즘 명세

> 파일: `lib/presentation/viewmodels/schedule_generation_viewmodel.dart` — `_generateShifts()`
> 기준일: 2026-04-05

---

## 개요

날짜를 1일부터 말일까지 순회하면서, 각 근무 유형(D/E/N)에 대해:
1. **하드 제약**으로 배정 불가 멤버를 먼저 걸러내고
2. **소프트 스코어**로 남은 멤버를 정렬해
3. 최소 인원만큼 순서대로 배정

배정되지 않은 멤버는 자동으로 **Off**가 됩니다.

---

## 1. 하드 제약 (Hard Constraints)

위반 시 해당 멤버는 해당 날짜·근무에 **배정 자체가 불가능**합니다.

### 1-1. 멤버 속성

| 속성 | 설명 |
|---|---|
| `night_dedicated` (나이트 전담) | N 근무만 배정 가능. D/E 불가 |
| `night_exempt` (야간 제외) | N 배정 불가. D/E만 가능 |
| `day_only` (데이 전용) | D 근무만 배정 가능. E/N 불가 |

### 1-2. 패턴 금지 (시퀀스 룰)

아래 표에서 `prev0` = 어제 근무코드, `prev1` = 2일전 근무코드, `null` = Off

| 패턴 | 조건 | 설명 | 하드코딩 여부 |
|---|---|---|---|
| **N → D** | prev0=N, 오늘=D | 나이트 다음날 데이. 시간상 물리적으로 불가 | 항상 금지 (코드 고정) |
| **N → E** | prev0=N, 오늘=E | 나이트 다음날 이브닝 | DB 설정 (`no_night_then_evening`, 기본 ON) |
| **E → D** | prev0=E, 오늘=D | 이브닝 다음날 데이 | DB 설정 (`no_evening_then_day`, 기본 ON) |
| **NOD** | prev1=N, prev0=Off, 오늘=D | 나이트→오프→데이 패턴 | DB 설정 (`nod_disabled`, 기본 ON) |
| **N→Off→D** | prev1=N, prev0=Off, 오늘=D | 나이트→오프→데이 직접 복귀 | DB 설정 (`nod_disabled`, 기본 ON) + 소프트 -50 중복 적용 |

> **N→Off→근무 규칙 설명**: 나이트 근무 후 최소 2일은 쉬어야 합니다. N 다음날은 N→D/E 금지로 이미 막히고, 이틀 후(N→Off→Work)도 막아서 나이트 후 반드시 이틀 연속 오프가 됩니다.

### 1-3. 누적 제한

| 규칙 | DB 키 | 기본값 |
|---|---|---|
| 최대 연속 근무일 | `max_consecutive_work_days.days` | 5일 |
| 최대 연속 야간 | `max_consecutive_night_shifts.days` | 3일 |
| 월 최대 근무 횟수 | `max_monthly_shifts.count` | 25회 |
| 월 최대 야간 횟수 | `max_monthly_night_shifts.count` | 8회 |
| 주 최소 오프일 | `min_weekly_off_days.days` | 2일 |

> **주 최소 오프 계산 방식**: 최근 7일 슬라이딩 윈도우 기준. 7일 중 근무일이 `(7 - minWeeklyOffDays)` 이상이면 오늘은 오프 강제.

### 1-4. 희망 휴무 (Wanted Request)

해당 날짜에 off_request를 등록한 멤버는 eligible에서 제거됩니다. 즉, 희망 휴무일에는 근무 배정이 불가능합니다.

### 1-5. 커스텀 하드 룰 (Custom Rules)

`custom_rules` 테이블에서 `is_active=true` + `priority='hard'`인 규칙들이 eligible 필터에 추가됩니다.

| DSL 유형 | 동작 | 예시 |
|---|---|---|
| `member_shift_ban` | 특정 멤버가 특정 근무코드에 배정되지 않도록 차단 | `rule_value: {member_id, shift_code: 'N'}` |
| `date_off` | 특정 날짜에 해당 멤버를 오프로 강제 | `rule_value: {member_id, dates: ['2026-04-15']}` |
| `post_night_off` | 연속 야간 N회 달성 시 해당 멤버를 즉시 모든 근무에서 차단 (강제 오프) | `rule_value: {consecutive_nights: 3, min_off_days: 2}` |
| `anti_pair` (hard) | 지정된 두 멤버가 같은 날 같은 근무에 동시 배정 금지 | `rule_value: {member_id_a, member_id_b, shift_code?}` |

---

## 2. 커스텀 룰 (Custom Rules)

> DB: `custom_rules` / Edge Function: `parse-custom-rule` / 화면: 팀 상세 → 커스텀 규칙

자연어 입력 → `parse-custom-rule` 1회 호출 → DSL JSON 저장. 구조화 불가 시 `freeform`으로 폴백 (soft 전용).

### DSL 유형

| rule_type | priority 기본값 | rule_value 키 | 알고리즘 적용 | 예시 |
|---|---|---|---|---|
| `member_shift_ban` | hard | `member_id`, `shift_code` | eligible 차단 | "홍길동은 나이트 안 서요" |
| `anti_pair` | soft | `member_id_a`, `member_id_b`, `shift_code?` | hard: eligible 차단 / soft: -100점 | "A와 B는 같은 나이트 금지" |
| `require_pair` | soft | `member_id_a`, `member_id_b`, `shift_code?` | 파트너 배정 시 +80점 | "신입 A는 선배 B와 같은 데이" |
| `date_off` | hard | `member_id`, `dates[]` | eligible 차단 | "C는 4/15~16 오프" |
| `post_night_off` | hard | `consecutive_nights`, `min_off_days` | N연속 달성 시 eligible 차단 | "나이트 3연속 후 2일 오프" |
| `skill_condition` | hard | `shift_code`, `min_skill`, `min_count` | 생성 후 사후 검증 → violation 경고 | "데이에 숙련도 3 이상 1명 필수" |
| `freeform` | soft (강제) | `description` | 생성 미반영 (향후 AI 사후 평가) | 복잡한 조건 |

### RLS

- **SELECT**: 같은 팀 멤버 (`is_deleted = false`)
- **INSERT / UPDATE / DELETE**: 팀 관리자 (`role = 'admin'`)

---

## 3. 소프트 스코어 (Soft Scoring)

하드 제약을 통과한 eligible 멤버들을 점수로 정렬해 상위 N명(최소 인원)을 배정합니다. 점수가 같으면 랜덤(seed=42).

| 항목 | 가중치 | 조건 |
|---|---|---|
| **공평 배분** | `(월최대 - 현재근무수) × 2` | 근무 적을수록 우선 |
| **야간 균등 배분** | `(야간최대 - 현재야간수) × 8` | N 배정 시만 적용. 야간 횟수 적은 멤버 강하게 우선 |
| **블록 연속성** | `+70` | 어제와 오늘 근무코드가 같을 때 (D→D, E→E, N→N) |
| **Off 클러스터링** | `-50` | 어제=Off이고 2일전=근무(N 제외)인 경우 → 아직 휴식 중으로 간주, 오늘 배정 비선호 |
| **생체리듬: D→E 순방향** | `+45` | 어제=D, 오늘=E |
| **생체리듬: E→N 순방향** | `+45` | 어제=E, 오늘=N |
| **생체리듬: N→E 완충** | `+30` | N 바로 다음 E (E가 N과 D 사이 완충) |
| **생체리듬: N→Off→E 완충** | `+25` | N→Off→E 흐름 (오프 하루 후 E로 복귀) |
| **역방향: D→N 직접** | `-40` | 어제=D, 오늘=N (E 없이 건너뜀) |
| **역방향: N→Off→D 직접** | `-50` | N→Off→D (E 완충 없이 복귀, NOD 하드금지와 중복) |
| **나이트 전담 우선** | `우선순위 가중치` | night_dedicated 멤버가 N 배정 시 |
| **숙련도 배치** | `+30` | `consider_skill_level` ON이고, N 배정 시 mid/senior인 경우 |
| **NOOD 기피** | `-60` | prev1=N, prev0=Off, 오늘=D (NOD는 하드금지지만 NOOD는 소프트) |
| **NOE 기피** | `-50` | prev1=N, prev0=Off, 오늘=E |
| **EOD 기피** | `-40` | prev1=E, prev0=Off, 오늘=D |
| **anti_pair 소프트** | `-100` | soft anti_pair 규칙: 파트너가 이미 같은 근무 배정된 경우 |
| **require_pair 선호** | `+80` | require_pair 규칙: 파트너가 이미 같은 근무 배정된 경우 선호 |

### 원티드 우선순위 가중치 계산

`wanted_priority_order`에 저장된 순서 기준으로 가중치가 결정됩니다.

```
1순위 → +80
2순위 → +60
3순위 → +40
4순위 → +20
```

기본 우선순위: `연차/법정휴가 > 나이트전담 > 휴무배려 > 균등배분`

---

## 4. 배정 로직 흐름

```
for 날짜 D in [start, end]:
  for 근무유형 S in [D, E, N]:          ← OFF는 처리 안 함
    eligible = 멤버.filter(하드제약 통과)
    
    if eligible.isEmpty:
      warning 추가 → skip
    
    scored = eligible.sortBy(소프트스코어 내림차순)
    assignCount = min(minStaffing[S], eligible.length)
    
    if assignCount < minStaffing[S]:
      understaffedWarning 추가
    
    scored[0..assignCount-1] → 해당 날짜 S 배정
  
  미배정 멤버 전원 → Off
  
  prevCodes 슬라이딩:
    배정됨 → prevCodes = [근무코드, 어제코드]
    오프됨  → prevCodes = [null,    어제코드]
```

---

## 5. 알고리즘이 추구하는 패턴

이 알고리즘이 생성하려고 하는 이상적 패턴:

```
...D→D→D → E→E→E → N→N → Off→Off → E→E → D→D→D...
```

- 같은 근무가 **뭉쳐서** 나옴 (블록 연속성 +70)
- Off도 **뭉쳐서** 나옴 (Off 클러스터링 -50 패널티)
- **D→E→N 순방향 흐름** 선호, E가 N과 D 사이 완충 역할 (생체리듬 +45/+30)
- N 후 E를 거쳐 D로 복귀 유도 (N→E→D 또는 N→Off→E→D)
- N이 특정 멤버에 쏠리지 않음 (야간 균등 ×8)

---

## 6. 현재 한계 / 고도화 예정 항목

| 항목 | 현황 | 비고 |
|---|---|---|
| 나이트 전담 멤버의 연속 야간 제한 | 미적용 | max_consecutive_night_shifts 룰이 night_dedicated에도 동일 적용돼야 함 |
| 알고리즘 탐색 방식 | Greedy (날짜순 1회 패스) | 역추적(backtracking) 없음. 앞날 배정이 뒷날에 영향 줄 수 있음 |
| 원티드 요청 근무 유형 지정 | 미지원 | 현재는 off_request만 반영. 특정 날 D 원한다는 요청은 없음 |
| 주말 고려 | 미적용 | 토/일 별도 처리 없음 |
| 피드백 가중치 반영 | 미구현 | schedule_feedback 저장은 되지만 다음달 생성에 반영 안 됨 (Phase E 후속) |
| 커스텀 룰 알고리즘 통합 | ✅ 구현 완료 | member_shift_ban, anti_pair, require_pair, date_off, post_night_off, skill_condition |
| 커스텀 룰 freeform 사후 평가 | 미구현 | freeform 타입은 저장만, 생성 후 AI 평가 미구현 |
