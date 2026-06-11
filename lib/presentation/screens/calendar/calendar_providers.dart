import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/datasources/personal_event_local_data_source.dart';
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

final monthlyEventsProvider =
    Provider.family<Map<DateTime, List<PersonalEvent>>, DateTime>(
  (ref, month) {
    ref.watch(eventRefreshProvider);
    return ref.watch(personalEventDataSourceProvider).getMonthlyEvents(month);
  },
);

final dateEventsProvider = Provider.family<List<PersonalEvent>, DateTime>(
  (ref, date) {
    ref.watch(eventRefreshProvider);
    return ref.watch(personalEventDataSourceProvider).getEvents(date);
  },
);
