# 의사결정 기록

> Phase 1 개발 중 내린 주요 기술 결정 (최신순)

---

## [2026-03-11] SUPABASE_ANON_KEY -> SUPABASE_PUBLISH_KEY 네이밍 변경

**배경:** Supabase가 대시보드에서 "anon key"를 "publishable key"로 리브랜딩

**결정:** 환경변수 및 상수 이름을 `SUPABASE_PUBLISH_KEY` / `publishKey`로 변경

**근거:**
- Supabase 공식 네이밍을 따르는 것이 혼동 방지에 유리
- SDK의 `anonKey` 파라미터명은 변경하지 않음 (SDK가 아직 미변경)

**영향 범위:**
- `.env` 파일
- `lib/core/constants/supabase_constants.dart`

---

## [2026-03-11] Supabase CLI 설치, 로그인은 대시보드 SQL Editor로 대체

**배경:** Supabase CLI로 마이그레이션을 관리하려 했으나, `supabase login`이 TTY(대화형 터미널) 환경을 요구

**결정:** CLI는 설치만 하고, 스키마 실행은 Supabase 대시보드 SQL Editor에서 직접 수행

**근거:**
- 개발 초기 단계에서 마이그레이션 파일을 코드로 관리하되, 실행은 대시보드에서 수행하는 것이 실용적
- CLI 로그인 문제는 환경 제약이므로, 후순위로 해결

**비고:** 마이그레이션 파일은 `supabase/migrations/` 디렉토리에 보관하여 버전 관리

---

## [2026-03-11] riverpod_generator 제거 -> 수동 Provider 정의

**배경:** `riverpod_generator`가 의존하는 `analyzer_plugin 0.12.0`이 `analyzer 7.6.0`과 호환되지 않아 `build_runner`가 실패

**결정:** `riverpod_generator`, `riverpod_lint`, `custom_lint`을 모두 제거하고 수동 Provider 정의로 전환

**대안 검토:**
| 방법 | 장점 | 단점 |
|------|------|------|
| analyzer 버전 다운그레이드 | 코드 생성 유지 | 다른 패키지와 충돌 가능 |
| riverpod_generator dev 버전 사용 | 최신 호환 가능 | 불안정 |
| **수동 Provider 정의** | **안정적, 의존성 감소** | **코드량 약간 증가** |

**근거:**
- 수동 정의도 충분히 간결 (`AsyncNotifierProvider<T, S>(T.new)`)
- `@riverpod` 어노테이션 대비 코드량 차이가 미미
- analyzer 호환 문제에서 자유로움

---

## [2026-03-11] Kakao SDK 임시 비활성화

**배경:** `kakao_flutter_sdk_user: ^1.9.7`이 Flutter 3.32.5와 호환되지 않아 빌드 자체가 불가

**결정:** Kakao SDK를 임시 비활성화하고, `signInWithKakao()`를 placeholder로 변경

**근거:**
- Google/Apple 로그인이 더 높은 우선순위
- Kakao SDK 호환 문제가 해결될 때까지 전체 빌드를 막을 수 없음
- UI에 카카오 버튼은 유지하되, 탭 시 "준비 중" 메시지 표시

**TODO:** Kakao SDK가 Flutter 3.32.x 호환 버전을 릴리스하면 복원

---

## [2026-03-11] iOS deployment target 15.0 선택

**배경:** `kakao_flutter_sdk_common`이 iOS 13.0+ 요구, Flutter 기본값은 12.0

**결정:** 13.0이 아닌 15.0으로 설정

**근거:**
- iOS 15.0은 2021년 출시 기기까지 지원하며 충분한 커버리지 제공
- 향후 다른 플러그인이 더 높은 버전을 요구할 가능성에 대비
- Apple의 앱 개발 가이드라인에서도 최근 2~3개 버전 지원을 권장
- 간호사 대상 앱의 주 사용층이 비교적 최신 기기를 사용할 것으로 예상

**영향 범위:**
- `ios/Podfile`
- `ios/Flutter/AppFrameworkInfo.plist`
- `ios/Runner.xcodeproj/project.pbxproj`
