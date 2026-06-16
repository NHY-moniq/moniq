import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/core/utils/time_utils.dart';
import 'package:moniq/data/models/shift_type_model.dart';
import 'package:moniq/data/models/shift_with_type.dart';
import 'package:moniq/data/models/user_model.dart';
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

class HomeViewModel extends AsyncNotifier<HomeCalendarState> {
  late ShiftRepository _shiftRepository;

  /// 개인 캘린더에 표시할 즐겨찾기 팀의 (1) 본인 근무 + (2) 팀이 스케줄을
  /// 가진 날짜 set 을 함께 반환. (2)는 본인 근무가 없는 날을 OFF로 표시하기 위함.
  ///
  /// coverage 는 published 스케줄의 period_start..period_end 합집합으로 계산해
  /// 실제 shift 배정이 없는 날(예: 전원 OFF)도 누락 없이 포함한다.
  Future<({Map<DateTime, List<ShiftWithType>> mine, Set<DateTime> coverage})>
      _loadFavoriteTeamData(DateTime month) async {
    final favorite = await ref.read(favoriteTeamProvider.future);
    if (favorite == null) {
      return (mine: const <DateTime, List<ShiftWithType>>{}, coverage: const <DateTime>{});
    }
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0);

    final results = await Future.wait<dynamic>([
      _shiftRepository.getMyShiftsForTeam(
        teamId: favorite.id,
        start: start,
        end: end,
      ),
      _shiftRepository.getCoveredDates(
        teamId: favorite.id,
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

    // 개인 캘린더에서 "근무 삭제"로 숨긴 날짜는 근무/OFF 모두 제거 (팀 데이터는 보존).
    final hidden = ref.read(personalHiddenShiftsDataSourceProvider).getHiddenDates();
    if (hidden.isNotEmpty) {
      mine.removeWhere((d, _) => hidden.contains(d));
      final visibleCoverage = coverage.where((d) => !hidden.contains(d)).toSet();
      return (mine: mine, coverage: visibleCoverage);
    }
    return (mine: mine, coverage: coverage);
  }

  @override
  Future<HomeCalendarState> build() async {
    final authState = ref.watch(authStateChangesProvider);
    final userId = authState.whenOrNull(data: (auth) => auth.session?.user.id);
    // 즐겨찾기 변경 시 자동 재빌드
    ref.watch(favoriteTeamProvider);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monthStart = DateTime(now.year, now.month, 1);

    if (userId == null) {
      return HomeCalendarState(focusedMonth: now, selectedDate: today);
    }

    _shiftRepository = ref.watch(shiftRepositoryProvider);
    final data = await _loadFavoriteTeamData(now);

    return HomeCalendarState(
      focusedMonth: monthStart,
      selectedDate: today,
      monthlyShifts: data.mine,
      selectedDateShifts: data.mine[today],
      teamScheduledDates: data.coverage,
    );
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
    state = AsyncData(
      current.copyWith(
        focusedMonth: month,
        selectedDate: selectedDate,
        selectedDateShifts: null,
      ),
    );

    try {
      final data = await _loadFavoriteTeamData(month);

      // 빠른 연속 이동 시 오래된 응답이 최신 화면(다른 달)을 덮어쓰지 않도록 가드.
      final latest = state.valueOrNull;
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
    } catch (_) {
      // 이동 중 실패는 화면을 깨뜨리지 않도록 조용히 무시(이미 즉시 반영됨).
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
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
