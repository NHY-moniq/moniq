import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/models/roster_entry.dart';
import 'package:moniq/data/models/shift_type_model.dart';
import 'package:moniq/data/models/shift_with_type.dart';
import 'package:moniq/data/models/team_model.dart';
import 'package:moniq/data/providers/shift_providers.dart';
import 'package:moniq/data/providers/supabase_providers.dart';
import 'package:moniq/data/providers/team_providers.dart';
import 'package:moniq/data/repositories/shift_repository.dart';
import 'package:moniq/data/repositories/team_repository.dart';
import 'package:moniq/presentation/widgets/calendar/view_mode_toggle.dart';

part 'team_calendar_viewmodel.freezed.dart';

@freezed
class TeamCalendarState with _$TeamCalendarState {
  const factory TeamCalendarState({
    required String teamId,
    required String teamName,
    required DateTime focusedMonth,
    required DateTime selectedDate,
    @Default(CalendarViewMode.month) CalendarViewMode viewMode,
    @Default({}) Map<DateTime, List<ShiftWithType>> monthlyShifts,
    @Default([]) List<RosterEntry> selectedDateRoster,
    @Default([]) List<ShiftTypeModel> shiftTypes,
  }) = _TeamCalendarState;
}

final teamCalendarViewModelProvider =
    AsyncNotifierProvider.family<
      TeamCalendarViewModel,
      TeamCalendarState,
      String
    >(TeamCalendarViewModel.new);

final favoriteTeamProvider = FutureProvider<TeamModel?>((ref) async {
  final authState = ref.watch(authStateChangesProvider);
  final userId = authState.whenOrNull(data: (auth) => auth.session?.user.id);
  if (userId == null) {
    return null;
  }

  final teamRepo = ref.watch(teamRepositoryProvider);
  return teamRepo.getFavoriteTeam();
});

class TeamCalendarViewModel
    extends FamilyAsyncNotifier<TeamCalendarState, String> {
  late ShiftRepository _shiftRepository;
  late TeamRepository _teamRepository;

  @override
  Future<TeamCalendarState> build(String teamId) async {
    final authState = ref.watch(authStateChangesProvider);
    final userId = authState.whenOrNull(data: (auth) => auth.session?.user.id);
    if (userId == null) {
      throw Exception('Not authenticated');
    }

    _shiftRepository = ref.watch(shiftRepositoryProvider);
    _teamRepository = ref.watch(teamRepositoryProvider);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final results = await Future.wait([
      _teamRepository.getTeamById(teamId),
      _shiftRepository.getShiftTypes(teamId),
      _shiftRepository.getTeamMonthlyShifts(teamId: teamId, month: now),
      _shiftRepository.getTeamRoster(teamId: teamId, date: today),
    ]);

    final team = results[0] as TeamModel;
    final shiftTypes = results[1] as List<ShiftTypeModel>;
    final monthlyShifts = results[2] as Map<DateTime, List<ShiftWithType>>;
    final roster = results[3] as List<RosterEntry>;

    return TeamCalendarState(
      teamId: teamId,
      teamName: team.name,
      focusedMonth: now,
      selectedDate: today,
      monthlyShifts: monthlyShifts,
      selectedDateRoster: roster,
      shiftTypes: shiftTypes,
    );
  }

  Future<void> selectDate(DateTime date) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final dateKey = DateTime(date.year, date.month, date.day);
    final roster = await _shiftRepository.getTeamRoster(
      teamId: current.teamId,
      date: dateKey,
    );

    state = AsyncData(
      current.copyWith(selectedDate: dateKey, selectedDateRoster: roster),
    );
  }

  Future<void> changeMonth(DateTime month) async {
    final current = state.valueOrNull;
    if (current == null) return;

    try {
      final monthlyShifts = await _shiftRepository.getTeamMonthlyShifts(
        teamId: current.teamId,
        month: month,
      );

      // 주간 모드에서는 focused 날짜를 그대로 사용, 월간에서는 1일
      final selectedDate = current.viewMode == CalendarViewMode.week
          ? DateTime(month.year, month.month, month.day)
          : DateTime(month.year, month.month, 1);

      final roster = await _shiftRepository.getTeamRoster(
        teamId: current.teamId,
        date: selectedDate,
      );

      state = AsyncData(
        current.copyWith(
          focusedMonth: month,
          selectedDate: selectedDate,
          monthlyShifts: monthlyShifts,
          selectedDateRoster: roster,
        ),
      );
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  void toggleViewMode() {
    final current = state.valueOrNull;
    if (current == null) return;

    final newMode = current.viewMode == CalendarViewMode.month
        ? CalendarViewMode.week
        : CalendarViewMode.month;

    state = AsyncData(current.copyWith(viewMode: newMode));
  }
}
