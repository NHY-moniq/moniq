import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moniq/core/utils/color_utils.dart';
import 'package:moniq/core/utils/recurrence_rule.dart';
import 'package:moniq/core/utils/time_utils.dart';
import 'package:moniq/data/datasources/personal_event_local_data_source.dart';
import 'package:moniq/data/datasources/personal_event_remote_data_source.dart'
    show kPersonalTeamImportMarker;
import 'package:moniq/data/datasources/personal_hidden_shifts_local_data_source.dart';
import 'package:moniq/data/datasources/personal_shift_override_remote_data_source.dart';
import 'package:moniq/data/datasources/personal_shift_type_local_data_source.dart';
import 'package:moniq/data/models/shift_type_model.dart';
import 'package:moniq/data/models/shift_with_type.dart';
import 'package:moniq/data/providers/shift_providers.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/home_viewmodel.dart';
import 'package:moniq/presentation/widgets/common/moniq_bottom_sheet.dart';
import 'package:moniq/presentation/widgets/common/moniq_date_picker_sheet.dart';
import 'package:moniq/presentation/widgets/common/moniq_date_time_picker_sheet.dart';

import 'calendar_drawer.dart' show PersonalShiftTypeSheet;
import 'calendar_providers.dart';

part 'calendar_dialogs_forms.dart';
part 'calendar_dialogs_widgets.dart';

// ── Helper functions ──

void refreshAll(WidgetRef ref, DateTime date) {
  // 모든 이벤트/노트 provider 캐시를 한번에 갱신
  ref.read(eventRefreshProvider.notifier).state++;
}

/// 바텀시트 저장 핸들러용 컨테이너.
///
/// 시트를 띄운 화면의 [WidgetRef]를 클로저로 잡으면 그 화면이 리빌드/이탈로
/// dispose됐을 때 "Cannot use ref after the widget was disposed"로 저장이
/// 실패한다. 시트 자신의 context에서 컨테이너를 얻으면 호출자 수명과 무관하게
/// 안전하다.
ProviderContainer sheetContainer(BuildContext ctx) =>
    ProviderScope.containerOf(ctx, listen: false);

TimeOfDay parseTime(String time) {
  final parts = time.split(':');
  return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
}

String formatTime(TimeOfDay time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

/// 일정 폼의 시작/종료 일자 버튼 라벨 (예: `7.27 (월)`).
String formatEventDate(DateTime date) => DateFormat('M.d (E)').format(date);

int _minutesOf(TimeOfDay t) => t.hour * 60 + t.minute;

/// 팀 근무 유형(ShiftTypeModel)을 개인 근무 유형(PersonalShiftType)으로 변환.
/// 개인 캘린더의 빠른추가/변경 칩과 셀 미리보기에서 팀 유형을 재사용하기 위함.
PersonalShiftType personalTypeFromTeam(ShiftTypeModel t) => PersonalShiftType(
  id: t.id,
  name: t.name,
  code: t.code,
  startTime: t.startTime ?? '',
  endTime: t.endTime ?? '',
  color: t.color,
);

/// 빠른 추가/변경 칩에 쓸 근무 유형 목록 — **항상 '오프'가 맨 앞**에 오게 한다.
///
/// 즐겨찾기 팀이 있으면 팀 근무 유형을 쓰는데, 팀에 오프 유형이 없는 경우가
/// 많다. 개인 캘린더에서 오프를 찍는 일은 잦으므로 없으면 기본 오프를 끼워
/// 넣고, 그다음 오프→데이→이브닝→나이트→교육 순으로 정렬한다.
List<PersonalShiftType> shiftTypesForQuickPick(List<PersonalShiftType> types) {
  final hasOff = types.any((t) => isOffShiftName(t.name, t.code));
  final withOff = hasOff
      ? types
      : [
          PersonalShiftTypeLocalDataSource.defaultTypes
              .firstWhere((t) => t.id == 'off'),
          ...types,
        ];
  return sortShiftTypesForDisplay(withOff);
}

// ── Dialog / Bottom Sheet functions ──

/// 근무를 연속으로 넣는 동안 시트를 이 비율까지 줄여 뒤 캘린더가 보이게 한다.
const _kAddSheetCompactFactor = 0.34;

/// 근무 칩·삭제·설정 버튼의 최소 높이 — 연타하는 버튼이라 터치 영역을 키우되,
/// 시트가 두꺼워 보이지 않게 42로 맞춘다(기본 36은 손가락이 자주 빗나갔다).
const double kMinShiftChipHeight = 42;

void showAddMenu(BuildContext context, WidgetRef ref, DateTime date) {
  // 연속 추가 모드로 들어가면 시트를 줄인다 — 뒤 캘린더에 근무가 하나씩
  // 채워지는 걸 보면서 이어서 누를 수 있어야 하기 때문.
  final heightFactor = ValueNotifier<double>(0.8);
  // 시트가 닫힌 뒤에도 안전하게 정리할 수 있도록 미리 잡아둔다.
  final focusNotifier = ref.read(addSheetFocusProvider.notifier);
  showMoniqBottomSheet<void>(
    context: context,
    eyebrow: 'ADD',
    title: '추가하기',
    // 근무 유형 개수만큼 칩이 줄바꿈되어 높이가 사용자마다 다르다.
    // 기본 상한(0.56)으로는 유형이 5개만 돼도 하단이 잘렸다.
    maxHeightFactor: 0.8,
    heightFactor: heightFactor,
    // 축소 모드에서 뒤 캘린더를 읽을 수 있도록 배리어를 옅게.
    barrierColor: Colors.black.withValues(alpha: 0.18),
    child: _AddMenuSheet(
      hostContext: context,
      date: date,
      heightFactor: heightFactor,
    ),
  ).whenComplete(() {
    heightFactor.dispose();
    focusNotifier.state = null;
  });
}

/// [showAddMenu]의 본문.
///
/// 근무 유형 칩을 누르면 시트를 닫지 않고 그 자리에서 근무를 추가한 뒤 대상
/// 날짜를 하루 앞으로 옮긴다 → 연속으로 누르면 연속한 날짜에 근무가 쌓인다.
/// (일정/메모 추가처럼 다른 화면으로 넘어가는 항목은 기존대로 시트를 닫는다)
class _AddMenuSheet extends ConsumerStatefulWidget {
  const _AddMenuSheet({
    required this.hostContext,
    required this.date,
    required this.heightFactor,
  });

  /// 시트가 닫힌 뒤 다음 화면(일정 폼 등)을 띄울 때 쓸 바깥 컨텍스트.
  final BuildContext hostContext;
  final DateTime date;

  /// 연속 추가 모드에서 시트를 줄이기 위해 셸과 공유하는 높이 비율.
  final ValueNotifier<double> heightFactor;

  @override
  ConsumerState<_AddMenuSheet> createState() => _AddMenuSheetState();
}

class _AddMenuSheetState extends ConsumerState<_AddMenuSheet> {
  /// 다음 근무가 추가될 날짜. 칩을 누를 때마다 하루씩 앞으로 간다.
  late DateTime _target = DateTime(
    widget.date.year,
    widget.date.month,
    widget.date.day,
  );

  /// 이번 시트에서 연속으로 추가한 일수 — 0이면 아직 아무것도 안 넣은 상태.
  int _addedDays = 0;

  /// 저장이 끝나기 전에 다음 탭이 들어오면 같은 날짜에 두 번 쓰게 된다.
  /// 저장 작업을 넣는 직렬 큐. 로컬 저장은 read-modify-write라 겹치면
  /// 서로의 결과를 덮어쓸 수 있어 순서대로 흘려보낸다.
  Future<void> _writes = Future<void>.value();

  /// 근무 칩 탭 — **저장을 기다리지 않고** 즉시 다음 날짜로 넘어간다.
  ///
  /// 연속 추가는 빠르게 연타하는 동작이라, 저장이 끝날 때까지 탭을 막으면
  /// 그 사이 누른 것이 통째로 사라진다. 대상 날짜는 탭 시점에 확정하고
  /// (그래서 같은 날에 두 번 쓰이지 않는다) 저장만 큐에 얹는다.
  void _onShiftTypeTap(PersonalShiftType st) {
    final target = _target;
    // 시트가 닫힌 뒤 저장이 끝나도 안전하도록 await 전에 잡아둔다.
    final writer = ShiftEventWriter(ref);
    final shiftTitles = ref.read(shiftEventTitlesProvider);
    final home = ref.read(homeViewModelProvider.notifier);
    final focused = ref.read(homeViewModelProvider).valueOrNull?.focusedMonth;

    // DateTime.add 대신 필드 산술 — 월/연 경계를 정확히 넘긴다.
    final next = DateTime(target.year, target.month, target.day + 1);
    setState(() {
      _target = next;
      _addedDays++;
    });
    // 첫 추가부터 시트를 줄여 뒤 캘린더가 드러나게 한다.
    widget.heightFactor.value = _kAddSheetCompactFactor;
    // 뒤 캘린더의 선택/포커스도 함께 옮겨 어디에 들어가는지 눈으로 따라가게 한다.
    if (focused != null &&
        (focused.year != next.year || focused.month != next.month)) {
      home.changeMonth(next);
    }
    home.selectDate(next);
    // 대상 줄이 시트에 가리면 캘린더가 그만큼 스크롤되도록 알린다.
    ref.read(addSheetFocusProvider.notifier).state = (
      date: next,
      sheetFactor: _kAddSheetCompactFactor,
    );

    _writes = _writes
        .then((_) => writer.setShift(target, st, shiftTitles))
        // 한 건이 실패해도 큐가 멈추면 이후 탭이 모두 유실된다.
        .catchError((_) {});
  }

  /// 삭제 칩 — 지금 보고 있는 날짜의 근무를 지우고 **전날로** 이동한다.
  /// 추가가 앞으로 나아가는 것과 대칭으로, 연속해서 뒤로 지워나갈 수 있다.
  void _onDeleteTap() {
    final target = _target;
    final writer = ShiftEventWriter(ref);
    final shiftTitles = ref.read(shiftEventTitlesProvider);
    final home = ref.read(homeViewModelProvider.notifier);
    final focused = ref.read(homeViewModelProvider).valueOrNull?.focusedMonth;

    final previous = DateTime(target.year, target.month, target.day - 1);
    setState(() => _target = previous);
    widget.heightFactor.value = _kAddSheetCompactFactor;
    if (focused != null &&
        (focused.year != previous.year || focused.month != previous.month)) {
      home.changeMonth(previous);
    }
    home.selectDate(previous);
    ref.read(addSheetFocusProvider.notifier).state = (
      date: previous,
      sheetFactor: _kAddSheetCompactFactor,
    );

    _writes = _writes
        .then((_) => writer.removeShiftsOn(target, shiftTitles))
        .catchError((_) {});
  }

  void _showShiftTypeManager() {
    showMoniqBottomSheet<void>(
      context: context,
      eyebrow: 'MY SHIFT',
      title: '근무 유형 설정',
      child: const PersonalShiftTypeSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // 즐겨찾기 팀이 있으면 그 팀의 근무 유형을 우선 사용.
    // 없으면 개인 근무 유형, 그마저 비어 있으면(전체 삭제됨) 빠른 근무
    // 추가가 사라지지 않도록 기본 근무 유형으로 대체한다.
    final teamTypes = ref.watch(favoriteTeamShiftTypesProvider).valueOrNull;
    final personalTypes = ref.watch(personalShiftTypesProvider);
    final rawTypes = (teamTypes != null && teamTypes.isNotEmpty)
        ? teamTypes.map(personalTypeFromTeam).toList()
        : (personalTypes.isNotEmpty
              ? personalTypes
              : PersonalShiftTypeLocalDataSource.defaultTypes);
    // 오프 → 데이 → 이브닝 → 나이트 → 교육 → 그 외 순으로 노출.
    final shiftTypes = shiftTypesForQuickPick(rawTypes);

    // 개인 근무 일정(이름이 근무유형과 매칭)의 저장 인덱스.
    // 화면에 보이는 목록(숨김/팀 근무 숨기기 필터 적용)에서 찾되, 변경·삭제는
    // 저장 위치(originIndex)로 해야 다른 일정이 잘못 바뀌지 않는다.
    // 이 날 시작하는 일정만 대상 — 이어지는 다일 일정은 시작일에서 다룬다.
    final personalShiftIndex =
        ref
            .watch(dateEventOccurrencesProvider(_target))
            .where(
              (o) =>
                  !o.isContinuation &&
                  shiftTypes.any((st) => st.name == o.event.title),
            )
            .firstOrNull
            ?.originIndex ??
        -1;
    final hasPersonalShift = personalShiftIndex >= 0;

    // 팀(서버) 근무
    final teamShifts =
        ref.watch(homeViewModelProvider).valueOrNull?.monthlyShifts[_target] ??
        const <ShiftWithType>[];
    final teamShift = teamShifts.isNotEmpty ? teamShifts.first : null;

    // 연속 추가 중에는 시트를 줄여 뒤 캘린더를 보여주므로, 근무 칩 외의
    // 부가 항목(일정/메모 추가)은 접어 자리를 비운다.
    final compact = _addedDays > 0;

    // 근무 유형이 많아도 시트 전체가 늘어나지 않도록 칩 영역만 스크롤시킨다.
    // (Flexible + 내부 스크롤 → 아래 고정 항목은 항상 보인다)
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          // ── 근무 섹션 ──
          if (teamShift != null) ...[
            // 팀(서버) 근무가 있으면 근무 수정 옵션 제공
            MoniqSheetOption(
              icon: Icons.swap_horiz,
              label: '근무 수정',
              description: '${teamShift.shiftType.name} · 근무 유형 변경',
              accentColor: parseHexColor(teamShift.shiftType.color),
              trailing: const SizedBox.shrink(),
              onTap: () {
                final target = _target;
                Navigator.pop(context);
                editTeamShiftAsPersonal(
                  widget.hostContext,
                  ref,
                  target,
                  teamShift,
                );
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            Divider(height: 1, color: cs.outlineVariant),
            const SizedBox(height: AppSpacing.sm),
          ] else if (shiftTypes.isNotEmpty) ...[
            // ── 근무 일정 빠른 추가/변경 (근무 유형 칩) ──
            Row(
              children: [
                Expanded(
                  child: Text(
                    hasPersonalShift ? '근무 변경' : '근무 일정 추가',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                // 대상 날짜 — 연속 추가 중에는 어디에 들어가는지가 핵심 정보다.
                _TargetDateBadge(date: _target),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            // 유형이 늘어나도 이 영역만 스크롤된다.
            Flexible(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    ...shiftTypes.map(
                      (st) => _ShiftQuickChip(
                        color: parseHexColor(st.color),
                        label: st.name,
                        onTap: () => _onShiftTypeTap(st),
                      ),
                    ),
                    // 삭제 칩 — 추가가 앞으로 가는 것과 대칭으로 뒤로 지워나간다.
                    _DeleteShiftChip(onTap: _onDeleteTap),
                    // 마지막 근무 유형 오른쪽에 붙는 + 칩 —
                    // 누르면 "내 근무 유형 설정"과 같은 [근무 유형 설정] 시트.
                    _AddShiftTypeChip(onTap: _showShiftTypeManager),
                  ],
                ),
              ),
            ),
            if (_addedDays > 0) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                '$_addedDays일 추가됨 · 계속 누르면 ${formatEventDate(_target)}부터 이어집니다',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
            if (!compact) ...[
              const SizedBox(height: AppSpacing.xl),
              Divider(height: 1, color: cs.outlineVariant),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
          if (!compact) ...[
            // ── 일정 추가 ──
            MoniqSheetOption(
              icon: Icons.event,
              label: '일정 추가',
              description: '시간, 색상, 설명을 포함한 일정',
              accentColor: AppColors.success,
              trailing: const SizedBox.shrink(),
              onTap: () {
                final target = _target;
                Navigator.pop(context);
                showEventForm(widget.hostContext, ref, target, null, null);
              },
            ),
            // ── 메모 추가 ──
            MoniqSheetOption(
              icon: Icons.edit_note,
              label: '메모 추가',
              description: '간단한 텍스트 메모',
              accentColor: cs.tertiary,
              trailing: const SizedBox.shrink(),
              onTap: () {
                final target = _target;
                Navigator.pop(context);
                showNoteForm(widget.hostContext, ref, target, null, null);
              },
            ),
          ],
          // 저장은 누르는 즉시 반영되므로 별도 "완료" 버튼을 두지 않는다.
          // 시트는 아래로 쓸어내리거나 바깥을 탭해 닫는다.
      ],
    );
  }
}

/// 근무 칩 줄 끝의 삭제 칩 — 지금 날짜의 근무를 지우고 전날로 이동한다.
class _DeleteShiftChip extends StatelessWidget {
  const _DeleteShiftChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: AppColors.error.withValues(alpha: 0.10),
      shape: const StadiumBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kMinShiftChipHeight),
          child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.delete_outline_rounded,
                size: 18,
                color: AppColors.error,
              ),
              const SizedBox(width: 6),
              Text(
                '삭제',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}

/// 개인 근무 카드의 "수정" — 근무 유형 칩 중에서 고르게 한다.
///
/// 제목/시간/색을 직접 치는 일반 일정 폼보다, 근무는 유형을 바꾸는 게 거의 전부다.
/// 세부 항목을 손봐야 할 때를 위해 아래에 "상세 수정"을 남겨둔다.
void showShiftTypeChangeSheet(
  BuildContext context,
  WidgetRef ref,
  DateTime date,
  int index,
  PersonalEvent existing,
) {
  showMoniqBottomSheet<void>(
    context: context,
    eyebrow: 'SHIFT',
    title: '근무 변경',
    maxHeightFactor: 0.7,
    child: _ShiftTypeChangeBody(
      hostContext: context,
      date: date,
      index: index,
      existing: existing,
    ),
  );
}

class _ShiftTypeChangeBody extends ConsumerWidget {
  const _ShiftTypeChangeBody({
    required this.hostContext,
    required this.date,
    required this.index,
    required this.existing,
  });

  final BuildContext hostContext;
  final DateTime date;
  final int index;
  final PersonalEvent existing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // 빠른 추가 시트와 같은 목록·같은 순서(오프→데이→이브닝→나이트→교육).
    final teamTypes = ref.watch(favoriteTeamShiftTypesProvider).valueOrNull;
    final personalTypes = ref.watch(personalShiftTypesProvider);
    final shiftTypes = shiftTypesForQuickPick(
      (teamTypes != null && teamTypes.isNotEmpty)
          ? teamTypes.map(personalTypeFromTeam).toList()
          : (personalTypes.isNotEmpty
                ? personalTypes
                : PersonalShiftTypeLocalDataSource.defaultTypes),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                existing.title,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            _TargetDateBadge(date: date),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Flexible(
          child: SingleChildScrollView(
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                ...shiftTypes.map(
                  (st) => _ShiftQuickChip(
                    color: parseHexColor(st.color),
                    label: st.name,
                    selected: st.name == existing.title,
                    onTap: () {
                      final writer = ShiftEventWriter(ref);
                      final titles = ref.read(shiftEventTitlesProvider);
                      Navigator.pop(context);
                      writer.setShift(date, st, titles);
                    },
                  ),
                ),
                _AddShiftTypeChip(
                  onTap: () => showMoniqBottomSheet<void>(
                    context: context,
                    eyebrow: 'MY SHIFT',
                    title: '근무 유형 설정',
                    child: const PersonalShiftTypeSheet(),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Divider(height: 1, color: cs.outlineVariant),
        const SizedBox(height: AppSpacing.sm),
        MoniqSheetOption(
          icon: Icons.tune_rounded,
          label: '상세 수정',
          description: '제목, 시간, 색상, 설명 직접 편집',
          trailing: const SizedBox.shrink(),
          onTap: () {
            Navigator.pop(context);
            showEventForm(hostContext, ref, date, index, existing,
                isShift: true);
          },
        ),
      ],
    );
  }
}

/// 근무 칩 줄 맨 끝에 붙는 `+` 칩 — [근무 유형 설정] 시트를 연다.
/// 근무 유형과 같은 크기/모양이라 "유형을 하나 더 만든다"는 뜻이 바로 읽힌다.
class _AddShiftTypeChip extends StatelessWidget {
  const _AddShiftTypeChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      shape: StadiumBorder(side: BorderSide(color: cs.outlineVariant)),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kMinShiftChipHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Center(
              widthFactor: 1,
              child: Icon(Icons.add, size: 20, color: cs.onSurfaceVariant),
            ),
          ),
        ),
      ),
    );
  }
}

/// 연속 추가의 대상 날짜를 보여주는 작은 배지 (예: `7.27 (월)`).
class _TargetDateBadge extends StatelessWidget {
  const _TargetDateBadge({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: AppRadius.borderRadiusFull,
      ),
      child: Text(
        formatEventDate(date),
        style: theme.textTheme.labelSmall?.copyWith(
          color: cs.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// 근무 유형 빠른 선택 칩 — 색 점 + 이름. 흰색 셸 위에서 단정한 톤.
class _ShiftQuickChip extends StatelessWidget {
  const _ShiftQuickChip({
    required this.color,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final Color color;
  final String label;
  final VoidCallback? onTap;

  /// 현재 근무 유형 — 변경 시트에서 지금 값을 알려주기 위해 테두리로 강조.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHighest,
      shape: StadiumBorder(
        side: selected
            ? BorderSide(color: cs.primary, width: 1.5)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: ConstrainedBox(
          // 연속으로 빠르게 누르는 버튼이라 손가락이 빗나가지 않게 넉넉히.
          // (iOS 권장 최소 터치 영역 44pt)
          // alignment를 주면 폭까지 늘어나 Wrap이 한 줄에 하나씩 놓으므로,
          // 높이만 키우는 ConstrainedBox를 쓴다.
          constraints: const BoxConstraints(minHeight: kMinShiftChipHeight),
          child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}

/// 근무 유형 변경 시트의 한 줄 옵션. 색 칩(코드) + 이름 + 시간(있을 때만).
/// `request_create_widgets.dart`의 `_PickerOptionTile`과 동일한 톤으로,
/// 선택(현재 근무 유형) 시 primary 배경/테두리 + 체크로 강조하고 탭을 막는다.
class _ShiftTypePickerTile extends StatelessWidget {
  const _ShiftTypePickerTile({
    required this.code,
    required this.name,
    required this.color,
    required this.selected,
    required this.onTap,
    this.timeText,
  });

  final String code;
  final String name;
  final Color color;
  final bool selected;
  final VoidCallback? onTap;
  final String? timeText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // 선택(현재) 항목은 primary 톤(연한 배경 + 테두리)으로 강조하고,
    // 그 외는 표준 시트 행처럼 surfaceContainer 톤으로 둔다.
    final bgColor = selected
        ? cs.primaryContainer.withValues(alpha: 0.5)
        : cs.surfaceContainerHigh;
    final borderColor = selected ? cs.primary : Colors.transparent;

    return Material(
      color: bgColor,
      borderRadius: AppRadius.borderRadiusMd,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.borderRadiusMd,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: AppRadius.borderRadiusMd,
            border: Border.all(color: borderColor),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: AppRadius.borderRadiusSm,
                ),
                child: Text(
                  code,
                  style: TextStyle(color: color, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurface,
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                    ),
                    if (timeText != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        timeText!,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_rounded, size: 20, color: cs.primary),
            ],
          ),
        ),
      ),
    );
  }
}

/// 근무 유형 하나로 만드는 개인 일정.
PersonalEvent _shiftEventOf(DateTime date, PersonalShiftType st) => PersonalEvent(
  date: DateTime(date.year, date.month, date.day),
  title: st.name,
  startTime: st.startTime,
  endTime: st.endTime,
  color: st.color,
  createdAt: DateTime.now(),
);

/// 저장이 끝난 뒤에도 안전하게 화면을 갱신하기 위한 핸들.
///
/// 시트에서 근무를 넣는 동안 사용자가 시트를 닫으면 위젯이 dispose되고,
/// 그 뒤 `ref`를 쓰면 "Cannot use ref after the widget was disposed"로 터진다.
/// await **전에** 필요한 것만 뽑아두면 저장이 늦게 끝나도 갱신이 유실되지 않는다.
class ShiftEventWriter {
  ShiftEventWriter(WidgetRef ref)
    : _ds = ref.read(personalEventDataSourceProvider),
      _hidden = ref.read(personalHiddenShiftsDataSourceProvider),
      _refresh = ref.read(eventRefreshProvider.notifier);

  final PersonalEventLocalDataSource _ds;
  final PersonalHiddenShiftsLocalDataSource _hidden;
  final StateController<int> _refresh;

  /// 근무를 새로 넣은 날은 "근무 삭제"로 숨긴 상태를 푼다.
  /// (그 달을 통째로 숨겨둔 경우, 풀지 않으면 넣자마자 다시 가려진다)
  Future<void> _unhide(DateTime date) => _hidden.unhideDates([date]);

  /// 근무 유형으로 빠르게 일정 추가
  Future<void> add(DateTime date, PersonalShiftType st) async {
    await _ds.addEvent(_shiftEventOf(date, st));
    await _unhide(date);
    _refresh.state++;
  }

  /// 그 날의 개인 근무를 [st]로 **교체**한다 — 하루에 개인 근무는 하나뿐.
  ///
  /// 화면에서 읽은 인덱스로 add/change를 나누면, 빠르게 두 번 누를 때 두 탭이
  /// 모두 "근무 없음"으로 판단해 같은 날에 근무가 두 개 쌓인다. 저장 직전에
  /// 실제 저장된 목록을 다시 보고 기존 근무를 지운 뒤 넣어 그 경우를 막는다.
  /// 팀에서 가져온(import) 근무는 팀 데이터라 건드리지 않는다.
  Future<void> setShift(
    DateTime date,
    PersonalShiftType st,
    Set<String> shiftTitles,
  ) async {
    final existing = _ds.getEvents(date);
    for (var i = existing.length - 1; i >= 0; i--) {
      final e = existing[i];
      final isImport =
          e.description?.startsWith(kPersonalTeamImportMarker) ?? false;
      if (!isImport && shiftTitles.contains(e.title)) {
        await _ds.removeEvent(date, i);
      }
    }
    await _ds.addEvent(_shiftEventOf(date, st));
    await _unhide(date);
    _refresh.state++;
  }

  /// 기존 개인 근무 일정을 다른 근무 유형으로 교체(변경).
  Future<void> change(DateTime date, int index, PersonalShiftType st) async {
    await _ds.updateEvent(date, index, _shiftEventOf(date, st));
    await _unhide(date);
    _refresh.state++;
  }

  /// 그 날의 개인 근무를 모두 지운다 (팀에서 가져온 근무는 그대로 둔다).
  /// 지울 게 없으면 조용히 넘어간다 — 연속 삭제 중 빈 날을 지나갈 수 있다.
  Future<void> removeShiftsOn(DateTime date, Set<String> shiftTitles) async {
    final existing = _ds.getEvents(date);
    var removed = false;
    for (var i = existing.length - 1; i >= 0; i--) {
      final e = existing[i];
      final isImport =
          e.description?.startsWith(kPersonalTeamImportMarker) ?? false;
      if (!isImport && shiftTitles.contains(e.title)) {
        await _ds.removeEvent(date, i);
        removed = true;
      }
    }
    if (removed) _refresh.state++;
  }

  /// 개인 근무 일정 삭제.
  Future<void> remove(DateTime date, int index) async {
    await _ds.removeEvent(date, index);
    _refresh.state++;
  }
}

/// 근무 유형으로 빠르게 일정 추가
Future<void> addShiftEvent(
  WidgetRef ref,
  DateTime date,
  PersonalShiftType st,
) => ShiftEventWriter(ref).add(date, st);

/// 기존 개인 근무 일정을 다른 근무 유형으로 교체(변경).
Future<void> changeShiftEvent(
  WidgetRef ref,
  DateTime date,
  int index,
  PersonalShiftType st,
) => ShiftEventWriter(ref).change(date, index, st);

/// 개인 근무 일정 삭제.
Future<void> removeShiftEvent(WidgetRef ref, DateTime date, int index) =>
    ShiftEventWriter(ref).remove(date, index);

/// 팀 캘린더 근무를 팀 근무 유형 중 하나로 변경 (팀 shift 레코드 직접 수정)
Future<void> editTeamShiftAsPersonal(
  BuildContext context,
  WidgetRef ref,
  DateTime date,
  ShiftWithType shift,
) async {
  final shiftRepo = ref.read(shiftRepositoryProvider);
  final List<ShiftTypeModel> types = await shiftRepo
      .getShiftTypes(shift.shift.teamId)
      .catchError((_) => <ShiftTypeModel>[]);

  if (!context.mounted) return;

  // 현재 "적용된" 근무 타입 = 오버라이드가 있으면 그 타입, 없으면 원본 팀 근무.
  // (오버라이드로 바꿔도 원본을 다시 고를 수 있도록 effective 기준으로 판정)
  final currentOverride = ref
      .read(personalShiftOverridesProvider)
      .valueOrNull?[shift.shift.id];
  final effectiveTypeId =
      currentOverride?.shiftTypeId ?? shift.shift.shiftTypeId;

  final selected = await showMoniqBottomSheet<ShiftTypeModel>(
    context: context,
    eyebrow: 'SELECT',
    title: '근무 유형 변경',
    child: Builder(
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '변경 내용은 내 개인 캘린더에만 반영됩니다',
              style: Theme.of(
                ctx,
              ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (types.isEmpty)
              Text(
                '등록된 근무 유형이 없습니다',
                style: Theme.of(
                  ctx,
                ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.5,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: types.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, i) {
                    final t = types[i];
                    final isCurrent = t.id == effectiveTypeId;
                    final hasTime =
                        t.startTime != null &&
                        t.endTime != null &&
                        t.startTime!.isNotEmpty &&
                        t.endTime!.isNotEmpty;
                    return _ShiftTypePickerTile(
                      code: t.code,
                      name: t.name,
                      color: parseHexColor(t.color),
                      timeText: hasTime
                          ? '${formatTimeString(t.startTime)}'
                                ' ~ ${formatTimeString(t.endTime)}'
                          : null,
                      selected: isCurrent,
                      onTap: isCurrent ? null : () => Navigator.pop(ctx, t),
                    );
                  },
                ),
              ),
          ],
        );
      },
    ),
  );

  if (selected == null || !context.mounted) return;

  // 팀 근무 레코드는 그대로 두고, 개인 오버라이드만 upsert 한다.
  // (승인 불필요 — 변경은 내 개인 캘린더에만 반영되고 기기 간 동기화됨)
  // 단, 원본 팀 근무를 다시 고른 경우엔 오버라이드를 삭제해 완전 복원한다.
  final isRestoreToOriginal = selected.id == shift.shift.shiftTypeId;
  try {
    final overrideRepo = ref.read(personalShiftOverrideRemoteProvider);
    if (isRestoreToOriginal) {
      await overrideRepo.remove(shift.shift.id);
    } else {
      await overrideRepo.upsert(
        PersonalShiftOverrideRemote(
          shiftId: shift.shift.id,
          shiftTypeId: selected.id,
          code: selected.code,
          name: selected.name,
          color: selected.color,
          startTime: selected.startTime,
          endTime: selected.endTime,
        ),
      );
    }
    refreshAll(ref, date);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isRestoreToOriginal
                ? '팀 근무로 복원되었습니다'
                : '"${selected.name}"(으)로 변경되었습니다',
          ),
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('변경 실패: $e')));
    }
  }
}

/// [descriptionMarker]가 주어지면 저장 시 description 앞에 마커가 prepend된다.
/// (프라이빗 팀 일정처럼 일반 개인 일정과 구분하기 위함.)
