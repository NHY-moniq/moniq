import 'package:flutter_test/flutter_test.dart';
import 'package:moniq/core/utils/recurrence_rule.dart';

void main() {
  group('RecurrenceRule.parse / encode', () {
    test('레거시 토큰은 규칙으로 정규화된다', () {
      final biweekly = RecurrenceRule.parse('biweekly');
      expect(biweekly, isNotNull);
      expect(biweekly!.freq, RecurrenceFreq.weekly);
      expect(biweekly.interval, 2);
      expect(RecurrenceRule.parse('none'), isNull);
      expect(RecurrenceRule.parse(null), isNull);
    });

    test('커스텀 문자열 round-trip', () {
      const raw = 'custom:freq=weekly;interval=2;days=1,3;end=count:10';
      final rule = RecurrenceRule.parse(raw);
      expect(rule, isNotNull);
      expect(rule!.freq, RecurrenceFreq.weekly);
      expect(rule.interval, 2);
      expect(rule.weekdays, {1, 3});
      expect(rule.count, 10);
      expect(rule.encode(), raw);
    });

    test('until 종료 round-trip', () {
      const raw = 'custom:freq=monthly;byLastWeekday=6;end=until:2027-03-01';
      final rule = RecurrenceRule.parse(raw);
      expect(rule, isNotNull);
      expect(rule!.byLastWeekday, 6);
      expect(rule.until, DateTime(2027, 3, 1));
      expect(rule.encode(), raw);
    });

    test('단순 조합은 레거시 토큰으로 정규화된다', () {
      expect(
        const RecurrenceRule(freq: RecurrenceFreq.weekly, interval: 2)
            .encode(),
        'biweekly',
      );
      expect(
        const RecurrenceRule(freq: RecurrenceFreq.daily).encode(),
        'daily',
      );
    });
  });

  group('expandRecurrenceDates — 레거시 (기존 동작 보존)', () {
    test('biweekly는 14일 간격으로 1년까지', () {
      final dates = expandRecurrenceDates(DateTime(2026, 8, 27), 'biweekly');
      expect(dates.first, DateTime(2026, 8, 27));
      expect(dates[1], DateTime(2026, 9, 10));
      expect(dates.length, 27); // 365 / 14 = 26 + 시작일
      expect(dates.last, DateTime(2027, 8, 26));
    });

    test('none/null은 시작일 하나', () {
      expect(expandRecurrenceDates(DateTime(2026, 1, 5), 'none'), [
        DateTime(2026, 1, 5),
      ]);
      expect(expandRecurrenceDates(DateTime(2026, 1, 5), null), [
        DateTime(2026, 1, 5),
      ]);
    });
  });

  group('expandRecurrenceDates — 커스텀', () {
    test('2주마다 월·수, 5회 후 종료', () {
      // 2026-01-05 = 월요일.
      final dates = expandRecurrenceDates(
        DateTime(2026, 1, 5),
        'custom:freq=weekly;interval=2;days=1,3;end=count:5',
      );
      expect(dates, [
        DateTime(2026, 1, 5), // 월 (0주차)
        DateTime(2026, 1, 7), // 수 (0주차)
        DateTime(2026, 1, 19), // 월 (2주차)
        DateTime(2026, 1, 21), // 수 (2주차)
        DateTime(2026, 2, 2), // 월 (4주차)
      ]);
    });

    test('매달 마지막 토요일, 특정 날짜까지', () {
      // 2026-01-31 = 토요일이자 1월의 마지막 토요일.
      final dates = expandRecurrenceDates(
        DateTime(2026, 1, 31),
        'custom:freq=monthly;byLastWeekday=6;end=until:2026-04-30',
      );
      expect(dates, [
        DateTime(2026, 1, 31),
        DateTime(2026, 2, 28),
        DateTime(2026, 3, 28),
        DateTime(2026, 4, 25),
      ]);
    });

    test('3일마다, 종료 없음 → 기본 1년 범위', () {
      final dates = expandRecurrenceDates(
        DateTime(2026, 8, 1),
        'custom:freq=daily;interval=3',
      );
      expect(dates.take(3), [
        DateTime(2026, 8, 1),
        DateTime(2026, 8, 4),
        DateTime(2026, 8, 7),
      ]);
      // 365일 안의 3일 간격 발생 = 122회 (k*3 <= 365, k=0..121).
      expect(dates.length, 122);
      expect(
        dates.last.isAfter(DateTime(2026, 8, 1).add(const Duration(days: 365))),
        isFalse,
      );
    });

    test('매달 31일 — 없는 달은 건너뛴다', () {
      final dates = expandRecurrenceDates(
        DateTime(2026, 1, 31),
        'custom:freq=monthly;byMonthDay=31;end=count:3',
      );
      expect(dates, [
        DateTime(2026, 1, 31),
        DateTime(2026, 3, 31),
        DateTime(2026, 5, 31),
      ]);
    });

    test('시작일 요일이 집합에 없어도 시작일은 항상 포함된다', () {
      // 2026-01-06 = 화요일, 반복은 월요일만.
      final dates = expandRecurrenceDates(
        DateTime(2026, 1, 6),
        'custom:freq=weekly;days=1;end=count:3',
      );
      expect(dates.first, DateTime(2026, 1, 6));
      expect(dates[1], DateTime(2026, 1, 12)); // 다음 월요일
      expect(dates[2], DateTime(2026, 1, 19));
      expect(dates.length, 3);
    });
  });

  group('recurrenceSummaryLabel', () {
    test('레거시 라벨', () {
      expect(recurrenceSummaryLabel('none'), '반복 안 함');
      expect(recurrenceSummaryLabel('weekly'), '매주');
      expect(recurrenceSummaryLabel('biweekly'), '2주마다');
    });

    test('커스텀 라벨 — 주기·요일·종료 요약', () {
      expect(
        recurrenceSummaryLabel(
          'custom:freq=weekly;interval=2;days=1,3;end=count:10',
        ),
        '2주마다 · 월·수 · 10회 후 종료',
      );
      expect(
        recurrenceSummaryLabel(
          'custom:freq=monthly;byLastWeekday=6;end=until:2027-03-01',
        ),
        '매달 · 마지막 토요일 · 2027.3.1까지',
      );
      expect(recurrenceSummaryLabel('custom:freq=daily;interval=3'), '3일마다');
    });
  });
}
