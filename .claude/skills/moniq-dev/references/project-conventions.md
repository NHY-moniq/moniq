# Moniq 프로젝트 컨벤션

## 기술 스택

- **프론트엔드**: Flutter, Riverpod 3.x, Flutter Hooks, go_router, Freezed + json_serializable
- **백엔드**: Supabase (Auth, Postgres, RLS, Realtime, Edge Functions)
- **아키텍처**: Layer-centered MVVM

## 디렉토리 구조

```
lib/
├── main.dart
├── app.dart                    # MaterialApp, ThemeData, Router
├── presentation/               # Presentation 레이어
│   ├── screens/                # 화면 위젯
│   │   ├── auth/               # 로그인, 회원가입, 비밀번호 찾기
│   │   ├── home/               # 홈 탭 (개인 캘린더)
│   │   ├── team/               # 팀 탭, 팀 리스트, 팀 상세
│   │   ├── schedule/           # 근무표 생성, 미리보기
│   │   ├── request/            # 교환/변경 요청
│   │   └── settings/           # 설정
│   ├── widgets/                # 공유 위젯
│   │   ├── calendar/           # 캘린더 관련 위젯
│   │   ├── bottom_sheets/      # Bottom Sheet 위젯
│   │   └── common/             # 공통 위젯 (버튼, 카드 등)
│   ├── viewmodels/             # Notifier/AsyncNotifier
│   ├── router/                 # go_router 설정
│   └── theme/                  # ThemeData, 컬러, 타이포그래피
├── domain/                     # Domain/Application 레이어
│   ├── models/                 # 도메인 모델 (순수 Dart)
│   ├── usecases/               # 유스케이스
│   ├── rules/                  # 룰 엔진
│   └── providers/              # 도메인 Provider
├── data/                       # Data 레이어
│   ├── datasources/            # Supabase 데이터소스
│   ├── repositories/           # Repository 구현체
│   ├── models/                 # Freezed 모델, DTO
│   └── providers/              # 데이터 Provider
└── core/                       # 공유 유틸리티
    ├── constants/
    ├── extensions/
    └── utils/
```

## 네이밍 컨벤션

| 항목 | 패턴 | 예시 |
|------|------|------|
| Screen | `{Name}Screen` | `LoginScreen` |
| Widget | `{Name}Widget` / `{Name}Card` | `TodayCard`, `ShiftBadge` |
| ViewModel | `{Name}ViewModel` | `HomeViewModel` |
| Repository | `{Name}Repository` | `TeamRepository` |
| DataSource | `{Name}DataSource` | `TeamRemoteDataSource` |
| UseCase | `{Verb}{Noun}UseCase` | `GenerateScheduleUseCase` |
| Model (Data) | `{Name}Model` | `TeamModel` |
| Model (Domain) | `{Name}` | `Team`, `ShiftType` |
| Provider | `{name}Provider` | `teamRepositoryProvider` |

## 파일 네이밍

- snake_case: `login_screen.dart`, `team_repository.dart`
- 접미사로 레이어 역할 표시: `_screen`, `_viewmodel`, `_repository`, `_model`

## 코딩 규칙

1. **불변성**: Freezed로 모델을 정의하고, copyWith로 업데이트
2. **상태 관리**: Riverpod AsyncNotifier/Notifier 사용
3. **에러 처리**: AsyncValue의 loading/error/data 상태 모두 처리. 에러는 `SelectableText.rich`로 빨간색 표시 (SnackBar 사용 금지)
4. **의존성 주입**: Riverpod Provider를 통한 DI
5. **관심사 분리**: UI에 비즈니스 로직을 넣지 않음
6. **함수형/선언적**: 구성(composition) > 상속(inheritance)
7. **변수 네이밍**: 보조 동사 사용 (isLoading, hasError, canSubmit)
8. **const 생성자**: 불변 위젯에는 반드시 const 생성자 사용
9. **arrow syntax**: 한 줄 함수/메서드에 `=>` 사용, expression body for one-line getters/setters
10. **trailing commas**: 다중 파라미터 함수의 닫는 괄호 앞에 반드시 콤마
11. **80자 줄 제한**: 줄 길이 80자 이내 유지
12. **log 사용**: `print` 대신 `dart:developer`의 `log` 사용
13. **private 위젯 클래스**: `Widget _buildSomething()` 메서드 대신 별도의 private 위젯 클래스 생성

## 파일 구조 규칙

각 파일의 구성 순서:
1. exported widget (메인 위젯)
2. subwidgets (private 위젯 클래스)
3. helpers (유틸 함수)
4. static content (상수)
5. types (타입 정의)

## Riverpod 규칙

**필수 사용:**
- `@riverpod` annotation으로 provider 생성
- `AsyncNotifierProvider`, `NotifierProvider`
- `ref.invalidate()`로 수동 갱신
- 위젯 dispose 시 비동기 작업 취소 처리

**사용 금지:**
- `StateProvider` (금지)
- `StateNotifierProvider` (금지)
- `ChangeNotifierProvider` (금지)

## Riverpod 패턴

```dart
// AsyncNotifier 기반 ViewModel
@riverpod
class HomeViewModel extends _$HomeViewModel {
  @override
  Future<HomeState> build() async {
    final repo = ref.watch(scheduleRepositoryProvider);
    return repo.getTodaySchedule();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetch());
  }
}
```

## 위젯 규칙

- **기본**: `ConsumerWidget` (Riverpod 상태 의존)
- **Hooks 필요 시**: `HookConsumerWidget` (Riverpod + Flutter Hooks)
- **Stateless 우선**: 가능하면 stateless 위젯 사용
- **RefreshIndicator**: pull-to-refresh가 필요한 목록에 필수 적용
- **TextField**: `textCapitalization`, `keyboardType`, `textInputAction` 항상 설정
- **Image.network**: 반드시 `errorBuilder` 포함
- **이미지**: 정적 이미지는 `AssetImage`, 원격 이미지는 `cached_network_image`
- **리스트**: `ListView.builder` 사용 (최적화)
- **반응형**: `LayoutBuilder` 또는 `MediaQuery` 사용
- **테마 참조**: `Theme.of(context).textTheme.titleLarge` (deprecated 이름 사용 금지)

## Model/JSON 규칙

```dart
@freezed
@JsonSerializable(fieldRename: FieldRename.snake)
class TeamModel with _$TeamModel {
  const factory TeamModel({
    // read-only 필드
    @JsonKey(includeFromJson: true, includeToJson: false)
    required String id,
    required String name,
    required DateTime createdAt,
    required DateTime updatedAt,
    @Default(false) bool isDeleted,
  }) = _TeamModel;

  factory TeamModel.fromJson(Map<String, dynamic> json) =>
      _$TeamModelFromJson(json);
}

// DB Enum
enum RequestStatus {
  @JsonValue(0) pending,
  @JsonValue(1) approved,
  @JsonValue(2) rejected,
  @JsonValue(3) cancelled,
}
```

## 팀 타입 규칙

- **조직형(organizational)**: 근무표 생성, 룰 설정, 인원 설정 UI 노출
- **개인형(personal)**: 관리자 기능 숨김, 캘린더 확인/협업만 제공
