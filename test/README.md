# Moniq 테스트

소스 레이어를 미러링한 디렉토리 구조로 단위/통합 테스트를 둔다. (Flutter 표준
테스트 디렉토리는 `test/` 이므로 `flutter test` 가 자동 인식하도록 `test/`
하위에 둔다.)

```
test/
├── helpers/
│   └── fixtures.dart        # 공용 fixture/빌더
├── unit/                    # 단위 테스트 — 순수 함수/모델 (UI 아님)
│   ├── core/utils/          #   core/utils/*.dart
│   └── models/              #   data/models/*.dart (fromJson/계산 속성)
├── integration/             # 통합 테스트 — 여러 유닛을 조합한 시나리오
│   ├── monthly_worked_hours_test.dart
│   └── team_icon_color_test.dart
├── widget/                  # 위젯(UI) 테스트 — 렌더/overflow/상호작용
│   ├── announcement_filter_sheet_test.dart
│   └── moniq_bottom_sheet_test.dart
└── widget_test.dart         # 기존 스모크 테스트
```

세 갈래의 차이:

| 레이어 | 무엇을 검증 | 위젯 렌더 | 예시 |
|---|---|---|---|
| `unit` | 순수 함수·모델 로직 (UI 무관) | ❌ | `parseHexColor`, `ShiftTypeModel.fromJson` |
| `integration` | 여러 유닛을 엮은 시나리오 | ❌ | `monthlyWorkedHours` 합산 |
| `widget` | 화면/위젯 렌더·overflow·탭 동작 | ✅ | 바텀시트 overflow 가드 |

> `unit` 은 **UI를 테스트하지 않는다.** `core/utils`·`data/models` 의 순수
> 로직만 다룬다. 화면/위젯 검증은 `widget/` 레이어에서 한다.

## 실행

```bash
flutter test                      # 전체
flutter test test/unit            # 단위만
flutter test test/integration     # 통합만
flutter test test/widget          # 위젯(UI)만
```

> 경로 인자는 **명령을 실행한 디렉토리 기준**이다. 프로젝트 루트에서 실행할 것
> (`test/` 안에서 `flutter test test/unit` 하면 `test/test/unit` 을 찾아 실패).

## 범위 메모

- `core/utils` 의 순수 함수와 `data/models` 의 `fromJson`/계산 속성처럼
  외부 의존성 없이 결정적으로 검증 가능한 로직을 우선 대상으로 한다.
- 스케줄 생성 알고리즘(`_generateShifts`, `_computeCustomRuleViolations`)은
  `schedule_generation_viewmodel.dart` 의 `part of` 로 선언된 **private**
  함수라 별도 파일에서 import 할 수 없다. 테스트하려면 별도 파일로 추출하거나
  public 진입점을 노출하는 리팩토링이 선행돼야 한다.
- DataSource/Repository 는 Supabase 클라이언트에 의존하므로, 테스트하려면
  mock 주입 구조가 필요하다(현재 미구성).
