import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:moniq/data/datasources/home_cache_local_data_source.dart';
import 'package:moniq/data/models/shift_model.dart';
import 'package:moniq/data/models/shift_with_type.dart';
import 'package:moniq/data/models/team_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fixtures.dart';

TeamModel buildTeam({
  String id = 'team-1',
  String name = '3병동',
  String teamType = 'organizational',
}) {
  return TeamModel(
    id: id,
    name: name,
    teamType: teamType,
    createdBy: 'user-1',
    createdAt: DateTime(2026, 1, 2, 3, 4, 5),
  );
}

ShiftWithType buildShiftWithType({
  String id = 'shift-1',
  String teamId = 'team-1',
  String userId = 'user-1',
  required DateTime date,
}) {
  final type = buildShiftType(teamId: teamId);
  return ShiftWithType(
    shift: ShiftModel(
      id: id,
      scheduleId: 'sched-1',
      teamId: teamId,
      userId: userId,
      shiftDate: date,
      shiftTypeId: type.id,
      note: '인수인계',
    ),
    shiftType: type,
  );
}

void main() {
  late SharedPreferences prefs;

  Future<HomeCacheLocalDataSource> cacheFor(String userId) async {
    return HomeCacheLocalDataSource(prefs: prefs, userId: userId);
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('HomeCacheLocalDataSource 라운드트립', () {
    test('즐겨찾기 팀을 저장하고 그대로 복원한다', () async {
      final cache = await cacheFor('user-1');
      final team = buildTeam(name: '중환자실', teamType: 'personal');

      await cache.setFavoriteTeam(team);

      final restored = cache.getFavoriteTeam();
      expect(restored, isNotNull);
      expect(restored!.value, team);
      expect(cache.getFavoriteTeamId(), 'team-1');
    });

    test('"즐겨찾기 없음"은 캐시 미스와 구분된다', () async {
      final cache = await cacheFor('user-1');

      // 저장 전: 미스
      expect(cache.getFavoriteTeam(), isNull);

      await cache.setFavoriteTeam(null);

      // 저장 후: hit 이지만 값이 null (= 확정된 "즐겨찾기 없음")
      final restored = cache.getFavoriteTeam();
      expect(restored, isNotNull);
      expect(restored!.value, isNull);
      expect(cache.getFavoriteTeamId(), isNull);
    });

    test('월별 근무와 coverage를 날짜 키까지 그대로 복원한다', () async {
      final cache = await cacheFor('user-1');
      final month = DateTime(2026, 8);
      final d1 = DateTime(2026, 8, 3);
      final d2 = DateTime(2026, 8, 4);

      await cache.setMonth(
        teamId: 'team-1',
        month: month,
        mine: {
          d1: [buildShiftWithType(id: 'shift-1', date: d1)],
          d2: [
            buildShiftWithType(id: 'shift-2', date: d2),
            buildShiftWithType(id: 'shift-3', date: d2),
          ],
        },
        coverage: {d1, d2, DateTime(2026, 8, 5)},
      );

      final restored = cache.getMonth(teamId: 'team-1', month: month);
      expect(restored, isNotNull);
      expect(restored!.value.teamId, 'team-1');
      expect(restored.value.mine.keys.toSet(), {d1, d2});
      expect(restored.value.mine[d2], hasLength(2));
      expect(restored.value.mine[d1]!.single.shift.id, 'shift-1');
      expect(restored.value.mine[d1]!.single.shift.shiftDate, d1);
      expect(restored.value.mine[d1]!.single.shift.note, '인수인계');
      expect(restored.value.mine[d1]!.single.shiftType, buildShiftType());
      expect(restored.value.coverage, {d1, d2, DateTime(2026, 8, 5)});
      expect(restored.savedAt.isAfter(DateTime(2020)), isTrue);
    });

    test('내 팀 목록을 순서까지 그대로 복원한다', () async {
      final cache = await cacheFor('user-1');
      final teams = [
        buildTeam(id: 'team-a', name: 'A'),
        buildTeam(id: 'team-b', name: 'B', teamType: 'personal'),
      ];

      await cache.setMyTeams(teams);

      expect(cache.getMyTeams()!.value, teams);
    });

    test('빈 월(근무 없음)도 미스가 아니라 hit 으로 복원된다', () async {
      final cache = await cacheFor('user-1');
      final month = DateTime(2026, 8);

      await cache.setMonth(
        teamId: 'team-1',
        month: month,
        mine: const {},
        coverage: const {},
      );

      final restored = cache.getMonth(teamId: 'team-1', month: month);
      expect(restored, isNotNull);
      expect(restored!.value.mine, isEmpty);
      expect(restored.value.coverage, isEmpty);
    });
  });

  group('스키마 버전 / 형식 불일치', () {
    test('저장된 스키마 버전이 다르면 폐기하고 미스를 반환한다', () async {
      final cache = await cacheFor('user-1');
      await cache.setFavoriteTeam(buildTeam());

      // 저장된 envelope 의 버전만 미래 버전으로 바꿔치기
      final key = prefs
          .getKeys()
          .firstWhere((k) => k.contains('favorite_team'));
      final envelope =
          jsonDecode(prefs.getString(key)!) as Map<String, dynamic>;
      envelope['v'] = HomeCacheLocalDataSource.schemaVersion + 1;
      await prefs.setString(key, jsonEncode(envelope));

      expect(cache.getFavoriteTeam(), isNull);
      // 폐기까지 되어 키가 남지 않는다
      expect(prefs.getString(key), isNull);
    });

    test('envelope 의 userId 가 다르면 폐기하고 미스를 반환한다', () async {
      final cache = await cacheFor('user-1');
      await cache.setFavoriteTeam(buildTeam());

      final key = prefs
          .getKeys()
          .firstWhere((k) => k.contains('favorite_team'));
      final envelope =
          jsonDecode(prefs.getString(key)!) as Map<String, dynamic>;
      envelope['uid'] = 'someone-else';
      await prefs.setString(key, jsonEncode(envelope));

      expect(cache.getFavoriteTeam(), isNull);
      expect(prefs.getString(key), isNull);
    });

    test('깨진 JSON 은 예외를 던지지 않고 폐기한다', () async {
      final cache = await cacheFor('user-1');
      await cache.setFavoriteTeam(buildTeam());

      final key = prefs
          .getKeys()
          .firstWhere((k) => k.contains('favorite_team'));
      await prefs.setString(key, '{not json');

      expect(cache.getFavoriteTeam(), isNull);
      expect(prefs.getString(key), isNull);
    });

    test('월 캐시의 team_id 가 다르면 미스로 취급한다', () async {
      final cache = await cacheFor('user-1');
      final month = DateTime(2026, 8);
      await cache.setMonth(
        teamId: 'team-1',
        month: month,
        mine: const {},
        coverage: const {},
      );

      final key = prefs.getKeys().firstWhere((k) => k.contains(':month:'));
      final envelope =
          jsonDecode(prefs.getString(key)!) as Map<String, dynamic>;
      (envelope['data'] as Map)['team_id'] = 'team-999';
      await prefs.setString(key, jsonEncode(envelope));

      expect(cache.getMonth(teamId: 'team-1', month: month), isNull);
    });

    test('purgeStaleVersions 는 현재 버전 항목만 남긴다', () async {
      final cache = await cacheFor('user-1');
      await cache.setFavoriteTeam(buildTeam());
      const legacyKey =
          '${HomeCacheLocalDataSource.keyPrefix}:v0:user-1:favorite_team';
      await prefs.setString(legacyKey, '{}');

      await HomeCacheLocalDataSource.purgeStaleVersions(prefs);

      expect(prefs.getString(legacyKey), isNull);
      expect(cache.getFavoriteTeam(), isNotNull);
    });
  });

  group('사용자 분리 / 무효화', () {
    test('다른 사용자의 캐시는 서로 보이지 않는다', () async {
      final a = await cacheFor('user-a');
      final b = await cacheFor('user-b');
      final month = DateTime(2026, 8);
      final day = DateTime(2026, 8, 3);

      await a.setFavoriteTeam(buildTeam(id: 'team-a', name: 'A팀'));
      await a.setMonth(
        teamId: 'team-a',
        month: month,
        mine: {
          day: [buildShiftWithType(teamId: 'team-a', date: day)],
        },
        coverage: {day},
      );

      expect(b.getFavoriteTeam(), isNull);
      expect(b.getMonth(teamId: 'team-a', month: month), isNull);
      expect(a.getFavoriteTeam()!.value!.name, 'A팀');
    });

    test('clear() 는 해당 사용자 캐시만 지운다', () async {
      final a = await cacheFor('user-a');
      final b = await cacheFor('user-b');
      await a.setFavoriteTeam(buildTeam(id: 'team-a'));
      await b.setFavoriteTeam(buildTeam(id: 'team-b'));

      await a.clear();

      expect(a.getFavoriteTeam(), isNull);
      expect(b.getFavoriteTeam(), isNotNull);
    });

    test('clearAll() 은 모든 사용자 캐시를 지우고 다른 설정은 남긴다', () async {
      final a = await cacheFor('user-a');
      final b = await cacheFor('user-b');
      await a.setFavoriteTeam(buildTeam(id: 'team-a'));
      await b.setFavoriteTeam(buildTeam(id: 'team-b'));
      await prefs.setString('theme_mode', 'dark');

      await HomeCacheLocalDataSource.clearAll(prefs);

      expect(a.getFavoriteTeam(), isNull);
      expect(b.getFavoriteTeam(), isNull);
      expect(prefs.getString('theme_mode'), 'dark');
    });

    test('오래된 월 캐시는 저장 시점에 정리된다', () async {
      final cache = await cacheFor('user-1');
      final now = DateTime(2026, 8);

      // 1년 전 달을 먼저 저장
      await cache.setMonth(
        teamId: 'team-1',
        month: DateTime(2025, 8),
        mine: const {},
        coverage: const {},
      );
      expect(
        cache.getMonth(teamId: 'team-1', month: DateTime(2025, 8)),
        isNotNull,
      );

      // 현재 달을 저장하면 보관 범위를 벗어난 달은 사라진다
      await cache.setMonth(
        teamId: 'team-1',
        month: now,
        mine: const {},
        coverage: const {},
      );

      expect(
        cache.getMonth(teamId: 'team-1', month: DateTime(2025, 8)),
        isNull,
      );
      expect(cache.getMonth(teamId: 'team-1', month: now), isNotNull);
    });
  });
}
