import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:moniq/core/utils/color_utils.dart';
import 'package:moniq/data/providers/team_providers.dart';
import 'package:moniq/presentation/viewmodels/home_viewmodel.dart';
import 'package:moniq/presentation/viewmodels/team_calendar_viewmodel.dart';

import 'calendar_providers.dart';

/// 개인 캘린더 이미지 bytes (웹 내보내기용 — 파일 I/O 없음)
Future<Uint8List> generateCalendarImageBytes(
    HomeCalendarState state, WidgetRef ref) async {
  return _renderCalendarBytes(state, ref);
}

/// 개인 캘린더 이미지 생성 (모바일 — 임시 파일 반환)
Future<File> generateCalendarImage(
    HomeCalendarState state, WidgetRef ref) async {
  final bytes = await _renderCalendarBytes(state, ref);
  final focusedMonth = state.focusedMonth;
  final dir = await getTemporaryDirectory();
  final file = File(
      '${dir.path}/moniq_${focusedMonth.year}_${focusedMonth.month}.png');
  await file.writeAsBytes(bytes);
  return file;
}

/// 렌더링만 수행, bytes 반환 (dart:ui만 사용)
Future<Uint8List> _renderCalendarBytes(
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
    // 화면 캘린더와 비슷하게 글씨를 키운다(개인 캘린더는 셀당 일정 수가 적음).
    const tagFontSize = 16.0;
    const tagHeight = 28.0;
    const tagStep = 32.0;
    double tagY = dayTextY + 30;
    int tagCount = 0;

    // 근무 일정 태그
    if (shifts != null && shifts.isNotEmpty) {
      for (final s in shifts) {
        if (tagCount >= 4) break;
        final shiftColor = parseHexColor(s.shiftType.color);
        drawPreviewTag(
            canvas, x, tagY, cellW, s.shiftType.name, shiftColor,
            isWork: true, fontSize: tagFontSize, tagHeight: tagHeight);
        tagY += tagStep;
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
            isWork: false, fontSize: tagFontSize, tagHeight: tagHeight);
        tagY += tagStep;
        tagCount++;
      }
    }
  }

  final picture = recorder.endRecording();
  final img = await picture.toImage(width.toInt(), height.toInt());
  final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}

/// 내보내기 이미지용 미리보기 태그 그리기
void drawPreviewTag(Canvas canvas, double x, double y, double cellW,
    String text, Color color,
    {required bool isWork, double fontSize = 12, double tagHeight = 20}) {
  final tagH = tagHeight;
  const hPad = 6.0;
  final tagW = cellW - 8;
  final tagX = x + 4;

  // 화면 미리보기와 동일하게: 근무 일정만 컬러 배경 박스 + 테두리를 채우고,
  // 개인 일정은 배경 없이 텍스트만 표시한다.
  if (isWork) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(tagX, y, tagW, tagH),
      const Radius.circular(3),
    );
    final bgPaint = Paint()..color = color.withValues(alpha: 0.25);
    canvas.drawRRect(rrect, bgPaint);
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
        fontSize: fontSize,
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

/// 팀 캘린더 이미지 bytes 생성 (ref 사용, 웹 다운로드용)
Future<Uint8List> generateTeamImageBytes(
    TeamCalendarState state, WidgetRef ref) async {
  final teamRepo = ref.read(teamRepositoryProvider);
  final members = await teamRepo.getTeamMembersWithUsers(state.teamId);
  final memberNames = <String, String>{};
  for (final m in members) {
    memberNames[m.userId] = m.displayName;
  }
  return _renderTeamImageBytes(state, memberNames);
}

/// 팀 캘린더 이미지 생성 (ref 사용)
Future<File> generateTeamCalendarImage(
    TeamCalendarState state, WidgetRef ref) async {
  final teamRepo = ref.read(teamRepositoryProvider);
  final members = await teamRepo.getTeamMembersWithUsers(state.teamId);
  final memberNames = <String, String>{};
  for (final m in members) {
    memberNames[m.userId] = m.displayName;
  }
  return generateTeamImageWithNames(state, memberNames);
}

/// 팀 캘린더 이미지 생성 (멤버 이름 맵 직접 전달)
Future<File> generateTeamImageWithNames(
    TeamCalendarState state, Map<String, String> memberNames) async {
  final bytes = await _renderTeamImageBytes(state, memberNames);
  final dir = await getTemporaryDirectory();
  final file = File(
      '${dir.path}/team_${state.teamId}_${state.focusedMonth.year}_${state.focusedMonth.month}.png');
  await file.writeAsBytes(bytes);
  return file;
}

Future<Uint8List> _renderTeamImageBytes(
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
  return byteData!.buffer.asUint8List();
}
