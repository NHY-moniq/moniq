import 'dart:math';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/models/schedule_model.dart';
import 'package:moniq/data/models/shift_model.dart';
import 'package:moniq/data/models/shift_rule_model.dart';
import 'package:moniq/data/models/shift_type_model.dart';
import 'package:moniq/data/models/team_member_with_user.dart';
import 'package:moniq/data/providers/schedule_providers.dart';
import 'package:moniq/data/providers/shift_providers.dart';
import 'package:moniq/data/providers/team_providers.dart';

part 'schedule_generation_viewmodel.freezed.dart';

@freezed
class ScheduleGenerationState with _$ScheduleGenerationState {
  const factory ScheduleGenerationState({
    required String teamId,
    required List<ShiftTypeModel> shiftTypes,
    required List<TeamMemberWithUser> members,
    required List<ShiftRuleModel> rules,
    DateTime? periodStart,
    DateTime? periodEnd,
    @Default(false) bool isGenerating,
    @Default(false) bool isPublishing,
    ScheduleModel? generatedSchedule,
    List<ShiftModel>? previewShifts,
    List<String>? validationWarnings,
    String? error,
  }) = _ScheduleGenerationState;
}

final scheduleGenerationViewModelProvider = AsyncNotifierProvider.family<
    ScheduleGenerationViewModel, ScheduleGenerationState, String>(
  ScheduleGenerationViewModel.new,
);

class ScheduleGenerationViewModel
    extends FamilyAsyncNotifier<ScheduleGenerationState, String> {
  @override
  Future<ScheduleGenerationState> build(String teamId) async {
    final teamRepo = ref.watch(teamRepositoryProvider);
    final shiftRepo = ref.watch(shiftRepositoryProvider);

    final results = await Future.wait([
      teamRepo.getTeamMembersWithUsers(teamId),
      shiftRepo.getShiftTypes(teamId),
    ]);

    List<ShiftRuleModel> rules = [];
    try {
      rules = await shiftRepo.getShiftRules(teamId);
    } catch (_) {}

    final members = results[0] as List<TeamMemberWithUser>;
    final shiftTypes = results[1] as List<ShiftTypeModel>;

    // 기본 기간: 다음 달
    final now = DateTime.now();
    final nextMonth = DateTime(now.year, now.month + 1, 1);
    final nextMonthEnd = DateTime(now.year, now.month + 2, 0);

    return ScheduleGenerationState(
      teamId: teamId,
      shiftTypes: shiftTypes,
      members: members,
      rules: rules,
      periodStart: nextMonth,
      periodEnd: nextMonthEnd,
    );
  }

  void setPeriod(DateTime start, DateTime end) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(periodStart: start, periodEnd: end));
  }

  /// 스케줄 자동 생성
  Future<void> generate() async {
    final current = state.valueOrNull;
    if (current == null) return;
    if (current.periodStart == null || current.periodEnd == null) return;

    state = AsyncData(current.copyWith(isGenerating: true, error: null));

    try {
      final scheduleRepo = ref.read(scheduleRepositoryProvider);

      // 1. 스케줄 레코드 생성
      final schedule = await scheduleRepo.createSchedule(
        teamId: current.teamId,
        periodStart: current.periodStart!,
        periodEnd: current.periodEnd!,
      );

      // 2. 자동 배정 알고리즘 실행
      final result = _generateShifts(
        members: current.members,
        shiftTypes: current.shiftTypes,
        rules: current.rules,
        start: current.periodStart!,
        end: current.periodEnd!,
        scheduleId: schedule.id,
        teamId: current.teamId,
      );

      // 3. shifts 삽입
      await scheduleRepo.insertShifts(result.shifts);

      // 4. 미리보기 조회
      final previewShifts =
          await scheduleRepo.getShiftsBySchedule(schedule.id);

      state = AsyncData(current.copyWith(
        isGenerating: false,
        generatedSchedule: schedule,
        previewShifts: previewShifts,
        validationWarnings: result.warnings,
      ));
    } catch (e) {
      state = AsyncData(current.copyWith(
        isGenerating: false,
        error: '스케줄 생성 중 오류가 발생했습니다: $e',
      ));
    }
  }

  /// 발행
  Future<bool> publish() async {
    final current = state.valueOrNull;
    if (current == null || current.generatedSchedule == null) return false;

    state = AsyncData(current.copyWith(isPublishing: true));

    try {
      final scheduleRepo = ref.read(scheduleRepositoryProvider);
      await scheduleRepo.publishSchedule(current.generatedSchedule!.id);
      state = AsyncData(current.copyWith(isPublishing: false));
      return true;
    } catch (e) {
      state = AsyncData(current.copyWith(
        isPublishing: false,
        error: '발행 중 오류가 발생했습니다: $e',
      ));
      return false;
    }
  }

  /// 초안 삭제
  Future<void> discardDraft() async {
    final current = state.valueOrNull;
    if (current == null || current.generatedSchedule == null) return;

    try {
      final scheduleRepo = ref.read(scheduleRepositoryProvider);
      await scheduleRepo.deleteSchedule(current.generatedSchedule!.id);
      state = AsyncData(current.copyWith(
        generatedSchedule: null,
        previewShifts: null,
        validationWarnings: null,
      ));
    } catch (_) {}
  }

  /// 간단한 스케줄 생성 알고리즘
  _GenerationResult _generateShifts({
    required List<TeamMemberWithUser> members,
    required List<ShiftTypeModel> shiftTypes,
    required List<ShiftRuleModel> rules,
    required DateTime start,
    required DateTime end,
    required String scheduleId,
    required String teamId,
  }) {
    final shifts = <Map<String, dynamic>>[];
    final warnings = <String>[];
    final random = Random(42); // deterministic seed

    if (members.isEmpty) {
      warnings.add('팀 멤버가 없습니다');
      return _GenerationResult(shifts: shifts, warnings: warnings);
    }

    if (shiftTypes.isEmpty) {
      warnings.add('근무 유형이 설정되지 않았습니다');
      return _GenerationResult(shifts: shifts, warnings: warnings);
    }

    // 규칙 파싱
    int maxConsecutiveDays = 5;
    int maxMonthlyShifts = 25;
    int maxMonthlyNightShifts = 8;
    int minStaffPerShift = 1;

    for (final rule in rules) {
      final value = rule.ruleValue;
      switch (rule.ruleType) {
        case 'max_consecutive_days':
          maxConsecutiveDays = (value['value'] as num?)?.toInt() ?? 5;
        case 'max_monthly_shifts':
          maxMonthlyShifts = (value['value'] as num?)?.toInt() ?? 25;
        case 'max_monthly_night_shifts':
          maxMonthlyNightShifts = (value['value'] as num?)?.toInt() ?? 8;
        case 'min_staff_per_shift':
          minStaffPerShift = (value['value'] as num?)?.toInt() ?? 1;
      }
    }

    // 멤버 인덱스별 카운터
    final memberShiftCount = <String, int>{};
    final memberNightCount = <String, int>{};
    final memberConsecutive = <String, int>{};
    final memberLastWorked = <String, DateTime?>{};

    for (final m in members) {
      memberShiftCount[m.userId] = 0;
      memberNightCount[m.userId] = 0;
      memberConsecutive[m.userId] = 0;
      memberLastWorked[m.userId] = null;
    }

    // 날짜별로 순회
    final dayCount = end.difference(start).inDays + 1;
    final workShiftTypes =
        shiftTypes.where((t) => t.code.toUpperCase() != 'OFF').toList();

    for (int d = 0; d < dayCount; d++) {
      final date = start.add(Duration(days: d));
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      // 각 근무 유형에 멤버 배정
      for (final shiftType in workShiftTypes) {
        final isNight = shiftType.code.toUpperCase() == 'N' ||
            shiftType.name.contains('야간') ||
            shiftType.name.contains('나이트');

        // 배정 가능한 멤버 필터링
        final eligible = members.where((m) {
          final shiftCount = memberShiftCount[m.userId] ?? 0;
          final nightCount = memberNightCount[m.userId] ?? 0;
          final consecutive = memberConsecutive[m.userId] ?? 0;

          if (shiftCount >= maxMonthlyShifts) return false;
          if (isNight && nightCount >= maxMonthlyNightShifts) return false;
          if (consecutive >= maxConsecutiveDays) return false;

          return true;
        }).toList();

        if (eligible.isEmpty) {
          warnings.add('$dateStr ${shiftType.name}: 배정 가능한 멤버가 없습니다');
          continue;
        }

        // 근무 횟수가 적은 멤버 우선 배정
        eligible.sort((a, b) {
          final aCount = memberShiftCount[a.userId] ?? 0;
          final bCount = memberShiftCount[b.userId] ?? 0;
          if (aCount != bCount) return aCount.compareTo(bCount);
          return random.nextBool() ? 1 : -1;
        });

        final assignCount = min(minStaffPerShift, eligible.length);
        for (int i = 0; i < assignCount; i++) {
          final member = eligible[i];

          shifts.add({
            'schedule_id': scheduleId,
            'team_id': teamId,
            'user_id': member.userId,
            'shift_date': dateStr,
            'shift_type_id': shiftType.id,
          });

          memberShiftCount[member.userId] =
              (memberShiftCount[member.userId] ?? 0) + 1;
          if (isNight) {
            memberNightCount[member.userId] =
                (memberNightCount[member.userId] ?? 0) + 1;
          }

          // 연속 근무 체크
          final lastWorked = memberLastWorked[member.userId];
          if (lastWorked != null &&
              date.difference(lastWorked).inDays == 1) {
            memberConsecutive[member.userId] =
                (memberConsecutive[member.userId] ?? 0) + 1;
          } else {
            memberConsecutive[member.userId] = 1;
          }
          memberLastWorked[member.userId] = date;
        }

        if (assignCount < minStaffPerShift) {
          warnings.add(
              '$dateStr ${shiftType.name}: 최소 인원($minStaffPerShift) 미충족 ($assignCount명 배정)');
        }
      }
    }

    return _GenerationResult(shifts: shifts, warnings: warnings);
  }
}

class _GenerationResult {
  _GenerationResult({required this.shifts, required this.warnings});
  final List<Map<String, dynamic>> shifts;
  final List<String> warnings;
}
