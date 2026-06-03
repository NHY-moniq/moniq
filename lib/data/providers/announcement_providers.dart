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

// ──────────────────────────────────────────────
// 내 팀 공지사항 무한 스크롤 상태
// ──────────────────────────────────────────────

/// 무한 스크롤 상태 모델.
class AnnouncementListState {
  const AnnouncementListState({
    this.items = const [],
    this.hasMore = true,
    this.page = 0,
    this.isLoadingMore = false,
  });

  final List<AnnouncementWithTeam> items;
  final bool hasMore;

  /// 다음에 불러올 페이지 번호 (0-based).
  final int page;

  /// 추가 페이지 로딩 중 여부.
  final bool isLoadingMore;

  AnnouncementListState copyWith({
    List<AnnouncementWithTeam>? items,
    bool? hasMore,
    int? page,
    bool? isLoadingMore,
  }) =>
      AnnouncementListState(
        items: items ?? this.items,
        hasMore: hasMore ?? this.hasMore,
        page: page ?? this.page,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      );
}

const _kPageSize = 20;

/// 홈 화면 내 팀 공지사항 무한 스크롤 Notifier.
///
/// - [build]: 첫 페이지(page=0) 로드.
/// - [loadMore]: 다음 페이지 누적.
/// - [refresh]: 전체 초기화 후 첫 페이지 재로드 (pull-to-refresh).
/// - [setTeamFilter]: 팀 필터 변경 후 리셋.
class MyAnnouncementsNotifier
    extends AutoDisposeAsyncNotifier<AnnouncementListState> {
  @override
  Future<AnnouncementListState> build() async {
    // 로그인/로그아웃 시 자동 재조회
    ref.watch(authStateChangesProvider);
    final userId =
        ref.watch(supabaseClientProvider).auth.currentUser?.id;
    if (userId == null) return const AnnouncementListState(hasMore: false);

    final teamId = ref.watch(selectedAnnouncementTeamFilterProvider);
    return _fetchPage(page: 0, teamId: teamId);
  }

  Future<AnnouncementListState> _fetchPage({
    required int page,
    String? teamId,
    List<AnnouncementWithTeam> existing = const [],
  }) async {
    final repo = ref.read(announcementRepositoryProvider);
    final fetched = await repo.getMyTeamsAnnouncements(
      limit: _kPageSize,
      offset: page * _kPageSize,
      teamId: teamId,
    );
    return AnnouncementListState(
      items: [...existing, ...fetched],
      hasMore: fetched.length == _kPageSize,
      page: page + 1,
      isLoadingMore: false,
    );
  }

  /// 다음 페이지 로드. 이미 로딩 중이거나 더 이상 데이터 없으면 노-옵.
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null) return;
    if (!current.hasMore) return;
    if (current.isLoadingMore) return;

    // isLoadingMore 플래그만 먼저 업데이트 (스피너 표시)
    state = AsyncData(current.copyWith(isLoadingMore: true));

    final teamId = ref.read(selectedAnnouncementTeamFilterProvider);
    try {
      final next = await _fetchPage(
        page: current.page,
        teamId: teamId,
        existing: current.items,
      );
      state = AsyncData(next);
    } catch (e, st) {
      // 추가 로딩 실패 시 isLoadingMore만 해제, 기존 목록 유지
      state = AsyncData(current.copyWith(isLoadingMore: false));
      // 에러 로그만 남기고 상위에 전파하지 않음
      assert(() {
        // ignore: avoid_print
        print('loadMore error: $e\n$st');
        return true;
      }());
    }
  }

  /// Pull-to-refresh: 전체 초기화 후 첫 페이지 재로드.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final teamId = ref.read(selectedAnnouncementTeamFilterProvider);
      return _fetchPage(page: 0, teamId: teamId);
    });
  }
}

/// 홈탭 공지사항 팀 필터 (null = 전체)
final selectedAnnouncementTeamFilterProvider =
    StateProvider<String?>((_) => null);

/// 무한 스크롤 provider — 팀 필터 변경 시 build()가 자동 재실행.
final myAnnouncementsProvider =
    AutoDisposeAsyncNotifierProvider<MyAnnouncementsNotifier,
        AnnouncementListState>(
  MyAnnouncementsNotifier.new,
);

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
