import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:moniq/data/datasources/home_cache_local_data_source.dart';
import 'package:moniq/data/models/team_model.dart';
import 'package:moniq/data/providers/home_cache_providers.dart';
import 'package:moniq/data/providers/settings_providers.dart';
import 'package:moniq/data/providers/shift_providers.dart';
import 'package:moniq/data/providers/supabase_providers.dart';
import 'package:moniq/data/providers/team_providers.dart';
import 'package:moniq/data/repositories/team_repository.dart';

const _teamOrderKey = 'team_order';

final teamViewModelProvider =
    AsyncNotifierProvider<TeamViewModel, List<TeamModel>>(TeamViewModel.new);

class TeamViewModel extends AsyncNotifier<List<TeamModel>> {
  late TeamRepository _repository;
  HomeCacheLocalDataSource? _cache;
  static const List<_DefaultShiftSeed> _defaultShiftSeeds = [
    _DefaultShiftSeed(
      name: '데이',
      code: 'D',
      color: '#F0C040',
      startTime: '07:00:00',
      endTime: '15:00:00',
    ),
    _DefaultShiftSeed(
      name: '이브닝',
      code: 'E',
      color: '#E8923A',
      startTime: '15:00:00',
      endTime: '22:00:00',
    ),
    _DefaultShiftSeed(
      name: '나이트',
      code: 'N',
      color: '#5A8BB5',
      startTime: '22:00:00',
      endTime: '07:00:00',
    ),
    _DefaultShiftSeed(
      name: '교육',
      code: 'ED',
      color: '#9F7AEA',
      startTime: '09:00:00',
      endTime: '18:00:00',
    ),
  ];

  @override
  FutureOr<List<TeamModel>> build() {
    ref.watch(authStateChangesProvider);
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) {
      return const [];
    }

    _repository = ref.watch(teamRepositoryProvider);
    _cache = ref.watch(homeCacheProvider);

    var disposed = false;
    ref.onDispose(() => disposed = true);

    final request = _fetchAndCache();
    final cached = _cache?.getMyTeams();
    if (cached == null) return request;

    // 캐시된 팀 목록으로 즉시 그리고(동기 반환), 응답이 오면 갈아끼운다.
    request.then(
      (teams) {
        if (disposed) return;
        state = AsyncData(teams);
      },
      onError: (Object e, StackTrace _) {
        debugPrint('[cache] 팀 목록 갱신 실패 — 캐시 유지: $e');
      },
    );
    return _applySavedOrder(cached.value);
  }

  Future<List<TeamModel>> _fetchAndCache() async {
    final teams = await _repository.getMyTeams();
    // 네트워크 성공 시 캐시는 항상 덮어쓴다 (정렬 전 원본을 저장).
    await _cache?.setMyTeams(teams);
    return _applySavedOrder(teams);
  }

  /// 사용자가 저장한 순서를 적용한다.
  ///
  /// SharedPreferences는 [sharedPreferencesProvider]에서 **동기적으로** 얻는다.
  /// `getInstance()`를 await하면 캐시 경로가 비동기가 돼 로딩 프레임이 다시
  /// 생기기 때문이다. 프로바이더가 준비되지 않은 환경에서는 저장 순서 없이
  /// 그룹핑만 적용한다.
  List<TeamModel> _applySavedOrder(List<TeamModel> teams) {
    List<String>? savedOrder;
    try {
      savedOrder = ref.read(sharedPreferencesProvider).getStringList(
            _teamOrderKey,
          );
    } catch (_) {
      savedOrder = null;
    }

    List<TeamModel> ordered;
    if (savedOrder == null || savedOrder.isEmpty) {
      ordered = teams;
    } else {
      final teamMap = {for (final t in teams) t.id: t};
      ordered = <TeamModel>[];
      for (final id in savedOrder) {
        final team = teamMap.remove(id);
        if (team != null) ordered.add(team);
      }
      ordered.addAll(teamMap.values);
    }

    // 항상 [조직(public) → 개인(private)] 순서로 그룹화. 각 그룹 안의
    // 상대 순서는 사용자가 저장한 순서를 유지한다.
    final orgs = ordered.where((t) => t.teamType != 'personal').toList();
    final personals = ordered.where((t) => t.teamType == 'personal').toList();
    return [...orgs, ...personals];
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final teams = List<TeamModel>.from(current);
    if (newIndex > oldIndex) newIndex--;
    final item = teams.removeAt(oldIndex);
    teams.insert(newIndex, item);

    state = AsyncData(teams);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_teamOrderKey, teams.map((t) => t.id).toList());
  }

  Future<TeamModel> createTeam({
    required String name,
    String? icon,
    String? description,
    String? teamType,
  }) async {
    final team = await _repository.createTeam(
      name: name,
      icon: icon,
      description: description,
      teamType: teamType,
    );
    await _ensureDefaultShiftTypes(team.id);

    // 방금 만든 팀이 바로 보여야 하므로 캐시가 아니라 네트워크로 갱신한다.
    await refresh();

    return team;
  }

  Future<Map<String, dynamic>> joinTeam(String inviteCode) async {
    final result = await _repository.joinTeamByInvite(inviteCode);

    await refresh();

    return result;
  }

  /// 네트워크에서 다시 받아 목록·캐시를 갱신한다.
  ///
  /// 캐시가 있으면 `invalidateSelf`는 캐시값으로 즉시 완료되므로, 팀 생성/참여
  /// 직후처럼 최신 목록이 반드시 필요한 경로에서는 이 메서드를 쓴다.
  Future<void> refresh() async {
    if (ref.read(currentUserIdProvider) == null) {
      ref.invalidateSelf();
      return;
    }
    try {
      state = AsyncData(await _fetchAndCache());
    } catch (error, stackTrace) {
      // 목록을 이미 그리고 있으면 실패로 화면을 비우지 않는다(오프라인 동작).
      if (state.valueOrNull == null) {
        state = AsyncError(error, stackTrace);
      } else {
        debugPrint('[cache] 팀 목록 갱신 실패 — 캐시 유지: $error');
      }
    }
  }

  Future<void> _ensureDefaultShiftTypes(String teamId) async {
    final shiftRepo = ref.read(shiftRepositoryProvider);
    final existing = await shiftRepo.getAllShiftTypes(teamId);
    final existingCodes = existing
        .map((t) => t.code.trim().toUpperCase())
        .toSet();
    var displayOrder = existing.length;

    for (final seed in _defaultShiftSeeds) {
      if (existingCodes.contains(seed.code)) continue;
      await shiftRepo.createShiftType(
        teamId,
        name: seed.name,
        code: seed.code,
        startTime: seed.startTime,
        endTime: seed.endTime,
        color: seed.color,
        displayOrder: displayOrder,
      );
      displayOrder += 1;
    }
  }
}

class _DefaultShiftSeed {
  const _DefaultShiftSeed({
    required this.name,
    required this.code,
    required this.color,
    required this.startTime,
    required this.endTime,
  });

  final String name;
  final String code;
  final String color;
  final String startTime;
  final String endTime;
}
