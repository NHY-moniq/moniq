# Phase 1: 기반 구성 (Foundation) - 진행 기록

> 작성일: 2026-03-11
> 상태: 완료
> flutter analyze: 0 issues

---

## 개요

Moniq(간호사 교대 근무표 관리 앱)의 Phase 1은 프로젝트의 기반이 되는 인프라, 디자인 시스템, 인증, 라우팅, 핵심 화면을 구축하는 단계이다. 총 7개 Step으로 구성되며, 약 37개 파일이 생성되었다.

---

## Step 7: 화면 구현 + Team data layer

**생성 파일:**
- `lib/presentation/screens/auth/login_screen.dart` - 이메일/소셜 로그인 (Google, Apple, Kakao)
- `lib/presentation/screens/auth/signup_screen.dart` - 회원가입
- `lib/presentation/screens/auth/forgot_password_screen.dart` - 비밀번호 재설정
- `lib/presentation/screens/home/home_screen.dart` - 홈 탭
- `lib/presentation/screens/team/team_screen.dart` - 팀 목록
- `lib/presentation/screens/team/team_create_screen.dart` - 팀 생성
- `lib/presentation/screens/team/team_join_screen.dart` - 초대 코드로 팀 참여
- `lib/presentation/screens/settings/settings_screen.dart` - 설정
- `lib/data/datasources/team_remote_data_source.dart` - 팀 Supabase 연동
- `lib/data/repositories/team_repository.dart` - 팀 레포지토리
- `lib/data/providers/team_providers.dart` - 팀 Riverpod Provider
- `lib/presentation/viewmodels/team_viewmodel.dart` - 팀 상태 관리

**주요 구현:**
- login_screen: `defaultTargetPlatform == TargetPlatform.iOS`로 플랫폼 분기 (dart:io 사용 불가 문제 해결)
- Team data layer: RPC 함수(`create_team`, `join_team_by_invite`) 호출, 즐겨찾기 팀 설정
- 팀 ViewModel: `AsyncNotifier` 기반, `ref.invalidateSelf()`로 목록 갱신

---

## Step 6: Router + 앱 셸

**생성 파일:**
- `lib/presentation/router/app_router.dart` - go_router 설정
- `lib/presentation/router/app_shell.dart` - 하단 네비게이션 셸

**주요 구현:**
- `StatefulShellRoute.indexedStack`으로 3탭 구성 (홈 / 팀 / 설정)
- `authStateChangesProvider`를 watch하여 인증 상태 기반 리다이렉트
- 미인증 사용자 -> `/login`, 인증된 사용자가 auth 라우트 접근 -> `/home`
- 팀 관리 라우트(`/teams/create`, `/teams/join`)는 셸 외부 배치

---

## Step 5: Auth 구현

**생성 파일:**
- `lib/data/datasources/auth_remote_data_source.dart` - Supabase GoTrue 연동
- `lib/data/repositories/auth_repository.dart` - 인증 레포지토리
- `lib/data/providers/auth_providers.dart` - 인증 Riverpod Provider
- `lib/presentation/viewmodels/auth_viewmodel.dart` - 인증 상태 관리

**주요 구현:**
- 이메일/비밀번호 로그인 및 회원가입
- Google Sign-In (`signInWithIdToken`)
- Apple Sign-In (`signInWithIdToken`)
- Kakao Sign-In: placeholder (`throw AuthException`) - SDK 호환 문제로 비활성화
- `AsyncNotifierProvider<AuthViewModel, User?>`로 상태 관리
- 수동 Provider 정의 (riverpod_generator 제거로 인해)

---

## Step 4: Supabase 스키마

**생성 파일:**
- `supabase/migrations/20260311000001_phase1_foundation.sql` - 마이그레이션
- `supabase/functions/social-auth/index.ts` - Edge Function

**마이그레이션 내용:**
- `public.users` 테이블 - `auth.users` 참조, 자동 생성 트리거(`handle_new_user`)
- `public.teams` 테이블 - 초대 코드(`invite_code`) 자동 생성, 소프트 삭제
- `public.team_members` 테이블 - `admin`/`member` 역할, 즐겨찾기 지원
- `update_updated_at()` 공통 트리거 함수
- RPC: `create_team` (팀 생성 + admin 자동 등록)
- RPC: `join_team_by_invite` (초대 코드 검증 + member 등록)
- RLS: 본인 프로필 조회/수정, 같은 팀 멤버 프로필 조회, 팀 admin 권한 관리

**Edge Function:**
- Kakao / Naver 소셜 로그인용 토큰 검증
- access_token으로 사용자 정보 조회 -> Supabase 유저 생성/조회 -> magiclink 발급

---

## Step 3: 디자인 시스템

**생성 파일:**
- `lib/presentation/theme/app_colors.dart` - 컬러 팔레트 (Primary Teal, Secondary Amber, 근무 유형별 색상)
- `lib/presentation/theme/app_typography.dart` - Pretendard 폰트 기반 타이포그래피
- `lib/presentation/theme/app_spacing.dart` - 4px 그리드 시스템, AppRadius, AppSizing
- `lib/presentation/theme/app_theme.dart` - Material 3 라이트/다크 테마
- `lib/presentation/widgets/common/moniq_error_view.dart` - 에러 표시 + 재시도 버튼
- `lib/presentation/widgets/common/moniq_loading_view.dart` - 로딩 인디케이터
- `lib/presentation/widgets/common/moniq_empty_state.dart` - 빈 상태 안내

**특징:**
- 간호사 근무 유형별 색상: Day(파랑), Evening(주황), Night(보라), Off(회색)
- Material 3 기반 light/dark 테마 동시 지원
- `ThemeMode.system`으로 시스템 설정 추종

---

## Step 2: 핵심 인프라

**생성 파일:**
- `lib/main.dart` - 앱 진입점 (dotenv, Supabase 초기화, ProviderScope)
- `lib/app.dart` - MaterialApp.router (한국어 로케일, 테마, go_router)
- `lib/core/constants/supabase_constants.dart` - 환경변수 기반 Supabase 설정
- `lib/data/providers/supabase_providers.dart` - Supabase 클라이언트 Provider
- `.env` - 환경변수 (SUPABASE_URL, SUPABASE_PUBLISH_KEY, KAKAO_NATIVE_KEY)

**특징:**
- `flutter_dotenv`으로 `.env` 파일 로드 (assets로 번들)
- `SUPABASE_PUBLISH_KEY` 네이밍 (Supabase 리브랜딩 반영)
- SDK 파라미터는 `anonKey` 유지 (SDK 미변경)

---

## Step 1: Flutter 프로젝트 초기화

**작업 내용:**
- `flutter create moniq` 실행
- `pubspec.yaml` 의존성 설치

**주요 의존성:**
- 상태 관리: hooks_riverpod, flutter_hooks, riverpod_annotation
- 라우팅: go_router
- 모델: freezed_annotation, json_annotation (+ build_runner, freezed, json_serializable)
- 백엔드: supabase_flutter
- 소셜 인증: google_sign_in, sign_in_with_apple
- 유틸: cached_network_image, flutter_dotenv, intl

**디렉토리 구조:**
```
lib/
  core/
    constants/
  data/
    datasources/
    models/
    providers/
    repositories/
  presentation/
    router/
    screens/
      auth/
      home/
      team/
      settings/
    theme/
    viewmodels/
    widgets/
      common/
```

---

## 파일 목록 (약 37개)

### 소스 파일 (32개)
| # | 경로 | 설명 |
|---|------|------|
| 1 | `lib/main.dart` | 앱 진입점 |
| 2 | `lib/app.dart` | MaterialApp.router |
| 3 | `lib/core/constants/supabase_constants.dart` | Supabase 환경변수 |
| 4 | `lib/data/providers/supabase_providers.dart` | Supabase Provider |
| 5 | `lib/data/providers/auth_providers.dart` | Auth Provider |
| 6 | `lib/data/providers/team_providers.dart` | Team Provider |
| 7 | `lib/data/datasources/auth_remote_data_source.dart` | Auth 데이터 소스 |
| 8 | `lib/data/datasources/team_remote_data_source.dart` | Team 데이터 소스 |
| 9 | `lib/data/repositories/auth_repository.dart` | Auth 레포지토리 |
| 10 | `lib/data/repositories/team_repository.dart` | Team 레포지토리 |
| 11 | `lib/data/models/user_model.dart` | User 모델 (freezed) |
| 12 | `lib/data/models/team_model.dart` | Team 모델 (freezed) |
| 13 | `lib/data/models/team_member_model.dart` | TeamMember 모델 (freezed) |
| 14 | `lib/presentation/theme/app_colors.dart` | 컬러 팔레트 |
| 15 | `lib/presentation/theme/app_typography.dart` | 타이포그래피 |
| 16 | `lib/presentation/theme/app_spacing.dart` | 스페이싱/사이징 |
| 17 | `lib/presentation/theme/app_theme.dart` | 테마 (light/dark) |
| 18 | `lib/presentation/widgets/common/moniq_error_view.dart` | 에러 위젯 |
| 19 | `lib/presentation/widgets/common/moniq_loading_view.dart` | 로딩 위젯 |
| 20 | `lib/presentation/widgets/common/moniq_empty_state.dart` | 빈 상태 위젯 |
| 21 | `lib/presentation/router/app_router.dart` | go_router 설정 |
| 22 | `lib/presentation/router/app_shell.dart` | 하단 탭 셸 |
| 23 | `lib/presentation/viewmodels/auth_viewmodel.dart` | Auth ViewModel |
| 24 | `lib/presentation/viewmodels/team_viewmodel.dart` | Team ViewModel |
| 25 | `lib/presentation/screens/auth/login_screen.dart` | 로그인 화면 |
| 26 | `lib/presentation/screens/auth/signup_screen.dart` | 회원가입 화면 |
| 27 | `lib/presentation/screens/auth/forgot_password_screen.dart` | 비밀번호 찾기 |
| 28 | `lib/presentation/screens/home/home_screen.dart` | 홈 화면 |
| 29 | `lib/presentation/screens/team/team_screen.dart` | 팀 목록 화면 |
| 30 | `lib/presentation/screens/team/team_create_screen.dart` | 팀 생성 화면 |
| 31 | `lib/presentation/screens/team/team_join_screen.dart` | 팀 참여 화면 |
| 32 | `lib/presentation/screens/settings/settings_screen.dart` | 설정 화면 |

### 생성 파일 (6개)
| # | 경로 | 설명 |
|---|------|------|
| 33 | `lib/data/models/user_model.freezed.dart` | freezed 자동 생성 |
| 34 | `lib/data/models/user_model.g.dart` | json_serializable 자동 생성 |
| 35 | `lib/data/models/team_model.freezed.dart` | freezed 자동 생성 |
| 36 | `lib/data/models/team_model.g.dart` | json_serializable 자동 생성 |
| 37 | `lib/data/models/team_member_model.freezed.dart` | freezed 자동 생성 |
| 38 | `lib/data/models/team_member_model.g.dart` | json_serializable 자동 생성 |

### Supabase 파일 (2개)
| # | 경로 | 설명 |
|---|------|------|
| 39 | `supabase/migrations/20260311000001_phase1_foundation.sql` | DB 스키마 마이그레이션 |
| 40 | `supabase/functions/social-auth/index.ts` | 소셜 인증 Edge Function |

### 설정 파일 (3개)
| # | 경로 | 설명 |
|---|------|------|
| 41 | `.env` | 환경변수 |
| 42 | `pubspec.yaml` | 프로젝트 의존성 |
| 43 | `analysis_options.yaml` | 분석 규칙 |
