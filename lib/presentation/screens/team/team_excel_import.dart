import 'dart:io';

import 'package:excel/excel.dart' as xl;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:moniq/presentation/screens/calendar/calendar_export_downloader_stub.dart'
    if (dart.library.html) 'package:moniq/presentation/screens/calendar/calendar_export_downloader_web.dart';
import 'package:moniq/presentation/screens/calendar/calendar_export_excel.dart';
import 'package:moniq/presentation/viewmodels/team_calendar_viewmodel.dart';
import 'package:moniq/data/repositories/schedule_repository.dart';
import 'package:moniq/data/repositories/shift_repository.dart';
import 'package:moniq/data/repositories/team_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/theme/app_typography.dart';

/// Excel 파일에서 팀 일정을 가져오는 함수
///
/// 지원 형식:
/// - 행: 날짜 (yyyy-MM-dd 또는 MM/dd 등)
/// - 열: 이름, 날짜, 근무유형
/// 또는 캘린더 형태의 Excel (내보내기한 형태)
Future<void> importTeamExcel(
  BuildContext context,
  WidgetRef ref, {
  required String teamId,
  required ShiftRepository shiftRepo,
  required ScheduleRepository scheduleRepo,
  required TeamRepository teamRepo,
}) async {
  // 1. 파일 선택 — 웹은 path가 없으므로 bytes를 함께 로드한다.
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['xlsx', 'xls'],
    withData: true,
  );

  if (result == null || result.files.isEmpty) return;
  if (!context.mounted) return;

  final file = result.files.first;
  // 웹: file.bytes / 모바일·데스크톱: file.path 로 읽기
  final fileBytes = file.bytes ??
      (file.path != null ? File(file.path!).readAsBytesSync() : null);
  if (fileBytes == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('파일을 읽을 수 없습니다')),
      );
    }
    return;
  }

  try {
    // 2. Excel 파일 읽기
    final excel = xl.Excel.decodeBytes(fileBytes);

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
    // 팀원이 아닌(매칭 실패) 이름 — 미리보기/등록에서 제외하고 사용자에게 안내한다.
    final nonMemberNames = <String>{};

    final dayRegex = RegExp(r'^(\d{1,2})일$');
    final ymRegex = RegExp(r'(\d{4})년\s*(\d{1,2})월');
    final isoDateRegex = RegExp(r'^(\d{4})-(\d{2})-(\d{2})');

    // 달력 그리드(날짜 셀 / '근무유형' 그룹 헤더 셀 / '■ 이름' 셀)는 열 단위로
    // 위→아래로 읽으며 현재 날짜·근무유형을 추적한다. 구 포맷("N일\n■ 유형 이름"이
    // 한 셀에 묶인 형태)도 같은 로직으로 함께 처리된다.
    for (final sheetName in validSheets) {
      final sheet = excel.tables[sheetName]!;
      final ym = ymRegex.firstMatch(sheetName);
      if (ym == null) continue;
      final sheetYear = int.parse(ym.group(1)!);
      final sheetMonth = int.parse(ym.group(2)!);

      final maxRows = sheet.maxRows;
      final maxCols = sheet.maxColumns;

      for (int c = 0; c < maxCols; c++) {
        DateTime? date;
        String? currentTypeId;
        String? currentTypeName;

        for (int r = 0; r < maxRows; r++) {
          final cell = sheet.cell(
              xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r));
          final raw = cell.value?.toString().trim() ?? '';
          if (raw.isEmpty) continue;

          for (final line in raw.split('\n')) {
            final trimmed = line.trim();
            if (trimmed.isEmpty) continue;

            // 'N일' → 새 날짜, 근무유형 컨텍스트 초기화
            final dayMatch = dayRegex.firstMatch(trimmed);
            if (dayMatch != null) {
              date = DateTime(
                  sheetYear, sheetMonth, int.parse(dayMatch.group(1)!));
              currentTypeId = null;
              currentTypeName = null;
              continue;
            }

            // 'yyyy-MM-dd' → 날짜
            final isoMatch = isoDateRegex.firstMatch(trimmed);
            if (isoMatch != null) {
              date = DateTime(
                int.parse(isoMatch.group(1)!),
                int.parse(isoMatch.group(2)!),
                int.parse(isoMatch.group(3)!),
              );
              currentTypeId = null;
              currentTypeName = null;
              continue;
            }

            // '■'는 선택적 — 있으면 떼고, 유무와 무관하게 동일하게 처리한다.
            final hadSquare = trimmed.startsWith('■');
            final content =
                hadSquare ? trimmed.substring(1).trim() : trimmed;
            if (content.isEmpty) continue;

            final parts = content.split(RegExp(r'\s+'));

            // 1) 근무유형 그룹 헤더 — '■' 없이 단독으로 온 근무유형명
            if (!hadSquare && parts.length == 1) {
              final tid = shiftTypeMap[content.toLowerCase()];
              if (tid != null) {
                currentTypeId = tid;
                currentTypeName = content;
                continue;
              }
            }

            // 2) 근무 한 건
            String? typeId;
            String? typeName;
            String userName;
            if (parts.length >= 2 &&
                shiftTypeMap.containsKey(parts.first.toLowerCase())) {
              // '■ 데이 백하은' 또는 '데이 백하은' (근무유형 + 이름)
              typeId = shiftTypeMap[parts.first.toLowerCase()];
              typeName = parts.first;
              userName = parts.sublist(1).join(' ');
            } else if (currentTypeId != null && date != null) {
              // '백하은' 또는 '■ 백하은' (이름만 — 근무유형은 위 그룹 헤더에서)
              typeId = currentTypeId;
              typeName = currentTypeName;
              userName = content;
            } else {
              // 날짜·근무유형 컨텍스트가 없으면 타이틀/요일 헤더 등으로 보고 무시
              continue;
            }

            // 샘플 플레이스홀더는 무시
            if (userName == '팀원명') continue;

            if (typeId == null || date == null) {
              skipped++;
              continue;
            }

            // 팀원이 아닌 사람은 근무 등록 불가 → 제외하고 별도 안내
            final userId = memberNameMap[userName.toLowerCase()];
            if (userId == null) {
              nonMemberNames.add(userName);
              continue;
            }

            parsed.add(_ParsedShift(
              date: date,
              shiftTypeId: typeId,
              shiftTypeName: typeName ?? '',
              userName: userName,
              userId: userId,
            ));
          }
        }
      }
    }

    if (!context.mounted) return;

    // 팀원이 아닌 사람이 있으면 등록 불가 안내 (미리보기에서는 이미 제외됨)
    if (nonMemberNames.isNotEmpty) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => _NonMemberDialog(names: nonMemberNames.toList()),
      );
      if (!context.mounted) return;
    }

    if (parsed.isEmpty) {
      // 비팀원 안내를 이미 보여줬다면 중복 안내하지 않는다.
      if (nonMemberNames.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(skipped > 0
                ? '가져올 수 있는 일정이 없습니다 ($skipped건 매칭 실패)'
                : '가져올 수 있는 일정이 없습니다. 지원하는 형식인지 확인해주세요.'),
          ),
        );
      }
      return;
    }

    // 5. 이미 일정이 있는 월인지 확인 — 중복 가져오기 방지
    final monthsToImport = <DateTime>{
      for (final p in parsed) DateTime(p.date.year, p.date.month),
    };
    final existingMonths = <DateTime>[];
    for (final month in monthsToImport) {
      final existing =
          await shiftRepo.getTeamMonthlyShifts(teamId: teamId, month: month);
      if (existing.isNotEmpty) existingMonths.add(month);
    }
    if (existingMonths.isNotEmpty) {
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => _MonthExistsDialog(months: existingMonths),
      );
      return;
    }

    if (!context.mounted) return;

    // 6. 미리보기 다이얼로그
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ImportPreviewDialog(
        parsed: parsed,
        skipped: skipped,
      ),
    );

    if (confirm != true || !context.mounted) return;

    // 7. 스케줄 생성 + shifts 삽입
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

    // 8. 발행 — 팀 캘린더는 published 스케줄만 표시하므로 즉시 발행한다.
    await scheduleRepo.publishSchedule(schedule.id);

    // 9. 가져온 일정의 달로 캘린더 포커스를 이동(현재 달 대신).
    ref.read(pendingTeamCalendarFocusProvider(teamId).notifier).state =
        DateTime(periodStart.year, periodStart.month, periodStart.day);

    // 10. 팀 캘린더 새로고침 — 방금 가져온 일정이 바로 보이도록 무효화한다.
    ref.invalidate(teamCalendarViewModelProvider(teamId));

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
/// - 근무표 내보내기와 동일한 달력 그리드 포맷
/// - 각 날짜에 근무유형(데이/이브닝/나이트…) 헤더 + "■ 팀원명" 예시를 채워 준다.
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

    // 근무 유형을 데이 → 이브닝 → 나이트 순으로 정렬
    final sortedTypes = [...shiftTypes]..sort((a, b) =>
        shiftTypeOrder(a.code, a.name).compareTo(shiftTypeOrder(b.code, b.name)));
    final typeNames = sortedTypes.isNotEmpty
        ? sortedTypes.map((t) => t.name).toList()
        : <String>['데이', '이브닝', '나이트'];

    // 각 날짜 동일 템플릿: 근무유형 헤더 + '팀원명' 4칸씩
    const placeholdersPerType = 4;
    final dayTemplate = <String>[];
    for (final typeName in typeNames) {
      dayTemplate.add(typeName);
      for (int i = 0; i < placeholdersPerType; i++) {
        dayTemplate.add('팀원명');
      }
    }

    final daysInMonth = DateTime(target.year, target.month + 1, 0).day;
    final perDay = <int, List<String>>{
      for (int d = 1; d <= daysInMonth; d++) d: [...dayTemplate],
    };

    final bytes = buildCalendarGridExcelBytes(
      year: target.year,
      month: target.month,
      title: '$sheetName 근무표 (샘플 양식)',
      perDay: perDay,
      typeHeaderLabels: typeNames.toSet(),
    );
    if (bytes.isEmpty) throw Exception('파일 생성 실패');

    if (!context.mounted) return;

    if (kIsWeb) {
      // 웹: 브라우저 다운로드 트리거
      await downloadFileWeb(
        'moniq_sample_$sheetName.xlsx',
        bytes,
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
    } else {
      // 모바일·데스크톱: 임시 파일 생성 후 공유
      final tempDir = await getTemporaryDirectory();
      final path = '${tempDir.path}/moniq_sample_$sheetName.xlsx';
      final file = File(path);
      await file.writeAsBytes(bytes);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: '모닝큐 Excel 샘플 양식',
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('샘플 생성 오류: $e')),
      );
    }
  }
}

/// 현재 팀 캘린더에 등록된 근무를 Excel 근무표로 내보낸다.
/// - 시트명: "yyyy년 M월" (현재 보고 있는 월)
/// - 웹: 브라우저 다운로드 / 모바일·데스크톱: 임시 파일 공유
Future<void> exportTeamRosterExcel(
  BuildContext context,
  WidgetRef ref, {
  required TeamCalendarState state,
}) async {
  try {
    final shiftCount =
        state.monthlyShifts.values.fold<int>(0, (sum, v) => sum + v.length);
    if (shiftCount == 0) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('내보낼 근무가 없습니다')),
        );
      }
      return;
    }

    final bytes = await generateTeamExcelBytes(state, ref);
    final fileName =
        '${state.teamName}_${state.focusedMonth.year}년 ${state.focusedMonth.month}월_근무표.xlsx';

    if (!context.mounted) return;

    if (kIsWeb) {
      await downloadFileWeb(
        fileName,
        bytes,
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
    } else {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: '${state.teamName} 근무표',
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('근무표 내보내기 오류: $e')),
      );
    }
  }
}

/// 팀원이 아닌 사람이 포함되어 있을 때 표시하는 안내 모달.
/// 팀원이 아닌 인원이 포함돼 일부가 제외됐을 때 표시하는 안내 모달.
///
/// 톤은 [_ImportPreviewDialog]와 통일: [Dialog] 셸 + maxWidth 제한 +
/// 헤더 아이콘 칩 + [AppTypography] + pill 버튼.
class _NonMemberDialog extends StatelessWidget {
  const _NonMemberDialog({required this.names});

  final List<String> names;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Dialog(
      backgroundColor: cs.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.borderRadiusLg,
      ),
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxl,
        vertical: AppSpacing.xxl,
      ),
      child: ConstrainedBox(
        // 웹/데스크톱에서 거대하게 늘어나지 않도록 최대 너비 제한.
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 헤더: 아이콘 칩 + 제목 + 안내 문구 ──
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xxl,
                AppSpacing.xxl,
                AppSpacing.xxl,
                AppSpacing.lg,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: AppRadius.borderRadiusMd,
                    ),
                    child: Icon(
                      Icons.person_off_rounded,
                      size: 24,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '일부 인원 제외됨',
                          style: AppTypography.titleLarge.copyWith(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '팀원이 아닌 사람은 근무 등록이 불가능합니다.',
                          style: AppTypography.bodyMedium.copyWith(
                            color: cs.onSurfaceVariant,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              thickness: 1,
              color: cs.outlineVariant.withValues(alpha: 0.5),
            ),
            // ── 본문: 제외된 인원 칩 목록 (높이 제한 + 스크롤) ──
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xxl,
                    vertical: AppSpacing.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '제외된 인원',
                        style: AppTypography.caption.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          for (final name in names)
                            _NonMemberNameChip(name: name),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Divider(
              height: 1,
              thickness: 1,
              color: cs.outlineVariant.withValues(alpha: 0.5),
            ),
            // ── 액션: 확인(주요) 단일 버튼 ──
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.md,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.borderRadiusFull,
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text(
                  '확인',
                  style: AppTypography.labelLarge.copyWith(
                    color: cs.onPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 제외된 인원 한 명을 나타내는 칩.
class _NonMemberNameChip extends StatelessWidget {
  const _NonMemberNameChip({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: AppRadius.borderRadiusFull,
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Text(
        name,
        style: AppTypography.labelMedium.copyWith(
          color: cs.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// 가져오려는 월에 이미 일정이 있을 때 표시하는 안내 모달.
///
/// 톤은 [_NonMemberDialog]/[_ImportPreviewDialog]와 통일: [Dialog] 셸 +
/// maxWidth 제한 + 헤더 아이콘 칩 + [AppTypography] + pill 버튼.
/// 반환값은 void이며 '확인' 시 [Navigator.pop] 한다.
class _MonthExistsDialog extends StatelessWidget {
  const _MonthExistsDialog({required this.months});

  final List<DateTime> months;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sorted = [...months]..sort((a, b) => a.compareTo(b));
    final labels = sorted.map((m) => '${m.year}년 ${m.month}월').toList();
    return Dialog(
      backgroundColor: cs.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.borderRadiusLg,
      ),
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxl,
        vertical: AppSpacing.xxl,
      ),
      child: ConstrainedBox(
        // 웹/데스크톱에서 거대하게 늘어나지 않도록 최대 너비 제한.
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 헤더: 주의 아이콘 칩 + 제목 + 안내 문구 ──
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xxl,
                AppSpacing.xxl,
                AppSpacing.xxl,
                AppSpacing.lg,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: AppRadius.borderRadiusMd,
                    ),
                    child: Icon(
                      Icons.event_busy_rounded,
                      size: 24,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '가져올 수 없습니다',
                          style: AppTypography.titleLarge.copyWith(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '이미 등록된 일정이 있는 달입니다.',
                          style: AppTypography.bodyMedium.copyWith(
                            color: cs.onSurfaceVariant,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              thickness: 1,
              color: cs.outlineVariant.withValues(alpha: 0.5),
            ),
            // ── 본문: 대상 월 칩 + 안내 문구 ──
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xxl,
                vertical: AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '대상 월',
                    style: AppTypography.caption.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final label in labels)
                        _MonthExistsChip(label: label),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    '기존 일정을 삭제한 후 다시 가져오기를 시도해주세요.',
                    style: AppTypography.bodyMedium.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              thickness: 1,
              color: cs.outlineVariant.withValues(alpha: 0.5),
            ),
            // ── 액션: 확인(주요) 단일 pill 버튼 ──
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.md,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.borderRadiusFull,
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text(
                  '확인',
                  style: AppTypography.labelLarge.copyWith(
                    color: cs.onPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 이미 일정이 등록된 대상 월 하나를 나타내는 강조 칩.
class _MonthExistsChip extends StatelessWidget {
  const _MonthExistsChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: AppRadius.borderRadiusFull,
        border: Border.all(
          color: cs.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Text(
        label,
        style: AppTypography.labelMedium.copyWith(
          color: cs.onPrimaryContainer,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
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

/// 가져올 일정을 날짜별로 정리해 보여주는 미리보기 모달.
///
/// 디자인 시스템 토큰만 사용하며, 웹/데스크톱에서는 최대 너비 460px로 제한해
/// 카드형으로 가운데 정렬된다. 항목이 많아도 본문이 스크롤된다.
/// `Navigator.pop(context, true)` = 가져오기, `false` = 취소 규약을 유지한다.
class _ImportPreviewDialog extends StatelessWidget {
  const _ImportPreviewDialog({
    required this.parsed,
    required this.skipped,
  });

  final List<_ParsedShift> parsed;
  final int skipped;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dateFormat = DateFormat('MM.dd (E)', 'ko_KR');

    // 날짜별 그룹핑 — 날짜 오름차순으로 정렬해 표시한다.
    final grouped = <DateTime, List<_ParsedShift>>{};
    for (final p in parsed) {
      final key = DateTime(p.date.year, p.date.month, p.date.day);
      grouped.putIfAbsent(key, () => []).add(p);
    }
    final dateKeys = grouped.keys.toList()..sort();

    return Dialog(
      backgroundColor: cs.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.borderRadiusLg,
      ),
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxl,
        vertical: AppSpacing.xxl,
      ),
      child: ConstrainedBox(
        // 웹/데스크톱에서 거대하게 늘어나지 않도록 최대 너비 제한.
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 헤더: 아이콘 칩 + 제목 + 요약 ──
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xxl,
                AppSpacing.xxl,
                AppSpacing.xxl,
                AppSpacing.lg,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: AppRadius.borderRadiusMd,
                    ),
                    child: Icon(
                      Icons.event_available_rounded,
                      size: 24,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '가져올 일정 확인',
                          style: AppTypography.titleLarge.copyWith(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '총 ${parsed.length}건의 일정을 가져옵니다',
                          style: AppTypography.bodyMedium.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        if (skipped > 0) ...[
                          const SizedBox(height: 2),
                          Text(
                            '$skipped건은 매칭되지 않아 제외됩니다',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              thickness: 1,
              color: cs.outlineVariant.withValues(alpha: 0.5),
            ),
            // ── 본문: 날짜별 그룹 리스트 (높이 제한 + 스크롤) ──
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xxl,
                    vertical: AppSpacing.lg,
                  ),
                  itemCount: dateKeys.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, index) {
                    final dateKey = dateKeys[index];
                    final shifts = grouped[dateKey]!;
                    return _ImportPreviewDateRow(
                      dateLabel: dateFormat.format(dateKey),
                      shifts: shifts,
                    );
                  },
                ),
              ),
            ),
            Divider(
              height: 1,
              thickness: 1,
              color: cs.outlineVariant.withValues(alpha: 0.5),
            ),
            // ── 액션: 취소(보조) + 가져오기(주요) ──
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.md,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.borderRadiusFull,
                          ),
                          side: BorderSide(color: cs.outlineVariant),
                        ),
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(
                          '취소',
                          style: AppTypography.labelLarge.copyWith(
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: cs.primary,
                          foregroundColor: cs.onPrimary,
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.md,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.borderRadiusFull,
                          ),
                        ),
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(
                          '가져오기',
                          style: AppTypography.labelLarge.copyWith(
                            color: cs.onPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 미리보기 모달의 한 날짜 행 — 날짜 라벨 + 근무 칩들.
class _ImportPreviewDateRow extends StatelessWidget {
  const _ImportPreviewDateRow({
    required this.dateLabel,
    required this.shifts,
  });

  final String dateLabel;
  final List<_ParsedShift> shifts;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              dateLabel,
              style: AppTypography.labelMedium.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: shifts.map((s) {
              final label = s.userName != null
                  ? '${s.shiftTypeName} ${s.userName}'
                  : s.shiftTypeName;
              return _ImportShiftChip(label: label);
            }).toList(),
          ),
        ),
      ],
    );
  }
}

/// 근무 한 건을 나타내는 칩 — surfaceContainerHigh 셸 위 단정한 톤.
class _ImportShiftChip extends StatelessWidget {
  const _ImportShiftChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: AppSpacing.xs + 1,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: AppRadius.borderRadiusFull,
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: cs.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
