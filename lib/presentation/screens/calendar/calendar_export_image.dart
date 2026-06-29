import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:moniq/core/utils/color_utils.dart';
import 'package:moniq/data/datasources/personal_event_remote_data_source.dart'
    show kPersonalTeamImportMarker;
import 'package:moniq/data/providers/team_providers.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/viewmodels/home_viewmodel.dart';
import 'package:moniq/presentation/viewmodels/team_calendar_viewmodel.dart';

import 'calendar_providers.dart';

// ── 앱 테마 정합용 export 토큰 (웜/크림) ──
const _kOuterMargin = 28.0;
const _kFooterH = 44.0;
const _kCardPad = 20.0;
const _kGridLeft = _kOuterMargin + _kCardPad; // 48
const _kCanvasBg = Color(0xFFFFF6EA); // surfaceContainerLow (웜 크림)
const _kCardBg = Color(0xFFFFFDF7); // surface (웜 화이트)
const _kCardBorder = Color(0x73E8E2D2); // borderLight @0.45
const _kInk = Color(0xFF373830); // onSurface
const _kWeekday = Color(0xFF818177); // textSecondary
const _kSat = Color(0xFF2196F3); // tertiary
const _kSun = Color(0xB3FF5252); // error @0.7
const _kTodayCircle = Color(0x40FFC107); // primary @0.25
const _kTodayNum = Color(0xFF5B4B00); // onPrimaryContainer
const _kWatermark = Color(0xFF64655C); // onSurfaceVariant
const _kBrandDot = Color(0xFFFF8F00); // brandOrange

double _gridWidth(double width) => width - 2 * _kOuterMargin - 2 * _kCardPad;

/// 요일/날짜 색 (col: 0=월 ~ 6=일)
Color _columnColor(int col, {Color weekday = _kInk}) {
  if (col == 6) return _kSun;
  if (col == 5) return _kSat;
  return weekday;
}

/// 웜 크림 캔버스 + 카드 프레임
void _drawFrame(Canvas canvas, double width, double height) {
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width, height),
    Paint()..color = _kCanvasBg,
  );
  final cardRect = Rect.fromLTWH(
    _kOuterMargin,
    _kOuterMargin,
    width - 2 * _kOuterMargin,
    height - _kFooterH - _kOuterMargin,
  );
  final rr = RRect.fromRectAndRadius(cardRect, const Radius.circular(32));
  canvas.drawRRect(rr, Paint()..color = _kCardBg);
  canvas.drawRRect(
    rr,
    Paint()
      ..color = _kCardBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5,
  );
}

/// 하단 브랜드 워터마크 (● OnorOff)
void _drawWatermark(Canvas canvas, double width, double height) {
  final tp = TextPainter(
    text: TextSpan(
      text: 'OnorOff',
      style: GoogleFonts.plusJakartaSans(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: _kWatermark,
        letterSpacing: 0.3,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final totalW = 8 + 8 + tp.width;
  final startX = (width - totalW) / 2;
  final cy = height - _kFooterH / 2;
  canvas.drawCircle(Offset(startX + 4, cy), 4, Paint()..color = _kBrandDot);
  tp.paint(canvas, Offset(startX + 16, cy - tp.height / 2));
}

/// 개인 캘린더 이미지 bytes (웹 내보내기용 — 파일 I/O 없음)
Future<Uint8List> generateCalendarImageBytes(
  HomeCalendarState state,
  WidgetRef ref,
) async {
  return _renderCalendarBytes(state, ref);
}

/// 개인 캘린더 이미지 생성 (모바일 — 임시 파일 반환)
Future<File> generateCalendarImage(
  HomeCalendarState state,
  WidgetRef ref,
) async {
  final bytes = await _renderCalendarBytes(state, ref);
  final focusedMonth = state.focusedMonth;
  final dir = await getTemporaryDirectory();
  final file = File(
    '${dir.path}/moniq_${focusedMonth.year}_${focusedMonth.month}.png',
  );
  await file.writeAsBytes(bytes);
  return file;
}

/// 렌더링만 수행, bytes 반환 (dart:ui만 사용)
Future<Uint8List> _renderCalendarBytes(
  HomeCalendarState state,
  WidgetRef ref,
) async {
  final focusedMonth = state.focusedMonth;
  final eventDs = ref.read(personalEventDataSourceProvider);
  final daysInMonth = DateTime(
    focusedMonth.year,
    focusedMonth.month + 1,
    0,
  ).day;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  const width = 780.0;
  const totalHeight = 1180.0;
  const headerH = 100.0;
  const dowH = 40.0;
  final cellW = _gridWidth(width) / 7;
  // 근무 띠는 높이·글자를 키워 또렷하게
  const tagFontSize = 22.0;
  const tagHeight = 40.0;
  const tagStep = 46.0;
  final firstWeekday =
      DateTime(focusedMonth.year, focusedMonth.month, 1).weekday - 1;
  final rows = ((daysInMonth + firstWeekday) / 7).ceil();
  const height = totalHeight;
  final rowH = (height - _kFooterH - headerH - dowH - 12) / rows;

  // 웜 크림 캔버스 + 카드
  _drawFrame(canvas, width, height);

  // 헤더 타이틀
  final headerPainter = TextPainter(
    text: TextSpan(
      text: '${focusedMonth.year}년 ${focusedMonth.month}월',
      style: GoogleFonts.plusJakartaSans(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: _kInk,
        letterSpacing: -0.5,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  headerPainter.paint(canvas, Offset((width - headerPainter.width) / 2, 40));

  // 요일 헤더
  const days = ['월', '화', '수', '목', '금', '토', '일'];
  for (int i = 0; i < 7; i++) {
    final dowColor = _columnColor(i, weekday: _kWeekday);
    final tp = TextPainter(
      text: TextSpan(
        text: days[i],
        style: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: dowColor,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(_kGridLeft + cellW * i + (cellW - tp.width) / 2, headerH + 8),
    );
  }

  // 셀 그리기
  final today = DateTime.now();
  final todayKey = DateTime(today.year, today.month, today.day);

  for (int d = 1; d <= daysInMonth; d++) {
    final date = DateTime(focusedMonth.year, focusedMonth.month, d);
    final col = (firstWeekday + d - 1) % 7;
    final row = (firstWeekday + d - 1) ~/ 7;
    final x = _kGridLeft + cellW * col;
    final y = headerH + dowH + row * rowH;

    final isToday = date == todayKey;
    final shifts = state.monthlyShifts[date];
    final allEvents = eventDs.getEvents(date);
    // 팀에서 가져온 근무(import)는 근무 박스로, 직접 만든 개인 일정은 텍스트로 분리.
    final importEvents = allEvents
        .where(
          (e) => e.description?.startsWith(kPersonalTeamImportMarker) == true,
        )
        .toList();
    final personalEvents = allEvents
        .where(
          (e) => e.description?.startsWith(kPersonalTeamImportMarker) != true,
        )
        .toList();
    final hasShift = shifts != null && shifts.isNotEmpty;
    // 서버 근무가 있으면 import 근무는 중복이므로 무시(이중 출력 방지).
    final hasWork = hasShift || importEvents.isNotEmpty;
    // 근무가 전혀 없고 발행된 스케줄 기간(coverage)에 속한 날 → OFF.
    final showOff = !hasWork && state.teamScheduledDates.contains(date);
    final hasContent = hasWork || personalEvents.isNotEmpty || showOff;

    // 날짜 숫자 색상
    Color dayColor = _columnColor(col);

    // 오늘 날짜 배경 원
    if (isToday) {
      final circlePaint = Paint()..color = _kTodayCircle;
      canvas.drawCircle(Offset(x + cellW / 2, y + 22), 17, circlePaint);
      dayColor = _kTodayNum;
    }

    // 날짜 숫자 — 일정이 있으면 상단, 없으면 중앙
    final dayTextY = hasContent ? y + 8 : y + 16;
    final dayPainter = TextPainter(
      text: TextSpan(
        text: '$d',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 21,
          fontWeight: (isToday) ? FontWeight.w800 : FontWeight.w600,
          color: dayColor,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    dayPainter.paint(
      canvas,
      Offset(x + (cellW - dayPainter.width) / 2, dayTextY),
    );

    // 미리보기 태그들 (근무 우선, 최대 4개)
    double tagY = dayTextY + 34;
    int tagCount = 0;

    // 1) 근무 일정 태그 (컬러 박스 채움)
    if (hasShift) {
      for (final s in shifts) {
        if (tagCount >= 4) break;
        final shiftColor = parseHexColor(s.shiftType.color);
        drawPreviewTag(
          canvas,
          x,
          tagY,
          cellW,
          s.shiftType.name,
          shiftColor,
          isWork: true,
          fontSize: tagFontSize,
          tagHeight: tagHeight,
        );
        tagY += tagStep;
        tagCount++;
      }
    } else if (importEvents.isNotEmpty) {
      // 서버 근무가 없을 때(예: 비즐겨찾기 팀 import)만 import 근무를 박스로 표시.
      for (final e in importEvents) {
        if (tagCount >= 4) break;
        final c = e.color != null
            ? parseHexColor(e.color!)
            : AppColors.shiftOff;
        drawPreviewTag(
          canvas,
          x,
          tagY,
          cellW,
          e.title,
          c,
          isWork: true,
          fontSize: tagFontSize,
          tagHeight: tagHeight,
        );
        tagY += tagStep;
        tagCount++;
      }
    }

    // 2) OFF 태그 (근무 없는 스케줄 기간 날 — 박스 채움)
    if (showOff && tagCount < 4) {
      drawPreviewTag(
        canvas,
        x,
        tagY,
        cellW,
        'OFF',
        AppColors.shiftOff,
        isWork: true,
        fontSize: tagFontSize,
        tagHeight: tagHeight,
      );
      tagY += tagStep;
      tagCount++;
    }

    // 3) 개인 일정 태그 (박스 없이 텍스트만)
    if (personalEvents.isNotEmpty) {
      for (final e in personalEvents) {
        if (tagCount >= 4) break;
        final eventColor = e.color != null
            ? parseHexColor(e.color!)
            : const Color(0xFF38A169);
        drawPreviewTag(
          canvas,
          x,
          tagY,
          cellW,
          e.title,
          eventColor,
          isWork: false,
          fontSize: tagFontSize,
          tagHeight: tagHeight,
        );
        tagY += tagStep;
        tagCount++;
      }
    }
  }

  _drawWatermark(canvas, width, height);

  final picture = recorder.endRecording();
  final img = await picture.toImage(width.toInt(), height.toInt());
  final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}

/// 내보내기 이미지용 미리보기 태그 그리기
void drawPreviewTag(
  Canvas canvas,
  double x,
  double y,
  double cellW,
  String text,
  Color color, {
  required bool isWork,
  double fontSize = 12,
  double tagHeight = 20,
}) {
  final tagH = tagHeight;
  const hPad = 6.0;
  final tagW = cellW - 8;
  final tagX = x + 4;

  // 근무 일정만 컬러 배경 박스(테두리 없음), 개인 일정은 배경 없이 텍스트만.
  // 채도를 높여 또렷하게 (파스텔 색이 너무 연하게 보이는 문제 보완)
  final vivid = _vividColor(color);
  if (isWork) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(tagX, y, tagW, tagH),
      const Radius.circular(8),
    );
    final bgPaint = Paint()..color = vivid.withValues(alpha: 0.22);
    canvas.drawRRect(rrect, bgPaint);
  }

  // 텍스트 — 근무는 진한 잉크색으로 가독성·채도 강화
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: fontSize,
        color: isWork ? _inkColor(color) : vivid,
        fontWeight: isWork ? FontWeight.w800 : FontWeight.w600,
      ),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: '..',
  )..layout(maxWidth: tagW - hPad * 2);
  tp.paint(
    canvas,
    Offset(tagX + (tagW - tp.width) / 2, y + (tagH - tp.height) / 2),
  );
}

/// 파스텔 색의 채도를 끌어올려 또렷하게 (배경·테두리용)
Color _vividColor(Color c) {
  final hsl = HSLColor.fromColor(c);
  if (hsl.saturation < 0.05) return c; // 무채색(회색/OFF)은 그대로
  return hsl
      .withSaturation((hsl.saturation * 1.5).clamp(0.0, 1.0))
      .withLightness((hsl.lightness * 0.88).clamp(0.0, 1.0))
      .toColor();
}

/// 텍스트용 진한 잉크색 (가독성 + 채도)
Color _inkColor(Color c) {
  final hsl = HSLColor.fromColor(c);
  if (hsl.saturation < 0.05) {
    return const Color(0xFF4B5563); // 무채색 텍스트는 진한 회색
  }
  return hsl
      .withSaturation((hsl.saturation * 1.5).clamp(0.0, 1.0))
      .withLightness((hsl.lightness * 0.5).clamp(0.0, 0.42))
      .toColor();
}

/// 팀 캘린더 이미지 bytes 생성 (ref 사용, 웹 다운로드용)
Future<Uint8List> generateTeamImageBytes(
  TeamCalendarState state,
  WidgetRef ref,
) async {
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
  TeamCalendarState state,
  WidgetRef ref,
) async {
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
  TeamCalendarState state,
  Map<String, String> memberNames,
) async {
  final bytes = await _renderTeamImageBytes(state, memberNames);
  final dir = await getTemporaryDirectory();
  final file = File(
    '${dir.path}/team_${state.teamId}_${state.focusedMonth.year}_${state.focusedMonth.month}.png',
  );
  await file.writeAsBytes(bytes);
  return file;
}

Future<Uint8List> _renderTeamImageBytes(
  TeamCalendarState state,
  Map<String, String> memberNames,
) async {
  final focusedMonth = state.focusedMonth;
  final daysInMonth = DateTime(
    focusedMonth.year,
    focusedMonth.month + 1,
    0,
  ).day;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  const width = 780.0;
  const totalHeight = 1180.0;
  const headerH = 100.0;
  const dowH = 40.0;
  final cellW = _gridWidth(width) / 7;
  final firstWeekday =
      DateTime(focusedMonth.year, focusedMonth.month, 1).weekday - 1;
  final rows = ((daysInMonth + firstWeekday) / 7).ceil();
  const height = totalHeight;
  final rowH = (height - _kFooterH - headerH - dowH - 12) / rows;

  // 웜 크림 캔버스 + 카드
  _drawFrame(canvas, width, height);

  // 헤더
  final headerPainter = TextPainter(
    text: TextSpan(
      text: '${state.teamName} · ${focusedMonth.year}년 ${focusedMonth.month}월',
      style: GoogleFonts.plusJakartaSans(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: _kInk,
        letterSpacing: -0.5,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: width - 2 * _kGridLeft);
  headerPainter.paint(canvas, Offset((width - headerPainter.width) / 2, 40));

  // 요일 헤더
  const days = ['월', '화', '수', '목', '금', '토', '일'];
  for (int i = 0; i < 7; i++) {
    final dowColor = _columnColor(i, weekday: _kWeekday);
    final tp = TextPainter(
      text: TextSpan(
        text: days[i],
        style: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: dowColor,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(_kGridLeft + cellW * i + (cellW - tp.width) / 2, headerH + 8),
    );
  }

  // 셀
  final today = DateTime.now();
  final todayKey = DateTime(today.year, today.month, today.day);

  for (int d = 1; d <= daysInMonth; d++) {
    final date = DateTime(focusedMonth.year, focusedMonth.month, d);
    final col = (firstWeekday + d - 1) % 7;
    final row = (firstWeekday + d - 1) ~/ 7;
    final x = _kGridLeft + cellW * col;
    final y = headerH + dowH + row * rowH;

    final isToday = date == todayKey;
    final shifts = state.monthlyShifts[date];
    final hasContent = shifts != null && shifts.isNotEmpty;

    Color dayColor = _columnColor(col);

    if (isToday) {
      final circlePaint = Paint()..color = _kTodayCircle;
      canvas.drawCircle(Offset(x + cellW / 2, y + 22), 17, circlePaint);
      dayColor = _kTodayNum;
    }

    final dayTextY = hasContent ? y + 8 : y + 16;
    final dayPainter = TextPainter(
      text: TextSpan(
        text: '$d',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 21,
          fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
          color: dayColor,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    dayPainter.paint(
      canvas,
      Offset(x + (cellW - dayPainter.width) / 2, dayTextY),
    );

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
          canvas,
          x,
          tagY,
          cellW,
          label,
          shiftColor,
          isWork: true,
          fontSize: 18,
          tagHeight: 34,
        );
        tagY += 39;
        tagCount++;
      }
    }
  }

  _drawWatermark(canvas, width, height);

  final picture = recorder.endRecording();
  final img = await picture.toImage(width.toInt(), height.toInt());
  final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}
