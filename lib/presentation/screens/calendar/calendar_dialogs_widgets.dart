part of 'calendar_dialogs.dart';

// ── 일정 폼 공통 축(axis) ──────────────────────────────────────────────
// 종일/시작/종료 행의 라벨을 같은 x에서 시작시키기 위한 고정 폭.
// 이 값을 공유해야 값 필드들의 좌측 경계도 자동으로 한 줄로 맞는다.
const double _eventRowLabelWidth = 52;

/// 일시 섹션 행 라벨(종일·시작·종료) 스타일 — 세 행이 같은 무게로 보이게 한다.
TextStyle? _eventRowLabelStyle(BuildContext context) {
  final theme = Theme.of(context);
  return theme.textTheme.bodyMedium?.copyWith(
    color: theme.colorScheme.onSurface,
    fontWeight: FontWeight.w600,
  );
}

/// 폼 섹션 라벨 — 일시/색상/설명/반복 그룹의 머리말.
/// 값 필드보다 한 단계 작고 흐린 톤이라 그룹 구분만 하고 시선을 뺏지 않는다.
class _FormSectionLabel extends StatelessWidget {
  const _FormSectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.xs,
        bottom: AppSpacing.sm,
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// 종일 토글 — 시작/종료 행과 같은 축(좌: 라벨, 우: 값)을 쓰는 한 줄 스위치.
/// 예전처럼 날짜 그리드 옆에 세로로 붙지 않아 여백이 어긋나지 않는다.
class _EventAllDayCheckbox extends StatelessWidget {
  const _EventAllDayCheckbox({required this.selected, required this.onChanged});

  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onChanged(!selected),
          borderRadius: AppRadius.borderRadiusMd,
          child: SizedBox(
            height: 40,
            child: Row(
              children: [
                SizedBox(
                  width: _eventRowLabelWidth,
                  child: Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.xs),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('종일', style: _eventRowLabelStyle(context)),
                    ),
                  ),
                ),
                const Spacer(),
                _MiniSwitch(on: selected),
                const SizedBox(width: AppSpacing.xs),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 종일 행의 작은 스위치 — 노브 색은 시프트별 primary 위에서도 대비가 남도록
/// on일 때 onPrimary, off일 때 밝기별로 갈라 고른다.
class _MiniSwitch extends StatelessWidget {
  const _MiniSwitch({required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // 스위치 트랙은 "면" 요소 — 오프처럼 면(cardColor)과 잉크(primary)가
    // 갈라진 시프트에서는 파스텔 면색을 쓴다 (ShiftFillColors 참고).
    final fills = Theme.of(context).extension<ShiftFillColors>();
    final trackOn = fills?.fill ?? cs.primary;
    final knobOn = fills?.onFill ?? cs.onPrimary;
    final knobColor = on
        ? knobOn
        : (cs.brightness == Brightness.dark
              ? cs.onSurface
              : cs.surfaceContainerLowest);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      width: 44,
      height: 26,
      padding: const EdgeInsets.all(3),
      alignment: on ? Alignment.centerRight : Alignment.centerLeft,
      decoration: BoxDecoration(
        color: on ? trackOn : cs.onSurfaceVariant.withValues(alpha: 0.22),
        borderRadius: AppRadius.borderRadiusFull,
      ),
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: knobColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: cs.shadow.withValues(alpha: 0.16),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
      ),
    );
  }
}

/// 일시 영역의 단일 진입점 — "시작 → 종료" 두 값이 함께 보이는 한 줄 버튼.
/// 탭하면 시작·종료를 한 시트에서 오가며 고르는 통합 피커가 열린다.
class _EventRangeButton extends StatelessWidget {
  const _EventRangeButton({
    required this.startValue,
    required this.endValue,
    required this.onTap,
  });

  final String startValue;
  final String endValue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final valueStyle = theme.textTheme.bodyMedium?.copyWith(
      color: cs.onSurface,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
    );

    return Semantics(
      button: true,
      label: '일시',
      value: '$startValue부터 $endValue까지',
      child: Material(
        color: cs.surfaceContainerHigh,
        borderRadius: AppRadius.borderRadiusMd,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.borderRadiusMd,
          child: SizedBox(
            height: 46,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      startValue,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: valueStyle,
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: cs.onSurfaceVariant,
                  ),
                  Expanded(
                    child: Text(
                      endValue,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: valueStyle,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 시작/종료 일자·시간 값 필드. 라벨은 [_EventDateTimeRow]가 맡으므로
/// 값만 가운데에 두고, 채우기 색은 제목/설명 입력과 같은 톤으로 통일한다.
/// [label]은 화면에 그리지 않고 스크린리더 설명으로만 쓴다.
class _EventTimeButton extends StatelessWidget {
  const _EventTimeButton({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Semantics(
      button: true,
      label: label,
      value: value,
      child: Material(
        color: cs.surfaceContainerHigh,
        borderRadius: AppRadius.borderRadiusMd,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.borderRadiusMd,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Center(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 색상 chip — 선택 시 primary 링 + 안쪽 원이 커지며 살짝 떠오른다.
/// 링/여백만으로 선택을 표현해 어떤 시프트 테마에서도 색이 탁해지지 않는다.
class _ColorChip extends StatelessWidget {
  const _ColorChip({
    required this.hex,
    required this.isSelected,
    required this.onTap,
  });

  final String hex;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = parseHexColor(hex);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        width: 40,
        height: 40,
        // 링은 항상 자리를 차지하고 색만 바뀌어야 선택 시 원이 튀지 않는다.
        padding: EdgeInsets.all(isSelected ? 3 : 6),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? cs.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.28),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
        ),
      ),
    );
  }
}

/// "+ 더보기" 행 — 설명·반복처럼 기본 폼에서 숨긴 항목의 진입점.
/// 탭하면 추가 가능한 항목 칩들이 나타나고, 칩을 누르면 해당 섹션이
/// 폼에 인라인으로 펼쳐진다. 남은 칩이 없으면 폼에서 행 자체를 숨긴다.
class _MoreFieldsRow extends StatelessWidget {
  const _MoreFieldsRow({
    required this.expanded,
    required this.onToggle,
    required this.chips,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final List<Widget> chips;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onToggle,
            borderRadius: AppRadius.borderRadiusMd,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 펼치면 +가 ×로 돌아가 닫기 역할임을 암시한다.
                  AnimatedRotation(
                    turns: expanded ? 0.125 : 0,
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOut,
                    child: Icon(
                      Icons.add_rounded,
                      size: 18,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    '더보기',
                    style: tt.labelLarge?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (expanded) ...[
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: chips,
          ),
        ],
      ],
    );
  }
}

/// 더보기 행에서 노출되는 추가 항목 칩 (예: 반복, 설명).
class _AddFieldChip extends StatelessWidget {
  const _AddFieldChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: AppRadius.borderRadiusFull,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.borderRadiusFull,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: cs.onSurfaceVariant),
              const SizedBox(width: AppSpacing.xs),
              Text(
                label,
                style: tt.labelMedium?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 반복 옵션 아이콘 — 빈도의 의미를 시각적으로 보조.
IconData _recurrenceIconFor(String val) {
  switch (val) {
    case 'none':
      return Icons.do_disturb_alt_outlined;
    case 'daily':
      return Icons.today_outlined;
    case 'weekly':
      return Icons.calendar_view_week_rounded;
    case 'biweekly':
      return Icons.event_repeat_rounded;
    case 'monthly':
      return Icons.calendar_month_outlined;
    case 'yearly':
      return Icons.cake_outlined;
    case 'custom':
      return Icons.tune_rounded;
    default:
      return Icons.repeat_rounded;
  }
}

/// 반복 선택 바텀시트 — 원탭 옵션 + 맨 아래 "커스텀…".
///
/// 반환값: 선택된 반복 저장 문자열
/// (`none`/레거시 토큰/`custom:…`), 취소 시 null.
Future<String?> _showRecurrencePickerSheet(
  BuildContext context, {
  required String current,
  required DateTime startDate,
}) {
  final weekday = weekdayShortKo(startDate.weekday);
  final options = <(String, String)>[
    ('none', '반복 안 함'),
    ('daily', '매일'),
    ('weekly', '매주 ($weekday요일)'),
    ('biweekly', '2주마다'),
    ('monthly', '매달 (${startDate.day}일)'),
    ('yearly', '매년'),
  ];
  final isCustom = isCustomRecurrence(current);

  return showMoniqBottomSheet<String>(
    context: context,
    title: '일정 반복',
    eyebrow: 'RECURRENCE',
    maxHeightFactor: 0.8,
    child: Builder(
      builder: (sheetCtx) => SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final opt in options) ...[
              _RecurrenceOptionTile(
                icon: _recurrenceIconFor(opt.$1),
                label: opt.$2,
                selected: opt.$1 == current,
                onTap: () =>
                    Navigator.of(sheetCtx, rootNavigator: true).pop(opt.$1),
              ),
              const SizedBox(height: 6),
            ],
            _RecurrenceOptionTile(
              icon: _recurrenceIconFor('custom'),
              // 현재 값이 커스텀이면 그 요약을 그대로 보여줘 "지금 상태"가
              // 어느 행인지 읽히게 한다.
              label: isCustom ? recurrenceSummaryLabel(current) : '커스텀…',
              selected: isCustom,
              onTap: () async {
                final encoded = await _showCustomRecurrenceSheet(
                  sheetCtx,
                  startDate: startDate,
                  initial: isCustom ? RecurrenceRule.parse(current) : null,
                );
                if (encoded == null || !sheetCtx.mounted) return;
                Navigator.of(sheetCtx, rootNavigator: true).pop(encoded);
              },
            ),
          ],
        ),
      ),
    ),
  );
}

/// 폼에 표시되는 반복 요약 라벨 행 (예: "반복 · 2주마다 · 월·수").
/// [onTap]이 있으면 탭 시 반복 시트를 다시 연다 (새 일정에서만).
class _RecurrenceSummaryRow extends StatelessWidget {
  const _RecurrenceSummaryRow({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FormSectionLabel('반복'),
        Material(
          color: cs.surfaceContainerHigh,
          borderRadius: AppRadius.borderRadiusLg,
          child: InkWell(
            borderRadius: AppRadius.borderRadiusLg,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.repeat_rounded,
                    size: 20,
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      label,
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (onTap != null)
                    Icon(Icons.expand_more_rounded, color: cs.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 커스텀 반복 바텀시트 — 단위/주기/요일/월 기준/종료를 한 시트에서 설정한다.
/// 확인 시 인코딩된 저장 문자열을, 취소 시 null을 반환한다.
Future<String?> _showCustomRecurrenceSheet(
  BuildContext context, {
  required DateTime startDate,
  RecurrenceRule? initial,
}) {
  return showMoniqBottomSheet<String>(
    context: context,
    title: '커스텀 반복',
    eyebrow: 'RECURRENCE',
    maxHeightFactor: 0.85,
    child: _CustomRecurrenceSheetBody(startDate: startDate, initial: initial),
  );
}

enum _RecurrenceEndMode { never, count, until }

class _CustomRecurrenceSheetBody extends StatefulWidget {
  const _CustomRecurrenceSheetBody({required this.startDate, this.initial});

  final DateTime startDate;
  final RecurrenceRule? initial;

  @override
  State<_CustomRecurrenceSheetBody> createState() =>
      _CustomRecurrenceSheetBodyState();
}

class _CustomRecurrenceSheetBodyState
    extends State<_CustomRecurrenceSheetBody> {
  late RecurrenceFreq _freq;
  late int _interval;
  late Set<int> _weekdays;
  late bool _monthlyLastWeekday;
  late _RecurrenceEndMode _endMode;
  late int _endCount;
  late DateTime _untilDate;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _freq = initial?.freq ?? RecurrenceFreq.weekly;
    _interval = initial?.interval ?? 1;
    _weekdays = {
      ...(initial != null && initial.weekdays.isNotEmpty
          ? initial.weekdays
          : {widget.startDate.weekday}),
    };
    _monthlyLastWeekday = initial?.byLastWeekday != null;
    _endMode = initial?.count != null
        ? _RecurrenceEndMode.count
        : (initial?.until != null
              ? _RecurrenceEndMode.until
              : _RecurrenceEndMode.never);
    _endCount = initial?.count ?? 10;
    _untilDate = initial?.until ??
        DateTime(
          widget.startDate.year,
          widget.startDate.month + 1,
          widget.startDate.day,
        );
  }

  /// 현재 선택을 저장 문자열로 인코딩. 단순한 조합(매주 1회 등)은
  /// [RecurrenceRule.encode]가 레거시 토큰으로 정규화한다.
  String _encode() {
    final startWeekday = widget.startDate.weekday;
    // 시작일 요일 하나뿐이면 생략 — 전개 시 시작일 요일이 기본값이라
    // 의미가 같고, 레거시 토큰으로 정규화될 수 있다.
    final weekdays =
        _weekdays.length == 1 && _weekdays.contains(startWeekday)
        ? const <int>{}
        : _weekdays;
    return RecurrenceRule(
      freq: _freq,
      interval: _interval,
      weekdays: _freq == RecurrenceFreq.weekly ? weekdays : const <int>{},
      byLastWeekday: _freq == RecurrenceFreq.monthly && _monthlyLastWeekday
          ? startWeekday
          : null,
      count: _endMode == _RecurrenceEndMode.count ? _endCount : null,
      until: _endMode == _RecurrenceEndMode.until ? _untilDate : null,
    ).encode();
  }

  String get _intervalLabel {
    final unit = switch (_freq) {
      RecurrenceFreq.daily => '일',
      RecurrenceFreq.weekly => '주',
      RecurrenceFreq.monthly => '달',
      RecurrenceFreq.yearly => '년',
    };
    if (_interval == 1) {
      return switch (_freq) {
        RecurrenceFreq.daily => '매일',
        RecurrenceFreq.weekly => '매주',
        RecurrenceFreq.monthly => '매달',
        RecurrenceFreq.yearly => '매년',
      };
    }
    return '$_interval$unit마다';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final startWeekdayKo = weekdayShortKo(widget.startDate.weekday);

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 단위 탭 — 매일/매주/매달/매년.
          const _FormSectionLabel('단위'),
          _SegmentedChoiceRow<RecurrenceFreq>(
            values: RecurrenceFreq.values,
            selected: _freq,
            labelOf: (f) => switch (f) {
              RecurrenceFreq.daily => '매일',
              RecurrenceFreq.weekly => '매주',
              RecurrenceFreq.monthly => '매달',
              RecurrenceFreq.yearly => '매년',
            },
            onChanged: (f) => setState(() => _freq = f),
          ),
          const SizedBox(height: AppSpacing.xl),
          // 반복 주기 (Repeat every N).
          const _FormSectionLabel('주기'),
          Row(
            children: [
              Expanded(
                child: Text(
                  _intervalLabel,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _StepperControl(
                value: _interval,
                min: 1,
                max: 99,
                onChanged: (v) => setState(() => _interval = v),
              ),
            ],
          ),
          if (_freq == RecurrenceFreq.weekly) ...[
            const SizedBox(height: AppSpacing.xl),
            const _FormSectionLabel('요일'),
            _WeekdayMultiSelect(
              selected: _weekdays,
              onToggle: (d) => setState(() {
                if (_weekdays.contains(d)) {
                  // 최소 한 개 요일은 남긴다.
                  if (_weekdays.length > 1) _weekdays.remove(d);
                } else {
                  _weekdays.add(d);
                }
              }),
            ),
          ],
          if (_freq == RecurrenceFreq.monthly) ...[
            const SizedBox(height: AppSpacing.xl),
            const _FormSectionLabel('기준'),
            _SegmentedChoiceRow<bool>(
              values: const [false, true],
              selected: _monthlyLastWeekday,
              labelOf: (last) => last
                  ? '마지막 $startWeekdayKo요일'
                  : '${widget.startDate.day}일',
              onChanged: (v) => setState(() => _monthlyLastWeekday = v),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          // 종료 — 안 함 / N회 후 / 특정 날짜에.
          const _FormSectionLabel('종료'),
          _SegmentedChoiceRow<_RecurrenceEndMode>(
            values: _RecurrenceEndMode.values,
            selected: _endMode,
            labelOf: (m) => switch (m) {
              _RecurrenceEndMode.never => '안 함',
              _RecurrenceEndMode.count => '횟수',
              _RecurrenceEndMode.until => '날짜',
            },
            onChanged: (m) => setState(() => _endMode = m),
          ),
          if (_endMode == _RecurrenceEndMode.count) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$_endCount회 반복 후 종료',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _StepperControl(
                  value: _endCount,
                  min: 1,
                  max: 99,
                  onChanged: (v) => setState(() => _endCount = v),
                ),
              ],
            ),
          ],
          if (_endMode == _RecurrenceEndMode.until) ...[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 46,
              child: _EventTimeButton(
                label: '종료 날짜',
                value: '${formatEventDate(_untilDate)} 까지',
                onTap: () async {
                  final picked = await showMoniqDatePickerSheet(
                    context: context,
                    initialDate: _untilDate,
                    firstDate: widget.startDate,
                    lastDate: DateTime(widget.startDate.year + 5, 12, 31),
                    title: '반복 종료 날짜',
                  );
                  if (picked == null || !mounted) return;
                  setState(() {
                    _untilDate = DateTime(
                      picked.year,
                      picked.month,
                      picked.day,
                    );
                  });
                },
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xxl),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.borderRadiusFull,
                      ),
                      side: BorderSide(color: cs.outlineVariant),
                    ),
                    child: const Text('취소'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, _encode()),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.borderRadiusFull,
                      ),
                    ),
                    child: const Text('확인'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 가로로 꽉 차는 단일 선택 세그먼트 행 (단위/기준/종료 선택에 공용).
class _SegmentedChoiceRow<T> extends StatelessWidget {
  const _SegmentedChoiceRow({
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
  });

  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: AppRadius.borderRadiusFull,
      ),
      child: Row(
        children: [
          for (final v in values)
            Expanded(
              child: Material(
                color: v == selected ? cs.primary : Colors.transparent,
                borderRadius: AppRadius.borderRadiusFull,
                child: InkWell(
                  borderRadius: AppRadius.borderRadiusFull,
                  onTap: () => onChanged(v),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                    child: Text(
                      labelOf(v),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: v == selected ? cs.onPrimary : cs.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// `- N +` 숫자 스테퍼 (1~99 등 좁은 범위 정수 입력).
class _StepperControl extends StatelessWidget {
  const _StepperControl({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    Widget button(IconData icon, bool enabled, VoidCallback onTap) {
      return Material(
        color: cs.surfaceContainerHigh,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: enabled ? onTap : null,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(
              icon,
              size: 18,
              color: enabled
                  ? cs.onSurface
                  : cs.onSurfaceVariant.withValues(alpha: 0.35),
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        button(
          Icons.remove_rounded,
          value > min,
          () => onChanged(value - 1),
        ),
        SizedBox(
          width: 44,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        button(
          Icons.add_rounded,
          value < max,
          () => onChanged(value + 1),
        ),
      ],
    );
  }
}

/// 요일 다중 선택 칩 (일~토 순서로 표시, 값은 `DateTime.weekday`).
class _WeekdayMultiSelect extends StatelessWidget {
  const _WeekdayMultiSelect({required this.selected, required this.onToggle});

  final Set<int> selected;
  final ValueChanged<int> onToggle;

  /// 표시 순서: 일 월 화 수 목 금 토.
  static const _order = [7, 1, 2, 3, 4, 5, 6];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final d in _order)
          Material(
            color: selected.contains(d) ? cs.primary : cs.surfaceContainerHigh,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: () => onToggle(d),
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: 40,
                height: 40,
                child: Center(
                  child: Text(
                    weekdayShortKo(d),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: selected.contains(d)
                          ? cs.onPrimary
                          : cs.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 반복 선택 바텀시트의 옵션 행 — 아이콘 + 라벨 + 선택 체크.
class _RecurrenceOptionTile extends StatelessWidget {
  const _RecurrenceOptionTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bg = selected
        ? cs.primary.withValues(alpha: 0.10)
        : cs.surfaceContainerHigh;
    final fg = selected ? cs.primary : cs.onSurface;
    return Material(
      color: bg,
      borderRadius: AppRadius.borderRadiusLg,
      child: InkWell(
        borderRadius: AppRadius.borderRadiusLg,
        onTap: onTap,
        child: Padding(
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
                  color: selected
                      ? cs.primary.withValues(alpha: 0.18)
                      : cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: selected ? cs.primary : cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: fg,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
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

/// 개인 캘린더 — 연/월 선택 후 해당 월의 **근무 일정(팀에서 가져온 근무)** 만
/// 일괄 삭제하는 바텀시트. 직접 추가한 개인 일정/메모는 보존된다.
/// 제목 있는 공용 바텀시트(showMoniqBottomSheet)로 통일한다.
void showDeletePersonalScheduleSheet({
  required BuildContext context,
  required WidgetRef ref,
}) {
  final now = DateTime.now();
  DateTime selectedDate = DateTime(now.year, now.month);

  showMoniqBottomSheet<void>(
    context: context,
    title: '근무 삭제',
    eyebrow: 'DELETE',
    child: StatefulBuilder(
      builder: (ctx, setSheetState) {
        final cs = Theme.of(ctx).colorScheme;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 180,
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.monthYear,
                initialDateTime: selectedDate,
                onDateTimeChanged: (d) {
                  setSheetState(() {
                    selectedDate = DateTime(d.year, d.month);
                  });
                },
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: cs.error,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.borderRadiusFull,
                ),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                final year = selectedDate.year;
                final month = selectedDate.month;

                final confirm = await showMoniqDestructiveConfirm(
                  context: context,
                  title: '근무 일정을 삭제할까요?',
                  message:
                      '$year년 $month월의 근무 일정이 개인 캘린더에서 제거됩니다.\n'
                      '팀 근무표 원본과 직접 추가한 개인 일정/메모는 유지됩니다.',
                );
                if (!confirm) return;

                try {
                  // 팀 데이터는 보존하고 개인 캘린더에서만 그 달 근무/OFF를 숨긴다.
                  await ref
                      .read(personalHiddenShiftsDataSourceProvider)
                      .hideMonth(year, month);

                  // 캐시 무효화 — 홈 캘린더가 숨김을 반영하도록
                  ref.read(eventRefreshProvider.notifier).state++;
                  ref.invalidate(monthlyEventsProvider);
                  ref.invalidate(dateEventsProvider);
                  ref.invalidate(dateEventOccurrencesProvider);
                  ref.invalidate(dateEventsIncludingSpansProvider);
                  ref.invalidate(homeViewModelProvider);

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$year년 $month월 근무를 개인 캘린더에서 제거했습니다'),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
                  }
                }
              },
              child: Text(
                '근무 삭제',
                style: TextStyle(
                  color: cs.onError,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}
