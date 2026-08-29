import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/core/utils/perf_trace.dart';
import 'package:moniq/core/utils/time_utils.dart';
import 'package:moniq/data/datasources/home_cache_local_data_source.dart';
import 'package:moniq/data/models/shift_type_model.dart';
import 'package:moniq/data/models/shift_with_type.dart';
import 'package:moniq/data/models/team_model.dart';
import 'package:moniq/data/models/user_model.dart';
import 'package:moniq/data/providers/home_cache_providers.dart';
import 'package:moniq/data/providers/shift_providers.dart';
import 'package:moniq/data/providers/supabase_providers.dart';
import 'package:moniq/data/repositories/shift_repository.dart';
import 'package:moniq/presentation/screens/calendar/calendar_providers.dart';
import 'package:moniq/presentation/viewmodels/team_calendar_viewmodel.dart';
import 'package:moniq/presentation/widgets/calendar/view_mode_toggle.dart';

part 'home_viewmodel.freezed.dart';

@freezed
class HomeCalendarState with _$HomeCalendarState {
  const factory HomeCalendarState({
    required DateTime focusedMonth,
    required DateTime selectedDate,
    @Default({}) Map<DateTime, List<ShiftWithType>> monthlyShifts,
    @Default(null) List<ShiftWithType>? selectedDateShifts,
    @Default(CalendarViewMode.month) CalendarViewMode viewMode,
    /// 즐겨찾기 팀의 published 스케줄이 커버하는 날짜들.
    /// 본인 근무가 없어도 이 set에 포함되면 OFF로 표시한다.
    @Default({}) Set<DateTime> teamScheduledDates,
  }) = _HomeCalendarState;
}

final homeViewModelProvider =
    AsyncNotifierProvider<HomeViewModel, HomeCalendarState>(HomeViewModel.new);

/// 한 달치 화면 데이터 — 본인 근무 + published 스케줄 커버리지.
typedef MonthShiftData = ({
  Map<DateTime, List<ShiftWithType>> mine,
  Set<DateTime> coverage,
});

/// 개인 캘린더에서만 적용되는 날짜 표시 — 팀 데이터는 건드리지 않는다.
///
/// - [hidden]: "근무 삭제"로 숨긴 날 → 근무·OFF 모두 감춰 빈 칸이 된다.
/// - [off]: "오프"로 바꾼 날 → 팀 근무만 감추고 OFF 표시는 남긴다.
///   (오프는 팀 근무 유형으로 존재하지 않아 오버라이드로 표현할 수 없다)
typedef PersonalDateMarks = ({Set<DateTime> hidden, Set<DateTime> off});

const MonthShiftData _emptyMonth = (
  mine: <DateTime, List<ShiftWithType>>{},
  coverage: <DateTime>{},
);

class HomeViewModel extends AsyncNotifier<HomeCalendarState> {
  late ShiftRepository _shiftRepository;
  HomeCacheLocalDataSource? _cache;

  /// 지금 화면이 기준으로 삼고 있는 팀 id (캐시된 즐겨찾기 또는 확인된 최신값).
  String? _teamId;

  /// 이 build 인스턴스가 폐기됐는지 — 백그라운드 갱신이 죽은 상태를
  /// 건드리지 않도록 가드한다.
  bool _disposed = false;

  /// 진행 중인 (팀, 월) 조회. 즐겨찾기 팀이 loading→data로 바뀌며 홈이 재빌드될
  /// 때 같은 달을 두 번 받아오지 않도록 요청을 공유한다.
  final Map<String, Future<MonthShiftData>> _inflightMonths = {};

  /// 특정 팀의 [month] 근무·커버리지를 받아 캐시에 저장한다 (서버 원본 그대로).
  ///
  /// 즐겨찾기 팀 조회를 기다리지 않고 팀 id만으로 곧바로 호출할 수 있어야
  /// 콜드 스타트의 순차 왕복이 사라진다.
  Future<MonthShiftData> _loadTeamMonth(String teamId, DateTime month) {
    final key = '$teamId:${month.year}-${month.month}';
    final existing = _inflightMonths[key];
    if (existing != null) return existing;
    final request = _fetchTeamMonth(teamId, month);
    _inflightMonths[key] = request;
    return request.whenComplete(() => _inflightMonths.remove(key));
  }

  /// coverage 는 published 스케줄의 period_start..period_end 합집합으로 계산해
  /// 실제 shift 배정이 없는 날(예: 전원 OFF)도 누락 없이 포함한다.
  Future<MonthShiftData> _fetchTeamMonth(String teamId, DateTime month) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0);

    final results = await Future.wait<dynamic>([
      _shiftRepository.getMyShiftsForTeam(
        teamId: teamId,
        start: start,
        end: end,
      ),
      _shiftRepository.getCoveredDates(
        teamId: teamId,
        start: start,
        end: end,
      ),
    ]);
    final myList = results[0] as List<ShiftWithType>;
    final coverage = results[1] as Set<DateTime>;

    final mine = <DateTime, List<ShiftWithType>>{};
    for (final sw in myList) {
      final d = DateTime(
        sw.shift.shiftDate.year,
        sw.shift.shiftDate.month,
        sw.shift.shiftDate.day,
      );
      mine.putIfAbsent(d, () => []).add(sw);
    }

    // 네트워크가 성공했으면 캐시는 **항상** 이 응답으로 덮어쓴다.
    // (오래된 근무가 남지 않도록 — 실패했을 때만 이전 캐시가 유지된다)
    // 저장은 서버 원본 그대로 — "근무 삭제" 숨김은 표시 시점에 적용한다.
    await _cache?.setMonth(
      teamId: teamId,
      month: month,
      mine: mine,
      coverage: coverage,
    );
    return (mine: mine, coverage: coverage);
  }

  /// 개인 캘린더에서 가릴 날짜들. `ref`를 쓰므로 await **이전에만** 호출한다.
  ///
  /// - hidden: "근무 삭제"로 숨긴 날 (근무·OFF 모두 제거 → 빈 칸)
  /// - off: "오프"로 바꾼 날 (팀 근무만 가리고 OFF 표시는 유지)
  PersonalDateMarks _hiddenDates() {
    final ds = ref.read(personalHiddenShiftsDataSourceProvider);
    return (hidden: ds.getHiddenDates(), off: ds.getOffDates());
  }

  /// 숨김·오프 표시를 화면 데이터에 반영한다 (팀 데이터·캐시 원본은 보존).
  static MonthShiftData _applyHidden(
    MonthShiftData data,
    PersonalDateMarks marks,
  ) {
    final hidden = marks.hidden;
    final off = marks.off;
    if (hidden.isEmpty && off.isEmpty) return data;
    final visible = Map<DateTime, List<ShiftWithType>>.from(data.mine)
      ..removeWhere((d, _) => hidden.contains(d) || off.contains(d));
    return (
      mine: visible,
      // 오프로 바꾼 날은 근무만 가리고 커버리지에 남겨 'O'가 보이게 한다.
      coverage: {
        ...data.coverage.where((d) => !hidden.contains(d)),
        ...off.where((d) => !hidden.contains(d)),
      },
    );
  }

  /// 즐겨찾기 팀을 확인하면서 근무를 받아온다 (서버 원본 그대로).
  ///
  /// [assumedTeamId]가 있으면 그 팀으로 **즉시** 근무 조회를 발사하고,
  /// 최신 즐겨찾기 팀 정보([favFuture])는 병렬로 받는다. 둘이 일치하면 그대로
  /// 쓰고, 다르면 새 팀으로 다시 조회한다. (콜드 스타트의 순차 왕복 제거)
  ///
  /// [favFuture]를 인자로 받는 이유: 이 메서드는 await를 넘나들기 때문에
  /// 내부에서 `ref`를 만지면 "의존성이 바뀐 뒤 재빌드 전" 창에서 실패할 수 있다.
  Future<MonthShiftData> _resolveAndLoad(
    DateTime month, {
    required Future<TeamModel?> favFuture,
    String? assumedTeamId,
  }) async {
    if (assumedTeamId != null) {
      final assumed = _loadTeamMonth(assumedTeamId, month);
      TeamModel? fresh;
      try {
        fresh = await favFuture;
      } catch (e) {
        // 팀 정보 조회가 실패해도 가정한 팀의 근무는 그대로 쓴다.
        debugPrint('[cache] 즐겨찾기 팀 확인 실패 — 캐시된 팀으로 진행: $e');
        return assumed;
      }
      if (fresh?.id == assumedTeamId) return assumed;

      // 즐겨찾기가 바뀌었다 — 방금 띄운 요청은 버리고 새 팀으로 다시 조회.
      assumed.ignore();
      _teamId = fresh?.id;
      if (fresh == null) return _emptyMonth;
      return _loadTeamMonth(fresh.id, month);
    }

    final fresh = await favFuture;
    _teamId = fresh?.id;
    if (fresh == null) return _emptyMonth;
    return _loadTeamMonth(fresh.id, month);
  }

  @override
  FutureOr<HomeCalendarState> build() {
    ref.watch(authStateChangesProvider);
    final userId = ref.watch(currentUserIdProvider);
    // 즐겨찾기 변경 시 자동 재빌드
    final favAsync = ref.watch(favoriteTeamProvider);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monthStart = DateTime(now.year, now.month, 1);

    if (userId == null) {
      return HomeCalendarState(focusedMonth: now, selectedDate: today);
    }

    _shiftRepository = ref.watch(shiftRepositoryProvider);
    _cache = ref.watch(homeCacheProvider);
    _disposed = false;
    ref.onDispose(() => _disposed = true);

    // 즐겨찾기 팀이 이미 확정(캐시 emit 포함)됐으면 그 값을, 아직이면
    // 캐시된 팀 id를 가정해 근무 조회를 곧바로 발사한다.
    _teamId = favAsync.hasValue
        ? favAsync.value?.id
        : _cache?.getFavoriteTeamId();

    final cached = _teamId == null
        ? null
        : _cache?.getMonth(teamId: _teamId!, month: now);
    final marks = _hiddenDates();

    if (cached != null) {
      final visible = _applyHidden(
        (mine: cached.value.mine, coverage: cached.value.coverage),
        marks,
      );
      final assumed = _teamId;
      // 캐시로 먼저 그리고(동기 반환 → 로딩 프레임 없음) 뒤에서 갱신한다.
      Future.microtask(() => _revalidate(now, assumedTeamId: assumed));
      PerfTrace.mark('home state from cache');
      return HomeCalendarState(
        focusedMonth: monthStart,
        selectedDate: today,
        monthlyShifts: visible.mine,
        selectedDateShifts: visible.mine[today],
        teamScheduledDates: visible.coverage,
      );
    }

    return _buildFresh(
      now,
      monthStart,
      today,
      assumedTeamId: _teamId,
      favFuture: ref.read(favoriteTeamProvider.notifier).fresh,
      marks: marks,
    );
  }

  Future<HomeCalendarState> _buildFresh(
    DateTime month,
    DateTime monthStart,
    DateTime today, {
    required Future<TeamModel?> favFuture,
    required PersonalDateMarks marks,
    String? assumedTeamId,
  }) async {
    final raw = await _resolveAndLoad(
      month,
      favFuture: favFuture,
      assumedTeamId: assumedTeamId,
    );
    final data = _applyHidden(raw, marks);
    PerfTrace.mark('home state from network');
    return HomeCalendarState(
      focusedMonth: monthStart,
      selectedDate: today,
      monthlyShifts: data.mine,
      selectedDateShifts: data.mine[today],
      teamScheduledDates: data.coverage,
    );
  }

  /// 백그라운드 갱신 — 성공하면 화면을 최신 데이터로 갈아끼우고,
  /// 실패하면 이미 그려진 캐시 화면을 그대로 둔다.
  Future<void> _revalidate(
    DateTime month, {
    String? assumedTeamId,
    bool forceFavoriteReload = false,
  }) async {
    try {
      // ref 접근은 첫 await 이전에 모두 끝낸다 — 갱신 도중 의존성이 바뀌면
      // await 이후의 ref.read가 실패해 갱신이 통째로 유실될 수 있다.
      final favNotifier = ref.read(favoriteTeamProvider.notifier);
      final marks = _hiddenDates();
      final raw = await _resolveAndLoad(
        month,
        favFuture:
            forceFavoriteReload ? favNotifier.reload() : favNotifier.fresh,
        assumedTeamId: assumedTeamId,
      );
      final data = _applyHidden(raw, marks);
      if (_disposed) return;
      final latest = state.valueOrNull;
      // 갱신 도중 사용자가 다른 달로 이동했으면 덮어쓰지 않는다.
      if (latest == null ||
          latest.focusedMonth.year != month.year ||
          latest.focusedMonth.month != month.month) {
        return;
      }
      state = AsyncData(
        latest.copyWith(
          monthlyShifts: data.mine,
          selectedDateShifts: data.mine[latest.selectedDate],
          teamScheduledDates: data.coverage,
        ),
      );
      PerfTrace.mark('home revalidated');
    } catch (e) {
      debugPrint('[cache] 홈 갱신 실패 — 캐시 유지: $e');
    }
  }

  Future<void> selectDate(DateTime date) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final dateKey = DateTime(date.year, date.month, date.day);
    state = AsyncData(
      current.copyWith(
        selectedDate: dateKey,
        selectedDateShifts: current.monthlyShifts[dateKey],
      ),
    );
  }

  Future<void> changeMonth(DateTime month) async {
    final current = state.valueOrNull;
    if (current == null) return;

    // 주간 모드에서는 focused 날짜를 그대로 사용(같은 달 내 주 이동도 반영),
    // 월간 모드에서는 1일. 팀 캘린더(team_calendar_viewmodel)와 동일한 처리.
    final selectedDate = current.viewMode == CalendarViewMode.week
        ? DateTime(month.year, month.month, month.day)
        : DateTime(month.year, month.month, 1);

    // focusedMonth/selectedDate를 즉시 업데이트 (스냅백 방지).
    // focusedMonth를 1일로 스냅하지 않고 focused 날짜를 그대로 둬야
    // 주간 보기에서 좌우 이동이 정상 동작한다.
    // 그 달 캐시가 있으면 근무까지 같이 채워 빈 격자를 보여주지 않는다.
    final teamId = _teamId;
    final cached =
        teamId == null ? null : _cache?.getMonth(teamId: teamId, month: month);
    final cachedVisible = cached == null
        ? null
        : _applyHidden(
            (mine: cached.value.mine, coverage: cached.value.coverage),
            _hiddenDates(),
          );
    state = AsyncData(
      current.copyWith(
        focusedMonth: month,
        selectedDate: selectedDate,
        monthlyShifts: cachedVisible?.mine ?? current.monthlyShifts,
        selectedDateShifts: cachedVisible?.mine[selectedDate],
        teamScheduledDates:
            cachedVisible?.coverage ?? current.teamScheduledDates,
      ),
    );

    // 이동 중 실패는 화면을 깨뜨리지 않도록 조용히 무시(이미 즉시 반영됨).
    await _revalidate(month, assumedTeamId: teamId);
  }

  /// 강제 새로고침 (pull-to-refresh) — 즐겨찾기 팀까지 네트워크에서 다시 받는다.
  Future<void> refresh() async {
    final current = state.valueOrNull;
    if (current == null) {
      // 아직 첫 로드가 진행 중 — 재빌드만 걸고 그 결과를 기다리지 않는다.
      // (재빌드 중인 provider의 future는 완료 보장이 없다)
      ref.invalidateSelf();
      return;
    }
    await _revalidate(
      current.focusedMonth,
      assumedTeamId: _teamId,
      forceFavoriteReload: true,
    );
  }

  void toggleViewMode() {
    final current = state.valueOrNull;
    if (current == null) return;
    final next = current.viewMode == CalendarViewMode.month
        ? CalendarViewMode.week
        : CalendarViewMode.month;
    state = AsyncData(current.copyWith(viewMode: next));
  }
}

/// 오늘 나와 같은 shift_type에 배정된 팀원 목록 (본인 제외)
final todayCoworkersProvider =
    FutureProvider.autoDispose<List<UserModel>>((ref) async {
  final homeAsync = ref.watch(homeViewModelProvider);
  final state = homeAsync.valueOrNull;
  if (state == null) return const [];

  final now = DateTime.now();
  final todayKey = DateTime(now.year, now.month, now.day);
  final todayShifts = state.monthlyShifts[todayKey];
  if (todayShifts == null || todayShifts.isEmpty) return const [];

  final myShift = todayShifts.first;
  if (myShift.shiftType.code.toUpperCase() == 'OFF') return const [];

  final repo = ref.watch(shiftRepositoryProvider);
  return repo.getCoworkers(
    teamId: myShift.shift.teamId,
    date: todayKey,
    shiftTypeId: myShift.shiftType.id,
  );
});

/// OnShiftTeam 모달용 — 현재 시프트 + 다음 시프트의 코워커 목록
class OnShiftTeamData {
  const OnShiftTeamData({
    this.teamId,
    this.currentType,
    this.nextType,
    this.currentCoworkers = const [],
    this.nextCoworkers = const [],
  });

  final String? teamId;
  final ShiftTypeModel? currentType;
  final ShiftTypeModel? nextType;
  final List<UserModel> currentCoworkers;
  final List<UserModel> nextCoworkers;
}

/// ON SHIFT NOW에서 '근무중'으로 인정하는 시프트 코드.
/// 데이/이브닝/나이트만 병원 근무로 보고, 교육(ED) 등은 개인 일정으로 간주해 제외한다.
const _workShiftCodes = {'D', 'E', 'N'};

final onShiftTeamDataProvider =
    FutureProvider.autoDispose<OnShiftTeamData>((ref) async {
  final homeAsync = ref.watch(homeViewModelProvider);
  final state = homeAsync.valueOrNull;
  if (state == null) return const OnShiftTeamData();

  final now = DateTime.now();
  final todayKey = DateTime(now.year, now.month, now.day);
  final todayShifts = state.monthlyShifts[todayKey];

  // teamId: 본인이 그날 schedule되어 있으면 그 팀(OFF여도 OK),
  // 아니면 favorite team. 둘 다 없으면 표시할 팀이 없음.
  String? teamId;
  if (todayShifts != null && todayShifts.isNotEmpty) {
    teamId = todayShifts.first.shift.teamId;
  } else {
    final fav = await ref.watch(favoriteTeamProvider.future);
    teamId = fav?.id;
  }
  if (teamId == null) return const OnShiftTeamData();

  final repo = ref.watch(shiftRepositoryProvider);
  final allTypes = await repo.getShiftTypes(teamId);
  final scheduled = allTypes
      .where((t) =>
          _workShiftCodes.contains(t.code.toUpperCase()) &&
          t.startTime != null &&
          t.startTime!.isNotEmpty &&
          t.endTime != null &&
          t.endTime!.isNotEmpty)
      .toList()
    ..sort((a, b) => (a.startTime ?? '').compareTo(b.startTime ?? ''));

  if (scheduled.isEmpty) return const OnShiftTeamData();

  // 현재 시각에 매치되는 shift_type
  ShiftTypeModel? currentType;
  for (final t in scheduled) {
    if (isNowInShiftRange(t, now)) {
      currentType = t;
      break;
    }
  }

  // 다음 shift_type (scheduled가 비어있지 않으므로 항상 non-null)
  final ShiftTypeModel nextType;
  if (currentType != null) {
    final idx = scheduled.indexWhere((t) => t.id == currentType!.id);
    nextType = idx >= 0 && idx < scheduled.length - 1
        ? scheduled[idx + 1]
        : scheduled.first; // 마지막이면 다음날 첫 시프트로 wrap
  } else {
    // 현재 매치 없으면 startTime이 현재 이후로 가장 가까운 것, 없으면 첫 시프트
    final nowMin = now.hour * 60 + now.minute;
    ShiftTypeModel? upcoming;
    for (final t in scheduled) {
      final s = parseTimeToMinutes(t.startTime);
      if (s != null && s > nowMin) {
        upcoming = t;
        break;
      }
    }
    nextType = upcoming ?? scheduled.first;
  }

  // ON SHIFT NOW는 본인 포함 — 팀 캘린더와 동일한 멤버 목록을 보여준다.
  final currentCoworkers = currentType == null
      ? const <UserModel>[]
      : await repo.getCoworkers(
          teamId: teamId,
          date: todayKey,
          shiftTypeId: currentType.id,
          excludeSelf: false,
        );
  final nextCoworkers = await repo.getCoworkers(
    teamId: teamId,
    date: todayKey,
    shiftTypeId: nextType.id,
    excludeSelf: false,
  );

  return OnShiftTeamData(
    teamId: teamId,
    currentType: currentType,
    nextType: nextType,
    currentCoworkers: currentCoworkers,
    nextCoworkers: nextCoworkers,
  );
});
