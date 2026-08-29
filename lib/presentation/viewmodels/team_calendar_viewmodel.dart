import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/datasources/home_cache_local_data_source.dart';
import 'package:moniq/data/datasources/notification_service.dart';
import 'package:moniq/data/providers/home_cache_providers.dart';
import 'package:moniq/data/datasources/push_service.dart';
import 'package:moniq/data/models/roster_entry.dart';
import 'package:moniq/data/models/shift_type_model.dart';
import 'package:moniq/data/models/shift_with_type.dart';
import 'package:moniq/data/models/team_model.dart';
import 'package:moniq/data/providers/shift_providers.dart';
import 'package:moniq/data/providers/supabase_providers.dart';
import 'package:moniq/data/providers/team_providers.dart';
import 'package:moniq/data/repositories/shift_repository.dart';
import 'package:moniq/data/repositories/team_repository.dart';
import 'package:moniq/presentation/widgets/calendar/view_mode_toggle.dart';

part 'team_calendar_viewmodel.freezed.dart';

/// AI swap-suggest 응답 후보 한 건.
class SwapSuggestion {
  const SwapSuggestion({
    required this.userId,
    required this.displayName,
    required this.date,
    required this.shiftCode,
    required this.reason,
  });

  final String userId;
  final String displayName;
  final String date; // 'YYYY-MM-DD'
  final String shiftCode;
  final String reason;
}

@freezed
class TeamCalendarState with _$TeamCalendarState {
  const factory TeamCalendarState({
    required String teamId,
    required String teamName,
    required DateTime focusedMonth,
    required DateTime selectedDate,
    // 팀 캘린더는 한 주치 근무를 훑는 용도가 대부분이라 주 단위로 시작한다.
    @Default(CalendarViewMode.week) CalendarViewMode viewMode,
    @Default({}) Map<DateTime, List<ShiftWithType>> monthlyShifts,
    @Default([]) List<RosterEntry> selectedDateRoster,
    @Default([]) List<ShiftTypeModel> shiftTypes,
  }) = _TeamCalendarState;
}

final teamCalendarViewModelProvider =
    AsyncNotifierProvider.family<
      TeamCalendarViewModel,
      TeamCalendarState,
      String
    >(TeamCalendarViewModel.new);

/// 알림 클릭 등 외부 트리거로 팀 캘린더가 특정 월에 포커스되도록
/// 다음 빌드에서 사용할 월을 임시 저장. viewmodel 빌드 후 자동으로 비워짐.
final pendingTeamCalendarFocusProvider =
    StateProvider.family<DateTime?, String>((ref, teamId) => null);

/// 팀 캘린더 탭에서 현재 보고 있는 팀 ID. null이면 즐겨찾기 팀 사용.
/// 팀 선택 바텀시트로 잠시 다른 팀을 보고 싶을 때 favorite을 바꾸지 않고
/// 이 값만 변경한다. 앱 재시작 시 초기화돼 다시 favorite으로 돌아간다.
final viewingTeamIdOverrideProvider = StateProvider<String?>((ref) => null);

/// 즐겨찾기 팀 — 로컬 캐시로 즉시 emit 후 백그라운드로 갱신(SWR).
///
/// 외부 사용처 관점의 인터페이스(`AsyncValue<TeamModel?>`, `.future`,
/// `ref.invalidate`)는 기존 FutureProvider와 동일하다.
final favoriteTeamProvider =
    AsyncNotifierProvider<FavoriteTeamNotifier, TeamModel?>(
  FavoriteTeamNotifier.new,
);

class FavoriteTeamNotifier extends AsyncNotifier<TeamModel?> {
  TeamRepository? _repository;
  HomeCacheLocalDataSource? _cache;
  Future<TeamModel?>? _inflight;

  /// **서버 기준** 최신 즐겨찾기 팀.
  ///
  /// 캐시로 먼저 emit한 경우 `future`는 캐시값으로 이미 완료돼 있으므로,
  /// "지금 보고 있는 팀이 여전히 맞는지" 확인하려면 이 future를 봐야 한다.
  /// 진행 중인 요청을 재사용하므로 왕복이 늘지 않는다.
  Future<TeamModel?> get fresh => _inflight ?? future;

  @override
  FutureOr<TeamModel?> build() {
    ref.watch(authStateChangesProvider);
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) {
      _inflight = Future.value(null);
      return null;
    }

    _repository = ref.watch(teamRepositoryProvider);
    _cache = ref.watch(homeCacheProvider);

    var disposed = false;
    ref.onDispose(() => disposed = true);

    final request = _fetch();
    _inflight = request;

    final cached = _cache?.getFavoriteTeam();
    if (cached == null) return request;

    // 캐시가 있으면 즉시 그리고(동기 반환 → 로딩 프레임 없음), 응답이 오면
    // 값이 달라진 경우에만 실질적으로 화면이 갱신된다.
    request.then(
      (team) {
        if (disposed) return;
        state = AsyncData(team);
      },
      onError: (Object e, StackTrace _) {
        // 네트워크 실패 시에는 캐시를 그대로 유지한다 (오프라인 동작).
        debugPrint('[cache] 즐겨찾기 팀 갱신 실패 — 캐시 유지: $e');
      },
    );
    return cached.value;
  }

  Future<TeamModel?> _fetch() async {
    final team = await _repository!.getFavoriteTeam();
    await _cache?.setFavoriteTeam(team);
    return team;
  }

  /// 네트워크에서 다시 받아 상태·캐시를 갱신한다 (pull-to-refresh 등).
  Future<TeamModel?> reload() async {
    if (_repository == null) return null;
    final request = _fetch();
    _inflight = request;
    final team = await request;
    state = AsyncData(team);
    return team;
  }

  /// 즐겨찾기 팀을 [teamId]로 바꾼다 (null이면 해제).
  ///
  /// 캐시를 **먼저** 갱신해야 한다 — 그러지 않으면 다음 콜드 스타트에서 이전
  /// 즐겨찾기 팀이 캐시에서 되살아난다. [team]을 알고 있으면 화면도 즉시
  /// 그 팀으로 맞춘다(낙관적 갱신).
  Future<void> select(String? teamId, {TeamModel? team}) async {
    final repository = _repository;
    if (repository == null) return;

    if (teamId == null) {
      await _cache?.setFavoriteTeam(null);
      state = const AsyncData(null);
    } else if (team != null) {
      await _cache?.setFavoriteTeam(team);
      state = AsyncData(team);
    } else {
      await _cache?.removeFavoriteTeam();
    }

    if (teamId == null) {
      await repository.clearFavoriteTeam();
    } else {
      await repository.setFavoriteTeam(teamId);
    }
    // 서버 기준 값으로 한 번 더 맞춘다 (낙관적 값이 틀렸을 경우 보정).
    unawaited(_reloadQuietly());
  }

  Future<void> _reloadQuietly() async {
    try {
      await reload();
    } catch (e) {
      debugPrint('[cache] 즐겨찾기 팀 재확인 실패 — 현재 값 유지: $e');
    }
  }
}

class TeamCalendarViewModel
    extends FamilyAsyncNotifier<TeamCalendarState, String> {
  late ShiftRepository _shiftRepository;
  late TeamRepository _teamRepository;

  @override
  Future<TeamCalendarState> build(String teamId) async {
    final authState = ref.watch(authStateChangesProvider);
    final userId = authState.whenOrNull(data: (auth) => auth.session?.user.id);
    if (userId == null) {
      throw Exception('Not authenticated');
    }

    _shiftRepository = ref.watch(shiftRepositoryProvider);
    _teamRepository = ref.watch(teamRepositoryProvider);

    final now = DateTime.now();
    // 알림 클릭 등으로 미리 설정된 focus month가 있으면 그 월을 초기 focus로 사용
    final pendingFocus =
        ref.read(pendingTeamCalendarFocusProvider(teamId));
    final focusMonth =
        pendingFocus != null ? DateTime(pendingFocus.year, pendingFocus.month) : now;
    // pending은 1회용 — 다음 빌드에 영향 없도록 비움
    if (pendingFocus != null) {
      Future.microtask(() {
        ref
            .read(pendingTeamCalendarFocusProvider(teamId).notifier)
            .state = null;
      });
    }
    final selected = pendingFocus != null
        ? DateTime(pendingFocus.year, pendingFocus.month, pendingFocus.day)
        : DateTime(now.year, now.month, now.day);

    // 월간 근무·근무 유형·팀원·선택일 로스터를 한 번에 받는다.
    // (예전엔 shift_types를 3번, 팀 shifts를 2번 받아 왕복이 배로 들었다)
    final results = await Future.wait([
      _teamRepository.getTeamById(teamId),
      _shiftRepository.getTeamCalendarMonth(
        teamId: teamId,
        month: focusMonth,
        selectedDate: selected,
      ),
    ]);

    final team = results[0] as TeamModel;
    final calendar =
        results[1]
            as ({
              Map<DateTime, List<ShiftWithType>> monthlyShifts,
              List<RosterEntry> roster,
              List<ShiftTypeModel> shiftTypes,
            });

    return TeamCalendarState(
      teamId: teamId,
      teamName: team.name,
      focusedMonth: focusMonth,
      selectedDate: selected,
      monthlyShifts: calendar.monthlyShifts,
      selectedDateRoster: calendar.roster,
      shiftTypes: calendar.shiftTypes,
    );
  }

  Future<void> selectDate(DateTime date) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final dateKey = DateTime(date.year, date.month, date.day);
    // 선택은 먼저 반영해 탭이 즉시 반응하게 하고, 로스터만 뒤따라 채운다.
    state = AsyncData(current.copyWith(selectedDate: dateKey));

    // 선택한 날이 이미 받아둔 달 안이면 네트워크 없이 로스터를 만든다.
    // 날짜를 탭할 때마다 왕복하던 것이 체감 지연의 큰 몫이었다.
    final inLoadedMonth =
        dateKey.year == current.focusedMonth.year &&
        dateKey.month == current.focusedMonth.month;

    final roster = inLoadedMonth
        ? await _shiftRepository.getTeamRosterFromMonthly(
            teamId: current.teamId,
            date: dateKey,
            monthlyShifts: current.monthlyShifts,
          )
        : await _shiftRepository.getTeamRoster(
            teamId: current.teamId,
            date: dateKey,
          );

    // 빠르게 여러 날짜를 누르면 오래된 응답이 최신 선택을 덮어쓸 수 있다.
    final latest = state.valueOrNull;
    if (latest == null || latest.selectedDate != dateKey) return;
    state = AsyncData(latest.copyWith(selectedDateRoster: roster));
  }

  Future<void> changeMonth(DateTime month) async {
    final current = state.valueOrNull;
    if (current == null) return;

    // 주간 모드에서는 focused 날짜를 그대로 사용, 월간에서는 1일
    final selectedDate = current.viewMode == CalendarViewMode.week
        ? DateTime(month.year, month.month, month.day)
        : DateTime(month.year, month.month, 1);

    // 1) focusedMonth와 selectedDate를 먼저 반영해 UI를 즉시 업데이트한다
    //    (스냅백 방지 + 즉각적인 반응성).
    state = AsyncData(
      current.copyWith(
        focusedMonth: month,
        selectedDate: selectedDate,
      ),
    );

    // 2) 월간 근무와 로스터를 한 번의 조회로 함께 만든다.
    try {
      final calendar = await _shiftRepository.getTeamCalendarMonth(
        teamId: current.teamId,
        month: month,
        selectedDate: selectedDate,
      );
      final monthlyShifts = calendar.monthlyShifts;
      final roster = calendar.roster;

      // 빠른 연속 이동 시 오래된 응답이 최신 화면(다른 달)을 덮어쓰지 않도록 가드.
      final latest = state.valueOrNull;
      if (latest == null ||
          latest.focusedMonth.year != month.year ||
          latest.focusedMonth.month != month.month) {
        return;
      }
      state = AsyncData(
        latest.copyWith(
          monthlyShifts: monthlyShifts,
          selectedDateRoster: roster,
        ),
      );
    } catch (_) {
      // 이동 중 실패는 화면을 깨뜨리지 않도록 조용히 무시(이미 즉시 반영됨).
    }
  }

  /// 관리자: 특정 shift의 shift_type 변경 후 현재 월/선택일 재조회 + 알림
  Future<void> updateShiftType(
    String shiftId,
    String newShiftTypeId, {
    String? affectedWorkerName,
    String? newShiftTypeName,
  }) async {
    final current = state.valueOrNull;
    if (current == null) return;
    await _shiftRepository.updateShift(shiftId, shiftTypeId: newShiftTypeId);
    // 변경된 shift의 날짜를 알림 페이로드/본문에 포함 (알림 클릭 시 해당 월로 이동)
    final changedShift = _findShiftById(current, shiftId);
    final changeDate = changedShift?.shift.shiftDate ?? current.selectedDate;
    final dateLabel = '${changeDate.month}/${changeDate.day}';
    await _notifyShiftChanged(
      teamName: current.teamName,
      action: '근무 변경',
      detail:
          '${affectedWorkerName ?? '근무자'}의 $dateLabel 근무가 ${newShiftTypeName ?? '다른 유형'}(으)로 변경되었습니다',
      changeDate: changeDate,
    );
    await _reloadCurrent(current);
  }

  ShiftWithType? _findShiftById(TeamCalendarState state, String shiftId) {
    for (final entry in state.monthlyShifts.entries) {
      for (final s in entry.value) {
        if (s.shift.id == shiftId) return s;
      }
    }
    return null;
  }

  /// 본인이 OFF 상태인 날짜에 본인 근무를 새로 추가.
  /// 같은 날짜에 이미 등록된 다른 사람 shift의 schedule_id를 사용한다.
  /// 같은 날에 shift가 하나도 없으면 예외.
  Future<void> createShiftForSelf({
    required DateTime date,
    required String userId,
    required String shiftTypeId,
    String? userDisplayName,
    String? shiftTypeName,
  }) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final dateKey = DateTime(date.year, date.month, date.day);
    final sameDayShifts = current.monthlyShifts[dateKey];
    if (sameDayShifts == null || sameDayShifts.isEmpty) {
      throw Exception('해당 날짜의 활성 스케줄을 찾을 수 없습니다');
    }
    final scheduleId = sameDayShifts.first.shift.scheduleId;

    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    await _shiftRepository.insertShifts([
      {
        'schedule_id': scheduleId,
        'team_id': current.teamId,
        'user_id': userId,
        'shift_date': dateStr,
        'shift_type_id': shiftTypeId,
      },
    ]);
    final dateLabel = '${date.month}/${date.day}';
    await _notifyShiftChanged(
      teamName: current.teamName,
      action: '근무 추가',
      detail:
          '${userDisplayName ?? '본인'}이 $dateLabel ${shiftTypeName ?? '근무'}에 추가되었습니다',
      changeDate: date,
    );
    await _reloadCurrent(current);
  }

  /// 관리자: 특정 shift 삭제 후 재조회 + 알림
  Future<void> deleteShift(
    String shiftId, {
    String? affectedWorkerName,
  }) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final deletedShift = _findShiftById(current, shiftId);
    final changeDate =
        deletedShift?.shift.shiftDate ?? current.selectedDate;
    final dateLabel = '${changeDate.month}/${changeDate.day}';
    await _shiftRepository.deleteShift(shiftId);
    await _notifyShiftChanged(
      teamName: current.teamName,
      action: '근무 삭제',
      detail:
          '${affectedWorkerName ?? '근무자'}의 $dateLabel 근무가 삭제되었습니다',
      changeDate: changeDate,
    );
    await _reloadCurrent(current);
  }

  /// 근무 변경 알림 발송 — 로컬 알림 + FCM 푸시 (팀 전체).
  Future<void> _notifyShiftChanged({
    required String teamName,
    required String action,
    required String detail,
    DateTime? changeDate,
  }) async {
    final teamId = state.valueOrNull?.teamId;
    try {
      await NotificationService.instance.showScheduleChangeNotification(
        teamName: teamName,
        message: '$action: $detail',
      );
    } catch (_) {}
    if (teamId != null) {
      await PushService.instance.sendToTeam(
        teamId: teamId,
        title: '[$teamName] $action',
        body: detail,
        data: {
          'type': 'shift_changed',
          'team_id': teamId,
          if (changeDate != null)
            'change_date':
                '${changeDate.year}-${changeDate.month.toString().padLeft(2, '0')}-${changeDate.day.toString().padLeft(2, '0')}',
        },
      );
    }
  }

  /// 근무 변경/새로고침 후 현재 월을 다시 읽는다.
  /// 캐시(근무 유형·팀원)도 함께 갱신해 최신 값을 보장한다.
  Future<void> _reloadCurrent(TeamCalendarState current) async {
    final calendar = await _shiftRepository.getTeamCalendarMonth(
      teamId: current.teamId,
      month: current.focusedMonth,
      selectedDate: current.selectedDate,
      forceRefresh: true,
    );
    state = AsyncData(current.copyWith(
      monthlyShifts: calendar.monthlyShifts,
      selectedDateRoster: calendar.roster,
      shiftTypes: calendar.shiftTypes,
    ));
  }

  void toggleViewMode() {
    final current = state.valueOrNull;
    if (current == null) return;

    final newMode = current.viewMode == CalendarViewMode.month
        ? CalendarViewMode.week
        : CalendarViewMode.month;

    state = AsyncData(current.copyWith(viewMode: newMode));
  }

  /// AI 기반 1:N 교환 후보 추천 (Edge Function `swap-suggest` 호출).
  /// 추천된 후보는 본인 외 동료 멤버이며, 시퀀스 룰을 위반하지 않는 안전한 교환만 반환.
  Future<List<SwapSuggestion>> suggestSwapCandidates({
    required DateTime myShiftDate,
    required String myShiftCode,
    required String myUserId,
    required String myDisplayName,
    required String teamName,
    int topK = 5,
  }) async {
    final current = state.valueOrNull;
    if (current == null) return [];

    // 같은 월의 모든 shift를 compact 배정표로 직렬화
    final shifts = current.monthlyShifts;
    final memberSchedules = <String, Map<String, String>>{};
    final members = <Map<String, String>>[];

    String dateFmt(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    String shortCode(String code, String name) {
      final c = code.toUpperCase();
      if (c == 'D' || name.contains('데이') || name.toLowerCase().contains('day')) return 'D';
      if (c == 'E' || name.contains('이브닝')) return 'E';
      if (c == 'N' || name.contains('나이트') || name.contains('야간')) return 'N';
      return c;
    }

    final userIdToName = <String, String>{};
    for (final entry in shifts.entries) {
      for (final s in entry.value) {
        final name = s.shift.userId; // fallback
        // 표시 이름은 RosterEntry에서 옴 — 여기선 user_id를 키로 일단 둔다
        userIdToName.putIfAbsent(s.shift.userId, () => name);
      }
    }
    // 더 나은 displayName을 selectedDateRoster에서 시도
    for (final entry in current.selectedDateRoster) {
      for (final w in entry.workers) {
        userIdToName[w.user.id] = w.user.displayName ?? w.user.email;
      }
    }
    // 본인 이름 보장
    userIdToName[myUserId] = myDisplayName;

    for (final e in userIdToName.entries) {
      members.add({'user_id': e.key, 'display_name': e.value});
      memberSchedules[e.value] = {};
    }
    for (final entry in shifts.entries) {
      for (final s in entry.value) {
        final name = userIdToName[s.shift.userId];
        if (name == null) continue;
        memberSchedules[name]![dateFmt(s.shift.shiftDate)] =
            shortCode(s.shiftType.code, s.shiftType.name);
      }
    }

    final periodLabel =
        '${current.focusedMonth.year}년 ${current.focusedMonth.month}월';
    final hardRules = <String>[
      'N→D 금지: 나이트 다음날 데이 배정 불가',
      'NOD 금지: 나이트→오프→데이 패턴 불가',
      'E→D 금지: 이브닝 다음날 데이 불가',
    ];

    try {
      final client = ref.read(supabaseClientProvider);
      final res = await client.functions.invoke(
        'swap-suggest',
        body: {
          'teamName': teamName,
          'periodLabel': periodLabel,
          'myUserId': myUserId,
          'myDisplayName': myDisplayName,
          'myShift': {
            'date': dateFmt(myShiftDate),
            'shiftCode': myShiftCode,
          },
          'memberSchedules': memberSchedules,
          'members': members,
          'hardRules': hardRules,
          'topK': topK,
        },
      );
      final data = res.data;
      if (data is! Map) return [];
      final list = (data['candidates'] as List?) ?? const [];
      return list
          .whereType<Map>()
          .map((e) => SwapSuggestion(
                userId: e['user_id'] as String? ?? '',
                displayName: e['display_name'] as String? ?? '',
                date: e['date'] as String? ?? '',
                shiftCode: e['shift_code'] as String? ?? '',
                reason: e['reason'] as String? ?? '',
              ))
          .where((c) => c.userId.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// 1:N 교환 요청 일괄 발송. 각 대상자에게 별도 request 생성 + 푸시.
  /// requestRepository는 외부에서 주입 (ViewModel이 request layer를 직접 의존하지 않도록).
  Future<int> sendBulkSwapRequests({
    required List<SwapSuggestion> targets,
    required Future<void> Function(SwapSuggestion target) submit,
  }) async {
    int success = 0;
    for (final t in targets) {
      try {
        await submit(t);
        success++;
      } catch (_) {}
    }
    return success;
  }

  /// 외부에서 호출 가능한 강제 새로고침 (pull-to-refresh, 화면 재진입 등)
  Future<void> refresh() async {
    final current = state.valueOrNull;
    if (current == null) {
      ref.invalidateSelf();
      return;
    }
    await _reloadCurrent(current);
  }
}
