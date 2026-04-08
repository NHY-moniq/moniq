import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:moniq/data/datasources/device_calendar_data_source.dart';
import 'package:moniq/data/datasources/personal_event_local_data_source.dart';
import 'package:moniq/data/providers/settings_providers.dart';
import 'package:moniq/data/repositories/team_repository.dart';

import 'calendar_providers.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/viewmodels/home_viewmodel.dart';
import 'package:moniq/presentation/viewmodels/team_calendar_viewmodel.dart';

import 'calendar_dialogs.dart';
import 'calendar_export_excel.dart';
import 'calendar_export_image.dart';

/// 개인 캘린더 내보내기 (다이얼로그 -> 형식 선택 -> 실행)
Future<void> exportCalendar(
    BuildContext context, WidgetRef ref, HomeCalendarState state) async {
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
  final format = await _showExportFormatDialog(context);
  if (format == null || !context.mounted) return;

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

// ── 공통 다이얼로그 ──────────────────────────────

/// 내보내기 형식 선택 다이얼로그 (앨범/공유/엑셀)
Future<String?> _showExportFormatDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: const Text('내보내기 형식 선택'),
      children: [
        SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, 'album'),
          child: const ListTile(
            leading:
                Icon(Icons.photo_album_outlined, color: AppColors.primary),
            title: Text('앨범에 저장'),
            subtitle: Text('캘린더 이미지를 사진 앨범에 저장'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, 'share'),
          child: const ListTile(
            leading:
                Icon(Icons.share_outlined, color: AppColors.tertiary),
            title: Text('이미지 공유하기'),
            subtitle: Text('카카오톡, 메시지 등으로 캘린더 이미지 공유'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, 'excel'),
          child: const ListTile(
            leading:
                Icon(Icons.table_chart_outlined, color: Color(0xFF217346)),
            title: Text('Excel로 내보내기'),
            subtitle: Text('엑셀/구글 스프레드시트용 .xlsx 파일'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    ),
  );
}
