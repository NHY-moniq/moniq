import 'package:flutter_test/flutter_test.dart';
import 'package:moniq/data/datasources/personal_event_local_data_source.dart';

void main() {
  group('PersonalEvent endDate', () {
    test('endDate가 없으면 당일 일정으로 취급한다', () {
      final e = PersonalEvent(
        date: DateTime(2026, 7, 27),
        title: '회의',
        startTime: '09:00',
        endTime: '10:00',
      );
      expect(e.spansMultipleDays, isFalse);
      expect(e.timeRange, '09:00 ~ 10:00');
    });

    test('endDate가 시작일과 같으면 당일 일정으로 취급한다', () {
      final e = PersonalEvent(
        date: DateTime(2026, 7, 27),
        endDate: DateTime(2026, 7, 27),
        title: '회의',
      );
      expect(e.spansMultipleDays, isFalse);
      expect(e.timeRange, '종일');
    });

    test('여러 날에 걸친 일정은 timeRange에 날짜가 포함된다', () {
      final allDay = PersonalEvent(
        date: DateTime(2026, 7, 27),
        endDate: DateTime(2026, 7, 29),
        title: '휴가',
      );
      expect(allDay.spansMultipleDays, isTrue);
      expect(allDay.timeRange, '7/27 ~ 7/29');

      final timed = PersonalEvent(
        date: DateTime(2026, 7, 27),
        endDate: DateTime(2026, 7, 28),
        title: '야간 근무',
        startTime: '22:00',
        endTime: '06:00',
      );
      expect(timed.timeRange, '7/27 22:00 ~ 7/28 06:00');
    });

    test('toJson/fromJson 왕복 시 endDate가 보존된다', () {
      final e = PersonalEvent(
        date: DateTime(2026, 7, 27),
        endDate: DateTime(2026, 8, 2),
        title: '워크숍',
        startTime: '09:00',
        endTime: '18:00',
        color: '#38A169',
        recurrence: 'none',
      );
      final restored = PersonalEvent.fromJson(e.toJson());
      expect(restored.date, DateTime(2026, 7, 27));
      expect(restored.endDate, DateTime(2026, 8, 2));
      expect(restored.title, '워크숍');
      expect(restored.startTime, '09:00');
      expect(restored.endTime, '18:00');
    });

    test('endDate가 없는 기존 JSON도 그대로 읽힌다 (하위 호환)', () {
      final restored = PersonalEvent.fromJson({
        'id': 'evt-1',
        'date': '2026-07-27',
        'title': '기존 일정',
        'startTime': null,
        'endTime': null,
        'description': null,
        'color': '#E53E3E',
        'createdAt': '2026-07-20T10:00:00.000',
        'recurrence': 'none',
      });
      expect(restored.endDate, isNull);
      expect(restored.spansMultipleDays, isFalse);
    });

    test('copyWith(id)는 endDate를 유지한다', () {
      final e = PersonalEvent(
        date: DateTime(2026, 7, 27),
        endDate: DateTime(2026, 7, 30),
        title: '출장',
      );
      final withId = e.copyWith(id: 'evt-2');
      expect(withId.id, 'evt-2');
      expect(withId.endDate, DateTime(2026, 7, 30));
    });
  });
}
