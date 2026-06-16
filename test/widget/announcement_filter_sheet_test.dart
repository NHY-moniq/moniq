import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/presentation/widgets/announcement/announcement_filter_sheet.dart';

/// 공지사항 "팀 선택" 필터 바텀시트의 overflow 회귀 테스트.
///
/// 팀이 많을 때 시트 최대 높이를 초과해 RenderFlex overflow 가 나던 버그
/// (BOTTOM OVERFLOWED BY N PIXELS)를 막기 위한 가드. 본문이 스크롤되도록
/// 수정한 뒤에는 작은 화면 + 많은 옵션에서도 overflow 예외가 없어야 한다.
void main() {
  List<AnnouncementFilterOption<String?>> manyOptions() => [
        const AnnouncementFilterOption<String?>(
          value: null,
          label: '전체',
          icon: Icons.groups_rounded,
        ),
        for (var i = 0; i < 12; i++)
          AnnouncementFilterOption<String?>(
            value: 'team-$i',
            label: '팀 $i',
            icon: Icons.campaign_outlined,
          ),
      ];

  Widget harness(void Function(BuildContext) onOpen) {
    return ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => onOpen(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('옵션이 많아도 overflow 없이 스크롤된다', (tester) async {
    // 작은 화면을 강제해 많은 옵션이 시트 최대 높이를 초과하게 한다.
    tester.view.physicalSize = const Size(400, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(harness((context) {
      showAnnouncementFilterSheet<String?>(
        context: context,
        title: '팀 선택',
        options: manyOptions(),
        selectedValue: null,
      );
    }));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // overflow 가 나면 layout/paint 단계에서 FlutterError 가 기록된다.
    expect(tester.takeException(), isNull);
    // 헤더와 첫 옵션은 보인다.
    expect(find.text('팀 선택'), findsOneWidget);
    expect(find.text('전체'), findsOneWidget);
    // 내용이 길어 스크롤 가능한 영역이 존재한다.
    expect(find.byType(Scrollable), findsWidgets);
  });

  testWidgets('옵션을 탭하면 해당 값을 반환한다', (tester) async {
    tester.view.physicalSize = const Size(400, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    AnnouncementFilterOption<String?>? picked;
    await tester.pumpWidget(harness((context) async {
      picked = await showAnnouncementFilterSheet<String?>(
        context: context,
        title: '팀 선택',
        options: manyOptions(),
        selectedValue: null,
      );
    }));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('팀 3'));
    await tester.pumpAndSettle();

    expect(picked?.value, 'team-3');
    expect(tester.takeException(), isNull);
  });
}
