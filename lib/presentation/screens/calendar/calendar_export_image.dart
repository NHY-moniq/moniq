import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:moniq/core/utils/color_utils.dart';
import 'package:moniq/core/utils/shift_code_utils.dart';
import 'package:moniq/data/datasources/personal_event_remote_data_source.dart'
    show kPersonalTeamImportMarker;
import 'package:moniq/data/models/shift_with_type.dart';
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
  // 파일명에 타임스탬프를 붙여 공유 대상 앱이 같은 이름의 이전 캐시를
  // 재사용하는 문제를 방지한다.
  final ts = DateTime.now().millisecondsSinceEpoch;
  final file = File(
    '${dir.path}/moniq_${focusedMonth.year}_${focusedMonth.month}_$ts.png',
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
  // 여러 날에 걸친 일정은 걸쳐 있는 모든 날짜에 그린다 (화면 캘린더와 동일).
  final monthEvents = eventDs.getMonthlyEventsIncludingSpans(focusedMonth);
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
    final allEvents = monthEvents[date] ?? const [];
    // 팀에서 가져온 근무(import)는 근무 박스로, 직접 만든 개인 일정은 텍스트로 분리.
    final importEvents = allEvents
        .where(
          (e) => e.description?.startsWith(kPersonalTeamImportMarker) == true,
        )
        .toList();
    // 근무 칩으로 직접 넣은 개인 근무도 "근무"다 — 내보내기에 포함한다.
    // (제외되는 건 일반 일정·메모뿐)
    final personalShiftEvents = allEvents
        .where(
          (e) =>
              e.isShift &&
              e.description?.startsWith(kPersonalTeamImportMarker) != true,
        )
        .toList();
    final hasShift = shifts != null && shifts.isNotEmpty;
    // 서버 근무가 있으면 import 근무는 중복이므로 무시(이중 출력 방지).
    final hasWork =
        hasShift || importEvents.isNotEmpty || personalShiftEvents.isNotEmpty;
    // 근무가 전혀 없고 발행된 스케줄 기간(coverage)에 속한 날 → OFF.
    final showOff = !hasWork && state.teamScheduledDates.contains(date);
    // 내보내기 이미지에는 근무 일정만 담는다 — 직접 만든 개인 일정은 제외.
    final hasContent = hasWork || showOff;

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
    } else if (personalShiftEvents.isNotEmpty) {
      // 개인 근무 — 팀 근무가 없는 날에만 그린다.
      for (final e in personalShiftEvents) {
        if (tagCount >= 4) break;
        drawPreviewTag(
          canvas,
          x,
          tagY,
          cellW,
          e.title,
          e.color != null ? parseHexColor(e.color!) : AppColors.shiftOff,
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
  // 파일명에 타임스탬프를 붙여 공유 대상 앱의 동일 파일명 캐시 재사용 방지.
  final ts = DateTime.now().millisecondsSinceEpoch;
  final file = File(
    '${dir.path}/team_${state.teamId}_${state.focusedMonth.year}_${state.focusedMonth.month}_$ts.png',
  );
  await file.writeAsBytes(bytes);
  return file;
}

// ── 팀 로스터 그리드 레이아웃 상수 ──
// 행=멤버, 열=1일~말일. 이름 열 + 31열이 가로형 캔버스에 모두 들어가도록
// 셀 폭을 고정하고 전체 폭을 날짜 수로부터 계산한다 (31일 기준 약 1592px).
const _kRosterNameColW = 132.0;
const _kRosterDayCellW = 44.0;
const _kRosterTitleZoneH = 84.0; // 카드 상단 ~ 그리드 시작
const _kRosterColHeaderH = 52.0; // 날짜 숫자 + 요일 1글자
const _kRosterRowH = 46.0;
const _kRosterBottomPad = 24.0;
const _kRosterEmptyBodyH = 120.0; // 멤버 0명일 때 안내 문구 영역

/// D/E/N 우선 정렬용 (기타 근무는 뒤로)
int _rosterCodePriority(String code) {
  switch (code) {
    case 'D':
      return 0;
    case 'E':
      return 1;
    case 'N':
      return 2;
    default:
      return 3;
  }
}

/// 같은 날 복수 근무 셀 라벨: 1개면 코드, 2개면 'D·N', 3개 이상 'D+2'
String _rosterCellLabel(List<String> codes) {
  if (codes.length == 1) return codes.first;
  if (codes.length == 2) return codes.join('·');
  return '${codes.first}+${codes.length - 1}';
}

/// 팀 캘린더 이미지 — 엑셀 근무표 스타일 로스터 그리드.
/// 행=멤버(이름 열 고정), 열=해당 월 날짜, 셀=근무 코드 칩.
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

  // ── 로스터 데이터 구성: userId → (day → shifts) ──
  // 행 순서는 memberNames(팀 멤버 목록) 순서를 따르고, 목록에 없는
  // userId(탈퇴 멤버 등)의 근무가 있으면 뒤에 덧붙여 데이터 유실을 막는다.
  final rowUserIds = <String>[...memberNames.keys];
  final byMemberDay = <String, Map<int, List<ShiftWithType>>>{};
  // 팀 근무가 하나라도 발행된 날 — 이 날짜의 빈 셀에만 옅은 'O'(오프) 표기.
  final coveredDays = <int>{};
  state.monthlyShifts.forEach((date, shifts) {
    if (date.year != focusedMonth.year || date.month != focusedMonth.month) {
      return;
    }
    if (shifts.isEmpty) return;
    coveredDays.add(date.day);
    for (final s in shifts) {
      final uid = s.shift.userId;
      if (!rowUserIds.contains(uid)) rowUserIds.add(uid);
      byMemberDay
          .putIfAbsent(uid, () => <int, List<ShiftWithType>>{})
          .putIfAbsent(date.day, () => <ShiftWithType>[])
          .add(s);
    }
  });

  // ── 캔버스 크기 산식 ──
  final gridW = _kRosterNameColW + daysInMonth * _kRosterDayCellW;
  final width = gridW + 2 * _kGridLeft;
  final gridTop = _kOuterMargin + _kRosterTitleZoneH;
  final bodyH = rowUserIds.isEmpty
      ? _kRosterEmptyBodyH
      : rowUserIds.length * _kRosterRowH;
  final height =
      gridTop + _kRosterColHeaderH + bodyH + _kRosterBottomPad + _kFooterH;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  // 웜 크림 캔버스 + 카드
  _drawFrame(canvas, width, height);

  // ── 헤더 타이틀 (기존 스타일 유지) ──
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
    maxLines: 1,
    ellipsis: '…',
  )..layout(maxWidth: width - 2 * _kGridLeft);
  headerPainter.paint(
    canvas,
    Offset(
      (width - headerPainter.width) / 2,
      _kOuterMargin + (_kRosterTitleZoneH - headerPainter.height) / 2,
    ),
  );

  final dayColsLeft = _kGridLeft + _kRosterNameColW;
  final bodyTop = gridTop + _kRosterColHeaderH;
  final today = DateTime.now();
  final isThisMonth =
      today.year == focusedMonth.year && today.month == focusedMonth.month;

  // ── 열 배경 틴트 (주말·오늘) — 그리드 선/칩보다 먼저 깐다 ──
  for (int d = 1; d <= daysInMonth; d++) {
    final weekday = DateTime(focusedMonth.year, focusedMonth.month, d).weekday;
    final colX = dayColsLeft + (d - 1) * _kRosterDayCellW;
    Color? tint;
    if (weekday == DateTime.saturday) {
      tint = _kSat.withValues(alpha: 0.06);
    } else if (weekday == DateTime.sunday) {
      tint = const Color(0xFFFF5252).withValues(alpha: 0.05);
    }
    if (tint != null) {
      canvas.drawRect(
        Rect.fromLTWH(
          colX,
          gridTop,
          _kRosterDayCellW,
          bodyTop - gridTop + bodyH,
        ),
        Paint()..color = tint,
      );
    }
    if (isThisMonth && d == today.day) {
      // 오늘 열: 은은한 브랜드 틴트 + 헤더 칩
      canvas.drawRect(
        Rect.fromLTWH(
          colX,
          gridTop,
          _kRosterDayCellW,
          bodyTop - gridTop + bodyH,
        ),
        Paint()..color = const Color(0xFFFFC107).withValues(alpha: 0.08),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            colX + 3,
            gridTop + 3,
            _kRosterDayCellW - 6,
            _kRosterColHeaderH - 6,
          ),
          const Radius.circular(10),
        ),
        Paint()..color = _kTodayCircle,
      );
    }
  }

  // ── 행 줄무늬 (짝수 행 옅게) ──
  for (int r = 0; r < rowUserIds.length; r++) {
    if (r.isOdd) {
      canvas.drawRect(
        Rect.fromLTWH(
          _kGridLeft,
          bodyTop + r * _kRosterRowH,
          gridW,
          _kRosterRowH,
        ),
        Paint()..color = _kInk.withValues(alpha: 0.025),
      );
    }
  }

  // ── 열 헤더: 날짜 숫자 + 요일 1글자 (토=파랑, 일=빨강) ──
  const weekdayChars = ['월', '화', '수', '목', '금', '토', '일'];
  for (int d = 1; d <= daysInMonth; d++) {
    final weekday = DateTime(focusedMonth.year, focusedMonth.month, d).weekday;
    final colX = dayColsLeft + (d - 1) * _kRosterDayCellW;
    final isToday = isThisMonth && d == today.day;
    Color numColor = weekday == DateTime.sunday
        ? _kSun
        : weekday == DateTime.saturday
        ? _kSat
        : _kInk;
    if (isToday) numColor = _kTodayNum;
    final dowColor = weekday == DateTime.sunday
        ? _kSun
        : weekday == DateTime.saturday
        ? _kSat
        : _kWeekday;

    final numTp = TextPainter(
      text: TextSpan(
        text: '$d',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          fontWeight: isToday ? FontWeight.w800 : FontWeight.w700,
          color: numColor,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    numTp.paint(
      canvas,
      Offset(colX + (_kRosterDayCellW - numTp.width) / 2, gridTop + 6),
    );

    final dowTp = TextPainter(
      text: TextSpan(
        text: weekdayChars[weekday - 1],
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: dowColor,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    dowTp.paint(
      canvas,
      Offset(colX + (_kRosterDayCellW - dowTp.width) / 2, gridTop + 28),
    );
  }

  // ── 그리드 선 ──
  final headerLine = Paint()
    ..color = _kCardBorder
    ..strokeWidth = 1.2;
  canvas.drawLine(
    Offset(_kGridLeft, bodyTop),
    Offset(_kGridLeft + gridW, bodyTop),
    headerLine,
  );
  // 이름 열 구분선
  canvas.drawLine(
    Offset(dayColsLeft, gridTop),
    Offset(dayColsLeft, bodyTop + bodyH),
    headerLine,
  );
  // 행 구분선 (옅게)
  final rowLine = Paint()
    ..color = _kCardBorder.withValues(alpha: 0.35)
    ..strokeWidth = 1;
  for (int r = 1; r <= rowUserIds.length; r++) {
    final y = bodyTop + r * _kRosterRowH;
    canvas.drawLine(
      Offset(_kGridLeft, y),
      Offset(_kGridLeft + gridW, y),
      rowLine,
    );
  }

  // ── 멤버 0명: 안내 문구 ──
  if (rowUserIds.isEmpty) {
    final emptyTp = TextPainter(
      text: TextSpan(
        text: '표시할 근무 데이터가 없어요',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: _kWeekday,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    emptyTp.paint(
      canvas,
      Offset(
        (width - emptyTp.width) / 2,
        bodyTop + (bodyH - emptyTp.height) / 2,
      ),
    );
  }

  // ── 멤버 행: 이름 + 날짜별 근무 코드 칩 ──
  for (int r = 0; r < rowUserIds.length; r++) {
    final uid = rowUserIds[r];
    final rowY = bodyTop + r * _kRosterRowH;
    final name = memberNames[uid] ?? '알 수 없음';

    // 이름 (긴 이름은 말줄임)
    final nameTp = TextPainter(
      text: TextSpan(
        text: name,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: _kInk,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: _kRosterNameColW - 20);
    nameTp.paint(
      canvas,
      Offset(_kGridLeft + 10, rowY + (_kRosterRowH - nameTp.height) / 2),
    );

    final dayShifts = byMemberDay[uid] ?? const <int, List<ShiftWithType>>{};
    for (int d = 1; d <= daysInMonth; d++) {
      final colX = dayColsLeft + (d - 1) * _kRosterDayCellW;
      final shifts = dayShifts[d];

      if (shifts == null || shifts.isEmpty) {
        // 근무 없음 — 발행된 날이면 옅은 'O'(오프), 아니면 빈 셀.
        if (coveredDays.contains(d)) {
          final offTp = TextPainter(
            text: TextSpan(
              text: 'O',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _kWeekday.withValues(alpha: 0.4),
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          offTp.paint(
            canvas,
            Offset(
              colX + (_kRosterDayCellW - offTp.width) / 2,
              rowY + (_kRosterRowH - offTp.height) / 2,
            ),
          );
        }
        continue;
      }

      // D → E → N → 기타 순 정렬 후 코드 라벨 구성
      final sorted = [...shifts]
        ..sort((a, b) {
          final ca = canonicalShiftCode(a.shiftType.code, a.shiftType.name);
          final cb = canonicalShiftCode(b.shiftType.code, b.shiftType.name);
          return _rosterCodePriority(ca).compareTo(_rosterCodePriority(cb));
        });
      final codes = sorted
          .map((s) => canonicalShiftCode(s.shiftType.code, s.shiftType.name))
          .toList();
      final color = parseHexColor(sorted.first.shiftType.color);
      final ink = readableInk(color);

      // 근무색 배경 칩 + 잉크 테두리 (앱 로스터 셀과 동일 문법)
      final chipRect = Rect.fromLTWH(
        colX + 3,
        rowY + 5,
        _kRosterDayCellW - 6,
        _kRosterRowH - 10,
      );
      final rrect = RRect.fromRectAndRadius(chipRect, const Radius.circular(8));
      canvas.drawRRect(rrect, Paint()..color = color.withValues(alpha: 0.22));
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = ink.withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );

      final labelTp = TextPainter(
        text: TextSpan(
          text: _rosterCellLabel(codes),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: ink,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '‥',
      )..layout(maxWidth: chipRect.width - 4);
      labelTp.paint(
        canvas,
        Offset(
          chipRect.left + (chipRect.width - labelTp.width) / 2,
          chipRect.top + (chipRect.height - labelTp.height) / 2,
        ),
      );
    }
  }

  _drawWatermark(canvas, width, height);

  final picture = recorder.endRecording();
  final img = await picture.toImage(width.toInt(), height.toInt());
  final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}
