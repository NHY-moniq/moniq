// 통합 테스트 — team_icon_utils(decode/encode) + color_utils(parseHexColor)를
// 함께 검증한다. 인코딩 문자열을 디코딩한 뒤 색상 문자열이 실제 Color 로
// 정상 변환되는지까지 확인한다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moniq/core/utils/color_utils.dart';
import 'package:moniq/core/utils/team_icon_utils.dart';

void main() {
  group('팀 아이콘 디코딩 → 색상 변환', () {
    test('이모지+색상 아이콘의 색상이 Color 로 변환된다', () {
      final data = TeamIconData.decode('🏥|#5A8BB5');
      expect(parseHexColor(data.color), const Color(0xFF5A8BB5));
    });

    test('null 아이콘의 기본 색상도 유효한 Color 로 변환된다', () {
      final data = TeamIconData.decode(null);
      expect(parseHexColor(data.color), const Color(0xFF5A8BB5));
    });

    test('레거시 아이콘 이름은 이모지로 매핑되고 기본 색상을 가진다', () {
      final data = TeamIconData.decode('local_hospital');
      expect(data.emoji, '🏥');
      expect(parseHexColor(data.color), const Color(0xFF5A8BB5));
    });

    test('encode→decode→encode 가 안정적이며 색상 변환도 일관된다', () {
      const original = '😀|#ED64A6';
      final decoded = TeamIconData.decode(original);
      expect(decoded.encode(), original);
      expect(parseHexColor(decoded.color), const Color(0xFFED64A6));
    });
  });
}
