import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/datasources/notification_service.dart';
import 'package:moniq/data/datasources/push_service.dart';
import 'package:moniq/data/models/wanted_request_model.dart';
import 'package:moniq/data/providers/team_providers.dart';
import 'package:moniq/data/providers/wanted_providers.dart';

part 'wanted_viewmodel.freezed.dart';

// ─── 관리자: 수집 요청 생성/관리 ───

@freezed
class WantedAdminState with _$WantedAdminState {
  const factory WantedAdminState({
    required String teamId,
    WantedRequestModel? activeRequest,
    @Default([]) List<WantedEntryWithUser> allEntries,
    @Default(false) bool isCreating,
    @Default(false) bool isLoading,
    String? error,
  }) = _WantedAdminState;
}

final wantedAdminViewModelProvider = AsyncNotifierProvider.family<
    WantedAdminViewModel, WantedAdminState, String>(
  WantedAdminViewModel.new,
);

class WantedAdminViewModel
    extends FamilyAsyncNotifier<WantedAdminState, String> {
  @override
  Future<WantedAdminState> build(String teamId) async {
    final repo = ref.watch(wantedRepositoryProvider);
    final activeRequest = await repo.getActiveWantedRequest(teamId);

    List<WantedEntryWithUser> entries = [];
    if (activeRequest != null) {
      entries = await repo.getAllEntries(activeRequest.id);
    }

    return WantedAdminState(
      teamId: teamId,
      activeRequest: activeRequest,
      allEntries: entries,
    );
  }

  /// 수집 요청 생성 + 로컬 푸시 알림 발송
  Future<bool> createWantedRequest({
    required DateTime periodStart,
    required DateTime periodEnd,
    DateTime? deadline,
    required String teamName,
    String wantedType = 'day_off',
  }) async {
    final current = state.valueOrNull;
    if (current == null) return false;

    state = AsyncData(current.copyWith(isCreating: true, error: null));

    try {
      final repo = ref.read(wantedRepositoryProvider);
      final request = await repo.createWantedRequest(
        teamId: current.teamId,
        periodStart: periodStart,
        periodEnd: periodEnd,
        deadline: deadline,
        wantedType: wantedType,
      );

      // 타입별 메시지 (day_off / preferred_shift / night_dedicated)
      final startStr =
          '${periodStart.month}/${periodStart.day}';
      final endStr =
          '${periodEnd.month}/${periodEnd.day}';
      final typeLabel = _wantedTypeLabel(wantedType);
      final body =
          '$startStr~$endStr 기간의 $typeLabel을(를) 입력해주세요.';

      await NotificationService.instance.showScheduleChangeNotification(
        teamName: teamName,
        message: body,
      );
      // 팀원 전체에게 FCM 푸시 (관리자 본인 제외)
      await PushService.instance.sendToTeam(
        teamId: current.teamId,
        title: '[$teamName] $typeLabel 수집 시작',
        body: body,
        data: {
          'type': 'wanted_open',
          'team_id': current.teamId,
          'wanted_type': wantedType,
        },
      );

      state = AsyncData(current.copyWith(
        isCreating: false,
        activeRequest: request,
      ));
      // 멤버 입력 화면(같은 팀)도 최신 활성 요청 반영하도록 invalidate
      ref.invalidate(wantedMemberViewModelProvider(current.teamId));
      return true;
    } catch (e) {
      state = AsyncData(current.copyWith(
        isCreating: false,
        error: '요청 생성 중 오류: $e',
      ));
      return false;
    }
  }

  /// 수집 마감
  Future<void> closeRequest() async {
    final current = state.valueOrNull;
    if (current == null || current.activeRequest == null) return;

    final closingRequest = current.activeRequest!;

    try {
      final repo = ref.read(wantedRepositoryProvider);
      await repo.closeWantedRequest(closingRequest.id);
      state = AsyncData(current.copyWith(activeRequest: null, allEntries: []));

      // 팀원 전체에게 종료 알림 (관리자 본인 제외)
      try {
        final team = await ref
            .read(teamRepositoryProvider)
            .getTeamById(current.teamId);
        final typeLabel = _wantedTypeLabel(closingRequest.wantedType);
        await PushService.instance.sendToTeam(
          teamId: current.teamId,
          title: '[${team.name}] $typeLabel 수집 종료',
          body: '$typeLabel 수집이 마감되었습니다.',
          data: {
            'type': 'wanted_close',
            'team_id': current.teamId,
            'wanted_type': closingRequest.wantedType,
          },
        );
      } catch (_) {}
    } catch (_) {}
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}

/// wanted_type → 한글 라벨
String _wantedTypeLabel(String wantedType) {
  switch (wantedType) {
    case 'preferred_shift':
      return '희망 근무';
    case 'night_dedicated':
      return '나이트 전담';
    case 'day_off':
    default:
      return '희망 휴무';
  }
}

// ─── 팀원: 희망 휴무일 입력 ───

@freezed
class WantedMemberState with _$WantedMemberState {
  const factory WantedMemberState({
    required String teamId,
    WantedRequestModel? activeRequest,
    @Default([]) List<WantedRequestModel> activeRequests,
    @Default([]) List<WantedEntryModel> myEntries,
    @Default(false) bool isSubmitting,
    String? error,
  }) = _WantedMemberState;
}

final wantedMemberViewModelProvider = AsyncNotifierProvider.family<
    WantedMemberViewModel, WantedMemberState, String>(
  WantedMemberViewModel.new,
);

class WantedMemberViewModel
    extends FamilyAsyncNotifier<WantedMemberState, String> {
  @override
  Future<WantedMemberState> build(String teamId) async {
    final repo = ref.watch(wantedRepositoryProvider);
    final activeRequests = await repo.getActiveWantedRequests(teamId);
    // 타입 순서 정렬: day_off → preferred_shift → night_dedicated
    const order = ['day_off', 'preferred_shift', 'night_dedicated'];
    activeRequests.sort((a, b) =>
        order.indexOf(a.wantedType).compareTo(order.indexOf(b.wantedType)));

    final activeRequest =
        activeRequests.isEmpty ? null : activeRequests.first;

    List<WantedEntryModel> myEntries = [];
    if (activeRequest != null) {
      myEntries = await repo.getMyEntries(activeRequest.id);
    }

    return WantedMemberState(
      teamId: teamId,
      activeRequest: activeRequest,
      activeRequests: activeRequests,
      myEntries: myEntries,
    );
  }

  /// 활성 요청 타입 전환 — 해당 타입의 내 엔트리를 로드
  Future<void> selectType(String wantedType) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final target = current.activeRequests
        .where((r) => r.wantedType == wantedType)
        .cast<WantedRequestModel?>()
        .firstWhere((_) => true, orElse: () => null);
    if (target == null) return;

    state = AsyncData(current.copyWith(
      activeRequest: target,
      myEntries: [],
      error: null,
    ));

    try {
      final repo = ref.read(wantedRepositoryProvider);
      final my = await repo.getMyEntries(target.id);
      state = AsyncData(state.value!.copyWith(myEntries: my));
    } catch (e) {
      state = AsyncData(state.value!.copyWith(error: '로드 중 오류: $e'));
    }
  }

  /// 희망 휴무일 추가
  Future<bool> addWantedDate({
    required DateTime date,
    String? reason,
  }) async {
    final current = state.valueOrNull;
    if (current == null || current.activeRequest == null) return false;

    state = AsyncData(current.copyWith(isSubmitting: true, error: null));

    try {
      final repo = ref.read(wantedRepositoryProvider);
      final entry = await repo.addWantedEntry(
        wantedRequestId: current.activeRequest!.id,
        teamId: current.teamId,
        wantedDate: date,
        reason: reason,
      );

      state = AsyncData(current.copyWith(
        isSubmitting: false,
        myEntries: [...current.myEntries, entry],
      ));
      return true;
    } catch (e) {
      state = AsyncData(current.copyWith(
        isSubmitting: false,
        error: '저장 중 오류: $e',
      ));
      return false;
    }
  }

  /// 희망 휴무일 복수 추가 (날짜별 우선순위)
  Future<bool> addWantedDates({
    required Map<DateTime, int> datesWithPriority,
    String? reason,
    String? shiftTypeId,
  }) async {
    final current = state.valueOrNull;
    if (current == null || current.activeRequest == null) return false;
    if (datesWithPriority.isEmpty) return false;

    state = AsyncData(current.copyWith(isSubmitting: true, error: null));

    try {
      final repo = ref.read(wantedRepositoryProvider);
      final newEntries = <WantedEntryModel>[];

      for (final entry in datesWithPriority.entries) {
        final date = entry.key;
        final priority = entry.value;
        // 이미 등록된 날짜는 스킵
        final alreadyExists = current.myEntries.any((e) =>
            e.wantedDate.year == date.year &&
            e.wantedDate.month == date.month &&
            e.wantedDate.day == date.day);
        if (alreadyExists) continue;

        final added = await repo.addWantedEntry(
          wantedRequestId: current.activeRequest!.id,
          teamId: current.teamId,
          wantedDate: date,
          reason: reason,
          priority: priority,
          shiftTypeId: shiftTypeId,
        );
        newEntries.add(added);
      }

      state = AsyncData(current.copyWith(
        isSubmitting: false,
        myEntries: [...current.myEntries, ...newEntries],
      ));
      return true;
    } catch (e) {
      state = AsyncData(current.copyWith(
        isSubmitting: false,
        error: '저장 중 오류: $e',
      ));
      return false;
    }
  }

  /// 희망 휴무일 삭제
  Future<bool> removeEntry(String entryId) async {
    final current = state.valueOrNull;
    if (current == null) return false;

    try {
      final repo = ref.read(wantedRepositoryProvider);
      await repo.deleteWantedEntry(entryId);
      state = AsyncData(current.copyWith(
        myEntries: current.myEntries.where((e) => e.id != entryId).toList(),
        error: null,
      ));
      return true;
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      state = AsyncData(current.copyWith(error: msg));
      return false;
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}
