import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/models/roster_entry.dart';
import 'package:moniq/data/models/shift_with_type.dart';
import 'package:moniq/data/providers/shift_providers.dart';
import 'package:moniq/data/providers/supabase_providers.dart';
import 'package:moniq/data/repositories/shift_repository.dart';

part 'home_viewmodel.freezed.dart';

@freezed
class HomeCalendarState with _$HomeCalendarState {
  const factory HomeCalendarState({
    required DateTime focusedMonth,
    required DateTime selectedDate,
    @Default({}) Map<DateTime, List<ShiftWithType>> monthlyShifts,
    @Default(null) List<ShiftWithType>? selectedDateShifts,
  }) = _HomeCalendarState;
}

final homeViewModelProvider =
    AsyncNotifierProvider<HomeViewModel, HomeCalendarState>(HomeViewModel.new);

class HomeViewModel extends AsyncNotifier<HomeCalendarState> {
  late ShiftRepository _shiftRepository;

  @override
  Future<HomeCalendarState> build() async {
    final authState = ref.watch(authStateChangesProvider);
    final userId = authState.whenOrNull(data: (auth) => auth.session?.user.id);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monthStart = DateTime(now.year, now.month, 1);

    if (userId == null) {
      return HomeCalendarState(focusedMonth: now, selectedDate: today);
    }

    _shiftRepository = ref.watch(shiftRepositoryProvider);
    final monthlyShifts = await _shiftRepository.getMyMonthlyShifts(month: now);

    return HomeCalendarState(
      focusedMonth: monthStart,
      selectedDate: today,
      monthlyShifts: monthlyShifts,
      selectedDateShifts: monthlyShifts[today],
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

    final monthStart = DateTime(month.year, month.month, 1);
    final today = DateTime.now();
    final selectedDate = DateTime(
      month.year,
      month.month,
      today.month == month.month && today.year == month.year ? today.day : 1,
    );

    // focusedMonth를 즉시 업데이트 (스냅백 방지)
    state = AsyncData(
      current.copyWith(
        focusedMonth: monthStart,
        selectedDate: selectedDate,
        selectedDateShifts: null,
      ),
    );

    try {
      final monthlyShifts = await _shiftRepository.getMyMonthlyShifts(
        month: month,
      );

      state = AsyncData(
        current.copyWith(
          focusedMonth: monthStart,
          selectedDate: selectedDate,
          monthlyShifts: monthlyShifts,
          selectedDateShifts: monthlyShifts[selectedDate],
        ),
      );
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}

/// 오늘 같은 팀에서 근무 중인 팀원 목록.
///
/// 사용자의 오늘 서버 근무가 있으면 해당 팀의 로스터를 조회하고,
/// 사용자와 같은 근무 유형의 팀원만 필터링하여 반환합니다.
final todayTeamRosterProvider =
    FutureProvider<OnShiftTeamInfo?>((ref) async {
  final calendarAsync = ref.watch(homeViewModelProvider);
  final state = calendarAsync.valueOrNull;
  if (state == null) return null;

  final today = DateTime.now();
  final todayKey = DateTime(today.year, today.month, today.day);
  final todayShifts = state.monthlyShifts[todayKey];
  if (todayShifts == null || todayShifts.isEmpty) return null;

  final myShift = todayShifts.first;
  final teamId = myShift.shift.teamId;
  final myShiftTypeId = myShift.shift.shiftTypeId;

  final repo = ref.watch(shiftRepositoryProvider);
  final roster = await repo.getTeamRoster(teamId: teamId, date: todayKey);

  // 나와 같은 근무 유형의 엔트리 찾기
  final myEntry = roster
      .where((e) => e.shiftType.id == myShiftTypeId)
      .firstOrNull;

  if (myEntry == null) return null;

  return OnShiftTeamInfo(
    shiftTypeName: myEntry.shiftType.name,
    teamName: myShift.teamName,
    workers: myEntry.workers,
    allRoster: roster,
  );
});

/// 홈 화면에서 사용할 On-Shift Team 정보 모음.
class OnShiftTeamInfo {
  const OnShiftTeamInfo({
    required this.shiftTypeName,
    this.teamName,
    required this.workers,
    required this.allRoster,
  });

  final String shiftTypeName;
  final String? teamName;
  final List<RosterWorker> workers;
  final List<RosterEntry> allRoster;
}
