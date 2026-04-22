import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/datasources/notification_service.dart';
import 'package:moniq/data/datasources/push_service.dart';
import 'package:moniq/data/models/wanted_request_model.dart';
import 'package:moniq/data/providers/shift_providers.dart';
import 'package:moniq/data/providers/team_providers.dart';
import 'package:moniq/data/providers/wanted_providers.dart';

part 'wanted_viewmodel.freezed.dart';

// ─── 관리자: 수집 요청 생성/관리 ───

@freezed
class WantedAdminState with _$WantedAdminState {
  const factory WantedAdminState({
    required String teamId,
    WantedRequestModel? activeRequest,
    @Default([]) List<WantedRequestModel> activeRequests,
    @Default([]) List<WantedEntryWithUser> allEntries,
    // 마감된 최근 수집 (활성 없을 때 표시)
    @Default([]) List<WantedRequestModel> lastClosedRequests,
    WantedRequestModel? lastClosedRequest,
    @Default([]) List<WantedEntryWithUser> lastClosedEntries,
    @Default(false) bool isCreating,
    @Default(false) bool isLoading,
    String? error,
  }) = _WantedAdminState;
}

final wantedAdminViewModelProvider =
    AsyncNotifierProvider.family<
      WantedAdminViewModel,
      WantedAdminState,
      String
    >(WantedAdminViewModel.new);

class WantedAdminViewModel
    extends FamilyAsyncNotifier<WantedAdminState, String> {
  @override
  Future<WantedAdminState> build(String teamId) async {
    final repo = ref.watch(wantedRepositoryProvider);
    final all = await repo.getActiveWantedRequests(teamId);

    // 타입별 중복 제거 (최신순 정렬이므로 첫 번째가 최신)
    final seen = <String>{};
    final unique = <WantedRequestModel>[];
    for (final r in all) {
      if (seen.add(r.wantedType)) unique.add(r);
    }
    // 타입 순서 정렬: day_off → preferred_shift → night_dedicated
    const order = ['day_off', 'preferred_shift', 'night_dedicated'];
    unique.sort(
      (a, b) =>
          order.indexOf(a.wantedType).compareTo(order.indexOf(b.wantedType)),
    );

    final nonNightRequests = unique
        .where((r) => r.wantedType != 'night_dedicated')
        .toList();
    final nightRequest = unique
        .where((r) => r.wantedType == 'night_dedicated')
        .cast<WantedRequestModel?>()
        .firstWhere((_) => true, orElse: () => null);
    final activeRequest = unique.isEmpty
        ? null
        : (nonNightRequests.isNotEmpty ? nonNightRequests.first : nightRequest);

    // 비나이트 요청 전체 병합; 비나이트가 없으면 나이트 엔트리 로드
    List<WantedEntryWithUser> entries = [];
    for (final req in nonNightRequests) {
      entries.addAll(await repo.getAllEntries(req.id));
    }
    if (nonNightRequests.isEmpty && nightRequest != null) {
      entries = await repo.getAllEntries(nightRequest.id);
    }

    // 활성 수집 없으면 마감된 최근 수집 로드
    List<WantedRequestModel> lastClosedRequests = [];
    WantedRequestModel? lastClosedRequest;
    List<WantedEntryWithUser> lastClosedEntries = [];
    if (unique.isEmpty) {
      try {
        final allRequests = await repo.getWantedRequests(teamId);
        final closedSeen = <String>{};
        for (final r in allRequests.where((r) => r.status == 'closed')) {
          if (closedSeen.add(r.wantedType)) lastClosedRequests.add(r);
          if (closedSeen.length == 3) break;
        }
        const order = ['day_off', 'preferred_shift', 'night_dedicated'];
        lastClosedRequests.sort(
          (a, b) => order
              .indexOf(a.wantedType)
              .compareTo(order.indexOf(b.wantedType)),
        );
        final nonNightClosedRequests = lastClosedRequests
            .where((r) => r.wantedType != 'night_dedicated')
            .toList();
        final closedNightRequest = lastClosedRequests
            .where((r) => r.wantedType == 'night_dedicated')
            .cast<WantedRequestModel?>()
            .firstWhere((_) => true, orElse: () => null);

        if (nonNightClosedRequests.isNotEmpty) {
          // 비나이트(휴무/희망근무)는 마감 후에도 하나의 "원티드"로 병합 표시
          lastClosedRequest = nonNightClosedRequests.first;
          for (final req in nonNightClosedRequests) {
            lastClosedEntries.addAll(await repo.getAllEntries(req.id));
          }
        } else if (closedNightRequest != null) {
          lastClosedRequest = closedNightRequest;
          lastClosedEntries = await repo.getAllEntries(closedNightRequest.id);
        }
      } catch (_) {}
    }

    return WantedAdminState(
      teamId: teamId,
      activeRequest: activeRequest,
      activeRequests: unique,
      allEntries: entries,
      lastClosedRequests: lastClosedRequests,
      lastClosedRequest: lastClosedRequest,
      lastClosedEntries: lastClosedEntries,
    );
  }

  /// 마감된 수집 타입 전환
  Future<void> selectClosedType(String wantedType) async {
    final current = state.valueOrNull;
    if (current == null) return;
    if (wantedType == 'night_dedicated') {
      final target = current.lastClosedRequests
          .where((r) => r.wantedType == 'night_dedicated')
          .cast<WantedRequestModel?>()
          .firstWhere((_) => true, orElse: () => null);
      if (target == null) return;

      state = AsyncData(
        current.copyWith(
          lastClosedRequest: target,
          lastClosedEntries: [],
          error: null,
        ),
      );

      try {
        final repo = ref.read(wantedRepositoryProvider);
        final entries = await repo.getAllEntries(target.id);
        state = AsyncData(state.value!.copyWith(lastClosedEntries: entries));
      } catch (e) {
        state = AsyncData(state.value!.copyWith(error: '로드 중 오류: $e'));
      }
    } else {
      // 비나이트(휴무/희망근무) 전체 엔트리 병합
      final nonNightRequests = current.lastClosedRequests
          .where((r) => r.wantedType != 'night_dedicated')
          .toList();
      if (nonNightRequests.isEmpty) return;
      final firstNonNight = nonNightRequests.first;

      state = AsyncData(
        current.copyWith(
          lastClosedRequest: firstNonNight,
          lastClosedEntries: [],
          error: null,
        ),
      );

      try {
        final repo = ref.read(wantedRepositoryProvider);
        final allEntries = <WantedEntryWithUser>[];
        for (final req in nonNightRequests) {
          allEntries.addAll(await repo.getAllEntries(req.id));
        }
        state = AsyncData(state.value!.copyWith(lastClosedEntries: allEntries));
      } catch (e) {
        state = AsyncData(state.value!.copyWith(error: '로드 중 오류: $e'));
      }
    }
  }

  /// 수집 타입 전환 — 나이트: 나이트 엔트리만, 그 외: 비나이트 전체 병합
  Future<void> selectType(String wantedType) async {
    final current = state.valueOrNull;
    if (current == null) return;

    if (wantedType == 'night_dedicated') {
      final target = current.activeRequests
          .where((r) => r.wantedType == 'night_dedicated')
          .cast<WantedRequestModel?>()
          .firstWhere((_) => true, orElse: () => null);
      if (target == null) return;

      state = AsyncData(
        current.copyWith(activeRequest: target, allEntries: [], error: null),
      );
      try {
        final repo = ref.read(wantedRepositoryProvider);
        final entries = await repo.getAllEntries(target.id);
        state = AsyncData(state.value!.copyWith(allEntries: entries));
      } catch (e) {
        state = AsyncData(state.value!.copyWith(error: '로드 중 오류: $e'));
      }
    } else {
      // 비나이트 요청 전체 엔트리 병합
      final nonNightRequests = current.activeRequests
          .where((r) => r.wantedType != 'night_dedicated')
          .toList();
      if (nonNightRequests.isEmpty) return;
      final firstNonNight = nonNightRequests.first;

      state = AsyncData(
        current.copyWith(
          activeRequest: firstNonNight,
          allEntries: [],
          error: null,
        ),
      );
      try {
        final repo = ref.read(wantedRepositoryProvider);
        final allEntries = <WantedEntryWithUser>[];
        for (final req in nonNightRequests) {
          allEntries.addAll(await repo.getAllEntries(req.id));
        }
        state = AsyncData(state.value!.copyWith(allEntries: allEntries));
      } catch (e) {
        state = AsyncData(state.value!.copyWith(error: '로드 중 오류: $e'));
      }
    }
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

      // 로컬 푸시 알림 발송
      final startStr = '${periodStart.month}/${periodStart.day}';
      final endStr = '${periodEnd.month}/${periodEnd.day}';

      final body = '$startStr~$endStr 기간의 원티드를 입력해주세요.';
      await NotificationService.instance.showScheduleChangeNotification(
        teamName: teamName,
        message: body,
      );
      // 팀원 전체에게 FCM 푸시 (관리자 본인 제외)
      await PushService.instance.sendToTeam(
        teamId: current.teamId,
        title: '[$teamName] 원티드 수집',
        body: body,
      );

      // 타입 순서 정렬 유지하며 추가
      const order = ['day_off', 'preferred_shift', 'night_dedicated'];
      final updatedRequests = [...current.activeRequests, request]
        ..sort(
          (a, b) => order
              .indexOf(a.wantedType)
              .compareTo(order.indexOf(b.wantedType)),
        );

      state = AsyncData(
        current.copyWith(
          isCreating: false,
          activeRequest: state.valueOrNull?.activeRequest ?? request,
          activeRequests: updatedRequests,
        ),
      );
      // 멤버 입력 화면(같은 팀)도 최신 활성 요청 반영하도록 invalidate
      ref.invalidate(wantedMemberViewModelProvider(current.teamId));
      return true;
    } catch (e) {
      state = AsyncData(
        current.copyWith(isCreating: false, error: '요청 생성 중 오류: $e'),
      );
      return false;
    }
  }

  /// 수집 마감 — DB에서 팀의 모든 collecting 요청을 가져와 전부 마감
  /// (state에 없는 과거 요청도 포함)
  Future<void> closeRequest() async {
    final current = state.valueOrNull;
    if (current == null) return;

    try {
      final repo = ref.read(wantedRepositoryProvider);
      // state가 아닌 DB 직접 조회로 누락 없이 마감
      final allActive = await repo.getActiveWantedRequests(current.teamId);
      for (final req in allActive) {
        await repo.closeWantedRequest(req.id);
      }
      // build() 재실행 → lastClosedRequests 로드
      ref.invalidateSelf();
      // 팀원 입력 화면도 즉시 마감 상태로 전환
      ref.invalidate(wantedMemberViewModelProvider(current.teamId));
    } catch (_) {}
  }

  /// 마감된 수집 재개 — lastClosedRequests를 모두 collecting으로 되돌림
  Future<bool> reopenRequests() async {
    final current = state.valueOrNull;
    if (current == null || current.lastClosedRequests.isEmpty) return false;

    try {
      final repo = ref.read(wantedRepositoryProvider);
      for (final req in current.lastClosedRequests) {
        await repo.reopenWantedRequest(req.id);
      }
      // build() 재실행 → 재개된 요청이 activeRequests로 로드됨
      ref.invalidateSelf();
      ref.invalidate(wantedMemberViewModelProvider(current.teamId));
      return true;
    } catch (e) {
      state = AsyncData(current.copyWith(error: '수집 재개 중 오류: $e'));
      return false;
    }
  }

  /// 새 수집 시작 — lastClosed 상태를 비우고 createView로 전환
  void startNewCollection() {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        lastClosedRequests: [],
        lastClosedRequest: null,
        lastClosedEntries: [],
      ),
    );
  }

  /// 나이트 전담 확정 — 선택된 userId들을 night_dedicated=true로 업데이트
  /// 비선택 userId들은 night_dedicated=false 처리
  Future<bool> confirmNightDedicated({
    required List<String> approvedUserIds,
    required List<String> allApplicantUserIds,
  }) async {
    final current = state.valueOrNull;
    if (current == null) return false;

    try {
      final teamRepo = ref.read(teamRepositoryProvider);
      for (final uid in allApplicantUserIds) {
        await teamRepo.updateMemberAttrs(
          current.teamId,
          uid,
          nightDedicated: approvedUserIds.contains(uid),
        );
      }
      ref.invalidateSelf();
      return true;
    } catch (e) {
      state = AsyncData(current.copyWith(error: '나이트 전담 확정 중 오류: $e'));
      return false;
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
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

final wantedMemberViewModelProvider =
    AsyncNotifierProvider.family<
      WantedMemberViewModel,
      WantedMemberState,
      String
    >(WantedMemberViewModel.new);

class WantedMemberViewModel
    extends FamilyAsyncNotifier<WantedMemberState, String> {
  @override
  Future<WantedMemberState> build(String teamId) async {
    final repo = ref.watch(wantedRepositoryProvider);
    final all = await repo.getActiveWantedRequests(teamId);

    // 타입별 중복 제거 (최신순이므로 첫 번째가 최신)
    final seen = <String>{};
    final activeRequests = <WantedRequestModel>[];
    for (final r in all) {
      if (seen.add(r.wantedType)) activeRequests.add(r);
    }
    // 타입 순서 정렬: day_off → preferred_shift → night_dedicated
    const order = ['day_off', 'preferred_shift', 'night_dedicated'];
    activeRequests.sort(
      (a, b) =>
          order.indexOf(a.wantedType).compareTo(order.indexOf(b.wantedType)),
    );

    final activeRequest = activeRequests.isEmpty ? null : activeRequests.first;

    List<WantedEntryModel> myEntries = [];
    for (final req in activeRequests) {
      final entries = await repo.getMyEntries(req.id);
      myEntries.addAll(entries);
    }

    return WantedMemberState(
      teamId: teamId,
      activeRequest: activeRequest,
      activeRequests: activeRequests,
      myEntries: myEntries,
    );
  }

  /// 활성 요청 타입 전환 — activeRequest만 변경, myEntries는 유지
  Future<void> selectType(String wantedType) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final target = current.activeRequests
        .where((r) => r.wantedType == wantedType)
        .cast<WantedRequestModel?>()
        .firstWhere((_) => true, orElse: () => null);
    if (target == null) return;
    state = AsyncData(current.copyWith(activeRequest: target, error: null));
  }

  /// 희망 휴무일 추가
  Future<bool> addWantedDate({required DateTime date, String? reason}) async {
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

      state = AsyncData(
        current.copyWith(
          isSubmitting: false,
          myEntries: [...current.myEntries, entry],
        ),
      );
      ref.invalidate(wantedAdminViewModelProvider(current.teamId));
      return true;
    } catch (e) {
      state = AsyncData(
        current.copyWith(isSubmitting: false, error: '저장 중 오류: $e'),
      );
      return false;
    }
  }

  /// 희망 날짜 복수 추가 (날짜별 우선순위) — 통합 피커용
  Future<bool> addWantedDates({
    required Map<DateTime, int> datesWithPriority,
    String? reason,
    String? shiftTypeId,
    String? requestId, // explicit override (for night_dedicated)
  }) async {
    final current = state.valueOrNull;
    if (current == null || current.activeRequests.isEmpty) return false;
    if (datesWithPriority.isEmpty) return false;

    // Find target request
    WantedRequestModel? targetRequest;
    if (requestId != null) {
      targetRequest = current.activeRequests
          .where((r) => r.id == requestId)
          .cast<WantedRequestModel?>()
          .firstWhere((_) => true, orElse: () => null);
    } else if (shiftTypeId != null) {
      targetRequest = current.activeRequests
          .where((r) => r.wantedType == 'preferred_shift')
          .cast<WantedRequestModel?>()
          .firstWhere((_) => true, orElse: () => null);
    } else {
      targetRequest = current.activeRequests
          .where((r) => r.wantedType == 'day_off')
          .cast<WantedRequestModel?>()
          .firstWhere((_) => true, orElse: () => null);
      // Fallback to any non-night request
      targetRequest ??= current.activeRequests
          .where((r) => r.wantedType != 'night_dedicated')
          .cast<WantedRequestModel?>()
          .firstWhere((_) => true, orElse: () => null);
    }

    if (targetRequest == null) {
      state = AsyncData(current.copyWith(error: '해당 원티드 요청이 없습니다'));
      return false;
    }

    // Validate P1/P2 limits from team rules
    try {
      final shiftRepo = ref.read(shiftRepositoryProvider);
      final rules = await shiftRepo.getShiftRules(current.teamId);
      final ruleMap = {for (final r in rules) r.ruleType: r.ruleValue};
      final p1Limit =
          ((ruleMap['wanted_p1_limit'] ?? {})['count'] as num?)?.toInt() ?? 0;
      final p2Limit =
          ((ruleMap['wanted_p2_limit'] ?? {})['count'] as num?)?.toInt() ?? 0;

      final nightRequestIds = current.activeRequests
          .where((r) => r.wantedType == 'night_dedicated')
          .map((r) => r.id)
          .toSet();

      for (final p in [1, 2]) {
        final limit = p == 1 ? p1Limit : p2Limit;
        if (limit <= 0) continue;
        final addingCount = datesWithPriority.values
            .where((v) => v == p)
            .length;
        if (addingCount == 0) continue;
        final existingCount = current.myEntries
            .where(
              (e) =>
                  e.priority == p &&
                  !nightRequestIds.contains(e.wantedRequestId),
            )
            .length;
        if (existingCount + addingCount > limit) {
          state = AsyncData(
            current.copyWith(
              error:
                  '$p순위 원티드는 최대 $limit개까지 신청할 수 있습니다 '
                  '(현재: $existingCount개)',
            ),
          );
          return false;
        }
      }
    } catch (_) {
      // 규칙 로드 실패 시 제한 없이 진행
    }

    state = AsyncData(current.copyWith(isSubmitting: true, error: null));

    try {
      final repo = ref.read(wantedRepositoryProvider);
      final newEntries = <WantedEntryModel>[];

      for (final entry in datesWithPriority.entries) {
        final date = entry.key;
        final priority = entry.value;
        // 같은 요청에 이미 등록된 날짜는 스킵
        final alreadyExists = current.myEntries.any(
          (e) =>
              e.wantedDate.year == date.year &&
              e.wantedDate.month == date.month &&
              e.wantedDate.day == date.day &&
              e.wantedRequestId == targetRequest!.id,
        );
        if (alreadyExists) continue;

        final added = await repo.addWantedEntry(
          wantedRequestId: targetRequest.id,
          teamId: current.teamId,
          wantedDate: date,
          reason: reason,
          priority: priority,
          shiftTypeId: shiftTypeId,
        );
        newEntries.add(added);
      }

      state = AsyncData(
        current.copyWith(
          isSubmitting: false,
          myEntries: [...current.myEntries, ...newEntries],
        ),
      );
      ref.invalidate(wantedAdminViewModelProvider(current.teamId));
      return true;
    } catch (e) {
      state = AsyncData(
        current.copyWith(isSubmitting: false, error: '저장 중 오류: $e'),
      );
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
      state = AsyncData(
        current.copyWith(
          myEntries: current.myEntries.where((e) => e.id != entryId).toList(),
          error: null,
        ),
      );
      ref.invalidate(wantedAdminViewModelProvider(current.teamId));
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
