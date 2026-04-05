# 스케줄링 기능 Phase 진행 현황

> 기준일: 2026-04-05

---

## Phase 전체 현황

| Phase | 내용 | 상태 |
|---|---|---|
| **A** | DB migration: `team_members` 컬럼 4개 + `schedule_feedback` 테이블 | ✅ 완료 |
| **B** | 알고리즘 전면 재작성: 하드 제약 + 소프트 스코어링 + ViolationReport | ✅ 완료 |
| **C** | 생성 화면 개편: Violation 배너 + 바텀시트(탭2개) | ✅ 완료 |
| **D** | `schedule-analyze` Edge Function + AI 분석 버튼/결과 카드 | ✅ 완료 (배포 필요) |
| **E** | 피드백 수집 UI (별점 + 항목별 좋아요/아쉬워요) + DB 저장 | ✅ 완료 |
| **E'** | 근무표 히스토리 화면: 버전 목록 + 그리드 + 버전별 피드백 | ✅ 완료 |
| **F** | team_settings_screen 보완: min_staffing/max_monthly 통합, night_interval·N→D 제거 | ✅ 완료 |
| **G** | members_screen: night_exempt / day_only / night_dedicated 토글 + 저장 버튼 | ✅ 완료 |
| **H** | schedule_rules_screen: avoid_nood/noe/eod 개별 토글 + drag-to-reorder 우선순위 | ✅ 완료 |
| **I** | 커스텀 룰 UI + AI 연동 + 알고리즘 통합 | ✅ 완료 |

> **참고**: `rules_screen.dart`는 삭제 예정이나 아직 파일 존재 (라우터에 route 미등록 — dead file)

---

## 내가 확인해야 할 체크리스트

### Phase A — DB 적용 여부

- [ ] Supabase 대시보드 → `team_members` 테이블에 컬럼 4개 확인
  - `night_exempt` (boolean, default false)
  - `day_only` (boolean, default false)
  - `night_dedicated` (boolean, default false)
  - ~~`skill_level_num`~~ ← 제거 완료
- [ ] `schedule_feedback` 테이블 생성 여부 확인

### Phase G — 멤버 속성 UI

- [ ] 멤버 편집 시트 → "야간제외 / 데이전용 / 나이트전담" 토글 3개 보이는지
- [ ] 나이트전담 ON → 야간제외·데이전용 토글 비활성화되는지
- [ ] 저장 버튼 탭 → Supabase DB에 실제 반영되는지

### Phase H — 규칙 화면

- [ ] NOOD / NOE / EOD 각각 On/Off 토글 동작 확인
- [ ] 원티드 우선순위 드래그로 순서 변경 → 저장 후 스케줄 생성 화면에서 변경된 순서 표시되는지
- [ ] 리스트 위쪽이 1순위로 표시되는지 (연차/법정휴가 최상단 = 1순위)

### Phase B — 알고리즘

- [ ] 스케줄 생성 후 **N(나이트) 다음날 D(데이) 없는지** (가장 중요한 하드 룰)
- [ ] `night_dedicated` 멤버 설정 → 생성 결과에 N만 배정되는지
- [ ] `night_exempt` 멤버 설정 → 생성 결과에 N이 없는지
- [ ] `day_only` 멤버 설정 → 생성 결과에 D만 배정되는지
- [ ] min_staffing을 높게 설정 후 생성 → "인원 부족 N건" violation 배너 뜨는지
- [ ] 원티드 요청 등록 후 생성 → 배너에 "원티드 N/M 반영" 수치 나오는지

### Phase C — Violation UI

- [ ] Violation 배너 탭 → 바텀시트 열리는지
- [ ] "하드 위반" 탭: 위반 없으면 초록 체크 표시, 위반 있으면 목록 표시
- [ ] "소프트 요약" 탭: 원티드 반영률 카드 (% 표시) 나오는지

---

### Phase E' — 히스토리 화면

- [ ] 팀 상세 → "근무표 히스토리" 카드 노출 확인
- [ ] 히스토리 목록: 버전 배지(v1/v2…) + 기간 + 발행됨/초안 상태 표시
- [ ] 버전 탭 → 날짜×멤버 그리드: 실제 근무유형 색상/코드(D/E/N/O) 표시
- [ ] 그리드 멤버 헤더 가로 스크롤 동작
- [ ] "피드백 남기기" 버튼 → 별점 + 항목별 좋아요/아쉬워요 패널 토글
- [ ] 피드백 저장 → DB 반영 확인 / 재진입 시 기존 피드백 로드 확인

---

### Phase I — 커스텀 룰

- [ ] 팀 상세 → "커스텀 규칙" 카드 → 화면 진입 확인
- [ ] 자연어 입력 (예: "홍길동은 나이트 안 서요") → AI 파싱 → 규칙 저장 확인
- [ ] 저장된 규칙 목록: 유형 배지·하드/소프트 배지 표시 확인
- [ ] 토글 Off → 해당 규칙이 생성에 반영 안 되는지 확인
- [ ] 삭제 → 목록에서 제거 확인
- [ ] 스케줄 생성 후 member_shift_ban 반영 확인 (해당 멤버 해당 근무 미배정)
- [ ] skill_condition 위반 시 violation 배너에 경고 노출 확인
- [ ] DB migration `20260405000003_custom_rules.sql` Supabase에 적용 필요

---

## 알려진 기술 부채

| 항목 | 설명 | 우선순위 |
|---|---|---|
| ~~`skill_level_num`~~ | ✅ 제거 완료 (2026-04-05) | — |
| `rules_screen.dart` | 라우터 미등록 dead file — 삭제 필요 | 낮음 |
| Phase D (AI 분석) 배포 | `--no-verify-jwt`로 Edge Function 배포 완료 후 실제 호출 테스트 필요 | 중간 |
| Phase E' 피드백→다음달 가중치 | 피드백 DB 저장됨, 다음달 알고리즘에 가중치 반영은 미구현 | 낮음 |
| Phase I freeform 룰 사후 평가 | freeform 타입 규칙은 저장만, 생성 후 AI 사후 평가 미구현 | 낮음 |
