---
name: flutter-screen
description: "Flutter 화면을 MVVM 패턴으로 구현한다. '화면 구현', '스크린 만들기', 'Flutter 화면', '위젯 구현' 요청 시 사용."
---

# Flutter Screen — MVVM 패턴 화면 구현

## 목적
디자이너 명세를 기반으로 Flutter 화면을 Layer-centered MVVM 패턴으로 구현한다.

## 워크플로우

### Step 1: 입력 확인
1. 디자인 명세 확인 (`docs/design/screens/` 하위)
2. 라우트 확인 (`lib/presentation/routes/app_router.dart`)
3. 필요한 도메인 모델/리포지토리 확인

### Step 2: ViewModel 생성
```dart
// lib/presentation/view_models/{feature}_view_model.dart
@riverpod
class FeatureViewModel extends _$FeatureViewModel {
  @override
  FutureOr<FeatureState> build() async {
    // 초기 데이터 로드
  }

  Future<void> someAction() async {
    // 비즈니스 로직은 use case에 위임
  }
}
```

**ViewModel 규칙:**
- AsyncNotifier 사용 (데이터 로딩이 필요한 경우)
- Notifier 사용 (동기적 UI 상태만 관리하는 경우)
- 리포지토리 직접 접근은 ref.watch/read로 처리
- UI 상태는 Freezed로 정의

### Step 3: UI State 정의
```dart
// lib/presentation/view_models/{feature}_state.dart
@freezed
class FeatureState with _$FeatureState {
  const factory FeatureState({
    required List<Item> items,
    @Default(false) bool isLoading,
    String? errorMessage,
  }) = _FeatureState;
}
```

### Step 4: Screen 구현
```dart
// lib/presentation/screens/{feature}/{feature}_screen.dart
class FeatureScreen extends ConsumerWidget {
  const FeatureScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(featureViewModelProvider);
    return state.when(
      data: (data) => _buildContent(context, data),
      loading: () => const LoadingView(),
      error: (e, st) => ErrorView(message: e.toString()),
    );
  }
}
```

**Screen 규칙:**
- ConsumerWidget 또는 ConsumerStatefulWidget 사용
- 상태 분기: AsyncValue.when() 패턴
- 큰 위젯은 별도 파일로 분리
- 하드코딩 문자열은 상수로 추출

### Step 5: 라우트 등록
```dart
GoRoute(
  path: '/feature',
  builder: (context, state) => const FeatureScreen(),
),
```

### Step 6: 빌드 확인
```bash
dart run build_runner build --delete-conflicting-outputs
flutter analyze
```

## 파일 생성 패턴
```
lib/presentation/
├── screens/{feature}/
│   ├── {feature}_screen.dart
│   └── widgets/                 # 화면 전용 위젯
├── view_models/
│   ├── {feature}_view_model.dart
│   └── {feature}_state.dart     # (별도 상태 모델 필요 시)
```

## 출력 규칙
- 모든 코드는 `flutter analyze` 통과해야 한다
- 상태별 UI(Loading/Empty/Error/Normal)를 반드시 처리한다
- 접근성: 시맨틱 위젯 사용, 최소 터치 타깃 44x44
