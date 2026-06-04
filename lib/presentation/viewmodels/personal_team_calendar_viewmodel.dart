import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/models/personal_team_member_shift.dart';
import 'package:moniq/data/providers/supabase_providers.dart';
import 'package:moniq/presentation/viewmodels/team_viewmodel.dart';
import 'package:moniq/presentation/widgets/calendar/view_mode_toggle.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PersonalTeamAppointmentSetupException implements Exception {
  const PersonalTeamAppointmentSetupException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PersonalTeamCalendarState {
  const PersonalTeamCalendarState({
    required this.teamId,
    required this.focusedMonth,
    required this.selectedDate,
    required this.viewMode,
    required this.members,
    required this.selectedMemberIds,
    required this.monthlyData,
  });

  final String teamId;
  final DateTime focusedMonth;
  final DateTime selectedDate;
  final CalendarViewMode viewMode;
  final List<PersonalTeamMember> members;
  final Set<String> selectedMemberIds;

  // normalized date (midnight) → 해당 날 각 멤버의 shift (shift 없으면 포함 안 됨)
  final Map<DateTime, List<PersonalMemberShift>> monthlyData;

  PersonalTeamCalendarState copyWith({
    DateTime? focusedMonth,
    DateTime? selectedDate,
    CalendarViewMode? viewMode,
    List<PersonalTeamMember>? members,
    Set<String>? selectedMemberIds,
    Map<DateTime, List<PersonalMemberShift>>? monthlyData,
  }) {
    return PersonalTeamCalendarState(
      teamId: teamId,
      focusedMonth: focusedMonth ?? this.focusedMonth,
      selectedDate: selectedDate ?? this.selectedDate,
      viewMode: viewMode ?? this.viewMode,
      members: members ?? this.members,
      selectedMemberIds: selectedMemberIds ?? this.selectedMemberIds,
      monthlyData: monthlyData ?? this.monthlyData,
    );
  }

  List<PersonalTeamMember> get selectedMembers {
    if (selectedMemberIds.isEmpty) return const [];
    return members
        .where((member) => selectedMemberIds.contains(member.userId))
        .toList();
  }

  bool get isAllMembersSelected =>
      members.isNotEmpty && selectedMemberIds.length == members.length;

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
      selectedMemberIds: members.map((member) => member.userId).toSet(),
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
    final nextSelectedMemberIds = _normalizeSelectedMemberIds(
      members: members,
      selectedIds: current.selectedMemberIds,
    );
    state = AsyncData(
      current.copyWith(
        focusedMonth: nextFocused,
        selectedDate: nextSelected,
        members: members,
        selectedMemberIds: nextSelectedMemberIds,
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

  void setSelectedMemberIds(Set<String> ids) {
    final current = state.valueOrNull;
    if (current == null) return;

    final validIds = current.members.map((member) => member.userId).toSet();
    state = AsyncData(
      current.copyWith(selectedMemberIds: ids.where(validIds.contains).toSet()),
    );
  }

  Set<String> _normalizeSelectedMemberIds({
    required List<PersonalTeamMember> members,
    required Set<String> selectedIds,
  }) {
    if (selectedIds.isEmpty) return const <String>{};
    final validIds = members.map((member) => member.userId).toSet();
    final preservedIds = selectedIds.where(validIds.contains).toSet();
    if (preservedIds.isNotEmpty) return preservedIds;
    return validIds;
  }

  Future<void> createAppointment({
    required DateTime date,
    required String title,
    required Set<String> participantIds,
    String? startTime,
    String? endTime,
    String? description,
  }) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final validIds = current.members.map((member) => member.userId).toSet();
    final participants = participantIds.where(validIds.contains).toList();
    if (participants.isEmpty) {
      throw Exception('참여자를 선택해주세요.');
    }

    final client = ref.read(supabaseClientProvider);
    try {
      await client.rpc(
        'create_personal_team_appointment',
        params: {
          'p_team_id': current.teamId,
          'p_event_date': _dateStr(date),
          'p_title': title.trim(),
          'p_participant_ids': participants,
          'p_start_time': startTime,
          'p_end_time': endTime,
          'p_description': description,
          'p_color': '#FFB800',
        },
      );
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST202' ||
          e.message.contains('create_personal_team_appointment')) {
        throw const PersonalTeamAppointmentSetupException(
          '약속 저장 기능이 아직 서버에 반영되지 않았습니다. Supabase 마이그레이션을 적용한 뒤 다시 시도해주세요.',
        );
      }
      rethrow;
    }
  }

  String _dateStr(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

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
