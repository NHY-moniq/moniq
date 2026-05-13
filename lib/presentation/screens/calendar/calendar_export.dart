import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:moniq/data/datasources/device_calendar_data_source.dart';
import 'package:moniq/data/datasources/personal_event_local_data_source.dart';
import 'package:moniq/data/datasources/personal_event_remote_data_source.dart';
import 'package:moniq/data/providers/settings_providers.dart';
import 'package:moniq/data/providers/shift_providers.dart';
import 'package:moniq/data/repositories/team_repository.dart';

import 'calendar_providers.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/home_viewmodel.dart';
import 'package:moniq/presentation/viewmodels/team_calendar_viewmodel.dart';
import 'package:moniq/presentation/widgets/common/moniq_bottom_sheet.dart';

import 'calendar_dialogs.dart';
import 'calendar_export_excel.dart';
import 'calendar_export_image.dart';
import 'calendar_export_downloader_stub.dart'
    if (dart.library.html) 'calendar_export_downloader_web.dart';

/// 개인 캘린더 내보내기 (플랫폼별 분기)
Future<void> exportCalendar(
    BuildContext context, WidgetRef ref, HomeCalendarState state) async {
  if (kIsWeb) return _exportCalendarWeb(context, ref, state);

  final format = await _showExportFormatDialog(context);
  if (format == null || !context.mounted) return;

  try {
    final file = await generateCalendarImage(state, ref);
    final focusedMonth = state.focusedMonth;

    if (format == 'album') {
      final result = await ImageGallerySaverPlus.saveFile(file.path);
      if (context.mounted) {
        final success = result['isSuccess'] == true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(success ? '앨범에 저장되었습니다' : '저장에 실패했습니다')),
        );
      }
    } else if (format == 'share') {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject:
              'Moniq ${focusedMonth.year}년 ${focusedMonth.month}월 일정',
        ),
      );
    } else if (format == 'excel') {
      final excelFile = await generateExcelFile(state, ref);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(excelFile.path)],
          subject:
              'OnorOff ${focusedMonth.year}년 ${focusedMonth.month}월 일정',
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('내보내기 실패: $e')),
      );
    }
  }
}

/// 디바이스 캘린더에서 일정 가져오기
Future<void> importDeviceCalendar(
    BuildContext context, WidgetRef ref) async {
  // 캘린더 소스 선택 다이얼로그
  final source = await showDialog<String>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: const Text('가져올 캘린더 선택'),
      children: [
        SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, 'device'),
          child: const ListTile(
            leading:
                Icon(Icons.calendar_month, color: AppColors.primary),
            title: Text('기본 캘린더'),
            subtitle: Text('iPhone 기본 캘린더에서 가져오기'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    ),
  );

  if (source != 'device' || !context.mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
        content: Text('캘린더에서 일정을 가져오는 중...'),
        duration: Duration(seconds: 1)),
  );

  try {
    final ds = ref.read(deviceCalendarDataSourceProvider);
    final granted = await ds.requestPermission();
    if (!granted) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('캘린더 접근 권한이 필요합니다. 설정에서 권한을 허용해주세요.')),
        );
      }
      return;
    }

    // 1년치 이벤트 가져오기
    final now = DateTime.now();
    final allEvents = <DeviceCalendarEvent>[];
    for (int i = 0; i < 12; i++) {
      final month = DateTime(now.year, now.month + i, 1);
      final monthEvents = await ds.getEventsForMonth(month);
      allEvents.addAll(monthEvents);
    }

    if (allEvents.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('신규로 추가할 일정이 없습니다')),
        );
      }
      return;
    }

    final events = allEvents;

    final eventDs = ref.read(personalEventDataSourceProvider);
    int imported = 0;

    for (final event in events) {
      final existing = eventDs.getEvents(event.date);
      final isDuplicate = existing.any((e) => e.title == event.title);

      if (!isDuplicate) {
        await eventDs.addEvent(PersonalEvent(
          date: event.date,
          title: event.title,
          startTime: event.startTime,
          endTime: event.endTime,
          description: event.calendarName,
          color: event.color ?? '#5A8BB5',
          createdAt: DateTime.now(),
        ));
        imported++;
      }
    }

    refreshAll(ref, DateTime.now());

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(imported > 0
              ? '$imported건의 일정을 가져왔습니다'
              : '신규로 추가할 일정이 없습니다 (이미 등록됨)'),
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류가 발생했습니다: $e')),
      );
    }
  }
}

// ====================================================
// 팀 캘린더 내보내기
// ====================================================

/// 팀 캘린더 내보내기 (ref 사용)
Future<void> exportTeamCalendar(
    BuildContext context, WidgetRef ref, TeamCalendarState state) async {
  if (kIsWeb) return _exportTeamCalendarWeb(context, ref, state);

  // 팀 캘린더에서는 "개인 캘린더로 가져오기" 옵션을 항상 활성 상태로 노출.
  // 비즐겨찾기 팀일 경우엔 import 진행 전 별도 확인 모달을 띄움.
  final favoriteTeam = ref.read(favoriteTeamProvider).valueOrNull;
  final isFavorite = favoriteTeam?.id == state.teamId;

  final format = await _showExportFormatDialog(
    context,
    showImportToPersonal: true,
    importToPersonalEnabled: true,
  );
  if (format == null || !context.mounted) return;

  if (format == 'import_personal') {
    if (!isFavorite) {
      final ok = await showMoniqInfoConfirm(
        context: context,
        title: '즐겨찾기 팀이 아닙니다',
        message: '${state.teamName}은(는) 즐겨찾기 팀이 아닙니다.\n'
            '그래도 이 팀의 근무를 개인 캘린더로 가져올까요?',
        confirmLabel: '진행',
        cancelLabel: '취소',
      );
      if (!ok || !context.mounted) return;
    }
    await _importTeamShiftsToPersonal(context, ref, state);
    return;
  }

  try {
    final focusedMonth = state.focusedMonth;

    if (format == 'excel') {
      final excelFile = await generateTeamExcelFile(state, ref);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(excelFile.path)],
          subject:
              '${state.teamName} ${focusedMonth.year}년 ${focusedMonth.month}월 근무표',
        ),
      );
    } else {
      final file = await generateTeamCalendarImage(state, ref);
      if (format == 'album') {
        final result = await ImageGallerySaverPlus.saveFile(file.path);
        if (context.mounted) {
          final success = result['isSuccess'] == true;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text(success ? '앨범에 저장되었습니다' : '저장에 실패했습니다')),
          );
        }
      } else if (format == 'share') {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            subject:
                '${state.teamName} ${focusedMonth.year}년 ${focusedMonth.month}월 근무표',
          ),
        );
      }
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('내보내기 실패: $e')),
      );
    }
  }
}

/// 팀 캘린더의 내 근무를 개인 캘린더로 import.
///
/// - 기존 team-import 이벤트(description이 [kPersonalTeamImportMarker]로 시작)는
///   모두 삭제되고, 사용자가 직접 추가한 개인 이벤트는 보존된다.
/// - 새 이벤트는 본인이 해당 팀에 배정된 shift를 기준으로 생성된다.
/// - 가져올 범위: 오늘 기준 -1개월 ~ +12개월.
Future<void> _importTeamShiftsToPersonal(
  BuildContext context,
  WidgetRef ref,
  TeamCalendarState state,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final confirm = await showMoniqInfoConfirm(
    context: context,
    title: '개인 캘린더로 가져오기',
    message: '${state.teamName} 팀의 내 근무를 개인 캘린더에 추가합니다.\n\n'
        '이전에 팀에서 가져온 근무는 모두 삭제되고\n'
        '새 근무로 대체됩니다. 직접 추가한 일정은 보존됩니다.',
    confirmLabel: '가져오기',
    cancelLabel: '취소',
    icon: Icons.event_repeat_outlined,
  );
  if (!confirm || !context.mounted) return;

  try {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month - 1, 1);
    final end = DateTime(now.year, now.month + 13, 0);

    final shiftRepo = ref.read(shiftRepositoryProvider);
    final myShifts = await shiftRepo.getMyShiftsForTeam(
      teamId: state.teamId,
      start: start,
      end: end,
    );

    // 각 shift → PersonalEvent. description에 import 마커 포함.
    final events = myShifts.map((sw) {
      return PersonalEvent(
        date: DateTime(
          sw.shift.shiftDate.year,
          sw.shift.shiftDate.month,
          sw.shift.shiftDate.day,
        ),
        title: sw.shiftType.name,
        startTime: sw.shiftType.startTime,
        endTime: sw.shiftType.endTime,
        color: sw.shiftType.color,
        description: '$kPersonalTeamImportMarker:${state.teamId}',
        createdAt: DateTime.now(),
      );
    }).toList();

    final eventDs = ref.read(personalEventDataSourceProvider);
    final inserted = await eventDs.replaceTeamImports(events);

    // 개인 캘린더 화면 캐시 무효화
    ref.read(eventRefreshProvider.notifier).state++;
    ref.invalidate(monthlyEventsProvider);
    ref.invalidate(dateEventsProvider);
    // 홈 캘린더 자체 데이터(shift) 갱신
    try {
      await ref.read(homeViewModelProvider.notifier).refresh();
    } catch (_) {}

    if (context.mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('개인 캘린더로 $inserted건의 근무를 가져왔습니다'),
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text('가져오기 실패: $e')),
      );
    }
  }
}

/// ref 없이 동작하는 팀 캘린더 내보내기 (드로어에서 호출용)
Future<void> exportTeamCalendarStandalone(
    BuildContext context,
    TeamCalendarState state,
    TeamRepository teamRepo) async {
  final format = await _showExportFormatDialog(context);
  if (format == null || !context.mounted) return;

  // 멤버 이름 맵
  final members = await teamRepo.getTeamMembersWithUsers(state.teamId);
  final memberNames = <String, String>{};
  for (final m in members) {
    memberNames[m.userId] = m.displayName;
  }

  try {
    final focusedMonth = state.focusedMonth;

    if (format == 'excel') {
      final excelFile =
          await generateTeamExcelWithNames(state, memberNames);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(excelFile.path)],
          subject:
              '${state.teamName} ${focusedMonth.year}년 ${focusedMonth.month}월 근무표',
        ),
      );
    } else {
      final file =
          await generateTeamImageWithNames(state, memberNames);
      if (format == 'album') {
        final result = await ImageGallerySaverPlus.saveFile(file.path);
        if (context.mounted) {
          final success = result['isSuccess'] == true;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text(success ? '앨범에 저장되었습니다' : '저장에 실패했습니다')),
          );
        }
      } else if (format == 'share') {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            subject:
                '${state.teamName} ${focusedMonth.year}년 ${focusedMonth.month}월 근무표',
          ),
        );
      }
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('내보내기 실패: $e')),
      );
    }
  }
}

// ── 웹 내보내기 ──────────────────────────────────

Future<void> _exportTeamCalendarWeb(
    BuildContext context, WidgetRef ref, TeamCalendarState state) async {
  final format = await _showWebExportDialog(context);
  if (format == null || !context.mounted) return;

  final focusedMonth = state.focusedMonth;
  final yearMonth =
      '${focusedMonth.year}_${focusedMonth.month.toString().padLeft(2, '0')}';
  final teamName = state.teamName;

  try {
    if (format == 'clipboard') {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('이미지 생성 중…'), duration: Duration(seconds: 1)),
      );
      final bytes = await generateTeamImageBytes(state, ref);
      final copied = await copyImageToClipboard(bytes);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              copied ? '클립보드에 복사되었습니다' : '클립보드 복사를 지원하지 않는 브라우저입니다',
            ),
          ),
        );
      }
    } else if (format == 'image') {
      final bytes = await generateTeamImageBytes(state, ref);
      await downloadFileWeb('${teamName}_$yearMonth.png', bytes, 'image/png');
    } else if (format == 'excel') {
      final bytes = await generateTeamExcelBytes(state, ref);
      await downloadFileWeb(
        '${teamName}_$yearMonth.xlsx',
        bytes,
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('내보내기 실패: $e')));
    }
  }
}

Future<void> _exportCalendarWeb(
    BuildContext context, WidgetRef ref, HomeCalendarState state) async {
  final format = await _showWebExportDialog(context);
  if (format == null || !context.mounted) return;

  final focusedMonth = state.focusedMonth;
  final yearMonth =
      '${focusedMonth.year}_${focusedMonth.month.toString().padLeft(2, '0')}';

  try {
    if (format == 'clipboard') {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미지 생성 중…'), duration: Duration(seconds: 1)),
      );
      final bytes = await generateCalendarImageBytes(state, ref);
      final copied = await copyImageToClipboard(bytes);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              copied ? '클립보드에 복사되었습니다' : '클립보드 복사를 지원하지 않는 브라우저입니다',
            ),
          ),
        );
      }
    } else if (format == 'image') {
      final bytes = await generateCalendarImageBytes(state, ref);
      await downloadFileWeb('calendar_$yearMonth.png', bytes, 'image/png');
    } else if (format == 'excel') {
      final bytes = await generateExcelBytes(state, ref);
      await downloadFileWeb(
        'calendar_$yearMonth.xlsx',
        bytes,
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('내보내기 실패: $e')));
    }
  }
}

Future<String?> _showWebExportDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: const Text('내보내기'),
      children: [
        SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, 'clipboard'),
          child: const ListTile(
            leading: Icon(Icons.content_copy_outlined, color: AppColors.primary),
            title: Text('클립보드에 복사'),
            subtitle: Text('캘린더 이미지를 클립보드에 복사'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, 'image'),
          child: const ListTile(
            leading: Icon(Icons.image_outlined, color: AppColors.tertiary),
            title: Text('이미지 저장'),
            subtitle: Text('PNG 파일로 다운로드'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, 'excel'),
          child: const ListTile(
            leading: Icon(Icons.table_chart_outlined, color: Color(0xFF217346)),
            title: Text('엑셀로 내보내기'),
            subtitle: Text('엑셀/구글 스프레드시트용 .xlsx 파일'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    ),
  );
}

// ── 공통 다이얼로그 ──────────────────────────────

/// 내보내기 형식 선택 다이얼로그 (앨범/공유/엑셀).
/// [showImportToPersonal]가 true이면 "개인 캘린더로 가져오기" 항목이 노출되며,
/// [importToPersonalEnabled]가 false면 비활성(회색) 상태로 안내된다.
Future<String?> _showExportFormatDialog(
  BuildContext context, {
  bool showImportToPersonal = false,
  bool importToPersonalEnabled = false,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      final cs = theme.colorScheme;
      return Dialog(
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.borderRadiusLg,
        ),
        insetPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl,
          vertical: AppSpacing.xxxl,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: Text(
                  '내보내기',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
              ),
              _ExportOptionTile(
                icon: Icons.photo_album_outlined,
                title: '앨범에 저장',
                subtitle: '캘린더 이미지를 사진 앨범에 저장',
                onTap: () => Navigator.pop(ctx, 'album'),
              ),
              _ExportOptionTile(
                icon: Icons.share_outlined,
                title: '이미지 공유하기',
                subtitle: '카카오톡, 메시지 등으로 캘린더 이미지 공유',
                onTap: () => Navigator.pop(ctx, 'share'),
              ),
              _ExportOptionTile(
                icon: Icons.table_chart_outlined,
                title: 'Excel로 내보내기',
                subtitle: '엑셀/구글 스프레드시트용 .xlsx 파일',
                onTap: () => Navigator.pop(ctx, 'excel'),
              ),
              if (showImportToPersonal)
                _ExportOptionTile(
                  icon: Icons.event_repeat_outlined,
                  title: '개인 캘린더로 가져오기',
                  subtitle: importToPersonalEnabled
                      ? '이 팀의 내 근무를 개인 캘린더에 동기화'
                      : '즐겨찾기한 팀에서만 사용할 수 있어요',
                  onTap: importToPersonalEnabled
                      ? () => Navigator.pop(ctx, 'import_personal')
                      : null,
                ),
            ],
          ),
        ),
      );
    },
  );
}

class _ExportOptionTile extends StatelessWidget {
  const _ExportOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final disabled = onTap == null;
    final iconColor =
        disabled ? cs.onSurface.withValues(alpha: 0.38) : cs.onSurface;
    final titleColor =
        disabled ? cs.onSurface.withValues(alpha: 0.5) : cs.onSurface;
    final subtitleColor = disabled
        ? cs.onSurfaceVariant.withValues(alpha: 0.6)
        : cs.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.borderRadiusMd,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh.withValues(
                  alpha: disabled ? 0.5 : 1,
                ),
                borderRadius: AppRadius.borderRadiusSm,
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                size: 20,
                color: iconColor,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: subtitleColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
