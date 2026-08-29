import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/datasources/personal_event_local_data_source.dart';
import 'package:moniq/data/datasources/personal_event_remote_data_source.dart'
    show kPersonalTeamImportMarker;
import 'package:moniq/data/datasources/personal_hidden_shifts_local_data_source.dart';
import 'package:moniq/data/datasources/personal_note_local_data_source.dart';
import 'package:moniq/data/datasources/personal_shift_override_remote_data_source.dart';
import 'package:moniq/data/datasources/personal_shift_type_local_data_source.dart';
import 'package:moniq/data/models/shift_type_model.dart';
import 'package:moniq/data/providers/shift_providers.dart';
import 'package:moniq/data/providers/supabase_providers.dart';
import 'package:moniq/data/providers/auth_providers.dart';
import 'package:moniq/data/providers/settings_providers.dart';
import 'package:moniq/presentation/viewmodels/team_calendar_viewmodel.dart';

// ── Providers ──

/// 이벤트/노트 변경 시 증가시켜 모든 관련 provider를 갱신하는 트리거
final eventRefreshProvider = StateProvider<int>((ref) => 0);

/// 캘린더 탭 전체의 접기/펼치기 상태 (기본 펼침).
/// 날짜별이 아니라 탭 단위로 적용 — 한 번 토글하면 모든 날짜에 동일하게 반영.
final dateExpandedProvider = StateProvider<bool>((ref) => true);

/// 메모 접기/펼치기 상태 (키: "date-index", 기본 접힘)
final noteExpandedProvider =
    StateProvider.family<bool, String>((ref, key) => false);

final personalNoteDataSourceProvider = Provider<PersonalNoteLocalDataSource>(
  (ref) {
    final userId = ref.watch(currentUserProvider)?.id ?? 'anonymous';
    return PersonalNoteLocalDataSource(
      prefs: ref.watch(sharedPreferencesProvider),
      userId: userId,
    );
  },
);

final personalEventDataSourceProvider = Provider<PersonalEventLocalDataSource>(
  (ref) {
    final userId = ref.watch(currentUserProvider)?.id ?? 'anonymous';
    return PersonalEventLocalDataSource(
      prefs: ref.watch(sharedPreferencesProvider),
      userId: userId,
    );
  },
);

/// 개인 캘린더에서 "근무 삭제"로 숨긴 날짜(로컬 전용). 팀 데이터는 보존하고
/// 개인 캘린더 화면에서만 해당 날짜의 팀 근무/OFF를 제거한다.
final personalHiddenShiftsDataSourceProvider =
    Provider<PersonalHiddenShiftsLocalDataSource>(
  (ref) {
    final userId = ref.watch(currentUserProvider)?.id ?? 'anonymous';
    return PersonalHiddenShiftsLocalDataSource(
      prefs: ref.watch(sharedPreferencesProvider),
      userId: userId,
    );
  },
);

final personalShiftTypeDataSourceProvider =
    Provider<PersonalShiftTypeLocalDataSource>(
  (ref) {
    final userId = ref.watch(currentUserProvider)?.id ?? 'anonymous';
    return PersonalShiftTypeLocalDataSource(
      prefs: ref.watch(sharedPreferencesProvider),
      userId: userId,
    );
  },
);

final personalShiftTypesProvider = Provider<List<PersonalShiftType>>(
  (ref) => ref.watch(personalShiftTypeDataSourceProvider).getAll(),
);

/// 즐겨찾기 팀이 있으면 그 팀의 근무 유형을, 없으면 빈 리스트를 반환.
/// 개인 캘린더의 "근무 추가/변경"과 셀 코드 미리보기에서 팀/개인 분기에 사용.
final favoriteTeamShiftTypesProvider =
    FutureProvider<List<ShiftTypeModel>>((ref) async {
  final fav = await ref.watch(favoriteTeamProvider.future);
  if (fav == null) return const <ShiftTypeModel>[];
  try {
    return await ref.watch(shiftRepositoryProvider).getShiftTypes(fav.id);
  } catch (_) {
    return const <ShiftTypeModel>[];
  }
});

final personalShiftOverrideRemoteProvider =
    Provider<PersonalShiftOverrideRemoteDataSource>(
  (ref) => PersonalShiftOverrideRemoteDataSource(
    client: ref.watch(supabaseClientProvider),
  ),
);

/// shiftId → override (Supabase에서 로드)
final personalShiftOverridesProvider =
    FutureProvider<Map<String, PersonalShiftOverrideRemote>>((ref) async {
  ref.watch(eventRefreshProvider);
  // 인증 상태 변경 시 재조회
  ref.watch(currentUserProvider);
  return ref.read(personalShiftOverrideRemoteProvider).fetchMine();
});

final monthlyNotesProvider =
    Provider.family<Map<DateTime, List<PersonalNote>>, DateTime>(
  (ref, month) {
    ref.watch(eventRefreshProvider);
    return ref.watch(personalNoteDataSourceProvider).getMonthlyNotes(month);
  },
);

final dateNotesProvider = Provider.family<List<PersonalNote>, DateTime>(
  (ref, date) {
    ref.watch(eventRefreshProvider);
    return ref.watch(personalNoteDataSourceProvider).getNotes(date);
  },
);

/// 숨긴(근무 삭제) 날짜의 team-import 근무 이벤트는 개인 캘린더에서 제거하고,
/// 직접 추가한 개인 일정은 유지한다.
bool _isImportWork(PersonalEvent e) =>
    e.description?.startsWith(kPersonalTeamImportMarker) ?? false;

/// "근무"로 볼 수 있는 일정 제목 모음 — 개인 근무 유형 + 즐겨찾기 팀 근무 유형.
/// 빠른 추가로 넣은 근무는 import 마커가 없어 제목으로만 구분된다.
final shiftEventTitlesProvider = Provider<Set<String>>((ref) {
  final personal = ref.watch(personalShiftTypesProvider).map((t) => t.name);
  Iterable<String> team = const [];
  try {
    team =
        ref
            .watch(favoriteTeamShiftTypesProvider)
            .valueOrNull
            ?.map((t) => t.name) ??
        const [];
  } catch (_) {
    // Supabase 미초기화 등으로 팀 유형을 못 읽어도 개인 유형만으로 판별한다.
  }
  // 빠른 추가 칩에는 팀/개인 목록에 없어도 기본 '오프'가 항상 끼어 있다.
  // 그렇게 넣은 오프가 개인 일정으로 분류되지 않도록 이름을 함께 넣는다.
  final offName = PersonalShiftTypeLocalDataSource.defaultTypes
      .firstWhere((t) => t.id == 'off')
      .name;
  return {...personal, ...team, offName};
});

/// 근무를 연속으로 넣는 동안 뒤 캘린더가 따라가야 할 날짜.
///
/// 시트가 화면 아래쪽을 가려서, 대상 날짜가 아래 주(week)로 내려가면 가려진다.
/// 캘린더 화면이 이 값을 보고 그 줄이 시트 위로 올라오도록 스크롤한다.
/// [sheetFactor]는 시트가 차지하는 화면 높이 비율.
final addSheetFocusProvider =
    StateProvider<({DateTime date, double sheetFactor})?>((ref) => null);

/// "근무 삭제"로 숨긴 날짜들. 팀 근무·개인 근무 모두 이 날짜에서 감춘다.
final hiddenShiftDatesProvider = Provider<Set<DateTime>>((ref) {
  ref.watch(eventRefreshProvider);
  return ref.watch(personalHiddenShiftsDataSourceProvider).getHiddenDates();
});

/// 숨긴 날짜에서 지워야 할 항목인지 — 가져온 근무이거나 근무 유형 이름과 같은 일정.
///
/// "팀 근무 숨기기" 토글은 팀에서 온 근무만 감추면 되지만, "근무 삭제"는
/// 그 달의 근무를 통째로 치우는 동작이라 직접 넣은 근무도 함께 사라져야 한다.
/// (제목이 근무 유형과 무관한 일반 일정·메모는 그대로 남는다)
bool _isShiftEvent(PersonalEvent e, Set<String> shiftTitles) =>
    // 제목 목록은 즐겨찾기 팀/개인 유형에서 오므로, 팀을 나갔거나 유형을
    // 지운 뒤에는 옛 근무를 못 알아본다. 저장 시 찍어둔 플래그를 함께 본다.
    _isImportWork(e) || e.isShift || shiftTitles.contains(e.title);

/// 캘린더 셀 표시용 월간 일정. 여러 날에 걸친 일정은 걸쳐 있는 모든 날짜에
/// 나타난다 (표시 전용 — 수정/삭제 인덱스로는 [dateEventOccurrencesProvider] 사용).
///
/// "팀 근무 숨기기"가 켜져 있으면 팀 캘린더에서 개인 일정으로 내보낸
/// team-import 근무도 함께 숨긴다 — 사용자 입장에선 둘 다 "팀 근무"다.
final monthlyEventsProvider =
    Provider.family<Map<DateTime, List<PersonalEvent>>, DateTime>(
  (ref, month) {
    ref.watch(eventRefreshProvider);
    final all = ref
        .watch(personalEventDataSourceProvider)
        .getMonthlyEventsIncludingSpans(month);
    final hidden = ref.watch(hiddenShiftDatesProvider);
    final hideTeamShifts = ref.watch(hideTeamShiftsInPersonalProvider);
    if (hidden.isEmpty && !hideTeamShifts) return all;
    // 숨긴 날이 없으면 근무 유형 목록을 들여다볼 필요도 없다.
    final shiftTitles = hidden.isEmpty
        ? const <String>{}
        : ref.watch(shiftEventTitlesProvider);
    final out = <DateTime, List<PersonalEvent>>{};
    all.forEach((date, evts) {
      // 숨긴 날은 근무 전체를, 토글만 켜져 있으면 팀에서 온 근무만 제외.
      final kept = hidden.contains(date)
          ? evts.where((e) => !_isShiftEvent(e, shiftTitles)).toList()
          : hideTeamShifts
          ? evts.where((e) => !_isImportWork(e)).toList()
          : evts;
      if (kept.isNotEmpty) out[date] = kept;
    });
    return out;
  },
);

/// 해당 날짜에 **저장된** 일정만 (저장 순서 = 수정/삭제 인덱스 기준).
final dateEventsProvider = Provider.family<List<PersonalEvent>, DateTime>(
  (ref, date) {
    ref.watch(eventRefreshProvider);
    final all = ref.watch(personalEventDataSourceProvider).getEvents(date);
    final hidden = ref.watch(hiddenShiftDatesProvider);
    final key = DateTime(date.year, date.month, date.day);
    if (!hidden.contains(key)) return all;
    final shiftTitles = ref.watch(shiftEventTitlesProvider);
    return all.where((e) => !_isShiftEvent(e, shiftTitles)).toList();
  },
);

/// 해당 날짜에 **표시돼야 하는** 일정 — 이 날 시작하는 일정 + 이전에 시작해
/// 이 날까지 이어지는 다일 일정. 각 항목이 저장 위치(시작일 + 인덱스)를 함께
/// 담고 있어 continuation 항목도 수정/삭제가 가능하다.
///
/// [monthlyEventsProvider]와 동일하게 "팀 근무 숨기기" 시 team-import 근무를 제외.
final dateEventOccurrencesProvider =
    Provider.family<List<PersonalEventOccurrence>, DateTime>(
  (ref, date) {
    ref.watch(eventRefreshProvider);
    final all = ref.watch(personalEventDataSourceProvider).getOccurrences(date);
    final hidden = ref.watch(hiddenShiftDatesProvider);
    final hideTeamShifts = ref.watch(hideTeamShiftsInPersonalProvider);
    final key = DateTime(date.year, date.month, date.day);
    if (hidden.contains(key)) {
      final shiftTitles = ref.watch(shiftEventTitlesProvider);
      return all.where((o) => !_isShiftEvent(o.event, shiftTitles)).toList();
    }
    if (!hideTeamShifts) return all;
    return all.where((o) => !_isImportWork(o.event)).toList();
  },
);

/// 홈 카드·테마 등 개인 캘린더 밖에서 쓰는 표시용 목록.
/// 다일 일정을 걸쳐 있는 날에도 포함하되, 저장 위치는 노출하지 않는다.
/// ("팀 근무 숨기기"는 개인 캘린더 화면 설정이므로 여기서는 적용하지 않는다)
final dateEventsIncludingSpansProvider =
    Provider.family<List<PersonalEvent>, DateTime>(
  (ref, date) {
    ref.watch(eventRefreshProvider);
    final all = ref
        .watch(personalEventDataSourceProvider)
        .getEventsIncludingSpans(date);
    final hidden = ref.watch(hiddenShiftDatesProvider);
    final key = DateTime(date.year, date.month, date.day);
    if (!hidden.contains(key)) return all;
    final shiftTitles = ref.watch(shiftEventTitlesProvider);
    return all.where((e) => !_isShiftEvent(e, shiftTitles)).toList();
  },
);
