import 'package:flutter_test/flutter_test.dart';
import 'package:moniq/core/utils/time_utils.dart';

import '../../../helpers/fixtures.dart';

void main() {
  group('formatTimeString', () {
    test('HH:mm:ss → HH:mm', () {
      expect(formatTimeString('09:00:00'), '09:00');
      expect(formatTimeString('23:30:45'), '23:30');
    });

    test('null 또는 너무 짧은 문자열은 빈 문자열', () {
      expect(formatTimeString(null), '');
      expect(formatTimeString('9:0'), '');
    });
  });

  group('parseTimeToMinutes', () {
    test('HH:mm / HH:mm:ss 를 분으로 변환', () {
      expect(parseTimeToMinutes('00:00'), 0);
      expect(parseTimeToMinutes('09:30'), 570);
      expect(parseTimeToMinutes('23:00:00'), 1380);
    });

    test('잘못된 입력은 null', () {
      expect(parseTimeToMinutes(null), isNull);
      expect(parseTimeToMinutes('ab'), isNull);
      expect(parseTimeToMinutes('0930'), isNull); // 콜론 없음
    });
  });

  group('isNowInShiftRange', () {
    test('OFF 근무는 항상 false', () {
      expect(isNowInShiftRange(offShiftType, DateTime(2026, 6, 1, 12)), isFalse);
    });

    test('주간 교대: 시작~종료 구간 내부만 true', () {
      expect(isNowInShiftRange(dayShiftType, DateTime(2026, 6, 1, 10)), isTrue);
      expect(isNowInShiftRange(dayShiftType, DateTime(2026, 6, 1, 8)), isFalse);
      // 종료시각(17:00) 정각은 미포함
      expect(isNowInShiftRange(dayShiftType, DateTime(2026, 6, 1, 17)), isFalse);
    });

    test('야간 교대(자정 넘김): 시작 이후 또는 종료 이전이면 true', () {
      expect(
        isNowInShiftRange(nightShiftType, DateTime(2026, 6, 1, 23, 30)),
        isTrue,
      );
      expect(
        isNowInShiftRange(nightShiftType, DateTime(2026, 6, 1, 5)),
        isTrue,
      );
      expect(
        isNowInShiftRange(nightShiftType, DateTime(2026, 6, 1, 12)),
        isFalse,
      );
    });
  });

  group('shiftTypeHours', () {
    test('주간/이브닝 근무 시간', () {
      expect(shiftTypeHours(dayShiftType), 8.0);
      expect(shiftTypeHours(eveningShiftType), 8.0);
    });

    test('야간 교대는 자정을 넘겨 계산한다', () {
      expect(shiftTypeHours(nightShiftType), 8.0);
    });

    test('OFF 또는 시간 미설정은 0', () {
      expect(shiftTypeHours(offShiftType), 0);
      expect(
        shiftTypeHours(buildShiftType(startTime: null, endTime: null)),
        0,
      );
    });
  });
}
