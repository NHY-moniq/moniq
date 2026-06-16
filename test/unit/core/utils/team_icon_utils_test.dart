import 'package:flutter_test/flutter_test.dart';
import 'package:moniq/core/utils/team_icon_utils.dart';

void main() {
  group('TeamIconData.decode', () {
    test('null/빈 문자열은 기본 이모지+색상', () {
      final d = TeamIconData.decode(null);
      expect(d.emoji, defaultEmoji);
      expect(d.color, '#5A8BB5');
      expect(d.isImage, isFalse);
    });

    test('이미지 형식 "image|url"', () {
      final d = TeamIconData.decode('image|https://cdn.example.com/a.png');
      expect(d.isImage, isTrue);
      expect(d.imageUrl, 'https://cdn.example.com/a.png');
    });

    test('이모지+색상 형식 "emoji|#color"', () {
      final d = TeamIconData.decode('😀|#FF0000');
      expect(d.emoji, '😀');
      expect(d.color, '#FF0000');
      expect(d.isImage, isFalse);
    });

    test('레거시 Material 아이콘 이름 → 이모지 매핑', () {
      expect(TeamIconData.decode('local_hospital').emoji, '🏥');
      expect(TeamIconData.decode('business').emoji, '🏢');
      expect(TeamIconData.decode('groups').emoji, '👥');
      // 미정의 레거시 이름은 기본(👥)으로 폴백
      expect(TeamIconData.decode('unknown_legacy').emoji, '👥');
    });
  });

  group('TeamIconData.encode', () {
    test('이모지+색상 인코딩', () {
      const d = TeamIconData(emoji: '🏥', color: '#5A8BB5');
      expect(d.encode(), '🏥|#5A8BB5');
    });

    test('이미지 인코딩', () {
      const d = TeamIconData(color: '#5A8BB5', imageUrl: 'https://x/y.png');
      expect(d.encode(), 'image|https://x/y.png');
    });
  });

  group('decode/encode 라운드트립', () {
    test('이모지+색상은 인코딩 후 동일 문자열로 복원', () {
      expect(TeamIconData.decode('😀|#FF0000').encode(), '😀|#FF0000');
    });

    test('이미지는 인코딩 후 동일 문자열로 복원', () {
      const icon = 'image|https://x/y.png';
      expect(TeamIconData.decode(icon).encode(), icon);
    });
  });
}
