---
name: moniq-build
description: "Moniq 프로젝트 빌드를 총괄하는 오케스트레이터. 에이전트 팀을 조율하여 Phase별 구현을 진행한다. '빌드 시작', '구현 시작', '다음 Phase', 'moniq 빌드' 요청 시 사용."
---

# Moniq Build — 오케스트레이터

## 목적
6개 에이전트 팀을 조율하여 Moniq MVP를 Phase별로 구현한다.

## 에이전트 팀

| Agent | 역할 | 전문 스킬 |
|-------|------|----------|
| `architect` | 프로젝트 구조, 아키텍처 | `project-scaffold` |
| `designer` | UI/UX 디자인, 컴포넌트 시스템 | `ui-design` |
| `flutter-dev` | Flutter 화면, 위젯, 뷰모델 | `flutter-screen` |
| `supabase-dev` | Supabase 스키마, RLS, 데이터 | `supabase-setup` |
| `scheduler` | 스케줄 생성 알고리즘 | `schedule-engine` |
| `reviewer` | 코드 리뷰, 품질 검증 | `code-review` |

## Phase별 워크플로우

### Phase 1: Foundation (기반)
```
Step 1 (병렬):
  architect  → project-scaffold (프로젝트 구조 생성)
  designer   → ui-design (디자인 시스템 정의)
  supabase-dev → supabase-setup (DB 스키마 + Auth 설정)

Step 2 (순차):
  architect  → 테마 통합 (designer 산출물 기반)
  flutter-dev → Auth 화면 구현 (Login, Signup, ForgotPassword)
  flutter-dev → App Shell 구현 (BottomNav, 빈 탭 화면)

Step 3:
  reviewer → Phase 1 전체 리뷰
```

### Phase 2: Core Calendar (캘린더 코어)
```
Step 1 (병렬):
  designer   → Home/Teams 화면 디자인 명세
  supabase-dev → shifts, schedules 테이블 + RLS

Step 2 (순차):
  flutter-dev → Home 개인 월간 캘린더
  flutter-dev → Teams 공유 캘린더 (월/주/일)
  flutter-dev → 선택 날짜 roster 패널
  flutter-dev → 즐겨찾기 팀 동작

Step 3:
  reviewer → Phase 2 리뷰
```

### Phase 3: Team Management (팀 관리)
```
Step 1 (병렬):
  designer   → Team List/Detail/Create/Join 디자인 명세
  supabase-dev → teams, team_members 관련 추가 RLS/함수

Step 2 (순차):
  flutter-dev → Team List 화면
  flutter-dev → Team Detail 화면
  flutter-dev → Team Create/Join 화면
  flutter-dev → Member 관리 섹션
  flutter-dev → Shift Type 관리 화면
  flutter-dev → Shift Rule 관리 화면

Step 3:
  reviewer → Phase 3 리뷰
```

### Phase 4: Schedule Generation (스케줄 생성)
```
Step 1 (병렬):
  designer   → Schedule Generation 화면 디자인
  scheduler  → 스케줄 생성 알고리즘 구현

Step 2 (병렬):
  supabase-dev → generate-schedule Edge Function
  flutter-dev  → 생성 폼 + 미리보기 + 게시 UI

Step 3:
  reviewer → Phase 4 리뷰 (알고리즘 + UI + 통합)
```

### Phase 5: Requests (스왑/변경 요청)
```
Step 1 (병렬):
  designer   → Request 화면 디자인 명세
  supabase-dev → requests 테이블 추가 RLS/정책

Step 2:
  flutter-dev → 요청 생성 화면
  flutter-dev → 요청 목록/상세 화면
  flutter-dev → 요청 승인/반려 플로우 (관리자)

Step 3:
  reviewer → Phase 5 리뷰
```

### Phase 6: Settings (설정)
```
Step 1:
  designer   → Settings 화면 디자인
  flutter-dev → 테마 설정
  flutter-dev → 폰트 크기 설정
  flutter-dev → 캘린더 시작 요일 설정
  flutter-dev → 계정 설정

Step 2:
  reviewer → Phase 6 리뷰 + 전체 통합 검증
```

## 실행 규칙

### Phase 시작 전
1. 이전 Phase의 리뷰가 완료되었는지 확인
2. 🔴 Critical 이슈가 0건인지 확인
3. 해당 Phase에 필요한 선행 산출물 존재 여부 확인

### Phase 진행 중
1. 병렬 작업은 Task 도구로 동시 실행
2. 순차 작업은 이전 Step 완료 후 실행
3. 에이전트 간 데이터 전달은 파일 시스템 기반 (docs/, lib/)

### Phase 완료 후
1. `reviewer`가 전체 리뷰 실행
2. `flutter analyze` 통과 확인
3. 앱 빌드 가능 상태 확인
4. 사용자에게 Phase 완료 리포트 제공

## 데이터 흐름
```
spec.md
  ↓
designer → docs/design/      (디자인 명세)
  ↓
architect → lib/ 구조         (프로젝트 골격)
  ↓
supabase-dev → supabase/ + lib/data/  (백엔드 + 데이터 레이어)
  ↓
flutter-dev → lib/presentation/       (화면 구현)
  ↓
scheduler → lib/domain/scheduling/    (알고리즘, Phase 4)
  ↓
reviewer → 리뷰 리포트                (품질 검증)
```
