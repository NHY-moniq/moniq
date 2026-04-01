import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:moniq/core/utils/color_utils.dart';
import 'package:moniq/data/datasources/device_calendar_data_source.dart';
import 'package:moniq/data/datasources/personal_event_local_data_source.dart';
import 'package:moniq/data/providers/settings_providers.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/viewmodels/home_viewmodel.dart';

import 'calendar_dialogs.dart';
import 'calendar_providers.dart';

Future<File> generateCalendarImage(
    HomeCalendarState state, WidgetRef ref) async {
  final focusedMonth = state.focusedMonth;
  final eventDs = ref.read(personalEventDataSourceProvider);
  final daysInMonth =
      DateTime(focusedMonth.year, focusedMonth.month + 1, 0).day;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  const width = 800.0;
  const headerH = 70.0;
  const dowH = 32.0;
  const rowH = 90.0;
  const cellW = width / 7;
  final firstWeekday =
      DateTime(focusedMonth.year, focusedMonth.month, 1).weekday - 1;
  final rows = ((daysInMonth + firstWeekday) / 7).ceil();
  final height = headerH + dowH + (rows * rowH) + 24;

  // 배경
  final bgPaint = Paint()..color = Colors.white;
  canvas.drawRRect(
    RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, width, height), const Radius.circular(16)),
    bgPaint,
  );

  // 헤더 타이틀
  final headerPainter = TextPainter(
    text: TextSpan(
      text: '${focusedMonth.year}년 ${focusedMonth.month}월',
      style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: Colors.black87),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  headerPainter.paint(
      canvas, Offset((width - headerPainter.width) / 2, 22));

  // 요일 헤더
  const days = ['월', '화', '수', '목', '금', '토', '일'];
  for (int i = 0; i < 7; i++) {
    Color dowColor;
    if (i == 6) {
      dowColor = const Color(0xCCE53E3E); // 일요일
    } else if (i == 5) {
      dowColor = const Color(0xFF5A8BB5); // 토요일
    } else {
      dowColor = const Color(0xFF9CA3AF);
    }
    final tp = TextPainter(
      text: TextSpan(
        text: days[i],
        style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600, color: dowColor),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
        canvas, Offset(cellW * i + (cellW - tp.width) / 2, headerH + 6));
  }

  // 셀 그리기
  final today = DateTime.now();
  final todayKey = DateTime(today.year, today.month, today.day);

  for (int d = 1; d <= daysInMonth; d++) {
    final date = DateTime(focusedMonth.year, focusedMonth.month, d);
    final col = (firstWeekday + d - 1) % 7;
    final row = (firstWeekday + d - 1) ~/ 7;
    final x = cellW * col;
    final y = headerH + dowH + row * rowH;

    final isToday = date == todayKey;
    final shifts = state.monthlyShifts[date];
    final events = eventDs.getEvents(date);
    final hasContent =
        (shifts != null && shifts.isNotEmpty) || events.isNotEmpty;

    // 날짜 숫자 색상
    Color dayColor;
    if (col == 6) {
      dayColor = const Color(0xCCE53E3E);
    } else if (col == 5) {
      dayColor = const Color(0xFF5A8BB5);
    } else {
      dayColor = Colors.black87;
    }

    // 오늘 날짜 배경 원
    if (isToday) {
      final circlePaint = Paint()..color = const Color(0x33E8923A);
      canvas.drawCircle(Offset(x + cellW / 2, y + 16), 14, circlePaint);
      dayColor = const Color(0xFFE8923A);
    }

    // 날짜 숫자 — 일정이 있으면 상단, 없으면 중앙
    final dayTextY = hasContent ? y + 4 : y + 10;
    final dayPainter = TextPainter(
      text: TextSpan(
        text: '$d',
        style: TextStyle(
          fontSize: 13,
          fontWeight: (isToday) ? FontWeight.w700 : FontWeight.normal,
          color: dayColor,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    dayPainter.paint(
        canvas, Offset(x + (cellW - dayPainter.width) / 2, dayTextY));

    // 미리보기 태그들 (근무 우선, 최대 3개)
    double tagY = dayTextY + 20;
    int tagCount = 0;

    // 근무 일정 태그
    if (shifts != null && shifts.isNotEmpty) {
      for (final s in shifts) {
        if (tagCount >= 3) break;
        final shiftColor = parseHexColor(s.shiftType.color);
        drawPreviewTag(
            canvas, x, tagY, cellW, s.shiftType.name, shiftColor,
            isWork: true);
        tagY += 16;
        tagCount++;
      }
    }

    // 개인 일정 태그
    if (events.isNotEmpty) {
      for (final e in events) {
        if (tagCount >= 3) break;
        final eventColor = e.color != null
            ? parseHexColor(e.color!)
            : const Color(0xFF38A169);
        drawPreviewTag(canvas, x, tagY, cellW, e.title, eventColor,
            isWork: false);
        tagY += 16;
        tagCount++;
      }
    }
  }

  final picture = recorder.endRecording();
  final img = await picture.toImage(width.toInt(), height.toInt());
  final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
  final bytes = byteData!.buffer.asUint8List();

  final dir = await getTemporaryDirectory();
  final file = File(
      '${dir.path}/moniq_${focusedMonth.year}_${focusedMonth.month}.png');
  await file.writeAsBytes(bytes);
  return file;
}

/// 내보내기 이미지용 미리보기 태그 그리기
void drawPreviewTag(Canvas canvas, double x, double y, double cellW,
    String text, Color color,
    {required bool isWork}) {
  const tagH = 14.0;
  const hPad = 4.0;
  final tagW = cellW - 8;
  final tagX = x + 4;

  // 배경 라운드 사각형
  final bgPaint = Paint()
    ..color = color.withValues(alpha: isWork ? 0.25 : 0.15);
  final rrect = RRect.fromRectAndRadius(
    Rect.fromLTWH(tagX, y, tagW, tagH),
    const Radius.circular(3),
  );
  canvas.drawRRect(rrect, bgPaint);

  // 근무 일정은 테두리 추가
  if (isWork) {
    final borderPaint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    canvas.drawRRect(rrect, borderPaint);
  }

  // 텍스트
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontSize: 9,
        color: color,
        fontWeight: isWork ? FontWeight.w700 : FontWeight.w500,
      ),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: '..',
  )..layout(maxWidth: tagW - hPad * 2);
  tp.paint(canvas,
      Offset(tagX + (tagW - tp.width) / 2, y + (tagH - tp.height) / 2));
}

Future<void> exportCalendar(
    BuildContext context, WidgetRef ref, HomeCalendarState state) async {
  final format = await showDialog<String>(
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
      ],
    ),
  );

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
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('내보내기 실패: $e')),
      );
    }
  }
}

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
        SimpleDialogOption(
          child: ListTile(
            leading: Icon(Icons.event, color: Colors.grey),
            title: Text('Google 캘린더',
                style: TextStyle(color: Colors.grey)),
            subtitle: const Text('추후 지원 예정'),
            contentPadding: EdgeInsets.zero,
          ),
          onPressed: () {
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Google 캘린더 연동은 추후 지원 예정입니다')),
            );
          },
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
