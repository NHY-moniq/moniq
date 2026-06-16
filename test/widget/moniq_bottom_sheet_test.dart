import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moniq/presentation/widgets/common/moniq_bottom_sheet.dart';

/// 공용 바텀시트 위젯들의 UI 가드.
///
/// - 셸이 화면 비율(maxHeightFactor)을 넘지 않게 높이를 제한하는지
/// - 긴 옵션 목록을 스크롤로 감싸면 overflow 가 없는지
/// - 확인/안내 시트 본문이 핵심 요소를 렌더하고 overflow 가 없는지
void main() {
  // 작은 화면을 강제하는 공통 셋업.
  void useSmallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(400, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget wrap(Widget child) => MaterialApp(
        home: Scaffold(
          body: Align(alignment: Alignment.bottomCenter, child: child),
        ),
      );

  group('MoniqBottomSheetShell', () {
    testWidgets('handle/eyebrow/title 을 렌더한다', (tester) async {
      useSmallScreen(tester);
      await tester.pumpWidget(
        wrap(
          const MoniqBottomSheetShell(
            title: '팀 선택',
            eyebrow: 'FILTER',
            child: Text('본문'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('팀 선택'), findsOneWidget);
      expect(find.text('FILTER'), findsOneWidget);
      expect(find.text('본문'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('내용이 길고 스크롤로 감싸면 maxHeight 를 넘지 않고 overflow 없음',
        (tester) async {
      useSmallScreen(tester);
      const factor = 0.56;
      await tester.pumpWidget(
        wrap(
          MoniqBottomSheetShell(
            title: '목록',
            maxHeightFactor: factor,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (var i = 0; i < 40; i++)
                    SizedBox(height: 48, child: Text('항목 $i')),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      final sheetHeight =
          tester.getSize(find.byType(MoniqBottomSheetShell)).height;
      // 화면 700 * 0.56 ≈ 392. 약간의 오차를 허용해 상한을 검증한다.
      expect(sheetHeight, lessThanOrEqualTo(700 * factor + 1));
      expect(find.byType(Scrollable), findsWidgets);
    });
  });

  group('MoniqConfirmSheetBody', () {
    testWidgets('메시지와 확인/취소 라벨을 렌더하고 overflow 없음', (tester) async {
      useSmallScreen(tester);
      await tester.pumpWidget(
        wrap(
          const MoniqBottomSheetShell(
            title: '삭제할까요?',
            child: MoniqConfirmSheetBody(
              message: '되돌릴 수 없어요.',
              confirmLabel: '삭제',
              cancelLabel: '취소',
              destructive: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('되돌릴 수 없어요.'), findsOneWidget);
      expect(find.text('삭제'), findsOneWidget);
      expect(find.text('취소'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('MoniqSheetOption', () {
    testWidgets('라벨/설명을 렌더하고 탭 콜백이 호출된다', (tester) async {
      useSmallScreen(tester);
      var tapped = false;
      await tester.pumpWidget(
        wrap(
          MoniqBottomSheetShell(
            child: MoniqSheetOption(
              icon: Icons.palette_outlined,
              label: '화면 모드',
              description: '시프트에 따라 자동',
              onTap: () => tapped = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('화면 모드'), findsOneWidget);
      expect(find.text('시프트에 따라 자동'), findsOneWidget);

      await tester.tap(find.text('화면 모드'));
      expect(tapped, isTrue);
      expect(tester.takeException(), isNull);
    });
  });
}
