import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/datasources/personal_event_local_data_source.dart';
import 'package:moniq/data/datasources/personal_event_remote_data_source.dart';
import 'package:moniq/data/datasources/personal_hidden_shifts_local_data_source.dart';
import 'package:moniq/data/providers/settings_providers.dart';
import 'package:moniq/presentation/screens/calendar/calendar_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

/// 팀 캘린더 → "개인 일정으로 내보내기"가 만드는 이벤트와 동일한 형태.
PersonalEvent _teamImport(DateTime date, String title) => PersonalEvent(
      date: date,
      title: title,
      startTime: '07:00',
      endTime: '15:00',
      description: '$kPersonalTeamImportMarker:team-1',
      color: '#5A8BB5',
    );

void main() {
  const day = 15;
  final date = DateTime(2026, 7, day);
  final month = DateTime(2026, 7, 1);

  /// [hideTeamShifts] 설정과 데이터가 주어진 컨테이너.
  Future<ProviderContainer> buildContainer({
    required bool hideTeamShifts,
    required List<PersonalEvent> events,
  }) async {
    SharedPreferences.setMockInitialValues({
      'settings_hide_team_shifts_in_personal': hideTeamShifts,
    });
    final prefs = await SharedPreferences.getInstance();
    final ds = PersonalEventLocalDataSource(
      prefs: prefs,
      userId: 'user-1',
      remote: _OfflineRemote(),
    );
    for (final e in events) {
      await ds.addEvent(e);
    }
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      personalEventDataSourceProvider.overrideWithValue(ds),
      personalHiddenShiftsDataSourceProvider.overrideWithValue(
        PersonalHiddenShiftsLocalDataSource(prefs: prefs, userId: 'user-1'),
      ),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  group('팀 근무 숨기기 — 개인 일정으로 내보낸 팀 근무도 숨긴다', () {
    test('토글 OFF면 team-import 근무가 보인다', () async {
      final c = await buildContainer(
        hideTeamShifts: false,
        events: [_teamImport(date, 'Day')],
      );
      expect(c.read(monthlyEventsProvider(month))[date]?.length, 1);
      expect(c.read(dateEventOccurrencesProvider(date)).length, 1);
    });

    test('토글 ON이면 team-import 근무가 셀/패널에서 모두 사라진다', () async {
      final c = await buildContainer(
        hideTeamShifts: true,
        events: [_teamImport(date, 'Day')],
      );
      expect(c.read(monthlyEventsProvider(month))[date], isNull);
      expect(c.read(dateEventOccurrencesProvider(date)), isEmpty);
    });

    test('토글 ON이어도 직접 추가한 개인 일정은 그대로 보인다', () async {
      final c = await buildContainer(
        hideTeamShifts: true,
        events: [
          _teamImport(date, 'Day'),
          PersonalEvent(date: date, title: '병원 예약', startTime: '18:00'),
        ],
      );
      final cellEvents = c.read(monthlyEventsProvider(month))[date];
      expect(cellEvents?.length, 1);
      expect(cellEvents?.single.title, '병원 예약');

      final occurrences = c.read(dateEventOccurrencesProvider(date));
      expect(occurrences.length, 1);
      expect(occurrences.single.event.title, '병원 예약');
      // 저장 인덱스는 필터와 무관하게 원본 위치를 유지해야 한다
      // (team-import가 0번, 개인 일정이 1번으로 저장됨)
      expect(occurrences.single.originIndex, 1);
    });

    test('저장 기준 조회(dateEventsProvider)는 토글에 영향받지 않는다', () async {
      final c = await buildContainer(
        hideTeamShifts: true,
        events: [_teamImport(date, 'Day')],
      );
      // 수정/삭제 인덱스의 기준이므로 항상 저장된 그대로여야 한다.
      expect(c.read(dateEventsProvider(date)).length, 1);
    });
  });
}
