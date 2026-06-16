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
import 'package:moniq/presentation/viewmodels/home_viewmodel.dart';
import 'package:moniq/presentation/viewmodels/team_calendar_viewmodel.dart';

part 'request_viewmodel.freezed.dart';

/// 요청 카드/시트에서 "근무 변경 전/후"를 한눈에 표시하기 위한 데이터.
/// targetBeforeShiftType은 swap일 때만 존재.
class RequestChangePreview {
  RequestChangePreview({
    this.requesterBeforeShiftType,
    this.requesterAfterShiftType,
    this.targetBeforeShiftType,
    this.targetAfterShiftType,
    this.requesterName,
    this.targetName,
  });

  final ShiftTypeModel? requesterBeforeShiftType;
  final ShiftTypeModel? requesterAfterShiftType; // null = OFF
  final ShiftTypeModel? targetBeforeShiftType;
  final ShiftTypeModel? targetAfterShiftType; // null = OFF
  final String? requesterName;
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
      // 멤버 간 근무 교환(양방향): 신청자 ↔ 대상자가 같은 날짜의 근무를 맞바꾼다.
      // DB의 apply_request(swap)와 동일하게, 신청자는 대상자의 근무로, 대상자는
      // 신청자의 근무로 변경된다.
      requesterAfter = targetBefore;
      targetAfter = requesterBefore;
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
    requesterName: state.userNames[req.requesterUserId],
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

  /// 승인 적용 후 팀/개인 캘린더 캐시를 무효화해 변경된 근무(스왑 등)가
  /// 캘린더에 즉시 반영되게 한다. (이전엔 요청 목록만 갱신돼 팀 캘린더는
  /// 재진입 전까지 옛 근무가 그대로 보였다)
  void _refreshCalendars() {
    final teamId = state.valueOrNull?.teamId;
    if (teamId != null) {
      ref.invalidate(teamCalendarViewModelProvider(teamId));
    }
    ref.invalidate(homeViewModelProvider);
  }

  /// 자동 적용(apply_request) 실패를 사용자용 한국어 메시지로 변환.
  /// 가장 흔한 케이스: swap 대상 중 한쪽이 해당 날짜에 근무가 없음(OFF).
  static String _applyFailureMessage(Object error) {
    final raw = error.toString();
    if (raw.contains('shift가 있어야') ||
        raw.contains('교환 가능') ||
        raw.contains('shift')) {
      return '교환하려는 날짜에 한쪽이 근무가 없어(OFF) 변경할 수 없어요.\n'
          '양쪽 모두 근무가 있는 날만 교환할 수 있어요.';
    }
    return '근무 변경을 적용하지 못했어요. 잠시 후 다시 시도해주세요.';
  }

  /// 단건 승인. 반환값으로 적용 성공 여부와 실패 메시지를 전달한다.
  /// 적용(apply_request)이 실패하면 승인 상태를 pending으로 되돌려
  /// "승인됐는데 실제로는 미반영" 상태를 막는다.
  Future<({bool ok, String? message})> approveRequest(String requestId) async {
    final repo = ref.read(requestRepositoryProvider);
    await repo.updateRequestStatus(requestId, 'approved');
    // 승인 후 shifts에 자동 반영 (day_off / shift_change / swap)
    String? failure;
    try {
      await repo.applyRequest(requestId);
    } catch (e) {
      failure = _applyFailureMessage(e);
      // 적용 실패 → 승인 취소(pending 복귀)
      try {
        await repo.updateRequestStatus(requestId, 'pending');
      } catch (_) {}
    }
    if (failure == null) {
      await _notifyStatusChange(requestId, '승인');
    }
    _refreshCalendars();
    ref.invalidateSelf();
    return (ok: failure == null, message: failure);
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

  /// 일괄 승인 — 한 건이라도 실패해도 나머지는 진행한다.
  /// 반환값: 적용 실패가 하나라도 있으면 첫 실패 메시지, 모두 성공이면 null.
  Future<String?> approveRequests(List<String> requestIds) async {
    final repo = ref.read(requestRepositoryProvider);
    String? firstFailure;
    for (final id in requestIds) {
      try {
        await repo.updateRequestStatus(id, 'approved');
        try {
          await repo.applyRequest(id);
        } catch (e) {
          firstFailure ??= _applyFailureMessage(e);
          // 적용 실패 → 승인 취소(pending 복귀)
          try {
            await repo.updateRequestStatus(id, 'pending');
          } catch (_) {}
          continue; // 알림 스킵
        }
        await _notifyStatusChange(id, '승인');
      } catch (_) {}
    }
    _refreshCalendars();
    ref.invalidateSelf();
    return firstFailure;
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
