# Flutter Web 반응형 구현 플랜

## Context
스케줄 생성, 희망 휴무 수집, 멤버/룰 관리 등 관리자 기능은 큰 화면에서 훨씬 효율적이다.
현재는 모바일 앱 전용으로만 구현되어 있어, Flutter Web으로 전체 앱을 반응형으로 제공한다.
관리자뿐 아니라 일반 멤버도 웹에서 동일하게 사용할 수 있도록 구현하며,
추후 별도 앱 없이 웹만으로 서비스할 수 있는 기반을 마련한다.

---

## 기술 결정: Flutter Web
- 기존 Dart 코드(Repositories, ViewModels, Freezed Models, Supabase 연동) 100% 재사용
- 별도 Next.js/React 프레임워크 신설 없음 (코드 중복 방지)
- `web/` 폴더 이미 존재, `flutter build web`으로 빌드
- 브레이크포인트: **768px** 이상 = 웹 레이아웃, 미만 = 모바일 레이아웃

---

## 전체 사용자 플로우

```
[웹 URL 진입]
      │
      ▼
[인증 확인] ─── 미인증 ──▶ [로그인 /login]  ←→  [회원가입 /signup]
      │ 인증됨                    │ Supabase Auth
      │◀──────────────────────────┘
      ▼
[홈 /home] — 웹: 사이드바 NavigationRail | 모바일: FloatingNavBar
  ┌─────────────────────────────────────────────────────┐
  │ NavigationRail (좌)    │  메인 콘텐츠 영역 (우)      │
  │ • 홈                   │                            │
  │ • 캘린더               │                            │
  │ • 팀                   │                            │
  │ • 설정                 │                            │
  └─────────────────────────────────────────────────────┘

[역할별 접근]
  일반 멤버:
  ├── 개인 캘린더 확인 (홈)
  ├── 팀 캘린더 조회
  ├── 희망 휴무 입력 (/teams/:teamId/wanted/entry)
  └── 교환/변경 요청 (/teams/:teamId/requests)

  관리자 (일반 기능 + 추가):
  ├── 스케줄 생성 (/teams/:teamId/schedule/generate)
  ├── 희망 휴무 수집 관리 (/teams/:teamId/wanted)
  ├── 멤버 관리 (/teams/:teamId/members)
  └── 팀 설정 (/teams/:teamId/settings 등)
```

**인증 가드:** 기존 `app_router.dart` redirect 로직 그대로 유지 (미인증 → `/login`)
**권한 체크:** 기존 `isAdmin` 체크 + RLS 이중 보호 유지

---

## 구현 범위 및 우선순위

| 기능 | 파일 | 대상 | 우선순위 |
|---|---|---|---|
| 웹 레이아웃 셸 | `app_shell.dart` | 전체 | ★★★ Phase 1 |
| 로그인 웹 레이아웃 | `login_screen.dart` | 전체 | ★★★ Phase 1 |
| 스케줄 생성 | `schedule_generation_screen.dart` | 관리자 | ★★★ Phase 2 |
| 희망 휴무 수집 관리 | `wanted_request_screen.dart` | 관리자 | ★★★ Phase 2 |
| 희망 휴무 입력 | `wanted_day_off_screen.dart` | 일반 멤버 | ★★★ Phase 2 |
| 멤버 관리 | `members_screen.dart` | 관리자 | ★★☆ Phase 3 |
| 팀 설정 / 근무 규칙 / 커스텀 룰 | 각 screen | 관리자 | ★★☆ Phase 3 |
| 교환/변경 요청 | `request_list_screen.dart` | 전체 | ★☆☆ Phase 4 |

---

## Phase 1: 반응형 기반 레이어

### 신규: `lib/presentation/layout/adaptive_layout.dart`
- `AdaptiveLayout.isWeb(ctx)` — 768px 기준 bool 반환
- `AdaptiveLayout(mobile: ..., web: ...)` — 조건부 렌더링 위젯

### 수정: `lib/presentation/router/app_shell.dart`
- `AppShell.build()`에서 `AdaptiveLayout.isWeb()` 체크
- 웹: `Row(NavigationRail + Expanded(child))`
- 모바일: 기존 `_FloatingNavBar` Scaffold 그대로

---

## Phase 2: 핵심 화면 웹 레이아웃

### 스케줄 생성 (`schedule_generation_screen.dart`)
```
웹: Row 2-column
┌─────────────────┬──────────────────────────────┐
│ 설정 패널 (좌)  │ 미리보기 그리드 (우)           │
│ · 기간 선택     │ 멤버 × 날짜 그리드              │
│ · 규칙 요약     │ D/E/N 색상 칩                  │
│ · 원티드 현황   │ 위반 셀 하이라이트              │
│ [생성 버튼]     │                               │
└─────────────────┴──────────────────────────────┘
```

### 희망 휴무 수집 (`wanted_request_screen.dart`)
- 웹: 엔트리 목록을 DataTable로 (행: 멤버, 열: 희망일 chips)

### 로그인 (`login_screen.dart`)
- 웹: 중앙 정렬 카드 레이아웃 (max-width 400px)

---

## Phase 3: 관리자 화면 웹 최적화

### 멤버 관리 (`members_screen.dart`)
- 웹: 목록을 DataTable로, 바텀시트 → 우측 SidePanel로

### 팀 설정 / 규칙 / 커스텀 룰
- 폼 최대 너비 640px 제한 + 좌우 여백 추가

---

## 수정/신규 파일 목록

| 파일 | 유형 | 내용 |
|---|---|---|
| `lib/presentation/layout/adaptive_layout.dart` | 신규 | 브레이크포인트 유틸 |
| `lib/presentation/router/app_shell.dart` | 수정 | 웹 NavigationRail 분기 |
| `lib/presentation/screens/auth/login_screen.dart` | 수정 | 웹: 중앙 카드 레이아웃 |
| `lib/presentation/screens/schedule/schedule_generation_screen.dart` | 수정 | 웹: 2-column |
| `lib/presentation/screens/wanted/wanted_request_screen.dart` | 수정 | 웹: DataTable |
| `lib/presentation/screens/wanted/wanted_day_off_screen.dart` | 수정 | 웹: 넓은 달력 |
| `lib/presentation/screens/team/members_screen.dart` | 수정 | 웹: DataTable + 사이드패널 |
| `lib/presentation/screens/team/team_settings_screen.dart` | 수정 | 웹: max-width |
| `lib/presentation/screens/team/schedule_rules_screen.dart` | 수정 | 웹: max-width |
| `lib/presentation/screens/team/custom_rules_screen.dart` | 수정 | 웹: max-width |

## 재사용 기존 코드 (변경 없음)
- `lib/data/repositories/` — 전체
- `lib/presentation/viewmodels/` — 전체
- `lib/data/models/` — 전체
- `lib/presentation/theme/` — 전체
- `lib/presentation/router/app_router.dart` — 인증 redirect 로직 그대로

---

## 검증 포인트
- [ ] `flutter build web --release` 빌드 성공
- [ ] 브라우저 로그인 → `/home` 정상 이동
- [ ] 768px 이상: 사이드바 NavigationRail 표시
- [ ] 768px 미만: FloatingNavBar 유지
- [ ] 일반 멤버: 관리자 메뉴 미노출, 희망 휴무 입력 가능
- [ ] 관리자: 스케줄 생성 / 멤버 관리 전체 접근
- [ ] 스케줄 생성 웹 2-column 렌더링 확인
- [ ] 기존 모바일 앱 동작 무영향 확인
- [ ] 페이지 새로고침 시 현재 라우트 유지
