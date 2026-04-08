import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/models/request_model.dart';
import 'package:moniq/data/providers/request_providers.dart';
import 'package:moniq/data/providers/shift_providers.dart';
import 'package:moniq/data/providers/supabase_providers.dart';
import 'package:moniq/data/providers/team_providers.dart';

part 'request_viewmodel.freezed.dart';

@freezed
class RequestListState with _$RequestListState {
  const factory RequestListState({
    required String teamId,
    required List<RequestModel> requests,
    @Default('all') String filter, // all, pending, approved, rejected
    @Default(false) bool isAdmin,
  }) = _RequestListState;
}

final requestListViewModelProvider = AsyncNotifierProvider.family<
    RequestListViewModel, RequestListState, String>(
  RequestListViewModel.new,
);

class RequestListViewModel
    extends FamilyAsyncNotifier<RequestListState, String> {
  @override
  Future<RequestListState> build(String teamId) async {
    final repo = ref.watch(requestRepositoryProvider);

    List<RequestModel> requests = [];
    try {
      requests = await repo.getTeamRequests(teamId);
    } catch (_) {}

    // 관리자 여부 확인
    bool isAdmin = false;
    try {
      final authState = ref.watch(authStateChangesProvider);
      final userId =
          authState.whenOrNull(data: (auth) => auth.session?.user.id);
      if (userId != null) {
        final teamRepo = ref.watch(teamRepositoryProvider);
        final members = await teamRepo.getTeamMembers(teamId);
        isAdmin = members.any(
            (m) => m.userId == userId && m.role == 'admin' && !m.isDeleted);
      }
    } catch (_) {}

    return RequestListState(
      teamId: teamId,
      requests: requests,
      isAdmin: isAdmin,
    );
  }

  void setFilter(String filter) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(filter: filter));
  }

  List<RequestModel> get filteredRequests {
    final current = state.valueOrNull;
    if (current == null) return [];
    if (current.filter == 'all') return current.requests;
    return current.requests
        .where((r) => r.status == current.filter)
        .toList();
  }

  Future<void> approveRequest(String requestId) async {
    final repo = ref.read(requestRepositoryProvider);
    await repo.updateRequestStatus(requestId, 'approved');
    ref.invalidateSelf();
  }

  Future<void> rejectRequest(String requestId) async {
    final repo = ref.read(requestRepositoryProvider);
    await repo.updateRequestStatus(requestId, 'rejected');
    ref.invalidateSelf();
  }

  Future<void> cancelRequest(String requestId) async {
    final repo = ref.read(requestRepositoryProvider);
    await repo.cancelRequest(requestId);
    ref.invalidateSelf();
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}
