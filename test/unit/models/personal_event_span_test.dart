import 'package:flutter_test/flutter_test.dart';
import 'package:moniq/data/datasources/personal_event_local_data_source.dart';
import 'package:moniq/data/datasources/personal_event_remote_data_source.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 원격 호출은 모두 실패/무시 — 로컬 캐시 동작만 검증한다.
class _OfflineRemote extends PersonalEventRemoteDataSource {
  _OfflineRemote()
      : super(client: SupabaseClient('http://localhost:1', 'test-key'));

  @override
  Future<PersonalEvent> insert(PersonalEvent event) async =>
      throw Exception('offline');

  @override
  Future<void> update(PersonalEvent event) async {}

  @override
  Future<void> delete(String id) async {}
}

void main() {
  late PersonalEventLocalDataSource ds;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ds = PersonalEventLocalDataSource(
      prefs: await SharedPreferences.getInstance(),
      userId: 'user-1',
      remote: _OfflineRemote(),
    );
  });

  group('다일 일정 표시 (getOccurrences)', () {
    test('3일 일정은 3일 모두에서 조회된다', () async {
      await ds.addEvent(PersonalEvent(
        date: DateTime(2026, 7, 27),
        endDate: DateTime(2026, 7, 29),
        title: '휴가',
      ));

      for (final day in [
        DateTime(2026, 7, 27),
        DateTime(2026, 7, 28),
        DateTime(2026, 7, 29),
      ]) {
        final occurrences = ds.getOccurrences(day);
        expect(occurrences.length, 1, reason: '$day');
        expect(occurrences.first.event.title, '휴가');
        // 저장 위치는 언제나 시작일 + 인덱스 0
        expect(occurrences.first.originDate, DateTime(2026, 7, 27));
        expect(occurrences.first.originIndex, 0);
      }

      // 시작일만 isContinuation == false
      expect(ds.getOccurrences(DateTime(2026, 7, 27)).first.isContinuation,
          isFalse);
      expect(ds.getOccurrences(DateTime(2026, 7, 28)).first.isContinuation,
          isTrue);
      expect(ds.getOccurrences(DateTime(2026, 7, 29)).first.isContinuation,
          isTrue);

      // 기간 밖
      expect(ds.getOccurrences(DateTime(2026, 7, 26)), isEmpty);
      expect(ds.getOccurrences(DateTime(2026, 7, 30)), isEmpty);
    });

    test('getEvents(저장 기준)는 시작일에만 항목을 돌려준다', () async {
      await ds.addEvent(PersonalEvent(
        date: DateTime(2026, 7, 27),
        endDate: DateTime(2026, 7, 29),
        title: '휴가',
      ));
      expect(ds.getEvents(DateTime(2026, 7, 27)).length, 1);
      expect(ds.getEvents(DateTime(2026, 7, 28)), isEmpty);
    });

    test('당일 일정은 그 날에만 나온다', () async {
      await ds.addEvent(PersonalEvent(
        date: DateTime(2026, 7, 27),
        title: '회의',
        startTime: '09:00',
        endTime: '10:00',
      ));
      expect(ds.getOccurrences(DateTime(2026, 7, 27)).length, 1);
      expect(ds.getOccurrences(DateTime(2026, 7, 28)), isEmpty);
    });

    test('occurrence 앞부분은 getEvents와 인덱스가 일치한다', () async {
      // 26일 시작 3일 일정 + 27일 당일 일정 2건
      await ds.addEvent(PersonalEvent(
        date: DateTime(2026, 7, 26),
        endDate: DateTime(2026, 7, 28),
        title: '출장',
      ));
      await ds.addEvent(
          PersonalEvent(date: DateTime(2026, 7, 27), title: 'A'));
      await ds.addEvent(
          PersonalEvent(date: DateTime(2026, 7, 27), title: 'B'));

      final occurrences = ds.getOccurrences(DateTime(2026, 7, 27));
      expect(occurrences.length, 3);
      // 저장분이 먼저, 그 뒤에 이어지는 일정
      expect(occurrences[0].event.title, 'A');
      expect(occurrences[0].originIndex, 0);
      expect(occurrences[1].event.title, 'B');
      expect(occurrences[1].originIndex, 1);
      expect(occurrences[2].event.title, '출장');
      expect(occurrences[2].originDate, DateTime(2026, 7, 26));
      expect(occurrences[2].originIndex, 0);
    });

    test('시작일 기준으로 삭제하면 걸쳐 있던 모든 날에서 사라진다', () async {
      await ds.addEvent(PersonalEvent(
        date: DateTime(2026, 7, 27),
        endDate: DateTime(2026, 7, 29),
        title: '휴가',
      ));
      final occurrence = ds.getOccurrences(DateTime(2026, 7, 29)).single;
      await ds.removeEvent(occurrence.originDate, occurrence.originIndex);

      expect(ds.getOccurrences(DateTime(2026, 7, 27)), isEmpty);
      expect(ds.getOccurrences(DateTime(2026, 7, 28)), isEmpty);
      expect(ds.getOccurrences(DateTime(2026, 7, 29)), isEmpty);
    });
  });

  group('월간 조회 (getMonthlyEventsIncludingSpans)', () {
    test('걸쳐 있는 모든 날짜에 채워진다', () async {
      await ds.addEvent(PersonalEvent(
        date: DateTime(2026, 7, 27),
        endDate: DateTime(2026, 7, 29),
        title: '휴가',
      ));
      final map = ds.getMonthlyEventsIncludingSpans(DateTime(2026, 7, 1));
      expect(map[DateTime(2026, 7, 27)]?.length, 1);
      expect(map[DateTime(2026, 7, 28)]?.length, 1);
      expect(map[DateTime(2026, 7, 29)]?.length, 1);
      expect(map[DateTime(2026, 7, 30)], isNull);
    });

    test('전월에서 넘어온 일정도 이번 달에 표시된다', () async {
      await ds.addEvent(PersonalEvent(
        date: DateTime(2026, 7, 30),
        endDate: DateTime(2026, 8, 2),
        title: '워크숍',
      ));
      final august = ds.getMonthlyEventsIncludingSpans(DateTime(2026, 8, 1));
      expect(august[DateTime(2026, 8, 1)]?.single.title, '워크숍');
      expect(august[DateTime(2026, 8, 2)]?.single.title, '워크숍');
      expect(august[DateTime(2026, 8, 3)], isNull);

      final july = ds.getMonthlyEventsIncludingSpans(DateTime(2026, 7, 1));
      expect(july[DateTime(2026, 7, 30)]?.single.title, '워크숍');
      expect(july[DateTime(2026, 7, 31)]?.single.title, '워크숍');
    });

    test('기존 getMonthlyEvents는 시작일 기준을 유지한다', () async {
      await ds.addEvent(PersonalEvent(
        date: DateTime(2026, 7, 27),
        endDate: DateTime(2026, 7, 29),
        title: '휴가',
      ));
      final map = ds.getMonthlyEvents(DateTime(2026, 7, 1));
      expect(map[DateTime(2026, 7, 27)]?.length, 1);
      expect(map[DateTime(2026, 7, 28)], isNull);
    });
  });

  group('반복 + 기간', () {
    test('매주 반복 일정도 각 회차가 같은 기간을 유지한다', () async {
      await ds.addEvent(PersonalEvent(
        date: DateTime(2026, 7, 27),
        endDate: DateTime(2026, 7, 28),
        title: '당직',
        recurrence: 'weekly',
      ));
      // 1회차
      expect(ds.getOccurrences(DateTime(2026, 7, 28)).single.isContinuation,
          isTrue);
      // 2회차 (8/3 ~ 8/4)
      final second = ds.getOccurrences(DateTime(2026, 8, 4));
      expect(second.single.event.title, '당직');
      expect(second.single.originDate, DateTime(2026, 8, 3));
      expect(second.single.isContinuation, isTrue);
    });
  });
}
