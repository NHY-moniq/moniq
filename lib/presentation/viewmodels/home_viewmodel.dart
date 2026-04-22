import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/models/shift_with_type.dart';
import 'package:moniq/data/models/user_model.dart';
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
