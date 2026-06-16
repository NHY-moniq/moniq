// 통합 테스트 — time_utils + 모델(ShiftWithType/ShiftModel/ShiftTypeModel)을
// 함께 엮어 "월별 근무 시간 합계" 시나리오를 검증한다.
//
// 여러 유닛을 조합해 흐름을 검증하는 다중 유닛 통합 테스트다.
import 'package:flutter_test/flutter_test.dart';
import 'package:moniq/core/utils/time_utils.dart';
import 'package:moniq/data/models/shift_with_type.dart';

import '../helpers/fixtures.dart';

void main() {
  group('monthlyWorkedHours', () {
    test('해당 월의 근무만 합산한다(다른 달은 제외)', () {
      final shifts = <DateTime, List<ShiftWithType>>{
        // 6월: 데이(8h) + 나이트(8h) = 16h
        DateTime(2026, 6, 1): [
          buildShiftWithType(shiftType: dayShiftType),
        ],
        DateTime(2026, 6, 2): [
          buildShiftWithType(shiftType: nightShiftType),
        ],
        // 7월 근무는 6월 합계에서 제외돼야 함
        DateTime(2026, 7, 1): [
          buildShiftWithType(shiftType: dayShiftType),
        ],
      };

      expect(monthlyWorkedHours(shifts, DateTime(2026, 6, 1)), 16.0);
      expect(monthlyWorkedHours(shifts, DateTime(2026, 7, 1)), 8.0);
    });

    test('하루 복수 근무 및 OFF(0h) 처리', () {
      final shifts = <DateTime, List<ShiftWithType>>{
        DateTime(2026, 6, 1): [
          buildShiftWithType(shiftType: dayShiftType), // 8h
          buildShiftWithType(shiftType: eveningShiftType), // 8h
        ],
        DateTime(2026, 6, 3): [
          buildShiftWithType(shiftType: offShiftType), // 0h
        ],
      };

      expect(monthlyWorkedHours(shifts, DateTime(2026, 6, 15)), 16.0);
    });

    test('근무가 없으면 0', () {
      expect(monthlyWorkedHours({}, DateTime(2026, 6, 1)), 0.0);
    });
  });
}
