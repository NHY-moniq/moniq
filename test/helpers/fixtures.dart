/// 테스트 공용 fixture/빌더 모음.
///
/// 여러 테스트에서 반복되는 모델 인스턴스 생성을 한곳에 모아 중복을 제거한다.
library;

import 'package:moniq/data/models/shift_model.dart';
import 'package:moniq/data/models/shift_type_model.dart';
import 'package:moniq/data/models/shift_with_type.dart';

/// 기본 근무 유형(데이) fixture. 필요한 필드만 override 한다.
ShiftTypeModel buildShiftType({
  String id = 'st-day',
  String teamId = 'team-1',
  String name = '데이',
  String code = 'D',
  String? startTime = '09:00:00',
  String? endTime = '17:00:00',
  String color = '#5A8BB5',
}) {
  return ShiftTypeModel(
    id: id,
    teamId: teamId,
    name: name,
    code: code,
    startTime: startTime,
    endTime: endTime,
    color: color,
  );
}

/// 데이(8h) / 이브닝(8h) / 나이트(8h, 자정 넘김) / OFF 근무 유형 프리셋.
ShiftTypeModel get dayShiftType => buildShiftType(
      id: 'st-day',
      name: '데이',
      code: 'D',
      startTime: '09:00:00',
      endTime: '17:00:00',
    );

ShiftTypeModel get eveningShiftType => buildShiftType(
      id: 'st-eve',
      name: '이브닝',
      code: 'E',
      startTime: '14:00:00',
      endTime: '22:00:00',
    );

ShiftTypeModel get nightShiftType => buildShiftType(
      id: 'st-night',
      name: '나이트',
      code: 'N',
      startTime: '23:00:00',
      endTime: '07:00:00',
    );

ShiftTypeModel get offShiftType => buildShiftType(
      id: 'st-off',
      name: '오프',
      code: 'OFF',
      startTime: null,
      endTime: null,
    );

/// 기본 근무(shift) fixture.
ShiftModel buildShift({
  String id = 'shift-1',
  String scheduleId = 'sched-1',
  String teamId = 'team-1',
  String userId = 'user-1',
  DateTime? shiftDate,
  String shiftTypeId = 'st-day',
}) {
  return ShiftModel(
    id: id,
    scheduleId: scheduleId,
    teamId: teamId,
    userId: userId,
    shiftDate: shiftDate ?? DateTime(2026, 6, 1),
    shiftTypeId: shiftTypeId,
  );
}

/// shift + shiftType 조합 fixture.
ShiftWithType buildShiftWithType({
  ShiftModel? shift,
  ShiftTypeModel? shiftType,
  String? teamName,
}) {
  final type = shiftType ?? dayShiftType;
  return ShiftWithType(
    shift: shift ?? buildShift(shiftTypeId: type.id),
    shiftType: type,
    teamName: teamName,
  );
}
