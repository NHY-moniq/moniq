import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:moniq/data/models/shift_model.dart';
import 'package:moniq/data/models/shift_type_model.dart';
import 'package:moniq/data/models/shift_with_type.dart';
import 'package:moniq/data/models/team_model.dart';

/// 캐시 조회 결과.
///
/// 반환값이 null이면 "저장된 게 없다"(miss)는 뜻이고, non-null이면 hit이다.
/// hit인데 [value]가 null일 수 있다 — 예: "즐겨찾기 팀 없음"을 캐시한 경우.
/// 이 둘을 구분해야 캐시 미스와 "확정된 없음"을 혼동하지 않는다.
@immutable
class CachedValue<T> {
  const CachedValue(this.value, this.savedAt);

  final T value;
  final DateTime savedAt;

  Duration get age => DateTime.now().difference(savedAt);
}

/// 한 달치 홈/캘린더 데이터 캐시 페이로드.
@immutable
class CachedHomeMonth {
  const CachedHomeMonth({
    required this.teamId,
    required this.mine,
    required this.coverage,
  });

  /// 이 데이터가 어느 팀 기준인지 — 즐겨찾기 팀이 바뀌면 재사용하면 안 된다.
  final String teamId;

  /// 날짜별 본인 근무 (서버 원본 그대로 — "근무 삭제" 숨김은 표시 단계에서 적용).
  final Map<DateTime, List<ShiftWithType>> mine;

  /// published 스케줄이 커버하는 날짜 집합.
  final Set<DateTime> coverage;
}

/// 홈/캘린더/팀 탭의 콜드 스타트를 위한 로컬 캐시 (SharedPreferences + JSON).
///
/// 콜드 스타트에서 네트워크 왕복을 기다리는 동안 화면이 통째로 비는 문제를
/// 없애기 위해, 마지막으로 성공한 응답을 그대로 저장해 두고 앱 시작 시 즉시
/// 그린다(stale-while-revalidate). 네트워크 응답이 오면 **항상** 덮어쓰고,
/// 실패했을 때만 캐시를 유지한다 — 오래된 근무가 계속 남지 않도록.
///
/// 키는 사용자별로 분리되고 스키마 버전을 포함한다. 저장된 envelope의 버전이나
/// userId가 맞지 않으면 그 항목은 미스로 취급해 폐기한다.
class HomeCacheLocalDataSource {
  HomeCacheLocalDataSource({
    required SharedPreferences prefs,
    required String userId,
  })  : _prefs = prefs,
        _userId = userId;

  final SharedPreferences _prefs;
  final String _userId;

  /// 저장 포맷 버전. 모델 필드나 직렬화 방식이 바뀌면 올린다 —
  /// 이전 버전으로 저장된 값은 자동으로 폐기된다.
  static const int schemaVersion = 1;

  /// 이 캐시가 쓰는 모든 키의 공통 접두사 (사용자·버전 무관).
  static const String keyPrefix = 'moniq_home_cache';

  /// 월 캐시를 보관하는 범위(현재 월 기준 앞뒤 개월 수). 넘어가면 정리한다.
  static const int _monthRetention = 3;

  String get _base => '$keyPrefix:v$schemaVersion:$_userId';
  String get _favoriteTeamKey => '$_base:favorite_team';
  String get _myTeamsKey => '$_base:my_teams';
  String _monthKey(String teamId, DateTime month) =>
      '$_base:month:$teamId:${_monthLabel(month)}';

  // ── 즐겨찾기 팀 ──

  /// 캐시된 즐겨찾기 팀. miss면 null, "즐겨찾기 없음"이 캐시됐으면
  /// `CachedValue(null, ...)`.
  CachedValue<TeamModel?>? getFavoriteTeam() {
    return _read(_favoriteTeamKey, (data) {
      if (data == null) return null;
      return TeamModel.fromJson(Map<String, dynamic>.from(data as Map));
    });
  }

  /// 캐시된 즐겨찾기 팀의 id만 — 시작 직후 근무 조회를 즉시 발사하는 데 쓴다.
  String? getFavoriteTeamId() => getFavoriteTeam()?.value?.id;

  Future<void> setFavoriteTeam(TeamModel? team) =>
      _write(_favoriteTeamKey, team?.toJson());

  /// 즐겨찾기 캐시를 **미스 상태로** 되돌린다.
  ///
  /// `setFavoriteTeam(null)`은 "즐겨찾기 없음"을 캐시하므로 다르다.
  /// 즐겨찾기를 방금 바꿨는데 새 팀 정보를 아직 모를 때 쓴다.
  Future<void> removeFavoriteTeam() => _prefs.remove(_favoriteTeamKey);

  // ── 내 팀 목록 ──

  CachedValue<List<TeamModel>>? getMyTeams() {
    return _read(_myTeamsKey, (data) {
      return (data as List)
          .map((e) => TeamModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(growable: false);
    });
  }

  Future<void> setMyTeams(List<TeamModel> teams) =>
      _write(_myTeamsKey, teams.map((t) => t.toJson()).toList());

  // ── 월별 근무 + coverage ──

  CachedValue<CachedHomeMonth>? getMonth({
    required String teamId,
    required DateTime month,
  }) {
    return _read(_monthKey(teamId, month), (data) {
      final map = Map<String, dynamic>.from(data as Map);
      final cachedTeamId = map['team_id'] as String;
      // 키에도 팀이 들어가지만, 페이로드로 한 번 더 확인해 엉뚱한 팀의
      // 근무가 화면에 뜨는 일을 막는다.
      if (cachedTeamId != teamId) {
        throw const FormatException('team_id mismatch');
      }
      final mineRaw = Map<String, dynamic>.from(map['mine'] as Map);
      final mine = <DateTime, List<ShiftWithType>>{};
      mineRaw.forEach((dateStr, list) {
        final date = _parseDate(dateStr);
        if (date == null) return;
        mine[date] = (list as List)
            .map((e) => _shiftWithTypeFromJson(
                  Map<String, dynamic>.from(e as Map),
                ))
            .toList();
      });
      final coverage = <DateTime>{};
      for (final s in (map['coverage'] as List).cast<String>()) {
        final d = _parseDate(s);
        if (d != null) coverage.add(d);
      }
      return CachedHomeMonth(teamId: teamId, mine: mine, coverage: coverage);
    });
  }

  Future<void> setMonth({
    required String teamId,
    required DateTime month,
    required Map<DateTime, List<ShiftWithType>> mine,
    required Set<DateTime> coverage,
  }) async {
    await _write(_monthKey(teamId, month), {
      'team_id': teamId,
      'mine': {
        for (final e in mine.entries)
          _dateLabel(e.key): e.value.map(_shiftWithTypeToJson).toList(),
      },
      'coverage': coverage.map(_dateLabel).toList(),
    });
    await _pruneMonths(around: month);
  }

  // ── 무효화 ──

  /// 이 사용자의 캐시를 모두 지운다.
  Future<void> clear() async {
    for (final key in _prefs.getKeys().toList()) {
      if (key.startsWith('$_base:') || key == _base) {
        await _prefs.remove(key);
      }
    }
  }

  /// 모든 사용자·모든 버전의 홈 캐시를 지운다 (로그아웃 / 계정 삭제).
  static Future<void> clearAll(SharedPreferences prefs) async {
    for (final key in prefs.getKeys().toList()) {
      if (key.startsWith('$keyPrefix:')) {
        await prefs.remove(key);
      }
    }
  }

  /// 현재 스키마 버전이 아닌 캐시 항목을 정리한다 (앱 시작 시 1회).
  static Future<void> purgeStaleVersions(SharedPreferences prefs) async {
    const current = '$keyPrefix:v$schemaVersion:';
    for (final key in prefs.getKeys().toList()) {
      if (key.startsWith('$keyPrefix:') && !key.startsWith(current)) {
        await prefs.remove(key);
      }
    }
  }

  // ── 내부: envelope 읽기/쓰기 ──

  CachedValue<T>? _read<T>(String key, T Function(Object? data) decode) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      final envelope = jsonDecode(raw);
      if (envelope is! Map) throw const FormatException('not a map');
      // 스키마 버전/사용자 불일치는 조용히 폐기 — 잘못된 형식을 억지로
      // 해석하다 화면에 엉뚱한 값이 뜨는 것보다 미스가 낫다.
      if (envelope['v'] != schemaVersion || envelope['uid'] != _userId) {
        _prefs.remove(key);
        return null;
      }
      final savedAt = DateTime.tryParse(envelope['at'] as String? ?? '');
      if (savedAt == null) {
        _prefs.remove(key);
        return null;
      }
      return CachedValue<T>(decode(envelope['data']), savedAt);
    } catch (e) {
      debugPrint('[cache] $key 해석 실패 — 폐기: $e');
      _prefs.remove(key);
      return null;
    }
  }

  Future<void> _write(String key, Object? data) async {
    try {
      await _prefs.setString(
        key,
        jsonEncode({
          'v': schemaVersion,
          'uid': _userId,
          'at': DateTime.now().toIso8601String(),
          'data': data,
        }),
      );
    } catch (e) {
      // 캐시 저장 실패가 기능을 막아선 안 된다.
      debugPrint('[cache] $key 저장 실패: $e');
    }
  }

  /// [around] 기준 [_monthRetention]개월을 벗어난 월 캐시를 지운다.
  Future<void> _pruneMonths({required DateTime around}) async {
    final lower = DateTime(around.year, around.month - _monthRetention);
    final upper = DateTime(around.year, around.month + _monthRetention);
    final monthPrefix = '$_base:month:';
    for (final key in _prefs.getKeys().toList()) {
      if (!key.startsWith(monthPrefix)) continue;
      final label = key.split(':').last;
      final month = _parseMonth(label);
      if (month == null || month.isBefore(lower) || month.isAfter(upper)) {
        await _prefs.remove(key);
      }
    }
  }

  // ── 내부: 모델 직렬화 ──

  static Map<String, dynamic> _shiftWithTypeToJson(ShiftWithType s) => {
        'shift': s.shift.toJson(),
        'type': s.shiftType.toJson(),
        if (s.teamName != null) 'team_name': s.teamName,
      };

  static ShiftWithType _shiftWithTypeFromJson(Map<String, dynamic> json) =>
      ShiftWithType(
        shift: ShiftModel.fromJson(
          Map<String, dynamic>.from(json['shift'] as Map),
        ),
        shiftType: ShiftTypeModel.fromJson(
          Map<String, dynamic>.from(json['type'] as Map),
        ),
        teamName: json['team_name'] as String?,
      );

  static String _dateLabel(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static String _monthLabel(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

  static DateTime? _parseDate(String s) {
    final p = s.split('-');
    if (p.length != 3) return null;
    final y = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    final d = int.tryParse(p[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  static DateTime? _parseMonth(String s) {
    final p = s.split('-');
    if (p.length != 2) return null;
    final y = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    if (y == null || m == null) return null;
    return DateTime(y, m);
  }
}
