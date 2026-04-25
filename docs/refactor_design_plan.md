# Moniq(OnorOff) 전체 화면 디자인 통일성 리팩터링 계획

- **브랜치**: `refactor/design-system-unification`
- **출처 자료**: `refactor/handoff.html`, `refactor/lib/presentation/**`, `design/*.html`, 현행 `lib/presentation/**`
- **목표**: 톤 일관성 감사(F1~F13) 중 F1·F2·F3·F4·F5·F7·F10·F11·F12·F13을 공통 컴포넌트 5종으로 흡수하고, 모든 `screens/*`를 동일한 디자인 톤으로 맞춘다.
- **코드 작성 금지 원칙**: 본 문서는 계획 문서이다. 실 코드 수정은 각 Step PR에서 진행한다.

---

## 0. 용어 / 범위

| 용어 | 의미 |
|------|------|
| **공통 컴포넌트 5종** | MoniqAppBar · MoniqBottomSheet · MoniqEmptyState(신규) · MoniqCard/GroupedCard/CardRow · MoniqStepper |
| **레거시 MoniqEmptyState** | 현행 `lib/presentation/widgets/common/moniq_empty_state.dart` (icon + CharacterType 기반) |
| **신규 MoniqEmptyState** | `refactor/lib/...`의 factory 기반(`peaceful`/`encouraging`, characterAsset) |
| **토큰** | `AppSpacing.*`, `AppRadius.md/lg/full`, `AppTypography.*`, `todayShiftTheme` |

---

## 1. 디자인 톤 원칙 (후속 작업자 판단 기준)

### 1-1. 브랜드 톤
- **HTML 시안(`design/*.html`)의 크림 배경(`#EAE6D5`)과 옐로우 액센트가 원천**이다. 다크 시안(`dark_*.html`)은 대응 다크 팔레트.
- **캐릭터(yellow/off/orange)를 톤 표현의 주요 장치로 사용한다.** Material 기본 아이콘은 "데이터 없음"이 아닌 "액션/메타" 맥락에만 쓴다.
- 대화체 카피: "조용한 하루네요 ☕", "아직 ~이 없어요", "~해볼까요?" 등. 존댓말 종결 "~합니다"는 금지(포맷/에러 문구 제외).

### 1-2. 라운드 토큰
- 허용: `AppRadius.md(16)` / `AppRadius.lg(24)` / `AppRadius.full(999)` 3종만.
- 금지: 화면 안에서 `BorderRadius.circular(12/20/24/32/40)` 하드코딩. 불가피하면 기존 `AppRadius.*`에 매핑하거나 토큰을 확장.
- 예외(합의): grab handle 2px, 미세 라인 4px 정도의 장식 요소는 하드코딩 허용.

### 1-3. 타이포
- `AppTypography.headlineMedium` = 타이틀, `AppTypography.captionSmall` + letterSpacing 1.6~2.2 = eyebrow.
- MONIQ ID/숫자는 `monospace` 금지, `Jakarta Sans 900 + FontFeature.tabularFigures()`.

### 1-4. 컬러
- 배경: `surfaceContainerLow`(페이지), `surfaceContainerLowest`(카드).
- 오늘의 시프트 강조면(프로필 히어로 등): `todayShiftTheme.cardColor` / `onPrimary` / `characterAsset` 사용.

### 1-5. 인터랙션
- 확인/파괴 액션은 **AlertDialog 금지, MoniqBottomSheet 사용**. 취소 버튼은 outlined pill, 확정 버튼은 filled pill.
- 다단계 플로우는 **MoniqStepper.bars(요청 생성) / MoniqStepper.dots(근무표 생성)** 로 노출.

---

## 2. Step 0 — 자료 통합 / 충돌 해결

### 2-1. 파일 이동 계획

| from (refactor/) | to (lib/) | 상태 |
|---|---|---|
| `refactor/lib/presentation/widgets/common/moniq_app_bar.dart` | `lib/presentation/widgets/common/moniq_app_bar.dart` | **신규 (충돌 없음)** |
| `refactor/lib/presentation/widgets/common/moniq_bottom_sheet.dart` | `lib/presentation/widgets/common/moniq_bottom_sheet.dart` | **신규 (충돌 없음)** |
| `refactor/lib/presentation/widgets/common/moniq_card.dart` | `lib/presentation/widgets/common/moniq_card.dart` | **신규 (충돌 없음)** |
| `refactor/lib/presentation/widgets/common/moniq_stepper.dart` | `lib/presentation/widgets/common/moniq_stepper.dart` | **신규 (충돌 없음)** |
| `refactor/lib/presentation/widgets/common/moniq_empty_state.dart` | `lib/presentation/widgets/common/moniq_empty_state.dart` | **충돌 — 기존 7개 호출부 마이그레이션 필요** |
| `refactor/lib/presentation/screens/settings/settings_screen.dart` | `lib/presentation/screens/settings/settings_screen.dart` | **전면 치환 (Step 1에서 수행)** |

### 2-2. MoniqEmptyState 충돌 해소 전략

**기존(`lib/`) 시그니처**
```
MoniqEmptyState({
  required IconData icon,
  required String message,
  String? description,
  String? actionLabel, VoidCallback? onAction,
  String? secondaryActionLabel, VoidCallback? onSecondaryAction,
  CharacterType? character,
})
```

**신규(`refactor/`) 시그니처**
```
MoniqEmptyState({title, message, characterAsset, action})
// factory .peaceful() / .encouraging()
// (secondaryAction 없음)
```

**호출부 영향 (7곳)**
- `screens/notifications/notifications_screen.dart:41`
- `screens/announcement/announcement_screen.dart:45`
- `screens/announcement/my_announcements_screen.dart:38`
- `screens/request/request_list_screen.dart:279, 419`
- `screens/team/team_screen.dart:101` (secondaryAction + character 사용)
- `screens/wanted/wanted_day_off_screen.dart:70`

**권장 접근(Option A — 신규 컴포넌트를 약간 확장 후 치환)**
1. 신규 `MoniqEmptyState`에 **`secondaryAction` 파라미터를 추가**한다 (team_screen의 "팀 만들기 / 초대 코드로 참여" 케이스 보존).
2. 호출부 마이그레이션 매핑표 적용:
   - `message` → `title`
   - `description` → `message`
   - `actionLabel + onAction` → `action: MoniqEmptyStateAction(label, onTap)`
   - `secondaryActionLabel + onSecondaryAction` → (확장 이후) `secondaryAction: MoniqEmptyStateAction(...)`
   - `character: CharacterType.off` → `.peaceful()`
   - `character: CharacterType.yellow` → `.encouraging()`
   - `character: CharacterType.orange` → 신규 factory `.cheerful()` 추가 또는 범용 생성자로 `characterAsset: 'assets/images/orange.png'`
   - `icon` 단독(캐릭터 없음) → 기본 `.peaceful()`로 통일하거나, 범용 생성자에 `icon` 옵션을 추가해 보존
3. `character_blob.dart`(CharacterType enum 포함)는 홈/빈상태 외 다른 용도로도 쓰이므로 **남겨둔다**. CharacterType→characterAsset 매핑 헬퍼만 하나 둔다.

**대안 Option B(보류)**: 두 파일을 네임스페이스 분리(`moniq_empty_state_v2.dart`)하고 점진 치환. 통일성 취지에 맞지 않으므로 선택하지 않는다.

### 2-3. 토큰/테마 호환성 체크리스트

| 항목 | 결과 | 비고 |
|---|---|---|
| `AppSpacing.xs/sm/md/lg/xl/xxl/xxxl/huge/massive` 존재 | OK | 신규 파일이 쓰는 키 모두 정의됨 |
| `AppRadius.md(16)/.lg(24)/.full(999) + borderRadiusFull/Lg/Md` | OK | |
| `AppTypography.headlineLarge/headlineMedium/titleMedium/bodyLarge/bodyMedium/caption/captionSmall/labelLarge/labelMedium` | OK | |
| `shift_theme.dart`의 `todayShiftThemeProvider` | 확인 필요(Settings에서 참조) | Step 1 PR에서 import 경로 검증 |
| `assets/images/off.png`, `yellow.png`, `orange.png` | 확인 필요 | `pubspec.yaml`의 assets 선언과 매치되는지 검증(Step 0 점검) |
| `data/providers/settings_providers.dart`의 `themeModeProvider`, `calendarStartDayProvider`, `fontScaleProvider` | 기존 코드에서 확인 | 네이밍 변경 시 Settings 리라이트본 수정 필요 |

### 2-4. Step 0 산출물 (PR #1)
- 공통 컴포넌트 4종(충돌 없음)만 **먼저 추가**: `moniq_app_bar.dart` / `moniq_bottom_sheet.dart` / `moniq_card.dart` / `moniq_stepper.dart`.
- `moniq_empty_state.dart`는 **본 PR에서 확장(option A) 후 교체**. CharacterType→asset 매핑 헬퍼 동봉.
- 호출부 7곳의 **컴파일 깨짐 방지**를 위해 Step 0 PR이 MoniqEmptyState 호출부까지 한 번에 고쳐야 함 (또는 기존 레거시를 deprecated 어댑터로 남겨 Step 2에서 정리 — 아래 Step 계획 참조).

---

## 3. Step별 우선순위 (작은 PR로 쪼개기)

| Step | 대상 | 목적 | 해결 Finding | 예상 파일 수 |
|---|---|---|---|---|
| **S0** | 공통 컴포넌트 4종 추가 + MoniqEmptyState 확장/치환 + 호출부 7곳 마이그레이션 | 기반 | F1·F3·F5·F7·F10·F11·F12·F13 토대 | 신규 5, 수정 7 |
| **S1** | Settings 화면 전면 치환 | 첫 적용 예시(1093→520줄) | F1·F2·F5·F10·F13 | 1 (큰 파일) |
| **S2** | 단순 AppBar 치환 — announcement / notifications / schedule_history / request_list / team_create / team_join / team_list / team_detail | 기본 AppBar → MoniqAppBar | F1·F11 | 8 |
| **S3** | 팀 하위 설정 화면 AppBar 치환 — rules / schedule_rules / custom_rules / shift_types / team_settings / members / profile_edit | 팀 관리 계열 톤 통일 | F1·F11 | 7 |
| **S4** | Auth 화면 AppBar 치환 — signup / forgot_password / email_verification (login은 AppBar 없음) | 로그인 외 Auth 계열 통일 | F1·F11 | 3 |
| **S5** | Dialog → BottomSheet 이행 (확인/파괴 액션) — request_list / announcement / calendar_dialogs / schedule_generation / shift_types / team_settings / team_list / schedule_rules | AlertDialog 전면 제거 | F5 | 8 |
| **S6** | Request Create에 MoniqStepper.bars 도입 (3-step) | 단계 인디케이터 | F4 | 2 (screen + widgets) |
| **S7** | Schedule Generation에 MoniqStepper.dots 도입 (기간 / 미리보기 / 발행) | 단계 인디케이터 | F7 | 1 |
| **S8** | 카드 일관화 — team_detail_widgets / members_widgets / notifications 내부 카드 / request_list 내부 카드 / wanted_day_off 배너 | 하드코딩 라운드 제거, MoniqCard/GroupedCard 적용 | F10 | 5~7 |
| **S9** | Home / Calendar / Team 메인 AppBar 영역 정비 | 커스텀 타이틀과 MoniqAppBar 혼재 정리 (점진 도입) | F1·F2·F11 | 3~4 |
| **S10** | 빈 상태/캐릭터 톤 일관화 감사 (2차) | Empty copy 교정 (조용한 하루네요 ☕ 등) | F3·F12 | 7 |

### 3-1. 화면 × 공통 컴포넌트 매트릭스

표기: A=AppBar, B=BottomSheet, E=EmptyState, C=Card, S=Stepper, / = 해당없음, ? = 2차 검토

| 화면 | A | B | E | C | S | 비고 |
|------|---|---|---|---|---|---|
| announcement/announcement_screen | A | B | E | C | / | 상세 페이지 2개 추가 AppBar 있음 |
| announcement/my_announcements_screen | A | / | E | / | / | 리스트 단순 |
| auth/login_screen | / | / | / | / | / | AppBar 없음, 커스텀 블롭 배경 유지 |
| auth/signup_screen | A | / | / | / | / | |
| auth/forgot_password_screen | A | / | / | / | / | |
| auth/email_verification_screen | A | / | / | / | / | |
| calendar/calendar_screen | A? | / | / | / | / | 커스텀 날짜 선택기가 AppBar title 자리 → S9에서 MoniqAppBar 커스텀 leading으로 흡수 |
| calendar/calendar_dialogs | / | B | / | / | / | showModalBottomSheet 다수 → shell만 교체 |
| home/home_screen | A? | B? | / | / | / | 홈은 별도 커스텀 AppBar(아바타+벨) — S9에서 MoniqAppBar + 커스텀 trailing으로 전환 |
| notifications/notifications_screen | A | / | E | / | / | |
| request/request_create_screen | A | / | / | C | **S** | S6에서 bars(3-step) |
| request/request_list_screen | A | B | E | C | / | 상세 시트 B로, 필터/카드 C로 |
| schedule/schedule_generation_screen | A | B | / | C | **S** | S7에서 dots |
| schedule/schedule_history_screen | A | / | / | C? | / | 버전 상세 포함 |
| settings/settings_screen | A | B | / | C | / | **S1에서 일괄 치환 완료** |
| settings/profile_edit_screen | A | / | / | / | / | |
| team/team_list_screen | A | B | / | C | / | 탈퇴/삭제 다이얼로그 B로 |
| team/team_screen | A | / | E | / | / | 메인 탭 / 무팀/무즐찾 분기 |
| team/team_detail_screen | A | B? | / | C | / | 섹션 카드 → GroupedCard 후보 |
| team/team_create_screen | A | / | / | C | / | 폼 단일 |
| team/team_join_screen | A | / | / | C | / | |
| team/members_screen | A | B | / | C | / | 멤버 상세 sheet |
| team/rules_screen | A | / | / | C | / | 섹션 카드 다수 |
| team/schedule_rules_screen | A | B | / | C | / | |
| team/custom_rules_screen | A | / | / | C | / | |
| team/shift_types_screen | A | B | / | C | / | |
| team/team_settings_screen | A | B | / | C | / | |
| wanted/wanted_day_off_screen | A | B | E | C | / | BorderRadius.circular 하드코딩 다수 (AppRadius 치환) |
| wanted/wanted_request_screen | A | / | / | C | / | |

**잠재 시트로 이동할 Dialog**: schedule_generation에 `showDialog<void>`가 4회 사용 — 발행/충돌 확인/결과 표시 등 모두 S5에서 B로 전환 검토.

---

## 4. 화면별 체크리스트

**범례**: ✅=적용 필요 · ➖=해당 없음/보류 · 🔍=2차 검토

### announcement
| 화면 | AppBar → MoniqAppBar | Dialog → BottomSheet | EmptyState | Card | Stepper |
|---|---|---|---|---|---|
| announcement_screen.dart | ✅ (`AppBar(title: Text('팀 공지사항'))` 3곳) | ✅ 삭제 AlertDialog(line 719~) | ✅ line 45 | ✅ line 856 BorderRadius.circular(...) | ➖ |
| my_announcements_screen.dart | ✅ line 24 | ➖ | ✅ line 38 | ➖ | ➖ |

### auth
| 화면 | AppBar | Dialog | EmptyState | Card | Stepper |
|---|---|---|---|---|---|
| login_screen.dart | ➖ (커스텀 블롭 유지) | ➖ | ➖ | ➖ | ➖ |
| signup_screen.dart | ✅ line 56 | ➖ | ➖ | ➖ | ➖ |
| forgot_password_screen.dart | ✅ line 39 | ➖ | ➖ | ➖ | ➖ |
| email_verification_screen.dart | ✅ line 47 | ➖ | ➖ | ➖ | ➖ |

### calendar
| 화면 | AppBar | Dialog | EmptyState | Card | Stepper |
|---|---|---|---|---|---|
| calendar_screen.dart | 🔍 3종(모바일/와이드/웹) 분기. title 슬롯에 커스텀 월 선택기. → MoniqAppBar의 `title`을 커스텀 위젯(String 외) 수용하도록 시그니처 확장하거나, 월 선택기를 `leading` 옆 eyebrow로 재배치 | ➖ | ➖ | ➖ | ➖ |
| calendar_dialogs.dart | ➖ | ✅ `showModalBottomSheet` 5곳 + 내부 AlertDialog → 스타일만 B로 교체 | ➖ | ➖ | ➖ |
| calendar_drawer.dart / date_items_panel.dart / export 관련 | 🔍 읽지 않음. Export는 캡처용이므로 톤 영향 적음 | 🔍 | ➖ | 🔍 | ➖ |

### home
| 화면 | AppBar | Dialog | EmptyState | Card | Stepper |
|---|---|---|---|---|---|
| home_screen.dart | 🔍 custom `buildAppBar()` (아바타+벨) → MoniqAppBar에 `leading=avatar`, `trailing=NotificationsBellButton`로 위임 가능 | ✅ line 118 `showDialog` 1회 | ➖ | ➖ | ➖ |
| home_body.dart | ➖ | ➖ | ➖ | ➖ | ➖ |
| active_shift_card.dart | ➖ | ➖ | ➖ | 🔍 `BorderRadius.circular(32)` — 브랜드 히어로 카드이므로 AppRadius.xl(32)로 토큰화만 | ➖ |
| home_widgets.dart | ➖ | ➖ | ➖ | 🔍 섹션 카드들 GroupedCard 검토 | ➖ |

### notifications
| notifications_screen.dart | ✅ line 19 | ➖ | ✅ line 41 | 🔍 `_NotificationTile` 내부 라운드 토큰화 | ➖ |

### request
| 화면 | AppBar | Dialog | EmptyState | Card | Stepper |
|---|---|---|---|---|---|
| request_create_screen.dart | ✅ line 24 | ➖ | ➖ | 🔍 내부 섹션 카드 | **✅ S6** bars(0~2) |
| request_list_screen.dart | ✅ line 87 | ✅ AlertDialog 2회(취소/삭제 확인) → B | ✅ line 279, 419 | ✅ RequestCard 라운드/쉐도우 AppRadius 정렬 | ➖ |
| request_create_widgets.dart | ➖ | ➖ | ➖ | 🔍 | ➖ |

### schedule
| 화면 | AppBar | Dialog | EmptyState | Card | Stepper |
|---|---|---|---|---|---|
| schedule_generation_screen.dart | ✅ line 51 | ✅ AlertDialog 4회 → B | ➖ | ✅ 내부 하드코딩 `BorderRadius.circular(12)` 다수 | **✅ S7** dots(기간/미리보기/발행) |
| schedule_history_screen.dart | ✅ line 62, 110 (버전 상세) | ➖ | ➖ | 🔍 | ➖ |

### settings
| 화면 | AppBar | Dialog | EmptyState | Card | Stepper |
|---|---|---|---|---|---|
| settings_screen.dart | ✅ **S1**에서 일괄 | ✅ AlertDialog 3회(로그아웃/탈퇴/에러) → B | ➖ | ✅ GroupedCard 4섹션 | ➖ |
| profile_edit_screen.dart | ✅ line 44 | ➖ | ➖ | 🔍 | ➖ |

### team
대부분 기본 `AppBar(title: Text('...'))` 패턴 → MoniqAppBar로 그대로 치환.

| 화면 | AppBar | Dialog | EmptyState | Card | Stepper |
|---|---|---|---|---|---|
| team_list_screen.dart | ✅ line 25 | ✅ AlertDialog 3회 → B | ➖ | ✅ TeamSlidableTile 라운드 정리 | ➖ |
| team_screen.dart | 🔍 S9 (뷰별 AppBar 5종) | ➖ | ✅ line 101 (secondaryAction 보존 필요) | ➖ | ➖ |
| team_detail_screen.dart | ✅ line 23 | 🔍 team_detail_dialogs | ➖ | ✅ 섹션 카드 → GroupedCard | ➖ |
| team_create_screen.dart | ✅ line 98 | ➖ | ➖ | 🔍 | ➖ |
| team_join_screen.dart | ✅ line 55 | ➖ | ➖ | 🔍 | ➖ |
| members_screen.dart | ✅ line 30 | ✅ showModalBottomSheet 있지만 스타일 없음 | ➖ | ✅ MemberTile | ➖ |
| rules_screen.dart | ✅ line 21 | ➖ | ➖ | ✅ `_SectionCard` → MoniqGroupedCard 치환 | ➖ |
| schedule_rules_screen.dart | ✅ line 35 | ✅ AlertDialog 1회 → B | ➖ | ✅ | ➖ |
| custom_rules_screen.dart | ✅ line 43 | ➖ | ➖ | ✅ | ➖ |
| shift_types_screen.dart | ✅ line 33 | ✅ AlertDialog 1회(삭제 확인) → B, showModalBottomSheet 2회 shell 교체 | ➖ | ✅ `_ShiftTypeTile` | ➖ |
| team_settings_screen.dart | ✅ line 26 | ✅ AlertDialog 1회 → B | ➖ | ✅ | ➖ |

### wanted
| 화면 | AppBar | Dialog | EmptyState | Card | Stepper |
|---|---|---|---|---|---|
| wanted_day_off_screen.dart | ✅ line 44 | ➖ | ✅ line 70 | ✅ **`BorderRadius.circular` 하드코딩 10+ 곳** (line 429, 822, 1019, 1160, 1194, 1465, 1587, 1696 등) AppRadius로 치환 | ➖ |
| wanted_request_screen.dart | ✅ line 33 | ➖ | ➖ | 🔍 | ➖ |

---

## 5. Finding 추적표 (F1~F13)

| # | 내용(감사 기준) | 이번 리팩터 | 담당 Step |
|---|---|---|---|
| F1 | AppBar 스타일 제각각 → 통일 | **해결** | S1·S2·S3·S4·S9 |
| F2 | Settings 캐릭터 부재 → hero 카드에 캐릭터 | **해결** | S1 |
| F3 | 빈 상태가 Material 아이콘 기반 → 캐릭터 기반 | **해결** | S0·S10 |
| F4 | Request Create 단계 인디케이터 부재 | **해결** | S6 |
| F5 | Dialog 남용 → MoniqBottomSheet | **해결** | S1·S5 |
| F6 | (핸드오프에서 언급되지 않음 — 잔여) | 잔여 | 후속 감사 |
| F7 | Schedule Gen 3단계 UI 부재 | **해결** | S7 |
| F8 | (핸드오프에서 언급되지 않음 — 잔여) | 잔여 | 후속 감사 |
| F9 | (핸드오프에서 언급되지 않음 — 잔여) | 잔여 | 후속 감사 |
| F10 | 라운드 토큰 혼재 → AppRadius.md/.lg/.full 3종 | **해결** | S1·S8 |
| F11 | 뒤로가기/뒤로가기 pill 스타일 제각각 | **해결** | S2·S3·S4 (MoniqAppBar `_BackPill`) |
| F12 | 빈 상태 카피 톤 formal 편중 | **해결** | S10 |
| F13 | MONIQ ID monospace 튐 | **해결** | S1 |

> **잔여 항목(F6/F8/F9)**은 handoff에 구체 내용이 없다. Step 완료 후 디자인팀 톤 재감사에서 번호와 내용을 재확인하고, 별도 후속 PR로 다룬다.

---

## 6. 리스크 / 주의사항

### 6-1. MoniqEmptyState 시그니처 변경 — 회귀 위험 큼
- 7개 호출부를 한 PR(S0)에서 일괄 수정하지 않으면 빌드 깨짐.
- **대안**: 레거시 `MoniqEmptyState`를 `MoniqEmptyStateLegacy`로 리네임하고 deprecation 마커 부착 → 신규 파일은 이름 그대로 배치 → 호출부는 Step별로 이동. 두 버전을 동시에 유지하는 기간을 최소화.

### 6-2. CalendarScreen의 타이틀 슬롯이 커스텀 위젯
- `buildAppBarTitle()`가 월 선택 드롭다운 역할. MoniqAppBar의 `title: String`와 호환 불가.
- **완화안**: MoniqAppBar에 `titleWidget: Widget?` 옵션을 **추가 확장**하거나, 월 선택기를 `leading` 우측에 별도 chip으로 재배치. 이 결정은 S9 PR에서.

### 6-3. HomeScreen의 커스텀 AppBar
- 아바타 leading + 벨 trailing + eyebrow 역할 "HELLO, JOY" 삽입 기회.
- MoniqAppBar로 바꿀 때 `leading: HomeAvatar(...)`, `trailing: _NotificationsBellButton(...)`, `eyebrow: 'HELLO, ${firstName.toUpperCase()}'` 가 자연스러움. 반응형(와이드 레이아웃)에서 surface 배경/패딩이 바뀌는 기존 분기는 유지.

### 6-4. todayShiftTheme 의존 화면
- Settings(히어로), Home(active shift) 둘 다 `todayShiftThemeProvider`에 의존. 샴페인/다크 테마 토글 시 **히어로 카드 색과 onPrimary 대비** 시각 회귀를 S1·S9에서 실제로 눈으로 확인.

### 6-5. showModalBottomSheet 스타일 일괄 교체의 side-effect
- calendar_dialogs 5개, shift_types 2개 등은 기존 콘텐츠를 그대로 Shell에 감싸 넣기만 해도 되지만, grab handle을 자체 구현한 경우가 많아 **이중 표시되지 않도록** 내부 grab handle을 제거해야 함. S5 PR 리뷰 체크리스트에 명시.

### 6-6. 테스트 영향 범위
- 위젯 테스트가 `find.byType(AppBar)`나 `AlertDialog`로 스코핑되어 있다면 `MoniqAppBar`/`MoniqBottomSheetShell`로 갱신 필요.
- **사용자 작업**: 테스트 현황 확인 필요 (이 계획 시점에는 `test/` 내용 미검증).

### 6-7. BorderRadius.circular 하드코딩 청소의 회귀
- wanted_day_off_screen에만 10+곳. 시각적 변화가 있으니 Before/After 스크린샷 필요.

---

## 7. 검증 방법 (사용자가 `flutter run`으로 눈으로 확인)

사용자 실행: `flutter analyze` → `flutter test` → `flutter run` (또는 디바이스별 실행).
각 Step PR에 포함할 **Before/After 확인 포인트**:

### S0 (공통 컴포넌트 추가)
- [ ] 빌드 통과 (analyze 0 에러).
- [ ] 기존 화면 7개의 빈 상태가 **캐릭터 + 신규 카피**로 바뀌었는지 (notifications, announcement × 2, request_list × 2, team(무팀), wanted_day_off).

### S1 (Settings)
- [ ] 상단 히어로 카드 색이 오늘 시프트에 따라 바뀌는지.
- [ ] 히어로 우하단에 캐릭터 블롭이 은은히 보이는지.
- [ ] MONIQ ID가 `MQ-XXX-XXX` 포맷 + tabular figures로 정렬되는지.
- [ ] 로그아웃/탈퇴 버튼을 누르면 **바텀시트**가 뜨는지 (AlertDialog 금지).
- [ ] 라운드 값이 md/lg/full만 쓰이는지 (Debug Paint로 시각 검증 or 코드 리뷰).

### S2~S4 (AppBar 치환)
- [ ] 각 화면 타이틀과 뒤로가기 pill이 Settings와 동일 톤인지.
- [ ] 다크 모드 전환 시 배경과 title 대비가 유지되는지.
- [ ] 긴 타이틀 ellipsis 처리 확인.

### S5 (Dialog → BottomSheet)
- [ ] 모든 확인/파괴 액션이 바텀시트에서 일어나는지.
- [ ] Confirm body의 취소/확정 버튼 페어가 일관되게 outlined + filled pill인지.

### S6 (Request Create Stepper)
- [ ] 상단에 bars stepper가 보이고 현재 단계가 primary 컬러로 채워지는지.
- [ ] 이전 단계로 돌아갔을 때 bars가 축소되는지 (animated 240ms).

### S7 (Schedule Gen Stepper)
- [ ] dots stepper가 3단계 "기간 / 미리보기 / 발행"으로 표시되는지.
- [ ] 완료된 단계에 check 아이콘이 찍히는지.

### S8 (Card 일관화)
- [ ] team_detail / members / rules 섹션 카드가 동일한 rounding/shadow.
- [ ] wanted_day_off의 하드코딩 라운드가 전부 AppRadius.*로 교체되었는지.

### S9 (Home/Calendar/Team 메인)
- [ ] Home AppBar가 MoniqAppBar 스타일로 보이되 아바타/벨 위치는 유지.
- [ ] Calendar의 월 선택기가 자연스럽게 배치되는지.

### S10 (Empty 톤 2차 감사)
- [ ] "~합니다" 종결이 빈 상태에서 모두 사라졌는지.
- [ ] 캐릭터 사용 기조가 일관되는지 (.peaceful / .encouraging / (.cheerful) 선택이 상황과 맞는지).

---

## 8. PR 분할 제안

| PR | Step | 타이틀 초안 |
|---|---|---|
| #1 | S0 | refactor(ui): add Moniq common widgets + migrate EmptyState call sites |
| #2 | S1 | refactor(settings): rewrite with MoniqAppBar/GroupedCard/BottomSheet (closes F1, F2, F5, F10, F13) |
| #3 | S2 | refactor(ui): unify AppBar across notifications/announcement/request_list/schedule_history/team list/detail/create/join (closes F1, F11) |
| #4 | S3 | refactor(team): unify AppBar in rules/schedule_rules/custom_rules/shift_types/members/team_settings/profile_edit |
| #5 | S4 | refactor(auth): unify AppBar in signup/forgot_password/email_verification |
| #6 | S5 | refactor(ui): migrate confirm AlertDialogs to MoniqBottomSheet (closes F5) |
| #7 | S6 | feat(request): add MoniqStepper.bars to request create (closes F4) |
| #8 | S7 | feat(schedule): add MoniqStepper.dots to generation (closes F7) |
| #9 | S8 | refactor(ui): replace hardcoded radii with AppRadius tokens (closes F10) |
| #10 | S9 | refactor(ui): adopt MoniqAppBar in Home/Calendar/Team main tabs |
| #11 | S10 | chore(ui): empty-state copy & character tone audit pass (closes F3, F12) |

각 PR 설명에 "Closes F<번호>"를 반드시 기입.

---

## 9. 후속(out-of-scope) 작업

- **F6/F8/F9** 재감사 — handoff.html에서 번호/내용 미상. 별도 토큰 감사 세션 필요.
- **다크 모드 톤 체크** — `design/dark_*.html`과의 1:1 맞춤 비교는 이번 계획에 포함하지 않음. S9 직후 별도 시각 감사.
- **테스트 보강** — MoniqAppBar/BottomSheet의 골든 테스트 추가는 별도 트랙으로.
- **moniq-design-system 스킬 문서 갱신** — 컴포넌트 5종이 확정되면 스킬의 컴포넌트 카탈로그에도 반영.
