import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/datasources/notification_service.dart';
import 'package:moniq/data/datasources/push_service.dart';
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

    // 관리자 여부 확인
    bool isAdmin = false;
    String? userId;
    try {
      final authState = ref.watch(authStateChangesProvider);
      userId = authState.whenOrNull(data: (auth) => auth.session?.user.id);
      if (userId != null) {
        final teamRepo = ref.watch(teamRepositoryProvider);
        final members = await teamRepo.getTeamMembers(teamId);
        isAdmin = members.any(
            (m) => m.userId == userId && m.role == 'admin' && !m.isDeleted);
      }
    } catch (_) {}

    // 관리자: 팀 전체 / 팀원: 본인 요청만
    List<RequestModel> requests = [];
    try {
      requests = isAdmin
          ? await repo.getTeamRequests(teamId)
          : await repo.getMyRequests(teamId);
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

  Future<void> deleteRequest(String requestId) async {
    final repo = ref.read(requestRepositoryProvider);
    await repo.deleteRequest(requestId);
    ref.invalidateSelf();
  }

  Future<void> deleteRequests(List<String> requestIds) async {
    final repo = ref.read(requestRepositoryProvider);
    await repo.deleteRequests(requestIds);
    ref.invalidateSelf();
  }

  /// 요청 상태 변경 시 신청자에게 FCM 푸시 + 관리자 본인에게 로컬 알림.
  Future<void> _notifyStatusChange(String requestId, String statusKo) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final req = current.requests
        .where((r) => r.id == requestId)
        .cast<dynamic>()
        .firstWhere((r) => true, orElse: () => null);
    if (req == null) return;
    final typeKo = _changeTypeLabel(req.changeType as String?);
    final body = '$typeKo 요청이 $statusKo되었습니다';

    // 1) 관리자 본인 화면 로컬 알림
    try {
      await NotificationService.instance.showScheduleChangeNotification(
        teamName: '근무 요청',
        message: body,
      );
    } catch (_) {}

    // 2) 신청자에게 FCM 푸시
    final requesterId = req.requesterUserId as String?;
    if (requesterId != null) {
      await PushService.instance.sendToUsers(
        userIds: [requesterId],
        title: '요청 $statusKo',
        body: body,
      );
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
