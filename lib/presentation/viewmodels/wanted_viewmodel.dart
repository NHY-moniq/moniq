import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/datasources/notification_service.dart';
import 'package:moniq/data/models/wanted_request_model.dart';
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

  /// 희망 휴무 수집 요청 생성 + 로컬 푸시 알림 발송
  Future<bool> createWantedRequest({
    required DateTime periodStart,
    required DateTime periodEnd,
    DateTime? deadline,
    required String teamName,
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
      );

      // 로컬 푸시 알림 발송
      final startStr =
          '${periodStart.month}/${periodStart.day}';
      final endStr =
          '${periodEnd.month}/${periodEnd.day}';

      await NotificationService.instance.showScheduleChangeNotification(
        teamName: teamName,
        message: '$startStr~$endStr 기간의 희망 휴무일을 입력해주세요.',
      );

      state = AsyncData(current.copyWith(
        isCreating: false,
        activeRequest: request,
      ));
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

    try {
      final repo = ref.read(wantedRepositoryProvider);
      await repo.closeWantedRequest(current.activeRequest!.id);
      state = AsyncData(current.copyWith(activeRequest: null, allEntries: []));
    } catch (_) {}
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
    final activeRequest = await repo.getActiveWantedRequest(teamId);

    List<WantedEntryModel> myEntries = [];
    if (activeRequest != null) {
      myEntries = await repo.getMyEntries(activeRequest.id);
    }

    return WantedMemberState(
      teamId: teamId,
      activeRequest: activeRequest,
      myEntries: myEntries,
    );
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
