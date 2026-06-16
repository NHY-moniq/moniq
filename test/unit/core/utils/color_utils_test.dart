import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moniq/core/utils/color_utils.dart';

void main() {
  group('parseHexColor', () {
    test('# 접두사가 있는 6자리 hex 는 불투명 색으로 변환', () {
      expect(parseHexColor('#5A8BB5'), const Color(0xFF5A8BB5));
    });

    test('# 없는 6자리 hex 도 동일하게 처리', () {
      expect(parseHexColor('5A8BB5'), const Color(0xFF5A8BB5));
    });

    test('알파를 포함한 8자리 hex 는 알파를 그대로 사용', () {
      // 8자리(#포함 9자) → FF 접두사 미추가, 입력 알파(80) 유지
      expect(parseHexColor('#805A8BB5'), const Color(0x805A8BB5));
    });

    test('검정/흰색 경계값', () {
      expect(parseHexColor('#000000'), const Color(0xFF000000));
      expect(parseHexColor('FFFFFF'), const Color(0xFFFFFFFF));
    });
  });
}
