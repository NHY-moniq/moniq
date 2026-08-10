import 'package:moniq/data/datasources/shift_remote_data_source.dart';
import 'package:moniq/data/models/roster_entry.dart';
import 'package:moniq/data/models/shift_model.dart';
import 'package:moniq/data/models/shift_rule_model.dart';
import 'package:moniq/data/models/shift_type_model.dart';
import 'package:moniq/data/models/shift_with_type.dart';
import 'package:moniq/data/models/user_model.dart';

class ShiftRepository {
  ShiftRepository({required ShiftRemoteDataSource dataSource})
      : _dataSource = dataSource;

  final ShiftRemoteDataSource _dataSource;

  // ── 팀 메타 캐시 ──
  //
  // 팀 캘린더를 한 번 여는 동안 shift_types는 3곳(초기 로드 / 월간 조회 /
  // 로스터)에서, 팀원 목록은 날짜를 바꿀 때마다 같은 값을 다시 요청했다.
  // 둘 다 자주 바뀌지 않으므로 짧은 TTL 캐시 + in-flight 공유로 왕복을 줄인다.
  // 변경 API(createShiftType 등)를 타면 해당 팀 캐시를 즉시 버린다.
  static const _metaTtl = Duration(minutes: 5);
  final _shiftTypesCache = <String, ({DateTime at, List<ShiftTypeModel> v})>{};
  final _shiftTypesInflight = <String, Future<List<ShiftTypeModel>>>{};
  final _teamUsersCache = <String, ({DateTime at, List<UserModel> v})>{};
  final _teamUsersInflight = <String, Future<List<UserModel>>>{};

  bool _isFresh(DateTime at) => DateTime.now().difference(at) < _metaTtl;

  /// [teamId]의 shift_types 캐시를 버린다 (유형 추가/수정/삭제/정렬 후).
  void invalidateShiftTypes(String teamId) => _shiftTypesCache.remove(teamId);

  /// [teamId]의 팀원 캐시를 버린다 (멤버 변동 후).
  void invalidateTeamUsers(String teamId) => _teamUsersCache.remove(teamId);

  Future<List<ShiftTypeModel>> _shiftTypesCached(
    String teamId, {
    bool forceRefresh = false,
  }) {
    if (!forceRefresh) {
      final cached = _shiftTypesCache[teamId];
      if (cached != null && _isFresh(cached.at)) return Future.value(cached.v);
      final inflight = _shiftTypesInflight[teamId];
      if (inflight != null) return inflight;
    }
    final future = _dataSource.getShiftTypes(teamId).then((v) {
      _shiftTypesCache[teamId] = (at: DateTime.now(), v: v);
      return v;
    });
    _shiftTypesInflight[teamId] = future;
    // 실패는 캐시하지 않는다 — 다음 호출이 다시 시도하도록 in-flight만 정리.
    return future.whenComplete(() => _shiftTypesInflight.remove(teamId));
  }

  Future<List<UserModel>> _teamUsersCached(
    String teamId, {
    bool forceRefresh = false,
  }) {
    if (!forceRefresh) {
      final cached = _teamUsersCache[teamId];
      if (cached != null && _isFresh(cached.at)) return Future.value(cached.v);
      final inflight = _teamUsersInflight[teamId];
      if (inflight != null) return inflight;
    }
    final future = _dataSource.getTeamUsers(teamId).then((v) {
      _teamUsersCache[teamId] = (at: DateTime.now(), v: v);
      return v;
    });
    _teamUsersInflight[teamId] = future;
    return future.whenComplete(() => _teamUsersInflight.remove(teamId));
  }

  /// 개인 캘린더: 월간 근무를 날짜별로 그룹핑
  Future<Map<DateTime, List<ShiftWithType>>> getMyMonthlyShifts({
    required DateTime month,
  }) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0);

    final shifts = await _dataSource.getMyShifts(start: start, end: end);
    if (shifts.isEmpty) return {};

    // 관련 팀들의 shift types 수집 — 팀별로 순차 대기하면 소속 팀 수만큼
    // 왕복이 쌓이므로 병렬로 받는다(캐시가 있으면 왕복 자체가 없다).
    final teamIds = shifts.map((s) => s.teamId).toSet();
    final perTeamTypes = await Future.wait(teamIds.map(_shiftTypesCached));
    final allShiftTypes = <String, ShiftTypeModel>{};
    for (final types in perTeamTypes) {
      for (final t in types) {
        allShiftTypes[t.id] = t;
      }
    }

    // 날짜별로 그룹핑
    final result = <DateTime, List<ShiftWithType>>{};
    for (final shift in shifts) {
      final type = allShiftTypes[shift.shiftTypeId];
      if (type == null) continue;
      final dateKey = _normalizeDate(shift.shiftDate);
      result.putIfAbsent(dateKey, () => []).add(
            ShiftWithType(shift: shift, shiftType: type),
          );
    }
    return result;
  }

  /// 특정 팀에서 내 근무를 [start, end] 범위로 조회 (shift_type 포함).
  /// 팀 → 개인 캘린더 import 등에서 사용.
  Future<List<ShiftWithType>> getMyShiftsForTeam({
    required String teamId,
    required DateTime start,
    required DateTime end,
  }) async {
    final allShifts = await _dataSource.getMyShifts(start: start, end: end);
    final mine = allShifts.where((s) => s.teamId == teamId).toList();
    if (mine.isEmpty) return const [];
    final types = await _shiftTypesCached(teamId);
    final typeMap = {for (final t in types) t.id: t};
    final result = <ShiftWithType>[];
    for (final s in mine) {
      final type = typeMap[s.shiftTypeId];
      if (type == null) continue;
      result.add(ShiftWithType(shift: s, shiftType: type));
    }
    return result;
  }

  /// 팀 캘린더: 월간 근무를 날짜별로 그룹핑
  Future<Map<DateTime, List<ShiftWithType>>> getTeamMonthlyShifts({
    required String teamId,
    required DateTime month,
  }) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0);

    final results = await Future.wait<dynamic>([
      _dataSource.getTeamShifts(teamId: teamId, start: start, end: end),
      _shiftTypesCached(teamId),
    ]);
    final shifts = results[0] as List<ShiftModel>;
    if (shifts.isEmpty) return {};
    final shiftTypes = results[1] as List<ShiftTypeModel>;
    final typeMap = {for (final t in shiftTypes) t.id: t};

    final result = <DateTime, List<ShiftWithType>>{};
    for (final shift in shifts) {
      final type = typeMap[shift.shiftTypeId];
      if (type == null) continue;
      final dateKey = _normalizeDate(shift.shiftDate);
      result.putIfAbsent(dateKey, () => []).add(
            ShiftWithType(shift: shift, shiftType: type),
          );
    }
    return result;
  }

  /// 팀 캘린더 한 달치를 한 번에 로드.
  ///
  /// 월간 근무·근무 유형·팀원을 병렬로 받아, 선택한 날짜의 로스터까지 그 자리에서
  /// 만들어 돌려준다. 예전엔 월간 조회와 로스터 조회가 각각 shifts/shift_types를
  /// 따로 받아와 같은 데이터를 두 번씩 실어 날랐다.
  Future<
    ({
      Map<DateTime, List<ShiftWithType>> monthlyShifts,
      List<RosterEntry> roster,
      List<ShiftTypeModel> shiftTypes,
    })
  >
  getTeamCalendarMonth({
    required String teamId,
    required DateTime month,
    required DateTime selectedDate,
    bool forceRefresh = false,
  }) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0);

    final results = await Future.wait<dynamic>([
      _dataSource.getTeamShifts(teamId: teamId, start: start, end: end),
      _shiftTypesCached(teamId, forceRefresh: forceRefresh),
      _teamUsersCached(teamId, forceRefresh: forceRefresh),
    ]);
    final shifts = results[0] as List<ShiftModel>;
    final shiftTypes = results[1] as List<ShiftTypeModel>;
    final users = results[2] as List<UserModel>;

    final typeMap = {for (final t in shiftTypes) t.id: t};
    final monthlyShifts = <DateTime, List<ShiftWithType>>{};
    final selectedKey = _normalizeDate(selectedDate);
    final daily = <ShiftModel>[];
    for (final shift in shifts) {
      final dateKey = _normalizeDate(shift.shiftDate);
      if (dateKey == selectedKey) daily.add(shift);
      final type = typeMap[shift.shiftTypeId];
      if (type == null) continue;
      monthlyShifts
          .putIfAbsent(dateKey, () => [])
          .add(ShiftWithType(shift: shift, shiftType: type));
    }

    return (
      monthlyShifts: monthlyShifts,
      roster: buildRoster(shifts: daily, shiftTypes: shiftTypes, users: users),
      shiftTypes: shiftTypes,
    );
  }

  /// 이미 받아둔 월간 근무에서 [date]의 로스터를 만든다.
  ///
  /// 근무 유형·팀원은 캐시에서 오므로 보통 네트워크 왕복이 없다. 날짜를 탭할
  /// 때마다 로스터를 새로 조회하던 것을 대체한다.
  Future<List<RosterEntry>> getTeamRosterFromMonthly({
    required String teamId,
    required DateTime date,
    required Map<DateTime, List<ShiftWithType>> monthlyShifts,
  }) async {
    final results = await Future.wait<dynamic>([
      _shiftTypesCached(teamId),
      _teamUsersCached(teamId),
    ]);
    final shifts = (monthlyShifts[_normalizeDate(date)] ?? const <ShiftWithType>[])
        .map((s) => s.shift)
        .toList();
    return buildRoster(
      shifts: shifts,
      shiftTypes: results[0] as List<ShiftTypeModel>,
      users: results[1] as List<UserModel>,
    );
  }

  /// 팀 로스터: 특정 날짜의 근무자를 근무 유형별로 그룹핑
  Future<List<RosterEntry>> getTeamRoster({
    required String teamId,
    required DateTime date,
  }) async {
    final results = await Future.wait<dynamic>([
      _dataSource.getTeamShifts(teamId: teamId, start: date, end: date),
      _shiftTypesCached(teamId),
      _teamUsersCached(teamId),
    ]);
    return buildRoster(
      shifts: results[0] as List<ShiftModel>,
      shiftTypes: results[1] as List<ShiftTypeModel>,
      users: results[2] as List<UserModel>,
    );
  }

  /// 근무·근무 유형·팀원에서 로스터(근무 유형별 그룹)를 만드는 순수 함수.
  /// 배정되지 않은 팀원은 맨 뒤 Off 그룹으로 모은다.
  List<RosterEntry> buildRoster({
    required List<ShiftModel> shifts,
    required List<ShiftTypeModel> shiftTypes,
    required List<UserModel> users,
  }) {
    // 근무가 하나도 없으면 전원 Off
    if (shifts.isEmpty) {
      if (users.isEmpty) return [];
      return [
        RosterEntry(
          shiftType: const ShiftTypeModel(
            id: '_off',
            teamId: '',
            name: '오프',
            code: 'O',
            color: '#A0AEC0',
            displayOrder: 9999,
          ),
          workers: users.map((u) => RosterWorker(user: u)).toList(),
        ),
      ];
    }
    final userMap = {for (final u in users) u.id: u};

    // 근무 유형별로 그룹핑
    final grouped = <String, List<RosterWorker>>{};
    final assignedUserIds = <String>{};
    for (final shift in shifts) {
      final user = userMap[shift.userId];
      if (user == null) continue;
      assignedUserIds.add(shift.userId);
      grouped.putIfAbsent(shift.shiftTypeId, () => []).add(
            RosterWorker(user: user, shiftId: shift.id, note: shift.note),
          );
    }

    // display_order 순서로 정렬
    final entries = <RosterEntry>[];
    for (final shiftType in shiftTypes) {
      final workers = grouped[shiftType.id];
      if (workers != null && workers.isNotEmpty) {
        entries.add(RosterEntry(shiftType: shiftType, workers: workers));
      }
    }

    // 근무가 배정되지 않은 팀원은 Off 그룹에 추가
    final unassignedWorkers = users
        .where((u) => !assignedUserIds.contains(u.id))
        .map((u) => RosterWorker(user: u))
        .toList();
    if (unassignedWorkers.isNotEmpty) {
      entries.add(RosterEntry(
        shiftType: const ShiftTypeModel(
          id: '_off',
          teamId: '',
          name: '오프',
          code: 'O',
          color: '#A0AEC0',
          displayOrder: 9999,
        ),
        workers: unassignedWorkers,
      ));
    }

    return entries;
  }

  /// 오늘(또는 특정 날짜) 같은 shift_type에 배정된 팀원.
  /// [excludeSelf]가 true(기본)면 본인 제외.
  Future<List<UserModel>> getCoworkers({
    required String teamId,
    required DateTime date,
    required String shiftTypeId,
    bool excludeSelf = true,
  }) {
    return _dataSource.getCoworkers(
      teamId: teamId,
      date: date,
      shiftTypeId: shiftTypeId,
      excludeSelf: excludeSelf,
    );
  }

  Future<List<ShiftTypeModel>> getShiftTypes(
    String teamId, {
    bool forceRefresh = false,
  }) {
    return _shiftTypesCached(teamId, forceRefresh: forceRefresh);
  }

  Future<List<ShiftModel>> getShiftsOnDate({
    required String teamId,
    required DateTime date,
  }) {
    return _dataSource.getShiftsOnDate(teamId: teamId, date: date);
  }

  /// 해당 기간을 커버하는 published 스케줄들의 기간 합집합을 반환.
  /// 실제 shift 배정이 없는 날(예: 전원 OFF)도 "스케줄 안" 으로 본다.
  Future<Set<DateTime>> getCoveredDates({
    required String teamId,
    required DateTime start,
    required DateTime end,
  }) async {
    final schedules = await _dataSource.getPublishedSchedules(
      teamId: teamId,
      start: start,
      end: end,
    );
    final covered = <DateTime>{};
    for (final s in schedules) {
      final pStart = s.periodStart.isBefore(start) ? start : s.periodStart;
      final pEnd = s.periodEnd.isAfter(end) ? end : s.periodEnd;
      for (var d = DateTime(pStart.year, pStart.month, pStart.day);
          !d.isAfter(pEnd);
          d = d.add(const Duration(days: 1))) {
        covered.add(d);
      }
    }
    return covered;
  }

  Future<List<ShiftTypeModel>> getAllShiftTypes(String teamId) {
    return _dataSource.getAllShiftTypes(teamId);
  }

  Future<ShiftTypeModel> createShiftType(
    String teamId, {
    required String name,
    required String code,
    String? startTime,
    String? endTime,
    required String color,
    required int displayOrder,
  }) {
    invalidateShiftTypes(teamId);
    return _dataSource.createShiftType(teamId,
        name: name,
        code: code,
        startTime: startTime,
        endTime: endTime,
        color: color,
        displayOrder: displayOrder);
  }

  // 아래 세 API는 teamId 없이 shift_type id만 받으므로 어느 팀 캐시를 버려야
  // 할지 알 수 없다. 유형 변경은 드물기에 전체를 비우는 편이 안전하다.
  Future<void> updateShiftType(String id,
      {String? name, String? code, String? startTime, String? endTime, String? color}) {
    _shiftTypesCache.clear();
    return _dataSource.updateShiftType(id,
        name: name, code: code, startTime: startTime, endTime: endTime, color: color);
  }

  Future<void> toggleShiftTypeActive(String id, bool isActive) {
    _shiftTypesCache.clear();
    return _dataSource.toggleShiftTypeActive(id, isActive);
  }

  Future<void> deleteShiftType(String id) {
    _shiftTypesCache.clear();
    return _dataSource.deleteShiftType(id);
  }

  Future<void> updateShift(
    String shiftId, {
    String? shiftTypeId,
    String? userId,
    String? note,
  }) {
    return _dataSource.updateShift(
      shiftId,
      shiftTypeId: shiftTypeId,
      userId: userId,
      note: note,
    );
  }

  Future<void> deleteShift(String shiftId) {
    return _dataSource.deleteShift(shiftId);
  }

  /// 단건/여러 건 shift 삽입. 본인 OFF → 새 근무 추가에서 사용.
  Future<void> insertShifts(List<Map<String, dynamic>> shifts) {
    return _dataSource.insertShifts(shifts);
  }

  Future<void> reorderShiftTypes(String teamId, List<String> orderedIds) {
    invalidateShiftTypes(teamId);
    return _dataSource.reorderShiftTypes(teamId, orderedIds);
  }

  Future<List<ShiftRuleModel>> getShiftRules(String teamId) {
    return _dataSource.getShiftRules(teamId);
  }

  Future<void> upsertShiftRule(String teamId,
      {required String ruleType, required Map<String, dynamic> ruleValue}) {
    return _dataSource.upsertShiftRule(teamId,
        ruleType: ruleType, ruleValue: ruleValue);
  }

  DateTime _normalizeDate(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
}
