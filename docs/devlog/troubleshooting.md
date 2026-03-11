# 트러블슈팅 로그

> Phase 1 개발 중 발생한 이슈와 해결 방법 (최신순)

---

## [2026-03-11] Google Sign-In People API 미활성화

**상황:** 웹에서 Google 로그인 시도 시 403 에러 발생

**에러 메시지:**
```
People API has not been used in project 826563961046 before or it is disabled
```

**원인:** Google Sign-In이 사용자 프로필 정보를 가져오기 위해 People API를 사용하는데, Google Cloud Console에서 해당 API가 활성화되지 않았음

**해결:** Google Cloud Console에서 People API 활성화 필요

**참고:** https://console.developers.google.com/apis/api/people.googleapis.com/overview?project=826563961046

---

## [2026-03-11] Google Sign-In Client ID 미설정 (웹)

**상황:** 웹에서 Google 로그인 버튼 클릭 시 assertion 에러 발생

**에러 메시지:**
```
ClientID not set. Either set it on a meta tag, or pass clientId when initializing GoogleSignIn
```

**원인:** `google_sign_in` 웹 플러그인은 HTML meta 태그에서 Client ID를 읽는데, `web/index.html`에 해당 태그가 없었음

**해결:** `web/index.html`의 `<head>` 섹션에 다음 태그 추가:
```html
<meta name="google-signin-client_id" content="826563961046-lkk5slp6s63fpcf8rc23e6r7k7aomlao.apps.googleusercontent.com">
```

---

## [2026-03-11] Supabase 이메일 rate limit / email not confirmed

**상황:** 회원가입 시 두 가지 에러가 연속 발생

**에러 메시지:**
```
429: over_email_send_rate_limit
400: email_not_confirmed
```

**원인:**
1. Supabase 무료 플랜의 이메일 발송 제한(시간당 4회)에 도달하여 확인 이메일 발송 실패
2. 이메일 확인이 활성화된 상태에서 확인 이메일을 받지 못한 유저가 로그인 시도

**해결:**
1. Supabase 대시보드 -> Authentication -> Providers -> Email -> "Confirm email" 옵션 OFF
2. Authentication -> Users에서 기존 미확인 유저 삭제 후 재가입

**비고:** 개발 단계에서는 이메일 확인 비활성화가 편리함. 프로덕션에서는 다시 활성화 필요.

---

## [2026-03-11] dart:io Platform.isIOS 웹 호환 불가

**상황:** `login_screen.dart`에서 `Platform.isIOS`를 사용하여 Apple 로그인 버튼 표시 분기 -> 웹에서 크래시

**에러 메시지:**
```
Unsupported operation: Platform._operatingSystem
```

**원인:** `dart:io`의 `Platform` 클래스는 웹 환경에서 사용 불가. 웹에서 import하면 런타임 에러 발생.

**해결:**
```dart
// 변경 전
import 'dart:io';
if (Platform.isIOS) { ... }

// 변경 후
import 'package:flutter/foundation.dart';
if (defaultTargetPlatform == TargetPlatform.iOS) { ... }
```

`defaultTargetPlatform`은 웹에서도 안전하게 동작하며, 웹에서는 `TargetPlatform.android` 또는 호스트 OS에 따른 값을 반환한다.

---

## [2026-03-11] kakao_flutter_sdk_user Flutter 3.32.5 호환 불가

**상황:** `kakao_flutter_sdk_user: ^1.9.7` 추가 후 빌드 시 컴파일 에러

**에러 메시지:**
```
Error when reading 'flutter/packages/flutter/lib/widget_previews.dart': No such file or directory
```

**원인:** `kakao_flutter_sdk_user` 패키지가 Flutter 3.32.5의 내부 구조 변경에 대응하지 못함. `widget_previews.dart` 파일이 더 이상 해당 경로에 존재하지 않음.

**해결:**
1. `pubspec.yaml`에서 `kakao_flutter_sdk_user` 주석 처리:
   ```yaml
   # kakao_flutter_sdk_user: ^1.9.7  # TODO: 호환 버전 나오면 복원
   ```
2. `main.dart`에서 `KakaoSdk.init()` 주석 처리
3. `auth_remote_data_source.dart`의 `signInWithKakao()` -> placeholder로 변경:
   ```dart
   Future<void> signInWithKakao() async {
     throw const AuthException('카카오 로그인은 준비 중입니다');
   }
   ```

**TODO:** Kakao SDK가 Flutter 3.32.x 호환 버전을 릴리스하면 복원

---

## [2026-03-11] iOS deployment target 12.0 -> 15.0

**상황:** `kakao_flutter_sdk_common` 의존성이 iOS 13.0 이상을 요구하며 CocoaPods 빌드 에러 발생

**에러 메시지:**
```
The plugin requires a higher minimum iOS deployment target
```

**원인:** Flutter 프로젝트 기본값은 iOS 12.0이나, 여러 플러그인이 더 높은 최소 버전을 요구

**해결:** 다음 3개 파일에서 iOS deployment target을 15.0으로 변경:
1. `ios/Podfile`:
   ```ruby
   platform :ios, '15.0'
   ```
2. `ios/Flutter/AppFrameworkInfo.plist`:
   ```xml
   <key>MinimumOSVersion</key>
   <string>15.0</string>
   ```
3. `ios/Runner.xcodeproj/project.pbxproj`:
   - `IPHONEOS_DEPLOYMENT_TARGET = 15.0` (모든 빌드 설정)

**비고:** 13.0이면 충분하나, 향후 호환성을 위해 15.0으로 설정

---

## [2026-03-11] build_runner 컴파일 실패 (analyzer_plugin 호환)

**상황:** `dart run build_runner build` 실행 시 컴파일 에러

**에러 메시지:**
```
The argument type 'Element' can't be assigned to the parameter type 'Element2'
```

**원인:** `riverpod_generator`가 의존하는 `analyzer_plugin 0.12.0`이 `analyzer 7.6.0`의 API 변경(Element -> Element2)에 대응하지 못함

**해결:**
1. `pubspec.yaml`에서 다음 패키지 제거:
   - `riverpod_generator`
   - `riverpod_lint`
   - `custom_lint`
2. `analysis_options.yaml`에서 `custom_lint` 플러그인 항목 제거
3. 코드 생성(`@riverpod`) 대신 수동 Provider 정의로 대체:
   ```dart
   // @riverpod 대신 수동 정의
   final authViewModelProvider =
       AsyncNotifierProvider<AuthViewModel, User?>(AuthViewModel.new);
   ```

**비고:** Riverpod 코드 생성은 편리하나, analyzer 버전 충돌이 빈번. 수동 정의도 충분히 간결함.

---

## [2026-03-11] intl 버전 충돌

**상황:** `pub get` 실행 시 intl 패키지 버전 충돌

**에러 메시지:**
```
Because flutter_localizations depends on intl 0.20.2 and moniq depends on intl ^0.19.0,
version solving failed.
```

**원인:** `flutter_localizations` SDK 패키지가 `intl 0.20.2`를 정확히 핀하고 있으나, `pubspec.yaml`에서 `intl: ^0.19.0`으로 지정하여 충돌

**해결:**
```yaml
# 변경 전
intl: ^0.19.0

# 변경 후
intl: ^0.20.2
```

---

## [2026-03-11] Supabase publishable key 네이밍 변경

**상황:** Supabase가 "anon key"를 "publishable key"로 리브랜딩

**해결:**
1. `.env` 파일에서 키 이름 변경:
   ```
   # 변경 전
   SUPABASE_ANON_KEY=eyJhbGciOi...

   # 변경 후
   SUPABASE_PUBLISH_KEY=eyJhbGciOi...
   ```
2. `supabase_constants.dart`에서 getter 이름 변경:
   ```dart
   static String get publishKey => dotenv.env['SUPABASE_PUBLISH_KEY'] ?? '';
   ```
3. `main.dart`에서 SDK 호출은 `anonKey` 파라미터명 유지 (SDK가 아직 변경되지 않음):
   ```dart
   await Supabase.initialize(
     url: SupabaseConstants.url,
     anonKey: SupabaseConstants.publishKey,  // SDK 파라미터명은 anonKey 유지
   );
   ```
