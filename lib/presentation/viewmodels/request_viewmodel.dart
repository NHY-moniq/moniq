import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/datasources/notification_service.dart';
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
    await _notifyStatusChange(requestId, '승인');
    ref.invalidateSelf();
  }

  Future<void> rejectRequest(String requestId) async {
    final repo = ref.read(requestRepositoryProvider);
    await repo.updateRequestStatus(requestId, 'rejected');
    await _notifyStatusChange(requestId, '거절');
    ref.invalidateSelf();
  }

  Future<void> cancelRequest(String requestId) async {
    final repo = ref.read(requestRepositoryProvider);
    await repo.cancelRequest(requestId);
    ref.invalidateSelf();
  }

  /// 요청 상태 변경 시 알림 발송. 현재는 로컬 알림 (TODO: Edge Function 푸시).
  Future<void> _notifyStatusChange(String requestId, String statusKo) async {
    try {
      final current = state.valueOrNull;
      final req = current?.requests.firstWhere(
        (r) => r.id == requestId,
        orElse: () => current.requests.first,
      );
      final typeKo = _changeTypeLabel(req?.changeType);
      await NotificationService.instance.showScheduleChangeNotification(
        teamName: '근무 요청',
        message: '$typeKo 요청이 $statusKo되었습니다',
      );
    } catch (_) {
      // 알림 실패는 무시
    }
  }

  String _changeTypeLabel(String? type) {
    switch (type) {
      case 'swap':
        return '근무 교환';
      case 'shift_change':
        return '근무 변경';
      case 'day_off':
        return '휴무';
      case 'schedule_change':
        return '스케줄 변경';
      default:
        return '근무';
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}
