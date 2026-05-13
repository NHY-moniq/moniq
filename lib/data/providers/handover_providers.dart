import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/datasources/handover_remote_data_source.dart';
import 'package:moniq/data/models/handover_model.dart';
import 'package:moniq/data/providers/supabase_providers.dart';
import 'package:moniq/data/repositories/handover_repository.dart';
import 'package:moniq/presentation/viewmodels/home_viewmodel.dart';
import 'package:moniq/presentation/viewmodels/team_calendar_viewmodel.dart';

final handoverRemoteDataSourceProvider =
    Provider<HandoverRemoteDataSource>((ref) {
  return HandoverRemoteDataSource(client: ref.watch(supabaseClientProvider));
});

final handoverRepositoryProvider = Provider<HandoverRepository>((ref) {
  return HandoverRepository(
    dataSource: ref.watch(handoverRemoteDataSourceProvider),
  );
});

/// 홈 카드용 — 오늘 우리 팀의 인계 메모.
/// teamId는 onShiftTeamData의 결정 로직과 동일 (본인 shift 팀 우선, 없으면 favorite)
final todayHandoversProvider =
    FutureProvider.autoDispose<List<HandoverWithMeta>>((ref) async {
  final homeAsync = ref.watch(homeViewModelProvider);
  final state = homeAsync.valueOrNull;
  if (state == null) return const [];

  final now = DateTime.now();
  final todayKey = DateTime(now.year, now.month, now.day);
  final todayShifts = state.monthlyShifts[todayKey];

  String? teamId;
  if (todayShifts != null && todayShifts.isNotEmpty) {
    teamId = todayShifts.first.shift.teamId;
  } else {
    final fav = await ref.watch(favoriteTeamProvider.future);
    teamId = fav?.id;
  }
  if (teamId == null) return const [];

  final repo = ref.watch(handoverRepositoryProvider);
  return repo.getTeamDayHandovers(teamId: teamId, date: todayKey);
});
