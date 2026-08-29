/// 콜드 스타트 경로 계측 — 로컬 캐시(stale-while-revalidate)와 순차 왕복 제거가
/// 실제로 "첫 콘텐츠까지의 시간"을 줄이는지 재현 가능하게 측정한다.
///
/// 네트워크 왕복은 [_rtt] 만큼 지연되는 가짜 Repository로 흉내 낸다.
/// 실제 기기 수치는 아니지만 **왕복 횟수와 병렬성**은 그대로 드러난다.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/datasources/home_cache_local_data_source.dart';
import 'package:moniq/data/datasources/shift_remote_data_source.dart';
import 'package:moniq/data/datasources/team_remote_data_source.dart';
import 'package:moniq/data/models/shift_model.dart';
import 'package:moniq/data/models/shift_with_type.dart';
import 'package:moniq/data/models/team_model.dart';
import 'package:moniq/data/providers/auth_providers.dart';
import 'package:moniq/data/providers/home_cache_providers.dart';
import 'package:moniq/data/providers/settings_providers.dart';
import 'package:moniq/data/providers/shift_providers.dart';
import 'package:moniq/data/providers/supabase_providers.dart';
import 'package:moniq/data/providers/team_providers.dart';
import 'package:moniq/data/repositories/shift_repository.dart';
import 'package:moniq/data/repositories/team_repository.dart';
import 'package:moniq/presentation/viewmodels/home_viewmodel.dart';
import 'package:moniq/presentation/viewmodels/team_calendar_viewmodel.dart';
import 'package:moniq/presentation/viewmodels/team_viewmodel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/fixtures.dart';

/// 왕복 1회에 해당하는 가짜 지연.
const _rtt = Duration(milliseconds: 200);

const _userId = 'user-1';

final _team = TeamModel(
  id: 'team-1',
  name: '3병동',
  createdBy: _userId,
  createdAt: DateTime(2026),
);

/// 호출 시작/종료 시각(ms)을 기록하는 타임라인.
class CallLog {
  final Stopwatch _sw = Stopwatch()..start();
  final List<({String name, String phase, int atMs})> entries = [];

  void begin(String name) =>
      entries.add((name: name, phase: 'begin', atMs: _sw.elapsedMilliseconds));
  void end(String name) =>
      entries.add((name: name, phase: 'end', atMs: _sw.elapsedMilliseconds));

  int? at(String name, String phase) {
    for (final e in entries) {
      if (e.name == name && e.phase == phase) return e.atMs;
    }
    return null;
  }

  int count(String name) =>
      entries.where((e) => e.name == name && e.phase == 'begin').length;

  int get elapsedMs => _sw.elapsedMilliseconds;
}

SupabaseClient _dummyClient() =>
    SupabaseClient('http://localhost:1', 'test-anon-key');

class FakeTeamRepository extends TeamRepository {
  FakeTeamRepository(this.log, {this.favorite, this.fail = false})
      : super(dataSource: TeamRemoteDataSource(client: _dummyClient()));

  final CallLog log;
  final TeamModel? favorite;
  final bool fail;

  @override
  Future<TeamModel?> getFavoriteTeam() async {
    log.begin('getFavoriteTeam');
    await Future<void>.delayed(_rtt);
    log.end('getFavoriteTeam');
    if (fail) throw Exception('offline');
    return favorite;
  }

  @override
  Future<List<TeamModel>> getMyTeams() async {
    log.begin('getMyTeams');
    await Future<void>.delayed(_rtt);
    log.end('getMyTeams');
    if (fail) throw Exception('offline');
    return favorite == null ? const [] : [favorite!];
  }
}

class FakeShiftRepository extends ShiftRepository {
  FakeShiftRepository(this.log, {this.shiftDates = const [], this.fail = false})
      : super(dataSource: ShiftRemoteDataSource(client: _dummyClient()));

  final CallLog log;
  final List<DateTime> shiftDates;
  final bool fail;

  @override
  Future<List<ShiftWithType>> getMyShiftsForTeam({
    required String teamId,
    required DateTime start,
    required DateTime end,
  }) async {
    log.begin('getMyShiftsForTeam');
    await Future<void>.delayed(_rtt);
    log.end('getMyShiftsForTeam');
    if (fail) throw Exception('offline');
    final type = buildShiftType(teamId: teamId);
    return [
      for (final d in shiftDates)
        ShiftWithType(
          shift: ShiftModel(
            id: 'shift-${d.day}',
            scheduleId: 'sched-1',
            teamId: teamId,
            userId: _userId,
            shiftDate: d,
            shiftTypeId: type.id,
          ),
          shiftType: type,
        ),
    ];
  }

  @override
  Future<Set<DateTime>> getCoveredDates({
    required String teamId,
    required DateTime start,
    required DateTime end,
  }) async {
    log.begin('getCoveredDates');
    await Future<void>.delayed(_rtt);
    log.end('getCoveredDates');
    if (fail) throw Exception('offline');
    return shiftDates.toSet();
  }
}

void main() {
  late SharedPreferences prefs;
  final now = DateTime.now();
  final day1 = DateTime(now.year, now.month, 1);
  final day2 = DateTime(now.year, now.month, 2);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  ProviderContainer makeContainer({
    required CallLog log,
    List<DateTime> shiftDates = const [],
    bool shiftsFail = false,
    bool teamsFail = false,
  }) {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        currentUserIdProvider.overrideWithValue(_userId),
        currentUserProvider.overrideWithValue(null),
        authStateChangesProvider
            .overrideWith((ref) => const Stream<AuthState>.empty()),
        teamRepositoryProvider.overrideWithValue(
          FakeTeamRepository(log, favorite: _team, fail: teamsFail),
        ),
        shiftRepositoryProvider.overrideWithValue(
          FakeShiftRepository(log, shiftDates: shiftDates, fail: shiftsFail),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  HomeCacheLocalDataSource cache() =>
      HomeCacheLocalDataSource(prefs: prefs, userId: _userId);

  /// 값이 채워질 때까지 기다린다.
  ///
  /// `provider.future`는 provider가 재빌드되면 완료되지 않을 수 있어
  /// (Riverpod 2 동작) 상태를 직접 폴링한다.
  Future<T> waitForValue<T>(
    ProviderContainer container,
    ProviderListenable<AsyncValue<T>> provider, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final sw = Stopwatch()..start();
    while (sw.elapsed < timeout) {
      final value = container.read(provider);
      if (value.hasValue && !value.isLoading) return value.requireValue;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    throw StateError('값이 $timeout 안에 채워지지 않았다');
  }

  group('콜드 스타트 왕복 수', () {
    test('캐시가 전혀 없으면 팀 조회 → 근무 조회 2왕복이 필요하다 (기준선)', () async {
      final log = CallLog();
      final container = makeContainer(log: log, shiftDates: [day1, day2]);

      final state = await waitForValue(container, homeViewModelProvider);

      expect(state.monthlyShifts.keys, containsAll([day1, day2]));
      // 근무 조회는 팀 조회가 끝난 뒤에야 시작한다 = 순차 2왕복.
      expect(
        log.at('getMyShiftsForTeam', 'begin'),
        greaterThanOrEqualTo(log.at('getFavoriteTeam', 'end')!),
      );
      expect(log.elapsedMs, greaterThanOrEqualTo(2 * _rtt.inMilliseconds));
    });

    test('즐겨찾기 팀 id가 캐시돼 있으면 근무 조회를 곧바로 발사한다 (1왕복)', () async {
      await cache().setFavoriteTeam(_team);

      final log = CallLog();
      final container = makeContainer(log: log, shiftDates: [day1, day2]);

      final state = await waitForValue(container, homeViewModelProvider);

      expect(state.monthlyShifts.keys, containsAll([day1, day2]));
      // 팀 조회 응답을 기다리지 않고 근무 조회가 시작됐다.
      expect(
        log.at('getMyShiftsForTeam', 'begin'),
        lessThan(log.at('getFavoriteTeam', 'end')!),
      );
      // 2왕복(400ms)이 아니라 1왕복(200ms) 수준으로 끝난다.
      expect(log.elapsedMs, lessThan(2 * _rtt.inMilliseconds));
      // 팀 조회는 한 번만 — 즐겨찾기 provider와 홈이 요청을 공유한다.
      expect(log.count('getFavoriteTeam'), 1);
    });

    test('월 근무까지 캐시돼 있으면 네트워크를 기다리지 않고 즉시 콘텐츠가 나온다 (0왕복)',
        () async {
      final type = buildShiftType(teamId: _team.id);
      await cache().setFavoriteTeam(_team);
      await cache().setMonth(
        teamId: _team.id,
        month: now,
        mine: {
          day1: [
            ShiftWithType(
              shift: ShiftModel(
                id: 'cached-shift',
                scheduleId: 'sched-1',
                teamId: _team.id,
                userId: _userId,
                shiftDate: day1,
                shiftTypeId: type.id,
              ),
              shiftType: type,
            ),
          ],
        },
        coverage: {day1, day2},
      );

      final log = CallLog();
      final container = makeContainer(log: log, shiftDates: [day1, day2]);

      // 동기적으로 이미 데이터가 있다 — 로딩 프레임이 없다.
      final immediate = container.read(homeViewModelProvider);
      expect(immediate.hasValue, isTrue);
      expect(immediate.isLoading, isFalse);
      expect(immediate.value!.monthlyShifts[day1]!.single.shift.id,
          'cached-shift');
      expect(immediate.value!.teamScheduledDates, {day1, day2});
      expect(log.elapsedMs, lessThan(_rtt.inMilliseconds));
    });
  });

  group('stale-while-revalidate 정확성', () {
    test('네트워크가 성공하면 오래된 캐시를 반드시 덮어쓴다', () async {
      final type = buildShiftType(teamId: _team.id);
      await cache().setFavoriteTeam(_team);
      await cache().setMonth(
        teamId: _team.id,
        month: now,
        mine: {
          day1: [
            ShiftWithType(
              shift: ShiftModel(
                id: 'stale-shift',
                scheduleId: 'sched-old',
                teamId: _team.id,
                userId: _userId,
                shiftDate: day1,
                shiftTypeId: type.id,
              ),
              shiftType: type,
            ),
          ],
        },
        coverage: {day1},
      );

      final log = CallLog();
      // 서버에는 day2 근무만 남아 있다 (day1 근무는 삭제됨).
      final container = makeContainer(log: log, shiftDates: [day2]);

      // 캐시로 먼저 그려진 상태
      expect(
        container.read(homeViewModelProvider).value!.monthlyShifts.keys,
        [day1],
      );

      await Future<void>.delayed(_rtt * 3);

      final refreshed = container.read(homeViewModelProvider).value!;
      expect(refreshed.monthlyShifts.keys, [day2],
          reason: '서버에서 사라진 근무가 캐시 때문에 남아 있으면 안 된다');
      // 캐시도 최신값으로 교체된다
      expect(
        cache().getMonth(teamId: _team.id, month: now)!.value.mine.keys,
        [day2],
      );
    });

    test('네트워크가 실패하면 캐시 내용을 그대로 유지한다 (오프라인)', () async {
      final type = buildShiftType(teamId: _team.id);
      await cache().setFavoriteTeam(_team);
      await cache().setMonth(
        teamId: _team.id,
        month: now,
        mine: {
          day1: [
            ShiftWithType(
              shift: ShiftModel(
                id: 'cached-shift',
                scheduleId: 'sched-1',
                teamId: _team.id,
                userId: _userId,
                shiftDate: day1,
                shiftTypeId: type.id,
              ),
              shiftType: type,
            ),
          ],
        },
        coverage: {day1},
      );

      final log = CallLog();
      final container = makeContainer(
        log: log,
        shiftsFail: true,
        teamsFail: true,
      );

      expect(container.read(homeViewModelProvider).hasValue, isTrue);
      await Future<void>.delayed(_rtt * 3);

      final state = container.read(homeViewModelProvider);
      expect(state.hasError, isFalse);
      expect(state.value!.monthlyShifts[day1]!.single.shift.id, 'cached-shift');
      expect(
        container.read(favoriteTeamProvider).value?.id,
        _team.id,
        reason: '즐겨찾기 팀도 캐시가 유지돼야 한다',
      );
    });

    test('[측정] 첫 콘텐츠까지 걸린 시간을 시나리오별로 출력한다', () async {
      // 1) 완전 최초 실행 — 캐시 없음
      var log = CallLog();
      var container = makeContainer(log: log, shiftDates: [day1]);
      await waitForValue(container, homeViewModelProvider);
      final coldMs = log.elapsedMs;

      // 2) 즐겨찾기 팀만 캐시됨 (앱 재설치 후 재로그인 등)
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      await cache().setFavoriteTeam(_team);
      log = CallLog();
      container = makeContainer(log: log, shiftDates: [day1]);
      await waitForValue(container, homeViewModelProvider);
      final warmTeamMs = log.elapsedMs;

      // 3) 월 근무까지 캐시됨 (두 번째 실행 이후 = 일반적인 콜드 스타트)
      log = CallLog();
      container = makeContainer(log: log, shiftDates: [day1]);
      await waitForValue(container, homeViewModelProvider);
      final warmMonthMs = log.elapsedMs;

      debugPrint(
        '[perf] 왕복 지연 ${_rtt.inMilliseconds}ms 기준 첫 콘텐츠까지: '
        '캐시없음=${coldMs}ms, 팀만캐시=${warmTeamMs}ms, 월캐시=${warmMonthMs}ms',
      );

      expect(warmTeamMs, lessThan(coldMs));
      expect(warmMonthMs, lessThan(warmTeamMs));
    });

    test('팀 목록도 캐시로 즉시 emit 후 네트워크로 갱신된다', () async {
      await cache().setMyTeams([_team]);

      final log = CallLog();
      final container = makeContainer(log: log);

      final immediate = container.read(teamViewModelProvider);
      expect(immediate.hasValue, isTrue);
      expect(immediate.value!.single.id, _team.id);
      expect(log.count('getMyTeams'), 1, reason: '갱신 요청은 백그라운드로 나간다');
    });
  });
}
