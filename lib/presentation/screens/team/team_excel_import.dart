import 'dart:io';

import 'package:excel/excel.dart' as xl;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:moniq/data/repositories/schedule_repository.dart';
import 'package:moniq/data/repositories/shift_repository.dart';
import 'package:moniq/data/repositories/team_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';

/// Excel 파일에서 팀 일정을 가져오는 함수
///
/// 지원 형식:
/// - 행: 날짜 (yyyy-MM-dd 또는 MM/dd 등)
/// - 열: 이름, 날짜, 근무유형
/// 또는 캘린더 형태의 Excel (내보내기한 형태)
Future<void> importTeamExcel(
  BuildContext context, {
  required String teamId,
  required ShiftRepository shiftRepo,
  required ScheduleRepository scheduleRepo,
  required TeamRepository teamRepo,
}) async {
  // 1. 파일 선택
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['xlsx', 'xls'],
  );

  if (result == null || result.files.isEmpty) return;
  if (!context.mounted) return;

  final file = result.files.first;
  if (file.path == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('파일을 읽을 수 없습니다')),
      );
    }
    return;
  }

  try {
    // 2. Excel 파일 읽기
    final bytes = File(file.path!).readAsBytesSync();
    final excel = xl.Excel.decodeBytes(bytes);

    // 3. 근무 유형 로드
    final shiftTypes = await shiftRepo.getShiftTypes(teamId);
    final shiftTypeMap = <String, String>{}; // name/code -> id
    for (final st in shiftTypes) {
      shiftTypeMap[st.name.toLowerCase()] = st.id;
      shiftTypeMap[st.code.toLowerCase()] = st.id;
    }

    // 3-1. 팀 멤버 이름 → userId 매핑
    final members = await teamRepo.getTeamMembersWithUsers(teamId);
    final memberNameMap = <String, String>{}; // displayName/email -> userId
    for (final m in members) {
      if (m.displayName.isNotEmpty) {
        memberNameMap[m.displayName.toLowerCase()] = m.userId;
      }
      // email 앞부분도 매핑
      final emailPrefix = m.displayName.split('@').first.toLowerCase();
      memberNameMap[emailPrefix] = m.userId;
    }

    // 3-2. 시트명 포맷 사전 검증: 최소 1개 시트가 "yyyy년 M월" 패턴을 포함해야 함
    final sheetNameRegex = RegExp(r'(\d{4})년\s*(\d{1,2})월');
    final validSheets = excel.tables.keys
        .where((name) => sheetNameRegex.hasMatch(name))
        .toList();
    if (validSheets.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                '시트명 형식이 올바르지 않습니다. 시트명은 "yyyy년 M월" 형식이어야 합니다. 샘플 양식을 내보내 확인하세요.'),
            duration: Duration(seconds: 5),
          ),
        );
      }
      return;
    }

    // 4. 파싱된 일정 데이터
    final parsed = <_ParsedShift>[];
    int skipped = 0;

    for (final sheetName in validSheets) {
      final sheet = excel.tables[sheetName]!;

      for (int r = 0; r < sheet.maxRows; r++) {
        final row = sheet.row(r);
        if (row.isEmpty) continue;

        // 각 셀에서 "N일\n■ 근무유형 이름" 패턴 파싱 (내보내기 형태)
        for (int c = 0; c < row.length; c++) {
          final cell = row[c];
          if (cell == null || cell.value == null) continue;

          final text = cell.value.toString().trim();
          if (text.isEmpty) continue;

          // "1일\n■ 나이트 홍길동" 패턴
          final lines = text.split('\n');
          DateTime? date;

          for (final line in lines) {
            final trimmed = line.trim();

            // "N일" 패턴으로 날짜 추출
            final dayMatch = RegExp(r'^(\d{1,2})일$').firstMatch(trimmed);
            if (dayMatch != null) {
              final day = int.parse(dayMatch.group(1)!);
              // 시트 이름에서 연/월 추출 시도
              final yearMonthMatch =
                  RegExp(r'(\d{4})년\s*(\d{1,2})월').firstMatch(sheetName);
              if (yearMonthMatch != null) {
                final year = int.parse(yearMonthMatch.group(1)!);
                final month = int.parse(yearMonthMatch.group(2)!);
                date = DateTime(year, month, day);
              }
              continue;
            }

            // "■ 근무유형" 또는 "■ 근무유형 이름" 패턴
            if (trimmed.startsWith('■') && date != null) {
              final content = trimmed.substring(1).trim();
              // 근무유형 매칭 (첫 단어)
              final parts = content.split(' ');
              final typeName = parts.first.toLowerCase();
              final shiftTypeId = shiftTypeMap[typeName];

              if (shiftTypeId != null) {
                final userName = parts.length > 1 ? parts.sublist(1).join(' ') : null;
                final userId = userName != null
                    ? memberNameMap[userName.toLowerCase()]
                    : null;
                parsed.add(_ParsedShift(
                  date: date,
                  shiftTypeId: shiftTypeId,
                  shiftTypeName: parts.first,
                  userName: userName,
                  userId: userId,
                ));
              } else {
                skipped++;
              }
            }

            // yyyy-MM-dd 형태 날짜
            final dateMatch =
                RegExp(r'(\d{4})-(\d{2})-(\d{2})').firstMatch(trimmed);
            if (dateMatch != null) {
              date = DateTime(
                int.parse(dateMatch.group(1)!),
                int.parse(dateMatch.group(2)!),
                int.parse(dateMatch.group(3)!),
              );
            }
          }
        }
      }
    }

    if (!context.mounted) return;

    if (parsed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(skipped > 0
              ? '가져올 수 있는 일정이 없습니다 ($skipped건 매칭 실패)'
              : '가져올 수 있는 일정이 없습니다. 지원하는 형식인지 확인해주세요.'),
        ),
      );
      return;
    }

    // 5. 미리보기 다이얼로그
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ImportPreviewDialog(
        parsed: parsed,
        skipped: skipped,
      ),
    );

    if (confirm != true || !context.mounted) return;

    // 6. 스케줄 생성 + shifts 삽입
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('일정을 가져오는 중...'),
        duration: Duration(seconds: 1),
      ),
    );

    final dates = parsed.map((p) => p.date).toList()..sort();
    final periodStart = dates.first;
    final periodEnd = dates.last;

    final schedule = await scheduleRepo.createSchedule(
      teamId: teamId,
      periodStart: periodStart,
      periodEnd: periodEnd,
    );

    // 매핑 안 된 경우 현재 사용자 ID를 기본값으로
    final fallbackUserId = Supabase.instance.client.auth.currentUser?.id ?? '';

    final shifts = parsed.map((p) => {
      'schedule_id': schedule.id,
      'team_id': teamId,
      'user_id': p.userId ?? fallbackUserId,
      'shift_date':
          '${p.date.year}-${p.date.month.toString().padLeft(2, '0')}-${p.date.day.toString().padLeft(2, '0')}',
      'shift_type_id': p.shiftTypeId,
    }).toList();

    await scheduleRepo.insertShifts(shifts);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${parsed.length}건의 일정을 가져왔습니다'),
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류: $e')),
      );
    }
  }
}

/// 팀 Excel 샘플 양식 파일을 생성하여 공유한다.
/// - 시트명: "yyyy년 M월" (다음 달)
/// - 1행: 월 타이틀
/// - 2행: 요일 헤더
/// - 3행~: 날짜 + "■ 근무코드 이름" 예시 2건
Future<void> exportSampleTemplate(
  BuildContext context, {
  required ShiftRepository shiftRepo,
  required String teamId,
}) async {
  try {
    final shiftTypes = await shiftRepo.getShiftTypes(teamId);
    final now = DateTime.now();
    final target = DateTime(now.year, now.month + 1, 1);
    final sheetName = '${target.year}년 ${target.month}월';

    final excel = xl.Excel.createExcel();
    final sheet = excel[sheetName];
    excel.delete('Sheet1');

    // 1행: 타이틀
    sheet.appendRow([xl.TextCellValue(sheetName)]);
    // 2행: 요일 헤더
    sheet.appendRow(['월', '화', '수', '목', '금', '토', '일']
        .map((d) => xl.TextCellValue(d))
        .toList());

    // 3행: 예시 셀 2개 — 실제 근무 유형 코드를 사용
    final sampleCode = shiftTypes.isNotEmpty ? shiftTypes.first.code : 'D';
    final sampleCode2 = shiftTypes.length > 1 ? shiftTypes[1].code : 'N';
    sheet.appendRow([
      xl.TextCellValue('1일\n■ $sampleCode 홍길동'),
      xl.TextCellValue('2일\n■ $sampleCode2 김철수'),
    ]);

    // 안내 시트
    final guide = excel['안내'];
    guide.appendRow([
      xl.TextCellValue(
          '시트명은 "yyyy년 M월" 형식이어야 합니다. 각 셀에 "N일\\n■ 근무코드 이름" 패턴으로 입력하세요.')
    ]);

    final bytes = excel.encode();
    if (bytes == null) throw Exception('파일 생성 실패');

    final tempDir = await getTemporaryDirectory();
    final path = '${tempDir.path}/moniq_sample_$sheetName.xlsx';
    final file = File(path);
    await file.writeAsBytes(bytes);

    if (!context.mounted) return;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: '모닝큐 Excel 샘플 양식',
      ),
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('샘플 생성 오류: $e')),
      );
    }
  }
}

class _ParsedShift {
  _ParsedShift({
    required this.date,
    required this.shiftTypeId,
    required this.shiftTypeName,
    this.userName,
    this.userId,
  });

  final DateTime date;
  final String shiftTypeId;
  final String shiftTypeName;
  final String? userName;
  final String? userId;
}

class _ImportPreviewDialog extends StatelessWidget {
  const _ImportPreviewDialog({
    required this.parsed,
    required this.skipped,
  });

  final List<_ParsedShift> parsed;
  final int skipped;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MM.dd');

    // 날짜별 그룹핑
    final grouped = <String, List<_ParsedShift>>{};
    for (final p in parsed) {
      final key = dateFormat.format(p.date);
      grouped.putIfAbsent(key, () => []).add(p);
    }

    return AlertDialog(
      title: const Text('가져올 일정 확인'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '총 ${parsed.length}건의 일정을 가져옵니다',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (skipped > 0)
              Text(
                '$skipped건은 매칭되지 않아 제외됩니다',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.error,
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: grouped.keys.length,
                itemBuilder: (context, index) {
                  final dateKey = grouped.keys.elementAt(index);
                  final shifts = grouped[dateKey]!;

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xs),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 50,
                          child: Text(
                            dateKey,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Wrap(
                            spacing: AppSpacing.xs,
                            runSpacing: AppSpacing.xs,
                            children: shifts.map((s) {
                              final label = s.userName != null
                                  ? '${s.shiftTypeName} ${s.userName}'
                                  : s.shiftTypeName;
                              return Chip(
                                label: Text(label,
                                    style: const TextStyle(fontSize: 11)),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                labelPadding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.xs),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('가져오기'),
        ),
      ],
    );
  }
}
