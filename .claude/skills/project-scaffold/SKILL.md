---
name: project-scaffold
description: "Flutter 프로젝트 초기 구조를 생성한다. '프로젝트 초기화', '스캐폴드', '프로젝트 구조 생성', '초기 설정' 요청 시 사용."
---

# Project Scaffold — 프로젝트 초기 구조 생성

## 목적
Moniq Flutter 프로젝트의 디렉토리 구조, 핵심 설정 파일, 레이어 경계를 한 번에 생성한다.

## 워크플로우

### Step 1: Flutter 프로젝트 생성
```bash
flutter create --org com.moniq --project-name moniq_app .
```

### Step 2: 디렉토리 구조 생성
```
lib/
├── app.dart                    # MaterialApp + Router 설정
├── main.dart                   # 엔트리포인트
├── presentation/
│   ├── screens/                # 화면별 디렉토리
│   │   ├── home/
│   │   ├── teams/
│   │   ├── settings/
│   │   └── auth/
│   ├── widgets/                # 공통 위젯
│   ├── view_models/            # Riverpod Notifier/AsyncNotifier
│   ├── routes/                 # go_router 설정
│   └── theme/                  # 테마, 색상, 타이포그래피
├── domain/
│   ├── models/                 # 도메인 모델 (Freezed)
│   ├── repositories/           # 리포지토리 인터페이스
│   ├── use_cases/              # 유즈케이스
│   └── scheduling/             # 스케줄 생성 알고리즘
├── data/
│   ├── repositories/           # 리포지토리 구현체
│   ├── data_sources/           # Supabase 데이터 소스
│   └── models/                 # DTO, json_serializable
└── core/
    ├── constants/              # 앱 상수
    ├── utils/                  # 유틸리티
    └── extensions/             # Dart 확장
```

### Step 3: pubspec.yaml 핵심 의존성
```yaml
dependencies:
  flutter_riverpod:
  riverpod_annotation:
  go_router:
  freezed_annotation:
  json_annotation:
  supabase_flutter:

dev_dependencies:
  riverpod_generator:
  build_runner:
  freezed:
  json_serializable:
  flutter_lints:
```

### Step 4: 기반 파일 생성
1. `lib/main.dart` — ProviderScope + Supabase 초기화
2. `lib/app.dart` — MaterialApp.router + 테마 설정
3. `lib/presentation/routes/app_router.dart` — go_router 라우트 정의
4. `lib/presentation/theme/app_theme.dart` — 라이트/다크 테마
5. `lib/core/constants/app_constants.dart` — Supabase URL, 키 등
6. `analysis_options.yaml` — lint 규칙

### Step 5: Supabase 초기 설정
```bash
supabase init
```
- `supabase/config.toml` 설정
- 초기 마이그레이션 디렉토리 생성

## 출력 규칙
- 모든 파일은 실제 컴파일 가능한 Dart 코드여야 한다
- placeholder 코드는 최소화하되, 앱이 빌드 가능한 상태를 유지한다
- TODO 주석으로 다음 단계 작업을 표시한다
