import 'package:moniq/data/datasources/shift_remote_data_source.dart';
import 'package:moniq/data/models/roster_entry.dart';
import 'package:moniq/data/models/shift_rule_model.dart';
import 'package:moniq/data/models/shift_type_model.dart';
import 'package:moniq/data/models/shift_with_type.dart';
import 'package:moniq/data/models/user_model.dart';

class ShiftRepository {
  ShiftRepository({required ShiftRemoteDataSource dataSource})
      : _dataSource = dataSource;

  final ShiftRemoteDataSource _dataSource;

  /// 개인 캘린더: 월간 근무를 날짜별로 그룹핑
  Future<Map<DateTime, List<ShiftWithType>>> getMyMonthlyShifts({
    required DateTime month,
  }) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0);

    final shifts = await _dataSource.getMyShifts(start: start, end: end);
    if (shifts.isEmpty) return {};

    // 관련 팀들의 shift types 수집
    final teamIds = shifts.map((s) => s.teamId).toSet();
    final allShiftTypes = <String, ShiftTypeModel>{};
    for (final teamId in teamIds) {
      final types = await _dataSource.getShiftTypes(teamId);
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
    final types = await _dataSource.getShiftTypes(teamId);
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

    final shifts =
        await _dataSource.getTeamShifts(teamId: teamId, start: start, end: end);
    if (shifts.isEmpty) return {};

    final shiftTypes = await _dataSource.getShiftTypes(teamId);
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

  /// 팀 로스터: 특정 날짜의 근무자를 근무 유형별로 그룹핑
  Future<List<RosterEntry>> getTeamRoster({
    required String teamId,
    required DateTime date,
  }) async {
    final shifts = await _dataSource.getTeamShifts(
      teamId: teamId,
      start: date,
      end: date,
    );

    final shiftTypes = await _dataSource.getShiftTypes(teamId);
    final users = await _dataSource.getTeamUsers(teamId);

    // 근무가 하나도 없으면 전원 Off
    if (shifts.isEmpty) {
      if (users.isEmpty) return [];
      return [
        RosterEntry(
          shiftType: const ShiftTypeModel(
            id: '_off',
            teamId: '',
            name: 'Off',
            code: 'OFF',
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
          name: 'Off',
          code: 'OFF',
          color: '#A0AEC0',
          displayOrder: 9999,
        ),
        workers: unassignedWorkers,
      ));
    }

    return entries;
  }

  /// 오늘(또는 특정 날짜) 같은 shift_type에 배정된 팀원(본인 제외)
  Future<List<UserModel>> getCoworkers({
    required String teamId,
    required DateTime date,
    required String shiftTypeId,
  }) {
    return _dataSource.getCoworkers(
      teamId: teamId,
      date: date,
      shiftTypeId: shiftTypeId,
    );
  }

  Future<List<ShiftTypeModel>> getShiftTypes(String teamId) {
    return _dataSource.getShiftTypes(teamId);
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
    return _dataSource.createShiftType(teamId,
        name: name,
        code: code,
        startTime: startTime,
        endTime: endTime,
        color: color,
        displayOrder: displayOrder);
  }

  Future<void> updateShiftType(String id,
      {String? name, String? code, String? startTime, String? endTime, String? color}) {
    return _dataSource.updateShiftType(id,
        name: name, code: code, startTime: startTime, endTime: endTime, color: color);
  }

  Future<void> toggleShiftTypeActive(String id, bool isActive) {
    return _dataSource.toggleShiftTypeActive(id, isActive);
  }

  Future<void> deleteShiftType(String id) {
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
