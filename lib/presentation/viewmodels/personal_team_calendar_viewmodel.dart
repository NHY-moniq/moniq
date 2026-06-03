import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/models/personal_team_member_shift.dart';
import 'package:moniq/data/providers/supabase_providers.dart';
import 'package:moniq/presentation/viewmodels/team_viewmodel.dart';
import 'package:moniq/presentation/widgets/calendar/view_mode_toggle.dart';

class PersonalTeamCalendarState {
  const PersonalTeamCalendarState({
    required this.teamId,
    required this.focusedMonth,
    required this.selectedDate,
    required this.viewMode,
    required this.members,
    required this.monthlyData,
  });

  final String teamId;
  final DateTime focusedMonth;
  final DateTime selectedDate;
  final CalendarViewMode viewMode;
  final List<PersonalTeamMember> members;

  // normalized date (midnight) → 해당 날 각 멤버의 shift (shift 없으면 포함 안 됨)
  final Map<DateTime, List<PersonalMemberShift>> monthlyData;

  PersonalTeamCalendarState copyWith({
    DateTime? focusedMonth,
    DateTime? selectedDate,
    CalendarViewMode? viewMode,
    List<PersonalTeamMember>? members,
    Map<DateTime, List<PersonalMemberShift>>? monthlyData,
  }) {
    return PersonalTeamCalendarState(
      teamId: teamId,
      focusedMonth: focusedMonth ?? this.focusedMonth,
      selectedDate: selectedDate ?? this.selectedDate,
      viewMode: viewMode ?? this.viewMode,
      members: members ?? this.members,
      monthlyData: monthlyData ?? this.monthlyData,
    );
  }

  List<PersonalMemberShift> shiftsForDate(DateTime date) {
    final key = DateTime(date.year, date.month, date.day);
    return monthlyData[key] ?? [];
  }
}

final personalTeamCalendarViewModelProvider =
    AsyncNotifierProvider.family<
      PersonalTeamCalendarViewModel,
      PersonalTeamCalendarState,
      String
    >(PersonalTeamCalendarViewModel.new);

class PersonalTeamCalendarViewModel
    extends FamilyAsyncNotifier<PersonalTeamCalendarState, String> {
  @override
  Future<PersonalTeamCalendarState> build(String teamId) async {
    // Re-fetch whenever team membership changes (e.g. new member joins).
    ref.watch(teamViewModelProvider);

    final now = DateTime.now();
    final selected = DateTime(now.year, now.month, now.day);
    final focusedDay = selected;
    final (members, data) = await _fetch(teamId, focusedDay);
    return PersonalTeamCalendarState(
      teamId: teamId,
      focusedMonth: focusedDay,
      selectedDate: selected,
      viewMode: CalendarViewMode.month,
      members: members,
      monthlyData: data,
    );
  }

  Future<void> changeMonth(DateTime month) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final nextFocused = DateTime(month.year, month.month, month.day);
    final nextSelected = current.viewMode == CalendarViewMode.week
        ? nextFocused
        : DateTime(month.year, month.month, 1);
    final isSameMonth =
        current.focusedMonth.year == nextFocused.year &&
        current.focusedMonth.month == nextFocused.month;

    if (isSameMonth) {
      state = AsyncData(
        current.copyWith(focusedMonth: nextFocused, selectedDate: nextSelected),
      );
      return;
    }

    final (members, data) = await _fetch(current.teamId, nextFocused);
    state = AsyncData(
      current.copyWith(
        focusedMonth: nextFocused,
        selectedDate: nextSelected,
        members: members,
        monthlyData: data,
      ),
    );
  }

  void selectDate(DateTime date) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(selectedDate: DateTime(date.year, date.month, date.day)),
    );
  }

  void setViewMode(CalendarViewMode mode) {
    final current = state.valueOrNull;
    if (current == null) return;
    if (current.viewMode == mode) return;
    state = AsyncData(current.copyWith(viewMode: mode));
  }

  Future<(List<PersonalTeamMember>, Map<DateTime, List<PersonalMemberShift>>)>
  _fetch(String teamId, DateTime month) async {
    final client = ref.read(supabaseClientProvider);
    final rows =
        await client.rpc(
              'get_personal_team_member_shifts',
              params: {
                'p_team_id': teamId,
                'p_year': month.year,
                'p_month': month.month,
              },
            )
            as List<dynamic>;

    final membersMap = <String, PersonalTeamMember>{};
    final dataMap = <DateTime, List<PersonalMemberShift>>{};

    for (final row in rows) {
      final m = row as Map<String, dynamic>;
      final uid = m['user_id'] as String;

      membersMap.putIfAbsent(
        uid,
        () => PersonalTeamMember(
          userId: uid,
          displayName: (m['display_name'] as String?) ?? uid,
          avatarUrl: m['avatar_url'] as String?,
        ),
      );

      final dateStr = m['shift_date'] as String?;
      if (dateStr == null) continue;
      final date = DateTime.parse(dateStr);
      final key = DateTime(date.year, date.month, date.day);

      final dayList = dataMap.putIfAbsent(key, () => []);
      // 멤버당 하루 1개 (is_favorite 중복 등 데이터 이슈 방어)
      if (dayList.any((s) => s.userId == uid)) continue;
      dayList.add(
        PersonalMemberShift(
          userId: uid,
          date: key,
          shiftCode: m['shift_type_code'] as String?,
          shiftColor: m['shift_type_color'] as String?,
          shiftName: m['shift_type_name'] as String?,
        ),
      );
    }

    return (membersMap.values.toList(), dataMap);
  }
}
