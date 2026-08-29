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

  group('반복 그룹 일괄 수정 (updateRecurringEventsFrom)', () {
    final createdAt = DateTime(2026, 8, 1, 10, 30);

    /// 매주 반복 일정 하나를 전개 저장한다 (8/3 월요일 시작).
    Future<void> addWeekly() => ds.addEvent(PersonalEvent(
          date: DateTime(2026, 8, 3),
          title: '요가',
          startTime: '18:00',
          endTime: '19:00',
          color: '#38A169',
          createdAt: createdAt,
          recurrence: 'weekly',
        ));

    test('fromDate 당일 포함 이후 회차만 변경, 날짜·그룹 키는 유지', () async {
      await addWeekly();

      // 3번째 회차(8/17)부터 제목·시간·색·설명 변경.
      final template = PersonalEvent(
        date: DateTime(2026, 8, 17),
        title: '필라테스',
        startTime: '19:00',
        endTime: '20:30',
        color: '#E53E3E',
        description: '장소 변경',
        createdAt: DateTime.now(), // 폼이 새로 찍는 값 — 저장엔 안 쓰임
        recurrence: 'weekly',
      );
      final updated = await ds.updateRecurringEventsFrom(
        fromDate: DateTime(2026, 8, 17),
        title: '요가',
        recurrence: 'weekly',
        createdAt: createdAt,
        template: template,
      );
      expect(updated, greaterThan(0));

      // 이전 회차(8/3, 8/10)는 그대로.
      for (final day in [DateTime(2026, 8, 3), DateTime(2026, 8, 10)]) {
        final e = ds.getEvents(day).single;
        expect(e.title, '요가', reason: '$day');
        expect(e.startTime, '18:00');
        expect(e.color, '#38A169');
      }

      // 당일(8/17)과 이후 회차(8/24)는 내용이 바뀌되 날짜는 유지.
      for (final day in [DateTime(2026, 8, 17), DateTime(2026, 8, 24)]) {
        final e = ds.getEvents(day).single;
        expect(e.title, '필라테스', reason: '$day');
        expect(e.startTime, '19:00');
        expect(e.endTime, '20:30');
        expect(e.color, '#E53E3E');
        expect(e.description, '장소 변경');
        expect(e.date, day);
        // 그룹 판별 키(createdAt·recurrence)는 원본 값 보존 —
        // 이후의 "모두 수정/삭제"가 계속 같은 그룹을 찾을 수 있어야 한다.
        expect(e.createdAt!.isAtSameMomentAs(createdAt), isTrue);
        expect(e.recurrence, 'weekly');
      }
    });

    test('같은 제목이어도 createdAt이 다르면 다른 그룹 — 건드리지 않는다',
        () async {
      await addWeekly();
      // 같은 제목·같은 recurrence지만 다른 시점에 만든 별개 그룹 (8/18 화).
      await ds.addEvent(PersonalEvent(
        date: DateTime(2026, 8, 18),
        title: '요가',
        startTime: '07:00',
        color: '#5A8BB5',
        createdAt: DateTime(2026, 8, 2, 9),
        recurrence: 'weekly',
      ));
      // 반복 아닌 동명 단건 (8/20 목).
      await ds.addEvent(PersonalEvent(
        date: DateTime(2026, 8, 20),
        title: '요가',
        createdAt: DateTime(2026, 8, 2, 9),
        recurrence: 'none',
      ));

      await ds.updateRecurringEventsFrom(
        fromDate: DateTime(2026, 8, 17),
        title: '요가',
        recurrence: 'weekly',
        createdAt: createdAt,
        template: PersonalEvent(
          date: DateTime(2026, 8, 17),
          title: '필라테스',
          createdAt: DateTime.now(),
          recurrence: 'weekly',
        ),
      );

      // 별개 그룹(화요일 요가)과 단건은 그대로.
      final tue = ds.getEvents(DateTime(2026, 8, 18)).single;
      expect(tue.title, '요가');
      expect(tue.startTime, '07:00');
      final thu = ds.getEvents(DateTime(2026, 8, 20)).single;
      expect(thu.title, '요가');
      // 대상 그룹(월요일)은 바뀜.
      expect(ds.getEvents(DateTime(2026, 8, 17)).single.title, '필라테스');
    });

    test('다일 span 템플릿이면 각 회차의 기간 길이만 적용, 시작일은 유지',
        () async {
      await addWeekly();

      await ds.updateRecurringEventsFrom(
        fromDate: DateTime(2026, 8, 10),
        title: '요가',
        recurrence: 'weekly',
        createdAt: createdAt,
        template: PersonalEvent(
          date: DateTime(2026, 8, 10),
          endDate: DateTime(2026, 8, 12), // 2박 3일 span
          title: '워크숍',
          createdAt: DateTime.now(),
          recurrence: 'weekly',
        ),
      );

      final e = ds.getEvents(DateTime(2026, 8, 17)).single;
      expect(e.title, '워크숍');
      expect(e.date, DateTime(2026, 8, 17));
      expect(e.endDate, DateTime(2026, 8, 19)); // 회차 날짜 + 2일
      // 이전 회차는 span 없음 그대로.
      expect(ds.getEvents(DateTime(2026, 8, 3)).single.endDate, isNull);
    });

    test('getRecurringEventsFrom — fromDate 이후 그룹 회차만 날짜순 조회',
        () async {
      await addWeekly();
      final matches = ds.getRecurringEventsFrom(
        fromDate: DateTime(2026, 8, 17),
        title: '요가',
        recurrence: 'weekly',
        createdAt: createdAt,
      );
      expect(matches, isNotEmpty);
      expect(matches.first.originDate, DateTime(2026, 8, 17));
      expect(
        matches.every((m) => !m.originDate.isBefore(DateTime(2026, 8, 17))),
        isTrue,
      );
      expect(matches.every((m) => m.event.title == '요가'), isTrue);
    });
  });
}
