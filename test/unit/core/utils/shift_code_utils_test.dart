import 'package:flutter_test/flutter_test.dart';
import 'package:moniq/core/utils/shift_code_utils.dart';

void main() {
  group('canonicalShiftCode', () {
    test('표준 코드 D/E/N 은 그대로 정규화된다', () {
      expect(canonicalShiftCode('D', '데이'), 'D');
      expect(canonicalShiftCode('E', '이브닝'), 'E');
      expect(canonicalShiftCode('N', '나이트'), 'N');
    });

    test('한글 이름으로 코드를 추론한다', () {
      expect(canonicalShiftCode('x', '주간 근무'), 'D');
      expect(canonicalShiftCode('x', '저녁 근무'), 'E');
      expect(canonicalShiftCode('x', '야간 근무'), 'N');
    });

    test('영문 이름(day/eve/night)은 대소문자 무시하고 추론한다', () {
      expect(canonicalShiftCode('x', 'Day Shift'), 'D');
      expect(canonicalShiftCode('x', 'EVENING'), 'E');
      expect(canonicalShiftCode('x', 'Night'), 'N');
    });

    test('매칭되지 않으면 입력 코드를 대문자로 반환한다', () {
      expect(canonicalShiftCode('ed', '교육'), 'ED');
      expect(canonicalShiftCode('off', '오프'), 'OFF');
    });

    test('이름 기반 매칭이 코드보다 우선 적용된다(D→E→N 순)', () {
      // code 'E' 이지만 이름에 '데이'가 있으면 첫 분기(D)에서 매칭된다.
      expect(canonicalShiftCode('E', '데이'), 'D');
    });
  });
}
