import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/datasources/personal_event_local_data_source.dart';
import 'package:moniq/data/datasources/personal_note_local_data_source.dart';
import 'package:moniq/data/datasources/personal_shift_type_local_data_source.dart';
import 'package:moniq/data/providers/auth_providers.dart';
import 'package:moniq/data/providers/settings_providers.dart';

// ── Providers ──

/// 이벤트/노트 변경 시 증가시켜 모든 관련 provider를 갱신하는 트리거
final eventRefreshProvider = StateProvider<int>((ref) => 0);

/// 날짜별 접기/펼치기 상태 (기본 펼침)
final dateExpandedProvider =
    StateProvider.family<bool, DateTime>((ref, date) => true);

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
