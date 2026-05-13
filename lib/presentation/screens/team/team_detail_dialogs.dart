import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:moniq/core/utils/team_icon_utils.dart';
import 'package:moniq/data/providers/schedule_providers.dart';
import 'package:moniq/data/repositories/schedule_repository.dart';
import 'package:moniq/data/providers/supabase_providers.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/widgets/common/moniq_bottom_sheet.dart';
import 'package:moniq/presentation/viewmodels/home_viewmodel.dart';
import 'package:moniq/presentation/viewmodels/team_calendar_viewmodel.dart';
import 'package:moniq/presentation/viewmodels/team_detail_viewmodel.dart';
import 'package:moniq/presentation/viewmodels/team_viewmodel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Confirm leave team dialog (handles lastAdmin, onlyMember, canLeave cases)
void showConfirmLeaveDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String teamId,
  required TeamDetailState state,
}) {
  final notifier = ref.read(teamDetailViewModelProvider(teamId).notifier);
  final result = notifier.checkLeaveCondition();

  switch (result) {
    case LeaveResult.lastAdmin:
      // 유일한 관리자 -> 위임 안내
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('관리자 위임 필요'),
          content: const Text(
            '팀에 관리자가 최소 1명 필요합니다.\n'
            '다른 멤버를 관리자로 지정한 후 나갈 수 있습니다.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('닫기'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.push('/teams/$teamId/members');
              },
              child: const Text('멤버 관리로 이동'),
            ),
          ],
        ),
      );

    case LeaveResult.onlyMember:
      // 혼자 남은 팀 -> 삭제 시도하지 않고 안내만
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('팀 나가기 불가'),
          content: const Text(
            '혼자 남으셨습니다. 팀 제거를 해주세요.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('확인'),
            ),
          ],
        ),
      );

    case LeaveResult.canLeave:
      // 일반 나가기
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('팀 나가기'),
          content: Text('${state.team.name} 팀에서 나가시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await notifier.leaveTeam();
                  ref.invalidate(teamViewModelProvider);
                  ref.invalidate(favoriteTeamProvider);
                  if (context.mounted) context.go('/teams');
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('팀 나가기에 실패했습니다: $e'),
                      ),
                    );
                  }
                }
              },
              child: Text(
                '나가기',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          ],
        ),
      );
  }
}

/// Confirm delete team dialog
void showConfirmDeleteDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String teamId,
  required TeamDetailState state,
}) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('팀 삭제'),
      content: Text(
        '${state.team.name} 팀을 삭제하시겠습니까?\n'
        '모든 멤버가 더 이상 이 팀에 접근할 수 없습니다.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop(ctx);
            try {
              await ref
                  .read(teamDetailViewModelProvider(teamId).notifier)
                  .deleteTeam();
              ref.invalidate(teamViewModelProvider);
              ref.invalidate(favoriteTeamProvider);
              if (context.mounted) context.go('/teams');
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('팀 삭제에 실패했습니다: $e')),
                );
              }
            }
          },
          child: Text(
            '삭제',
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Delete schedule by month bottom sheet
void showDeleteScheduleSheet({
  required BuildContext context,
  WidgetRef? ref,
  ScheduleRepository? scheduleRepo,
  required String teamId,
  required TeamDetailState state,
}) {
  // ref 또는 scheduleRepo 중 하나는 반드시 제공되어야 함
  final ScheduleRepository repo =
      scheduleRepo ?? ref!.read(scheduleRepositoryProvider);
  final now = DateTime.now();
  DateTime selectedDate = DateTime(now.year, now.month);

  showModalBottomSheet(
    context: context,
    // 루트 네비게이터로 띄워 하단 탭바 위에 표시 (탭바 가림)
    useRootNavigator: true,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (ctx) => SizedBox(
      height: 350,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('취소'),
                ),
                Text('삭제할 연월 선택',
                    style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        )),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final year = selectedDate.year;
                    final month = selectedDate.month;

                    // 2차 확인
                    final confirm = await showMoniqDestructiveConfirm(
                      context: context,
                      title: '정말 삭제하시겠습니까?',
                      message:
                          '$year년 $month월의 모든 팀 일정이\n삭제되며 복구할 수 없습니다.',
                    );
                    if (!confirm) return;

                    try {
                      await repo.deleteSchedulesByMonth(
                        teamId: teamId,
                        year: year,
                        month: month,
                      );
                      // 삭제 후 팀 캘린더/팀 상세/개인 캘린더 자동 리프레시.
                      if (ref != null) {
                        try {
                          await ref
                              .read(teamCalendarViewModelProvider(teamId)
                                  .notifier)
                              .refresh();
                        } catch (_) {}
                        ref.invalidate(teamDetailViewModelProvider(teamId));
                        // 개인 캘린더의 monthlyShifts도 함께 갱신
                        try {
                          await ref
                              .read(homeViewModelProvider.notifier)
                              .refresh();
                        } catch (_) {}
                      }
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                '$year년 $month월 일정이 삭제되었습니다'),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('삭제 실패: $e')),
                        );
                      }
                    }
                  },
                  child: Text('삭제',
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .error,
                      )),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.monthYear,
              initialDateTime: now,
              minimumDate: DateTime(now.year - 1),
              maximumDate: DateTime(now.year + 2),
              onDateTimeChanged: (dt) {
                selectedDate = dt;
              },
            ),
          ),
        ],
      ),
    ),
  );
}

/// Edit team info bottom sheet
void showEditTeamSheet({
  required BuildContext context,
  required WidgetRef ref,
  required String teamId,
  required TeamDetailState state,
}) {
  final nameController = TextEditingController(text: state.team.name);
  final descController =
      TextEditingController(text: state.team.description ?? '');
  Uint8List? pickedImageBytes;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheetState) => Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.xxl,
          right: AppSpacing.xxl,
          top: AppSpacing.xxl,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('팀 정보 수정',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    )),
            const SizedBox(height: AppSpacing.xxl),

            // 프로필 이미지
            Center(
              child: GestureDetector(
                onTap: () async {
                  final picker = ImagePicker();
                  final picked = await picker.pickImage(
                    source: ImageSource.gallery,
                    maxWidth: 400,
                    maxHeight: 400,
                    imageQuality: 80,
                  );
                  if (picked != null) {
                    final bytes = await picked.readAsBytes();
                    setSheetState(() {
                      pickedImageBytes = bytes;
                    });
                  }
                },
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: Theme.of(ctx)
                          .colorScheme
                          .primaryContainer,
                      backgroundImage: pickedImageBytes != null
                          ? MemoryImage(pickedImageBytes!)
                          : (state.team.icon != null &&
                                  state.team.icon!.startsWith('http'))
                              ? NetworkImage(state.team.icon!)
                              : null,
                      child: (pickedImageBytes == null &&
                              (state.team.icon == null ||
                                  !state.team.icon!.startsWith('http')))
                          ? TeamProfileAvatar(
                              icon: state.team.icon, radius: 44)
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Theme.of(ctx)
                              .colorScheme
                              .primary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.camera_alt,
                            size: 14,
                            color: Theme.of(ctx)
                                .colorScheme
                                .surface),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),

            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '팀 이름',
                hintText: '팀 이름을 입력하세요',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: '팀 설명',
                hintText: '간단한 설명을 입력하세요 (선택)',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: AppSpacing.xxl),
            ElevatedButton(
              onPressed: () async {
                String? iconUrl;

                // 이미지 업로드 (자기 userId 폴더 아래)
                if (pickedImageBytes != null) {
                  try {
                    final client = ref.read(supabaseClientProvider);
                    final userId = client.auth.currentUser!.id;
                    final path =
                        '$userId/team_${state.team.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
                    await client.storage.from('avatars').uploadBinary(
                          path,
                          pickedImageBytes!,
                          fileOptions:
                              const FileOptions(upsert: true),
                        );
                    iconUrl = client.storage
                        .from('avatars')
                        .getPublicUrl(path);
                  } catch (_) {}
                }

                await ref
                    .read(teamDetailViewModelProvider(teamId).notifier)
                    .updateTeam(
                      name: nameController.text.trim(),
                      description: descController.text.trim(),
                      icon: iconUrl,
                    );
                ref.invalidate(teamViewModelProvider);
                ref.invalidate(favoriteTeamProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    ),
  );
}
