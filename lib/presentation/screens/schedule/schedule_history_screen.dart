import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/models/schedule_model.dart';
import 'package:moniq/data/models/shift_model.dart';
import 'package:moniq/data/models/shift_type_model.dart';
import 'package:moniq/data/models/team_member_with_user.dart';
import 'package:moniq/data/providers/schedule_providers.dart';
import 'package:moniq/data/providers/shift_providers.dart';
import 'package:moniq/data/providers/team_providers.dart';
import 'package:moniq/presentation/screens/schedule/widgets/schedule_history_widgets.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/widgets/common/moniq_app_bar.dart';
import 'package:moniq/presentation/widgets/common/moniq_error_view.dart';
import 'package:moniq/presentation/widgets/common/moniq_loading_view.dart';

// ── Provider: 팀의 스케줄 버전 목록 ──
final scheduleVersionsProvider =
    FutureProvider.family<List<ScheduleModel>, String>((ref, teamId) async {
  final repo = ref.watch(scheduleRepositoryProvider);
  return repo.getSchedules(teamId);
});

// ── Provider: 팀의 시프트 타입 ──
final shiftTypesForTeamProvider =
    FutureProvider.autoDispose.family<List<ShiftTypeModel>, String>(
  (ref, teamId) => ref.watch(shiftRepositoryProvider).getShiftTypes(teamId),
);

// ── Provider: 스케줄 상세 (시프트 목록) ──
final scheduleDetailProvider = FutureProvider.autoDispose
    .family<ScheduleDetail, String>((ref, scheduleId) async {
  final shiftRepo = ref.watch(scheduleRepositoryProvider);
  final shifts = await shiftRepo.getShiftsBySchedule(scheduleId);
  return ScheduleDetail(shifts: shifts);
});

class ScheduleDetail {
  ScheduleDetail({required this.shifts});
  final List<ShiftModel> shifts;
}

// ── Provider: 팀 멤버 ──
final teamMembersWithUsersProvider =
    FutureProvider.family<List<TeamMemberWithUser>, String>(
        (ref, teamId) async {
  final repo = ref.watch(teamRepositoryProvider);
  return repo.getTeamMembersWithUsers(teamId);
});

// ────────────────────────────────────────
// 히스토리 목록 화면
// ────────────────────────────────────────

class ScheduleHistoryScreen extends ConsumerWidget {
  const ScheduleHistoryScreen({super.key, required this.teamId});
  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final versionsAsync = ref.watch(scheduleVersionsProvider(teamId));

    return Scaffold(
      appBar: const MoniqAppBar(title: '근무표 히스토리'),
      body: versionsAsync.when(
        loading: () => const MoniqLoadingView(),
        error: (e, _) => MoniqErrorView(
          message: '불러올 수 없습니다',
          onRetry: () => ref.invalidate(scheduleVersionsProvider(teamId)),
        ),
        data: (versions) {
          if (versions.isEmpty) {
            return const Center(child: Text('생성된 근무표가 없습니다'));
          }
          return ListView.separated(
            padding: AppSpacing.screenAll,
            itemCount: versions.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: AppSpacing.md),
            itemBuilder: (_, i) => ScheduleHistoryVersionCard(
              schedule: versions[i],
              teamId: teamId,
            ),
          );
        },
      ),
    );
  }
}

// ────────────────────────────────────────
// 버전 상세 화면
// ────────────────────────────────────────

class ScheduleVersionDetailScreen extends ConsumerWidget {
  const ScheduleVersionDetailScreen({
    super.key,
    required this.teamId,
    required this.scheduleId,
  });
  final String teamId;
  final String scheduleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final versionsAsync = ref.watch(scheduleVersionsProvider(teamId));
    final detailAsync = ref.watch(scheduleDetailProvider(scheduleId));
    final membersAsync = ref.watch(teamMembersWithUsersProvider(teamId));
    final shiftTypesAsync = ref.watch(shiftTypesForTeamProvider(teamId));

    final detailTitle = versionsAsync.maybeWhen(
      data: (versions) {
        final s = versions.firstWhere(
          (v) => v.id == scheduleId,
          orElse: () => versions.first,
        );
        return 'v${s.versionNo} 근무표';
      },
      orElse: () => '근무표',
    );

    return Scaffold(
      appBar: MoniqAppBar(title: detailTitle),
      body: detailAsync.when(
        loading: () => const MoniqLoadingView(),
        error: (e, _) => MoniqErrorView(
          message: '불러올 수 없습니다',
          onRetry: () => ref.invalidate(scheduleDetailProvider(scheduleId)),
        ),
        data: (detail) => membersAsync.when(
          loading: () => const MoniqLoadingView(),
          error: (e, _) => const MoniqErrorView(message: '멤버 정보 오류'),
          data: (members) => ScheduleHistoryDetailBody(
            shifts: detail.shifts,
            members: members,
            shiftTypes: shiftTypesAsync.valueOrNull ?? const [],
          ),
        ),
      ),
    );
  }
}
