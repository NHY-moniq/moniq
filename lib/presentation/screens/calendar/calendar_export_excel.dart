import 'dart:io';

import 'package:excel/excel.dart' as xl;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:moniq/data/providers/team_providers.dart';
import 'package:moniq/presentation/viewmodels/home_viewmodel.dart';
import 'package:moniq/presentation/viewmodels/team_calendar_viewmodel.dart';

import 'calendar_providers.dart';

/// 개인 캘린더 Excel 파일 생성
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

  final dir = await getTemporaryDirectory();
  final file = File(
      '${dir.path}/onoroff_${focusedMonth.year}_${focusedMonth.month}.xlsx');
  final bytes = excel.encode();
  if (bytes != null) {
    await file.writeAsBytes(bytes);
  }
  return file;
}

/// 팀 캘린더 Excel 생성 (ref 사용)
Future<File> generateTeamExcelFile(
    TeamCalendarState state, WidgetRef ref) async {
  // 멤버 이름 맵
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
