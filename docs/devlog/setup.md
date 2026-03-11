# 환경 및 설정 변경 기록

> Phase 1 개발 환경 설정 내역 (최신순)

---

## 개발 환경

| 항목 | 값 |
|------|-----|
| Flutter | 3.32.5 |
| Dart SDK | ^3.8.1 |
| iOS deployment target | 15.0 |
| Supabase project ID | oqlkbucovpqterqinzoc |
| Supabase CLI | 2.75.0 (brew install supabase/tap/supabase) |

---

## 외부 서비스 설정

### Supabase
- **프로젝트:** oqlkbucovpqterqinzoc
- **환경변수:** `.env` 파일 (assets로 번들)
  - `SUPABASE_URL`
  - `SUPABASE_PUBLISH_KEY` (구 anon key)
  - `KAKAO_NATIVE_KEY`
- **이메일 확인:** 개발 중 비활성화 (Authentication -> Providers -> Email -> Confirm email OFF)

### Google OAuth
- **Client ID:** `826563961046-lkk5slp6s63fpcf8rc23e6r7k7aomlao.apps.googleusercontent.com`
- **설정 위치:** `web/index.html` meta 태그
  ```html
  <meta name="google-signin-client_id" content="826563961046-lkk5slp6s63fpcf8rc23e6r7k7aomlao.apps.googleusercontent.com">
  ```
- **필요 API:** People API 활성화 필요 (Google Cloud Console)

---

## 제거된 패키지

| 패키지 | 제거 사유 |
|--------|-----------|
| `kakao_flutter_sdk_user` | Flutter 3.32.5 호환 불가 (widget_previews.dart 참조 에러) |
| `riverpod_generator` | analyzer 7.6.0과 호환 불가 (Element vs Element2) |
| `riverpod_lint` | riverpod_generator 의존, 함께 제거 |
| `custom_lint` | riverpod_lint 의존, 함께 제거 |

---

## 현재 의존성 (pubspec.yaml)

### dependencies
| 패키지 | 버전 | 용도 |
|--------|------|------|
| hooks_riverpod | ^2.6.1 | 상태 관리 |
| flutter_hooks | ^0.20.5 | React-style hooks |
| riverpod_annotation | ^2.6.1 | Riverpod 어노테이션 |
| go_router | ^14.8.1 | 선언적 라우팅 |
| freezed_annotation | ^2.4.4 | 불변 모델 어노테이션 |
| json_annotation | ^4.9.0 | JSON 직렬화 어노테이션 |
| supabase_flutter | ^2.8.3 | Supabase 백엔드 |
| google_sign_in | ^6.2.2 | Google 소셜 로그인 |
| sign_in_with_apple | ^6.1.4 | Apple 소셜 로그인 |
| cached_network_image | ^3.4.1 | 이미지 캐싱 |
| flutter_dotenv | ^5.2.1 | 환경변수 관리 |
| intl | ^0.20.2 | 국제화/날짜 포맷 |

### dev_dependencies
| 패키지 | 버전 | 용도 |
|--------|------|------|
| flutter_lints | ^5.0.0 | 린트 규칙 |
| build_runner | ^2.4.14 | 코드 생성 실행기 |
| freezed | ^2.5.8 | 불변 모델 코드 생성 |
| json_serializable | ^6.9.4 | JSON 직렬화 코드 생성 |

---

## iOS 설정 변경

### 변경된 파일 및 내용

**ios/Podfile:**
```ruby
platform :ios, '15.0'
```

**ios/Flutter/AppFrameworkInfo.plist:**
```xml
<key>MinimumOSVersion</key>
<string>15.0</string>
```

**ios/Runner.xcodeproj/project.pbxproj:**
```
IPHONEOS_DEPLOYMENT_TARGET = 15.0  (모든 빌드 설정)
```

---

## 분석 설정 (analysis_options.yaml)

```yaml
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    avoid_print: true
    require_trailing_commas: true
    prefer_single_quotes: true

analyzer:
  errors:
    invalid_annotation_target: ignore
  exclude:
    - '**/*.g.dart'
    - '**/*.freezed.dart'
```

- `custom_lint` 플러그인 항목 제거됨 (riverpod_generator 제거에 따라)
- `invalid_annotation_target: ignore` - freezed/json_serializable 어노테이션 경고 억제
- `*.g.dart`, `*.freezed.dart` 분석 제외
