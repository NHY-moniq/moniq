import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/datasources/notification_service.dart';
import 'package:moniq/data/datasources/push_service.dart';
import 'package:moniq/data/models/request_model.dart';
import 'package:moniq/data/models/shift_type_model.dart';
import 'package:moniq/data/providers/request_providers.dart';
import 'package:moniq/data/providers/shift_providers.dart';
import 'package:moniq/data/providers/supabase_providers.dart';
import 'package:moniq/data/providers/team_providers.dart';

part 'request_viewmodel.freezed.dart';

/// 요청 카드/시트에서 "근무 변경 전/후"를 한눈에 표시하기 위한 데이터.
/// targetBeforeShiftType은 swap일 때만 존재.
class RequestChangePreview {
  RequestChangePreview({
    this.requesterBeforeShiftType,
    this.requesterAfterShiftType,
    this.targetBeforeShiftType,
    this.targetAfterShiftType,
    this.targetName,
  });

  final ShiftTypeModel? requesterBeforeShiftType;
  final ShiftTypeModel? requesterAfterShiftType; // null = OFF
  final ShiftTypeModel? targetBeforeShiftType;
  final ShiftTypeModel? targetAfterShiftType; // null = OFF
  final String? targetName;
}

/// 단일 요청의 before/after 정보를 조회.
/// Key: '{teamId}|{requestId}'
final requestChangePreviewProvider = FutureProvider.autoDispose
    .family<RequestChangePreview, String>((ref, key) async {
  final sep = key.indexOf('|');
  if (sep < 0) return RequestChangePreview();
  final teamId = key.substring(0, sep);
  final requestId = key.substring(sep + 1);

  final state = ref.watch(requestListViewModelProvider(teamId)).valueOrNull;
  if (state == null) return RequestChangePreview();

  final req = state.requests.cast<RequestModel?>().firstWhere(
        (r) => r?.id == requestId,
        orElse: () => null,
      );
  if (req == null || req.requestedDate == null) {
    return RequestChangePreview();
  }

  final shiftRepo = ref.watch(shiftRepositoryProvider);
  final shiftTypes = await shiftRepo.getAllShiftTypes(teamId);
  final typeMap = {for (final t in shiftTypes) t.id: t};

  final shiftsOnDate = await shiftRepo.getShiftsOnDate(
    teamId: teamId,
    date: req.requestedDate!,
  );

  ShiftTypeModel? typeOf(String userId) {
    final s = shiftsOnDate.cast<dynamic>().firstWhere(
          (e) => e?.userId == userId,
          orElse: () => null,
        );
    return s == null ? null : typeMap[s.shiftTypeId];
  }

  final requesterBefore = typeOf(req.requesterUserId);
  final targetBefore =
      req.targetUserId != null ? typeOf(req.targetUserId!) : null;

  final ShiftTypeModel? requesterAfter;
  final ShiftTypeModel? targetAfter;

  switch (req.changeType) {
    case 'swap':
      // 멤버 간 근무 변경(단방향): 신청자가 다른 멤버의 근무 변경을 요청.
      // 신청자 본인 근무는 변경되지 않으며, 대상자만 requestedShiftType로 변경된다.
      requesterAfter = requesterBefore;
      targetAfter = req.requestedShiftTypeId != null
          ? typeMap[req.requestedShiftTypeId!]
          : null;
      break;
    case 'day_off':
      requesterAfter = null; // OFF
      targetAfter = null;
      break;
    case 'shift_change':
      requesterAfter = req.requestedShiftTypeId != null
          ? typeMap[req.requestedShiftTypeId!]
          : null;
      targetAfter = null;
      break;
    default:
      requesterAfter = null;
      targetAfter = null;
  }

  return RequestChangePreview(
    requesterBeforeShiftType: requesterBefore,
    requesterAfterShiftType: requesterAfter,
    targetBeforeShiftType: targetBefore,
    targetAfterShiftType: targetAfter,
    targetName:
        req.targetUserId != null ? state.userNames[req.targetUserId!] : null,
  );
});

@freezed
class RequestListState with _$RequestListState {
  const factory RequestListState({
    required String teamId,
    required List<RequestModel> requests,
    @Default('pending') String filter, // pending, approved, rejected, all
    @Default(false) bool isAdmin,
    @Default({}) Map<String, String> userNames, // userId → displayName
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

    // 관리자 여부 + 멤버 이름 맵 (요청 카드 표시용)
    bool isAdmin = false;
    String? userId;
    final userNames = <String, String>{};
    try {
      final authState = ref.watch(authStateChangesProvider);
      userId = authState.whenOrNull(data: (auth) => auth.session?.user.id);
      if (userId != null) {
        final teamRepo = ref.watch(teamRepositoryProvider);
        final membersWithUsers =
            await teamRepo.getTeamMembersWithUsers(teamId);
        for (final mu in membersWithUsers) {
          final name = mu.user.displayName;
          if (name != null && name.isNotEmpty) {
            userNames[mu.member.userId] = name;
          }
        }
        isAdmin = membersWithUsers.any(
            (mu) => mu.member.userId == userId &&
                mu.member.role == 'admin' &&
                !mu.member.isDeleted);
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
      userNames: userNames,
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
    // 승인 후 shifts에 자동 반영 (day_off / shift_change / swap)
    // 자동 적용 실패는 침묵 — 관리자가 수동으로 처리 가능
    try {
      await repo.applyRequest(requestId);
    } catch (_) {}
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

  /// 일괄 승인 — 한 건이라도 실패해도 나머지는 진행하고 마지막에 1회 invalidate.
  Future<void> approveRequests(List<String> requestIds) async {
    final repo = ref.read(requestRepositoryProvider);
    for (final id in requestIds) {
      try {
        await repo.updateRequestStatus(id, 'approved');
        try {
          await repo.applyRequest(id);
        } catch (_) {}
        await _notifyStatusChange(id, '승인');
      } catch (_) {}
    }
    ref.invalidateSelf();
  }

  Future<void> rejectRequests(List<String> requestIds) async {
    final repo = ref.read(requestRepositoryProvider);
    for (final id in requestIds) {
      try {
        await repo.updateRequestStatus(id, 'rejected');
        await _notifyStatusChange(id, '거절');
      } catch (_) {}
    }
    ref.invalidateSelf();
  }

  Future<void> cancelRequests(List<String> requestIds) async {
    final repo = ref.read(requestRepositoryProvider);
    for (final id in requestIds) {
      try {
        await repo.cancelRequest(id);
      } catch (_) {}
    }
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
        data: {
          'type': 'request',
          'team_id': current.teamId,
          'request_id': requestId,
        },
      );
    }
  }

  String _changeTypeLabel(String? type) {
    switch (type) {
      case 'swap':
        return '멤버 간 근무 변경';
      case 'shift_change':
        return '내 근무 변경';
      case 'day_off':
        return '내 근무 변경(휴무)';
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
