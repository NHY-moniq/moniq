import 'dart:io';
import 'dart:ui' as ui;

import 'package:excel/excel.dart' as xl;
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:moniq/core/utils/color_utils.dart';
import 'package:moniq/data/datasources/device_calendar_data_source.dart';
import 'package:moniq/data/datasources/personal_event_local_data_source.dart';
import 'package:moniq/data/providers/settings_providers.dart';
import 'package:moniq/data/providers/team_providers.dart';
import 'package:moniq/data/repositories/team_repository.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/viewmodels/home_viewmodel.dart';
import 'package:moniq/presentation/viewmodels/team_calendar_viewmodel.dart';

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

  // 아이폰 화면 비율
  const width = 780.0;
  const totalHeight = 1400.0;
  const headerH = 100.0;
  const dowH = 40.0;
  const cellW = width / 7;
  final firstWeekday =
      DateTime(focusedMonth.year, focusedMonth.month, 1).weekday - 1;
  final rows = ((daysInMonth + firstWeekday) / 7).ceil();
  final rowH = (totalHeight - headerH - dowH - 40) / rows;
  const height = totalHeight;

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
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: Colors.black87),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  headerPainter.paint(
      canvas, Offset((width - headerPainter.width) / 2, 32));

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
            fontSize: 18, fontWeight: FontWeight.w600, color: dowColor),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
        canvas, Offset(cellW * i + (cellW - tp.width) / 2, headerH + 8));
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
      canvas.drawCircle(Offset(x + cellW / 2, y + 22), 18, circlePaint);
      dayColor = const Color(0xFFE8923A);
    }

    // 날짜 숫자 — 일정이 있으면 상단, 없으면 중앙
    final dayTextY = hasContent ? y + 8 : y + 16;
    final dayPainter = TextPainter(
      text: TextSpan(
        text: '$d',
        style: TextStyle(
          fontSize: 18,
          fontWeight: (isToday) ? FontWeight.w700 : FontWeight.normal,
          color: dayColor,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    dayPainter.paint(
        canvas, Offset(x + (cellW - dayPainter.width) / 2, dayTextY));

    // 미리보기 태그들 (근무 우선, 최대 4개)
    double tagY = dayTextY + 28;
    int tagCount = 0;

    // 근무 일정 태그
    if (shifts != null && shifts.isNotEmpty) {
      for (final s in shifts) {
        if (tagCount >= 4) break;
        final shiftColor = parseHexColor(s.shiftType.color);
        drawPreviewTag(
            canvas, x, tagY, cellW, s.shiftType.name, shiftColor,
            isWork: true);
        tagY += 22;
        tagCount++;
      }
    }

    // 개인 일정 태그
    if (events.isNotEmpty) {
      for (final e in events) {
        if (tagCount >= 4) break;
        final eventColor = e.color != null
            ? parseHexColor(e.color!)
            : const Color(0xFF38A169);
        drawPreviewTag(canvas, x, tagY, cellW, e.title, eventColor,
            isWork: false);
        tagY += 22;
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
  const tagH = 20.0;
  const hPad = 6.0;
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
        fontSize: 12,
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

/// Excel 파일 생성
Future<File> generateExcelFile(
    HomeCalendarState state, WidgetRef ref) async {
  final focusedMonth = state.focusedMonth;
  final eventDs = ref.read(personalEventDataSourceProvider);
  final daysInMonth =
      DateTime(focusedMonth.year, focusedMonth.month + 1, 0).day;

  final excel = xl.Excel.createExcel();
  final sheetName = '${focusedMonth.year}년 ${focusedMonth.month}월';
  final sheet = excel[sheetName];
  // 기본 시트 제거
  excel.delete('Sheet1');

  // A4 가로 기준 열 너비 (7열 균등 배분)
  for (int i = 0; i < 7; i++) {
    sheet.setColumnWidth(i, 38);
  }

  // ── 타이틀 행 (병합) ──
  final titleCell = sheet.cell(
      xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
  titleCell.value = xl.TextCellValue(
      '${focusedMonth.year}년 ${focusedMonth.month}월 근무표');
  titleCell.cellStyle = xl.CellStyle(
    bold: true,
    fontSize: 16,
    horizontalAlign: xl.HorizontalAlign.Center,
    verticalAlign: xl.VerticalAlign.Center,
  );
  sheet.merge(
    xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
    xl.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: 0),
  );
  sheet.setRowHeight(0, 35);

  // ── 요일 헤더 (2행) ──
  final headerStyle = xl.CellStyle(
    bold: true,
    fontSize: 12,
    horizontalAlign: xl.HorizontalAlign.Center,
    verticalAlign: xl.VerticalAlign.Center,
    backgroundColorHex: xl.ExcelColor.fromHexString('#F0C040'),
    fontColorHex: xl.ExcelColor.fromHexString('#FFFFFF'),
  );

  const dayNames = ['월', '화', '수', '목', '금', '토', '일'];
  for (int i = 0; i < 7; i++) {
    final cell = sheet.cell(
        xl.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 1));
    cell.value = xl.TextCellValue(dayNames[i]);
    cell.cellStyle = i == 5
        ? headerStyle.copyWith(
            fontColorHexVal: xl.ExcelColor.fromHexString('#5A8BB5'))
        : i == 6
            ? headerStyle.copyWith(
                fontColorHexVal: xl.ExcelColor.fromHexString('#E53E3E'))
            : headerStyle;
  }
  sheet.setRowHeight(1, 25);

  // ── 날짜 + 일정 (한 셀에 합쳐서) ──
  final firstWeekday =
      DateTime(focusedMonth.year, focusedMonth.month, 1).weekday - 1;
  final totalRows = ((daysInMonth + firstWeekday) / 7).ceil();

  // 날짜 스타일
  final dateCellStyle = xl.CellStyle(
    fontSize: 11,
    verticalAlign: xl.VerticalAlign.Top,
    textWrapping: xl.TextWrapping.WrapText,
    leftBorder: xl.Border(borderStyle: xl.BorderStyle.Thin),
    rightBorder: xl.Border(borderStyle: xl.BorderStyle.Thin),
    topBorder: xl.Border(borderStyle: xl.BorderStyle.Thin),
    bottomBorder: xl.Border(borderStyle: xl.BorderStyle.Thin),
  );

  final weekendStyle = dateCellStyle.copyWith(
    backgroundColorHexVal: xl.ExcelColor.fromHexString('#FFF5F5'),
  );

  // 각 주의 행 높이 설정 (A4 세로 맞춤)
  final rowHeight = (180.0 / totalRows).clamp(28.0, 80.0);

  for (int d = 1; d <= daysInMonth; d++) {
    final date = DateTime(focusedMonth.year, focusedMonth.month, d);
    final col = (firstWeekday + d - 1) % 7;
    final weekRow = (firstWeekday + d - 1) ~/ 7;
    final excelRow = weekRow + 2; // 타이틀 + 요일 헤더 다음

    sheet.setRowHeight(excelRow, rowHeight);

    // 일정 텍스트 조합
    final shifts = state.monthlyShifts[date];
    final events = eventDs.getEvents(date);
    final items = <String>['$d일'];

    if (shifts != null) {
      for (final s in shifts) {
        items.add('■ ${s.shiftType.name}');
      }
    }
    for (final e in events) {
      final time = e.startTime != null ? '${e.startTime} ' : '';
      items.add('· $time${e.title}');
    }

    final cell = sheet.cell(
        xl.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: excelRow));
    cell.value = xl.TextCellValue(items.join('\n'));
    cell.cellStyle = (col == 5 || col == 6) ? weekendStyle : dateCellStyle;
  }

  // 빈 셀에도 테두리 적용
  for (int r = 0; r < totalRows; r++) {
    for (int c = 0; c < 7; c++) {
      final excelRow = r + 2;
      final cell = sheet.cell(
          xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: excelRow));
      if (cell.value == null) {
        cell.value = xl.TextCellValue('');
        cell.cellStyle = dateCellStyle;
      }
    }
  }

  final dir = await getTemporaryDirectory();
  final file = File(
      '${dir.path}/onoroff_${focusedMonth.year}_${focusedMonth.month}.xlsx');
  final bytes = excel.encode();
  if (bytes != null) {
    await file.writeAsBytes(bytes);
  }
  return file;
}

// ══════════════════════════════════════════════
// 팀 캘린더 내보내기
// ══════════════════════════════════════════════

Future<void> exportTeamCalendar(
    BuildContext context, WidgetRef ref, TeamCalendarState state) async {
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

  if (format == null || !context.mounted) return;

  try {
    final focusedMonth = state.focusedMonth;

    if (format == 'excel') {
      final excelFile = await _generateTeamExcelFile(state, ref);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(excelFile.path)],
          subject:
              '${state.teamName} ${focusedMonth.year}년 ${focusedMonth.month}월 근무표',
        ),
      );
    } else {
      final file = await _generateTeamCalendarImage(state, ref);
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

/// 팀 캘린더 이미지 생성
Future<File> _generateTeamCalendarImage(
    TeamCalendarState state, WidgetRef ref) async {
  // 멤버 이름 맵 조회
  final teamRepo = ref.read(teamRepositoryProvider);
  final members = await teamRepo.getTeamMembersWithUsers(state.teamId);
  final memberNames = <String, String>{};
  for (final m in members) {
    memberNames[m.userId] = m.displayName;
  }
  final focusedMonth = state.focusedMonth;
  final daysInMonth =
      DateTime(focusedMonth.year, focusedMonth.month + 1, 0).day;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  const width = 780.0;
  const totalHeight = 1400.0;
  const headerH = 100.0;
  const dowH = 40.0;
  const cellW = width / 7;
  final firstWeekday =
      DateTime(focusedMonth.year, focusedMonth.month, 1).weekday - 1;
  final rows = ((daysInMonth + firstWeekday) / 7).ceil();
  final rowH = (totalHeight - headerH - dowH - 40) / rows;
  const height = totalHeight;

  // 배경
  final bgPaint = Paint()..color = Colors.white;
  canvas.drawRRect(
    RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, width, height), const Radius.circular(16)),
    bgPaint,
  );

  // 헤더
  final headerPainter = TextPainter(
    text: TextSpan(
      text: '${state.teamName} · ${focusedMonth.year}년 ${focusedMonth.month}월',
      style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: Colors.black87),
    ),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: width - 40);
  headerPainter.paint(
      canvas, Offset((width - headerPainter.width) / 2, 32));

  // 요일 헤더
  const days = ['월', '화', '수', '목', '금', '토', '일'];
  for (int i = 0; i < 7; i++) {
    Color dowColor;
    if (i == 6) {
      dowColor = const Color(0xCCE53E3E);
    } else if (i == 5) {
      dowColor = const Color(0xFF5A8BB5);
    } else {
      dowColor = const Color(0xFF9CA3AF);
    }
    final tp = TextPainter(
      text: TextSpan(
        text: days[i],
        style: TextStyle(
            fontSize: 18, fontWeight: FontWeight.w600, color: dowColor),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
        canvas, Offset(cellW * i + (cellW - tp.width) / 2, headerH + 8));
  }

  // 셀
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
    final hasContent = shifts != null && shifts.isNotEmpty;

    Color dayColor;
    if (col == 6) {
      dayColor = const Color(0xCCE53E3E);
    } else if (col == 5) {
      dayColor = const Color(0xFF5A8BB5);
    } else {
      dayColor = Colors.black87;
    }

    if (isToday) {
      final circlePaint = Paint()..color = const Color(0x33E8923A);
      canvas.drawCircle(Offset(x + cellW / 2, y + 22), 18, circlePaint);
      dayColor = const Color(0xFFE8923A);
    }

    final dayTextY = hasContent ? y + 8 : y + 16;
    final dayPainter = TextPainter(
      text: TextSpan(
        text: '$d',
        style: TextStyle(
          fontSize: 18,
          fontWeight: isToday ? FontWeight.w700 : FontWeight.normal,
          color: dayColor,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    dayPainter.paint(
        canvas, Offset(x + (cellW - dayPainter.width) / 2, dayTextY));

    // 근무 태그 (근무유형 + 담당자 이름)
    double tagY = dayTextY + 28;
    int tagCount = 0;

    if (shifts != null) {
      for (final s in shifts) {
        if (tagCount >= 4) break;
        final shiftColor = parseHexColor(s.shiftType.color);
        final name = memberNames[s.shift.userId] ?? '';
        final label = name.isNotEmpty
            ? '${s.shiftType.name} $name'
            : s.shiftType.name;
        drawPreviewTag(
            canvas, x, tagY, cellW, label, shiftColor,
            isWork: true);
        tagY += 22;
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
      '${dir.path}/team_${state.teamId}_${focusedMonth.year}_${focusedMonth.month}.png');
  await file.writeAsBytes(bytes);
  return file;
}

/// 팀 캘린더 Excel 생성
Future<File> _generateTeamExcelFile(
    TeamCalendarState state, WidgetRef ref) async {
  // 멤버 이름 맵
  final teamRepo = ref.read(teamRepositoryProvider);
  final members = await teamRepo.getTeamMembersWithUsers(state.teamId);
  final memberNames = <String, String>{};
  for (final m in members) {
    memberNames[m.userId] = m.displayName;
  }
  final focusedMonth = state.focusedMonth;
  final daysInMonth =
      DateTime(focusedMonth.year, focusedMonth.month + 1, 0).day;

  final excel = xl.Excel.createExcel();
  final sheetName = '${focusedMonth.year}년 ${focusedMonth.month}월';
  final sheet = excel[sheetName];
  excel.delete('Sheet1');

  for (int i = 0; i < 7; i++) {
    sheet.setColumnWidth(i, 38);
  }

  // 타이틀
  final titleCell = sheet.cell(
      xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
  titleCell.value = xl.TextCellValue(
      '${state.teamName} · ${focusedMonth.year}년 ${focusedMonth.month}월 근무표');
  titleCell.cellStyle = xl.CellStyle(
    bold: true,
    fontSize: 16,
    horizontalAlign: xl.HorizontalAlign.Center,
    verticalAlign: xl.VerticalAlign.Center,
  );
  sheet.merge(
    xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
    xl.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: 0),
  );
  sheet.setRowHeight(0, 35);

  // 요일 헤더
  final headerStyle = xl.CellStyle(
    bold: true,
    fontSize: 12,
    horizontalAlign: xl.HorizontalAlign.Center,
    verticalAlign: xl.VerticalAlign.Center,
    backgroundColorHex: xl.ExcelColor.fromHexString('#F0C040'),
    fontColorHex: xl.ExcelColor.fromHexString('#FFFFFF'),
  );

  const dayNames = ['월', '화', '수', '목', '금', '토', '일'];
  for (int i = 0; i < 7; i++) {
    final cell = sheet.cell(
        xl.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 1));
    cell.value = xl.TextCellValue(dayNames[i]);
    cell.cellStyle = headerStyle;
  }
  sheet.setRowHeight(1, 25);

  // 날짜 + 근무
  final firstWeekday =
      DateTime(focusedMonth.year, focusedMonth.month, 1).weekday - 1;
  final totalRows = ((daysInMonth + firstWeekday) / 7).ceil();

  final dateCellStyle = xl.CellStyle(
    fontSize: 11,
    verticalAlign: xl.VerticalAlign.Top,
    textWrapping: xl.TextWrapping.WrapText,
    leftBorder: xl.Border(borderStyle: xl.BorderStyle.Thin),
    rightBorder: xl.Border(borderStyle: xl.BorderStyle.Thin),
    topBorder: xl.Border(borderStyle: xl.BorderStyle.Thin),
    bottomBorder: xl.Border(borderStyle: xl.BorderStyle.Thin),
  );

  final weekendStyle = dateCellStyle.copyWith(
    backgroundColorHexVal: xl.ExcelColor.fromHexString('#FFF5F5'),
  );

  final rowHeight = (180.0 / totalRows).clamp(28.0, 80.0);

  for (int d = 1; d <= daysInMonth; d++) {
    final date = DateTime(focusedMonth.year, focusedMonth.month, d);
    final col = (firstWeekday + d - 1) % 7;
    final weekRow = (firstWeekday + d - 1) ~/ 7;
    final excelRow = weekRow + 2;

    sheet.setRowHeight(excelRow, rowHeight);

    final shifts = state.monthlyShifts[date];
    final items = <String>['$d일'];

    if (shifts != null) {
      for (final s in shifts) {
        final name = memberNames[s.shift.userId] ?? '';
        items.add(name.isNotEmpty
            ? '■ ${s.shiftType.name} $name'
            : '■ ${s.shiftType.name}');
      }
    }

    final cell = sheet.cell(
        xl.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: excelRow));
    cell.value = xl.TextCellValue(items.join('\n'));
    cell.cellStyle = (col == 5 || col == 6) ? weekendStyle : dateCellStyle;
  }

  // 빈 셀 테두리
  for (int r = 0; r < totalRows; r++) {
    for (int c = 0; c < 7; c++) {
      final excelRow = r + 2;
      final cell = sheet.cell(
          xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: excelRow));
      if (cell.value == null) {
        cell.value = xl.TextCellValue('');
        cell.cellStyle = dateCellStyle;
      }
    }
  }

  final dir = await getTemporaryDirectory();
  final file = File(
      '${dir.path}/team_${state.teamId}_${focusedMonth.year}_${focusedMonth.month}.xlsx');
  final bytes = excel.encode();
  if (bytes != null) {
    await file.writeAsBytes(bytes);
  }
  return file;
}

/// ref 없이 동작하는 팀 캘린더 내보내기 (드로어에서 호출용)
Future<void> exportTeamCalendarStandalone(
    BuildContext context,
    TeamCalendarState state,
    TeamRepository teamRepo) async {
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
          await _generateTeamExcelWithNames(state, memberNames);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(excelFile.path)],
          subject:
              '${state.teamName} ${focusedMonth.year}년 ${focusedMonth.month}월 근무표',
        ),
      );
    } else {
      final file =
          await _generateTeamImageWithNames(state, memberNames);
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

Future<File> _generateTeamImageWithNames(
    TeamCalendarState state, Map<String, String> memberNames) async {
  final focusedMonth = state.focusedMonth;
  final daysInMonth =
      DateTime(focusedMonth.year, focusedMonth.month + 1, 0).day;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  const width = 780.0;
  const totalHeight = 1400.0;
  const headerH = 100.0;
  const dowH = 40.0;
  const cellW = width / 7;
  final firstWeekday =
      DateTime(focusedMonth.year, focusedMonth.month, 1).weekday - 1;
  final rows = ((daysInMonth + firstWeekday) / 7).ceil();
  final rowH = (totalHeight - headerH - dowH - 40) / rows;
  const height = totalHeight;

  final bgPaint = Paint()..color = Colors.white;
  canvas.drawRRect(
    RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, width, height), const Radius.circular(16)),
    bgPaint,
  );

  final headerPainter = TextPainter(
    text: TextSpan(
      text: '${state.teamName} · ${focusedMonth.year}년 ${focusedMonth.month}월',
      style: const TextStyle(
          fontSize: 28, fontWeight: FontWeight.w700, color: Colors.black87),
    ),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: width - 40);
  headerPainter.paint(
      canvas, Offset((width - headerPainter.width) / 2, 32));

  const days = ['월', '화', '수', '목', '금', '토', '일'];
  for (int i = 0; i < 7; i++) {
    Color dowColor;
    if (i == 6) {
      dowColor = const Color(0xCCE53E3E);
    } else if (i == 5) {
      dowColor = const Color(0xFF5A8BB5);
    } else {
      dowColor = const Color(0xFF9CA3AF);
    }
    final tp = TextPainter(
      text: TextSpan(
        text: days[i],
        style: TextStyle(
            fontSize: 18, fontWeight: FontWeight.w600, color: dowColor),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
        canvas, Offset(cellW * i + (cellW - tp.width) / 2, headerH + 8));
  }

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
    final hasContent = shifts != null && shifts.isNotEmpty;

    Color dayColor;
    if (col == 6) {
      dayColor = const Color(0xCCE53E3E);
    } else if (col == 5) {
      dayColor = const Color(0xFF5A8BB5);
    } else {
      dayColor = Colors.black87;
    }

    if (isToday) {
      final circlePaint = Paint()..color = const Color(0x33E8923A);
      canvas.drawCircle(Offset(x + cellW / 2, y + 22), 18, circlePaint);
      dayColor = const Color(0xFFE8923A);
    }

    final dayTextY = hasContent ? y + 8 : y + 16;
    final dayPainter = TextPainter(
      text: TextSpan(
        text: '$d',
        style: TextStyle(
          fontSize: 18,
          fontWeight: isToday ? FontWeight.w700 : FontWeight.normal,
          color: dayColor,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    dayPainter.paint(
        canvas, Offset(x + (cellW - dayPainter.width) / 2, dayTextY));

    double tagY = dayTextY + 28;
    int tagCount = 0;

    if (shifts != null) {
      for (final s in shifts) {
        if (tagCount >= 4) break;
        final shiftColor = parseHexColor(s.shiftType.color);
        final name = memberNames[s.shift.userId] ?? '';
        final label = name.isNotEmpty
            ? '${s.shiftType.name} $name'
            : s.shiftType.name;
        drawPreviewTag(canvas, x, tagY, cellW, label, shiftColor,
            isWork: true);
        tagY += 22;
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
      '${dir.path}/team_${state.teamId}_${focusedMonth.year}_${focusedMonth.month}.png');
  await file.writeAsBytes(bytes);
  return file;
}

Future<File> _generateTeamExcelWithNames(
    TeamCalendarState state, Map<String, String> memberNames) async {
  final focusedMonth = state.focusedMonth;
  final daysInMonth =
      DateTime(focusedMonth.year, focusedMonth.month + 1, 0).day;

  final excel = xl.Excel.createExcel();
  final sheetName = '${focusedMonth.year}년 ${focusedMonth.month}월';
  final sheet = excel[sheetName];
  excel.delete('Sheet1');

  for (int i = 0; i < 7; i++) {
    sheet.setColumnWidth(i, 38);
  }

  final titleCell = sheet.cell(
      xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
  titleCell.value = xl.TextCellValue(
      '${state.teamName} · ${focusedMonth.year}년 ${focusedMonth.month}월 근무표');
  titleCell.cellStyle = xl.CellStyle(
    bold: true, fontSize: 16,
    horizontalAlign: xl.HorizontalAlign.Center,
    verticalAlign: xl.VerticalAlign.Center,
  );
  sheet.merge(
    xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
    xl.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: 0),
  );
  sheet.setRowHeight(0, 35);

  final headerStyle = xl.CellStyle(
    bold: true, fontSize: 12,
    horizontalAlign: xl.HorizontalAlign.Center,
    verticalAlign: xl.VerticalAlign.Center,
    backgroundColorHex: xl.ExcelColor.fromHexString('#F0C040'),
    fontColorHex: xl.ExcelColor.fromHexString('#FFFFFF'),
  );

  const dayNames = ['월', '화', '수', '목', '금', '토', '일'];
  for (int i = 0; i < 7; i++) {
    final cell = sheet.cell(
        xl.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 1));
    cell.value = xl.TextCellValue(dayNames[i]);
    cell.cellStyle = headerStyle;
  }
  sheet.setRowHeight(1, 25);

  final firstWeekday =
      DateTime(focusedMonth.year, focusedMonth.month, 1).weekday - 1;
  final totalRows = ((daysInMonth + firstWeekday) / 7).ceil();

  final dateCellStyle = xl.CellStyle(
    fontSize: 11,
    verticalAlign: xl.VerticalAlign.Top,
    textWrapping: xl.TextWrapping.WrapText,
    leftBorder: xl.Border(borderStyle: xl.BorderStyle.Thin),
    rightBorder: xl.Border(borderStyle: xl.BorderStyle.Thin),
    topBorder: xl.Border(borderStyle: xl.BorderStyle.Thin),
    bottomBorder: xl.Border(borderStyle: xl.BorderStyle.Thin),
  );

  final weekendStyle = dateCellStyle.copyWith(
    backgroundColorHexVal: xl.ExcelColor.fromHexString('#FFF5F5'),
  );

  final rowHeight = (180.0 / totalRows).clamp(28.0, 80.0);

  for (int d = 1; d <= daysInMonth; d++) {
    final date = DateTime(focusedMonth.year, focusedMonth.month, d);
    final col = (firstWeekday + d - 1) % 7;
    final weekRow = (firstWeekday + d - 1) ~/ 7;
    final excelRow = weekRow + 2;

    sheet.setRowHeight(excelRow, rowHeight);

    final shifts = state.monthlyShifts[date];
    final items = <String>['$d일'];

    if (shifts != null) {
      for (final s in shifts) {
        final name = memberNames[s.shift.userId] ?? '';
        items.add(name.isNotEmpty
            ? '■ ${s.shiftType.name} $name'
            : '■ ${s.shiftType.name}');
      }
    }

    final cell = sheet.cell(
        xl.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: excelRow));
    cell.value = xl.TextCellValue(items.join('\n'));
    cell.cellStyle = (col == 5 || col == 6) ? weekendStyle : dateCellStyle;
  }

  for (int r = 0; r < totalRows; r++) {
    for (int c = 0; c < 7; c++) {
      final excelRow = r + 2;
      final cell = sheet.cell(
          xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: excelRow));
      if (cell.value == null) {
        cell.value = xl.TextCellValue('');
        cell.cellStyle = dateCellStyle;
      }
    }
  }

  final dir = await getTemporaryDirectory();
  final file = File(
      '${dir.path}/team_${state.teamId}_${focusedMonth.year}_${focusedMonth.month}.xlsx');
  final bytes = excel.encode();
  if (bytes != null) {
    await file.writeAsBytes(bytes);
  }
  return file;
}
