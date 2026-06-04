import 'dart:io';

import 'package:excel/excel.dart' as xl;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:moniq/data/providers/team_providers.dart';
import 'package:moniq/presentation/viewmodels/home_viewmodel.dart';
import 'package:moniq/presentation/viewmodels/team_calendar_viewmodel.dart';

import 'calendar_providers.dart';

/// 개인 캘린더 Excel bytes (웹 내보내기용 — 파일 I/O 없음)
Future<List<int>> generateExcelBytes(
    HomeCalendarState state, WidgetRef ref) async {
  return _buildPersonalExcelBytes(state, ref);
}

/// 개인 캘린더 Excel 파일 생성 (모바일)
Future<File> generateExcelFile(
    HomeCalendarState state, WidgetRef ref) async {
  final bytes = await _buildPersonalExcelBytes(state, ref);
  final focusedMonth = state.focusedMonth;
  final dir = await getTemporaryDirectory();
  final file = File(
      '${dir.path}/onoroff_${focusedMonth.year}_${focusedMonth.month}.xlsx');
  await file.writeAsBytes(bytes);
  return file;
}

/// 개인 캘린더 Excel 빌드 (bytes 반환 — dart:io 없음)
Future<List<int>> _buildPersonalExcelBytes(
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

  // -- 타이틀 행 (병합) --
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

  // -- 요일 헤더 (2행) --
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

  // -- 날짜 + 일정 (한 셀에 합쳐서) --
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

  return excel.encode() ?? [];
}



/// 팀 캘린더 Excel bytes 생성 (ref 사용, 웹 다운로드용)
Future<List<int>> generateTeamExcelBytes(
    TeamCalendarState state, WidgetRef ref) async {
  final teamRepo = ref.read(teamRepositoryProvider);
  final members = await teamRepo.getTeamMembersWithUsers(state.teamId);
  final memberNames = <String, String>{};
  for (final m in members) {
    memberNames[m.userId] = m.displayName;
  }
  return _buildTeamExcelBytes(state, memberNames);
}

/// 팀 캘린더 Excel 생성 (ref 사용)
Future<File> generateTeamExcelFile(
    TeamCalendarState state, WidgetRef ref) async {
  final teamRepo = ref.read(teamRepositoryProvider);
  final members = await teamRepo.getTeamMembersWithUsers(state.teamId);
  final memberNames = <String, String>{};
  for (final m in members) {
    memberNames[m.userId] = m.displayName;
  }
  return generateTeamExcelWithNames(state, memberNames);
}

/// 팀 캘린더 Excel 생성 (멤버 이름 맵 직접 전달)
Future<File> generateTeamExcelWithNames(
    TeamCalendarState state, Map<String, String> memberNames) async {
  final bytes = await _buildTeamExcelBytes(state, memberNames);
  final dir = await getTemporaryDirectory();
  final file = File(
      '${dir.path}/team_${state.teamId}_${state.focusedMonth.year}_${state.focusedMonth.month}.xlsx');
  await file.writeAsBytes(bytes);
  return file;
}

/// 근무 유형 정렬 순서: 데이(0) → 이브닝(1) → 나이트(2) → 기타(3)
int shiftTypeOrder(String code, String name) {
  final c = code.toUpperCase();
  final n = name.toLowerCase();
  if (c == 'D' || name.contains('데이') || n.contains('day')) return 0;
  if (c == 'E' || name.contains('이브닝') || n.contains('eve')) return 1;
  if (c == 'N' || name.contains('나이트') || n.contains('night')) return 2;
  return 3;
}

Future<List<int>> _buildTeamExcelBytes(
    TeamCalendarState state, Map<String, String> memberNames) async {
  final focusedMonth = state.focusedMonth;
  final daysInMonth =
      DateTime(focusedMonth.year, focusedMonth.month + 1, 0).day;

  // 각 날짜 셀 목록: 근무유형 헤더(예: '데이') 다음에 '■ 이름'들이 이어진다.
  final perDay = <int, List<String>>{};
  for (int d = 1; d <= daysInMonth; d++) {
    final date = DateTime(focusedMonth.year, focusedMonth.month, d);
    final shifts = state.monthlyShifts[date];
    final list = <String>[];
    if (shifts != null) {
      // 데이 → 이브닝 → 나이트 → 기타 순, 같은 유형끼리 묶고 이름순으로 정렬
      final sorted = [...shifts]..sort((a, b) {
          final oa = shiftTypeOrder(a.shiftType.code, a.shiftType.name);
          final ob = shiftTypeOrder(b.shiftType.code, b.shiftType.name);
          if (oa != ob) return oa.compareTo(ob);
          if (a.shiftType.name != b.shiftType.name) {
            return a.shiftType.name.compareTo(b.shiftType.name);
          }
          final na = memberNames[a.shift.userId] ?? '';
          final nb = memberNames[b.shift.userId] ?? '';
          return na.compareTo(nb);
        });
      String? currentType;
      for (final s in sorted) {
        if (s.shiftType.name != currentType) {
          // 근무유형 그룹 헤더
          list.add(s.shiftType.name);
          currentType = s.shiftType.name;
        }
        final name = memberNames[s.shift.userId] ?? '';
        list.add(name.isNotEmpty ? '■ $name' : '■');
      }
    }
    perDay[d] = list;
  }

  return buildCalendarGridExcelBytes(
    year: focusedMonth.year,
    month: focusedMonth.month,
    title:
        '${state.teamName} · ${focusedMonth.year}년 ${focusedMonth.month}월 근무표',
    perDay: perDay,
  );
}

/// 주 단위 달력 그리드 Excel을 생성한다.
/// - 1행: 타이틀(7칸 병합)
/// - 2행: 요일 헤더(월~일)
/// - 이후: 각 주마다 [날짜 행: 'N일'] + [내용 행들]
/// [perDay]의 각 값은 셀에 위→아래로 한 칸씩 들어갈 문자열 목록이다.
/// - 빈 문자열 또는 '■'로 시작 → 일반(이름) 셀
/// - 그 외 비어있지 않은 문자열 → 근무유형 그룹 헤더 셀
List<int> buildCalendarGridExcelBytes({
  required int year,
  required int month,
  required String title,
  required Map<int, List<String>> perDay,
}) {
  final daysInMonth = DateTime(year, month + 1, 0).day;

  final excel = xl.Excel.createExcel();
  final sheetName = '$year년 $month월';
  final sheet = excel[sheetName];
  excel.delete('Sheet1');

  for (int i = 0; i < 7; i++) {
    sheet.setColumnWidth(i, 24);
  }

  // 타이틀
  final titleCell = sheet.cell(
      xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
  titleCell.value = xl.TextCellValue(title);
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

  final firstWeekday = DateTime(year, month, 1).weekday - 1;
  final totalWeeks = ((daysInMonth + firstWeekday) / 7).ceil();

  // 날짜 헤더 셀 스타일 ('N일')
  final dateHeaderStyle = xl.CellStyle(
    bold: true,
    fontSize: 11,
    horizontalAlign: xl.HorizontalAlign.Left,
    verticalAlign: xl.VerticalAlign.Center,
    backgroundColorHex: xl.ExcelColor.fromHexString('#FBEFD0'),
    leftBorder: xl.Border(borderStyle: xl.BorderStyle.Thin),
    rightBorder: xl.Border(borderStyle: xl.BorderStyle.Thin),
    topBorder: xl.Border(borderStyle: xl.BorderStyle.Thin),
    bottomBorder: xl.Border(borderStyle: xl.BorderStyle.Thin),
  );
  final dateHeaderWeekendStyle = dateHeaderStyle.copyWith(
    backgroundColorHexVal: xl.ExcelColor.fromHexString('#FCE4E4'),
  );

  // 일반(이름) 셀 스타일
  final staffStyle = xl.CellStyle(
    fontSize: 11,
    verticalAlign: xl.VerticalAlign.Center,
    leftBorder: xl.Border(borderStyle: xl.BorderStyle.Thin),
    rightBorder: xl.Border(borderStyle: xl.BorderStyle.Thin),
    topBorder: xl.Border(borderStyle: xl.BorderStyle.Thin),
    bottomBorder: xl.Border(borderStyle: xl.BorderStyle.Thin),
  );
  final staffWeekendStyle = staffStyle.copyWith(
    backgroundColorHexVal: xl.ExcelColor.fromHexString('#FFF5F5'),
  );

  // 근무유형 그룹 헤더 셀 스타일 ('데이'/'이브닝'/'나이트')
  final groupStyle = staffStyle.copyWith(
    boldVal: true,
    backgroundColorHexVal: xl.ExcelColor.fromHexString('#F2F2F2'),
  );
  final groupWeekendStyle = staffStyle.copyWith(
    boldVal: true,
    backgroundColorHexVal: xl.ExcelColor.fromHexString('#F7ECEC'),
  );

  bool isWeekendCol(int col) => col == 5 || col == 6;

  // 셀 내용에 따라 스타일 결정: 빈칸/'■ 이름' / 근무유형 그룹 헤더
  xl.CellStyle cellStyleFor(String text, bool weekend) {
    if (text.isEmpty || text.startsWith('■')) {
      return weekend ? staffWeekendStyle : staffStyle;
    }
    return weekend ? groupWeekendStyle : groupStyle;
  }

  // 주 단위로 [날짜 행] + [내용 행들]을 쌓는다.
  int excelRow = 2;
  for (int w = 0; w < totalWeeks; w++) {
    final dateRow = excelRow;
    int maxRows = 0;

    // 날짜 헤더 행
    for (int col = 0; col < 7; col++) {
      final dayNumber = w * 7 + col - firstWeekday + 1;
      final cell = sheet.cell(
          xl.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: dateRow));
      if (dayNumber >= 1 && dayNumber <= daysInMonth) {
        cell.value = xl.TextCellValue('$dayNumber일');
        final count = perDay[dayNumber]?.length ?? 0;
        if (count > maxRows) maxRows = count;
      } else {
        cell.value = xl.TextCellValue('');
      }
      cell.cellStyle =
          isWeekendCol(col) ? dateHeaderWeekendStyle : dateHeaderStyle;
    }
    sheet.setRowHeight(dateRow, 20);

    // 내용 행들 — 한 셀에 한 칸씩
    for (int i = 0; i < maxRows; i++) {
      final r = dateRow + 1 + i;
      for (int col = 0; col < 7; col++) {
        final dayNumber = w * 7 + col - firstWeekday + 1;
        final cell = sheet.cell(
            xl.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: r));
        var text = '';
        if (dayNumber >= 1 && dayNumber <= daysInMonth) {
          final list = perDay[dayNumber];
          if (list != null && i < list.length) text = list[i];
        }
        cell.value = xl.TextCellValue(text);
        cell.cellStyle = cellStyleFor(text, isWeekendCol(col));
      }
      sheet.setRowHeight(r, 16);
    }

    excelRow = dateRow + 1 + maxRows;
  }

  return excel.encode() ?? [];
}
