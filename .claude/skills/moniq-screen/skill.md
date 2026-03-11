---
name: moniq-screen
description: "Flutter 화면 및 위젯 생성 패턴. Screen, ViewModel, Bottom Sheet, Empty State 템플릿. '화면 생성', '스크린', '위젯' 시 사용."
---

# Moniq Screen — 화면/위젯 생성 패턴

## Screen 템플릿

`_build...` 메서드 대신 private 위젯 클래스를 사용한다.
Hooks가 필요하면 `HookConsumerWidget`을 사용한다.

```dart
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class {Name}Screen extends ConsumerWidget {
  const {Name}Screen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch({name}ViewModelProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('{Title}'),
      ),
      body: state.when(
        data: (data) => data.isEmpty
            ? const _{Name}EmptyState()
            : _{Name}Content(data: data),
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, _) => _{Name}Error(
          error: error,
        ),
      ),
    );
  }
}

// --- private 위젯 클래스 ---

class _{Name}Content extends StatelessWidget {
  const _{Name}Content({required this.data});
  final {State} data;

  @override
  Widget build(BuildContext context) {
    return /* content */;
  }
}

class _{Name}Error extends ConsumerWidget {
  const _{Name}Error({required this.error});
  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SelectableText.rich(
            TextSpan(
              text: '오류가 발생했습니다: $error',
              style: const TextStyle(
                color: Colors.red,
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => ref.invalidate(
              {name}ViewModelProvider,
            ),
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }
}
```

### HookConsumerWidget 패턴 (Hooks 필요 시)

```dart
class {Name}Screen extends HookConsumerWidget {
  const {Name}Screen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = useTextEditingController();
    final isLoading = useState(false);
    // ...
  }
}
```

## ViewModel 템플릿

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

part '{name}_viewmodel.g.dart';

@riverpod
class {Name}ViewModel extends _${Name}ViewModel {
  @override
  Future<{State}> build() async {
    final repo = ref.watch({name}RepositoryProvider);
    return repo.fetch();
  }

  Future<void> doAction(/* params */) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      // 비즈니스 로직
      return /* result */;
    });
  }
}
```

## Bottom Sheet 템플릿

```dart
void show{Name}BottomSheet(BuildContext context, {required /* params */}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) => SingleChildScrollView(
        controller: scrollController,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 드래그 핸들
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // 컨텐츠
            ],
          ),
        ),
      ),
    ),
  );
}
```

## Empty State 템플릿

```dart
class {Name}EmptyState extends StatelessWidget {
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const {Name}EmptyState({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(message, style: Theme.of(context).textTheme.bodyLarge),
          if (actionLabel != null) ...[
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
```

## go_router 라우트 등록 패턴

```dart
GoRoute(
  path: '/{path}',
  name: '{Name}Screen.routeName',
  builder: (context, state) => const {Name}Screen(),
),
```

## 화면별 구현 참조

| 화면 | spec 섹션 | 필수 상태 |
|------|----------|----------|
| 로그인 | 9.1 | 로딩, 오류 (자격증명/네트워크) |
| 홈 | 9.2 | 로딩, 빈 상태, 일반 |
| 팀 | 9.3 | 로딩, 빈 상태 (즐겨찾기 없음/미가입), 일반 |
| 팀 리스트 | 9.4 | 빈 상태 |
| 팀 상세 | 9.5 | 로딩 |
| 룰 관리 | 9.6 | 빈 상태, 일반 |
| 근무표 생성 | 9.7 | 입력, 미리보기, 로딩 |
| 요청 | 9.8 | 탭별 빈 상태, 일반 |
| 설정 | 9.9 | 일반 |
