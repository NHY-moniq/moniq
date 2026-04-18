import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/datasources/announcement_remote_data_source.dart';
import 'package:moniq/data/models/announcement_model.dart';
import 'package:moniq/data/providers/supabase_providers.dart';
import 'package:moniq/data/repositories/announcement_repository.dart';

final announcementRemoteDataSourceProvider =
    Provider<AnnouncementRemoteDataSource>(
  (ref) => AnnouncementRemoteDataSource(
    client: ref.watch(supabaseClientProvider),
  ),
);

final announcementRepositoryProvider = Provider<AnnouncementRepository>(
  (ref) => AnnouncementRepository(
    dataSource: ref.watch(announcementRemoteDataSourceProvider),
  ),
);

/// 내 팀 공지사항 (홈 화면용, 팀 이름 포함)
final myAnnouncementsProvider =
    FutureProvider<List<AnnouncementWithTeam>>((ref) async {
  // 로그인/로그아웃 시 캐시 폐기하고 재조회
  ref.watch(authStateChangesProvider);
  final userId =
      ref.watch(supabaseClientProvider).auth.currentUser?.id;
  if (userId == null) return [];
  final repo = ref.watch(announcementRepositoryProvider);
  return repo.getMyTeamsAnnouncements();
});

/// 특정 팀 공지사항
final teamAnnouncementsProvider =
    FutureProvider.family<List<AnnouncementModel>, String>((ref, teamId) async {
  ref.watch(authStateChangesProvider);
  final userId =
      ref.watch(supabaseClientProvider).auth.currentUser?.id;
  if (userId == null) return [];
  final repo = ref.watch(announcementRepositoryProvider);
  return repo.getByTeam(teamId);
});

/// 특정 공지의 댓글
final announcementCommentsProvider = FutureProvider.family<
    List<AnnouncementCommentWithUser>, String>((ref, announcementId) async {
  final repo = ref.watch(announcementRepositoryProvider);
  return repo.getComments(announcementId);
});
