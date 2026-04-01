---
name: moniq-setup
description: "OnorOff 프로젝트 초기 설정. Flutter 프로젝트 생성, 패키지 설치, 디렉토리 구조, Supabase 설정. '프로젝트 초기화', '세팅' 시 사용."
---

# OnorOff Setup — 프로젝트 초기화

## 워크플로우

### Step 1: Flutter 프로젝트 생성

```bash
flutter create --org com.moniq --project-name moniq .
```

### Step 2: 핵심 패키지 설치

```yaml
# pubspec.yaml dependencies
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.6.1
  hooks_riverpod: ^2.6.1
  flutter_hooks: ^0.20.5
  riverpod_annotation: ^2.6.1
  go_router: ^14.8.1
  freezed_annotation: ^2.4.4
  json_annotation: ^4.9.0
  supabase_flutter: ^2.8.3
  cached_network_image: ^3.4.1
  intl: ^0.19.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
  build_runner: ^2.4.14
  riverpod_generator: ^2.6.3
  freezed: ^2.5.8
  json_serializable: ^6.9.4
```

패키지 버전은 설치 시점의 최신 안정 버전을 사용한다.

### Step 3: 디렉토리 구조 생성

```
lib/
├── main.dart
├── app.dart
├── presentation/
│   ├── screens/
│   │   ├── auth/
│   │   ├── home/
│   │   ├── team/
│   │   ├── schedule/
│   │   ├── request/
│   │   └── settings/
│   ├── widgets/
│   │   ├── calendar/
│   │   ├── bottom_sheets/
│   │   └── common/
│   ├── viewmodels/
│   ├── router/
│   └── theme/
├── domain/
│   ├── models/
│   ├── usecases/
│   ├── rules/
│   └── providers/
├── data/
│   ├── datasources/
│   ├── repositories/
│   ├── models/
│   └── providers/
└── core/
    ├── constants/
    ├── extensions/
    └── utils/
```

### Step 4: 기본 파일 생성

1. `lib/main.dart` — Supabase 초기화, ProviderScope, runApp
2. `lib/app.dart` — MaterialApp.router, ThemeData, GoRouter
3. `lib/core/constants/supabase_constants.dart` — URL, AnonKey (env 기반)
4. `lib/presentation/router/app_router.dart` — GoRouter 설정
5. `lib/presentation/theme/app_theme.dart` — 라이트/다크 테마

### Step 5: Supabase 프로젝트 연결

```bash
supabase init
supabase link --project-ref <project-ref>
```

- `.env` 파일에 `SUPABASE_URL`, `SUPABASE_ANON_KEY` 설정
- `.gitignore`에 `.env` 추가

### Step 6: 빌드 검증

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
```

## 완료 기준

- [ ] Flutter 프로젝트 생성 완료
- [ ] 모든 패키지 설치 및 resolve 완료
- [ ] 디렉토리 구조 생성 완료
- [ ] 기본 파일 (main, app, router, theme) 작성 완료
- [ ] 빌드 성공
- [ ] 분석기 오류 없음
