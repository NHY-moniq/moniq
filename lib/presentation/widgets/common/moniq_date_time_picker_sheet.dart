import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/widgets/common/moniq_bottom_sheet.dart';

/// 날짜+시간을 **한 휠에서** 고르는 바텀시트.
///
/// [showMoniqDatePickerSheet]/[showMoniqTimePickerSheet]와 같은 골격
/// (eyebrow + 타이틀 + 선택값 요약 + 휠 + 취소/확인)을 쓰되, 휠은
/// `CupertinoDatePickerMode.dateAndTime` — 좌측 날짜 휠(요일·오늘 표기 포함)과
/// 시·분·오전/오후 휠이 한 번의 스크롤로 끝난다.
///
/// [minimumDate]를 넘기면 그 이전 값은 휠에서 아예 선택되지 않는다
/// (종료 일시가 시작보다 앞서지 못하게 하는 용도).
Future<DateTime?> showMoniqDateTimePickerSheet({
  required BuildContext context,
  required DateTime initialDateTime,
  DateTime? minimumDate,
  DateTime? maximumDate,
  String title = '일시 선택',
  String? eyebrow,
  String confirmLabel = '확인',
  String cancelLabel = '취소',
}) {
  // CupertinoDatePicker는 분 단위까지만 다루므로 초 이하를 버려
  // initial/minimum 비교가 어긋나지 않게 한다.
  DateTime normalize(DateTime d) =>
      DateTime(d.year, d.month, d.day, d.hour, d.minute);
  final min = minimumDate != null ? normalize(minimumDate) : null;
  final max = maximumDate != null ? normalize(maximumDate) : null;
  var seed = normalize(initialDateTime);
  if (min != null && seed.isBefore(min)) seed = min;
  if (max != null && seed.isAfter(max)) seed = max;

  return showMoniqBottomSheet<DateTime>(
    context: context,
    title: title,
    eyebrow: eyebrow ?? 'DATE · TIME',
    // 220px 휠 + 요약 + 버튼이라 기본 상한(0.56)으로는 하단이 잘린다.
    maxHeightFactor: 0.78,
    child: _MoniqDateTimePickerSheetBody(
      initialDateTime: seed,
      minimumDate: min,
      maximumDate: max,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
    ),
  );
}

/// 시작·종료를 **한 시트에서 함께** 고르는 통합 피커.
///
/// 상단의 시작/종료 헤더 탭으로 어느 값을 편집할지 고르고(활성 쪽 강조),
/// 아래 휠이 그 값을 편집한다. 규칙:
/// - 시작 변경 시 종료가 따라온다 — 시간 모드는 종료 = 시작 + 1시간,
///   종일 모드는 종료가 시작보다 앞설 때만 종료 = 시작.
/// - 종료 편집 시 휠의 최소값 = 시작 (시간 모드는 시작 + 1분).
/// - 시작에서 값을 고르고 잠시 멈추면 자동으로 종료 탭으로 넘어간다.
/// - **확인 한 번으로 시작·종료가 함께 반영**되고, 취소하면 둘 다 원복.
///
/// [allDay]면 날짜 휠([showMoniqDatePickerSheet]와 같은 본문),
/// 아니면 날짜+시간 휠([showMoniqDateTimePickerSheet]와 같은 본문)을 쓴다.
///
/// 반환: `(start:, end:)` 레코드, 취소 시 null.
Future<({DateTime start, DateTime end})?> showMoniqDateTimeRangePickerSheet({
  required BuildContext context,
  required DateTime initialStart,
  required DateTime initialEnd,
  required bool allDay,
  DateTime? minimumDate,
  DateTime? maximumDate,
  String title = '일시 선택',
  String? eyebrow,
  String confirmLabel = '확인',
  String cancelLabel = '취소',
}) {
  // 휠 정밀도(종일: 일 단위, 시간: 분 단위)에 맞춰 초 이하를 버린다.
  DateTime normalize(DateTime d) => allDay
      ? DateTime(d.year, d.month, d.day)
      : DateTime(d.year, d.month, d.day, d.hour, d.minute);
  final min = minimumDate != null ? normalize(minimumDate) : null;
  final max = maximumDate != null ? normalize(maximumDate) : null;
  var start = normalize(initialStart);
  if (min != null && start.isBefore(min)) start = min;
  if (max != null && start.isAfter(max)) start = max;
  var end = normalize(initialEnd);
  if (allDay) {
    if (end.isBefore(start)) end = start;
  } else if (!end.isAfter(start)) {
    end = start.add(const Duration(hours: 1));
  }
  if (max != null && end.isAfter(max)) end = max;

  return showMoniqBottomSheet<({DateTime start, DateTime end})>(
    context: context,
    title: title,
    eyebrow: eyebrow ?? (allDay ? 'DATE' : 'DATE · TIME'),
    // 탭 헤더 + 220px 휠 + 버튼이라 기본 상한(0.56)으로는 하단이 잘린다.
    maxHeightFactor: 0.78,
    child: _MoniqDateTimeRangePickerSheetBody(
      initialStart: start,
      initialEnd: end,
      allDay: allDay,
      minimumDate: min,
      maximumDate: max,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
    ),
  );
}

class _MoniqDateTimeRangePickerSheetBody extends StatefulWidget {
  const _MoniqDateTimeRangePickerSheetBody({
    required this.initialStart,
    required this.initialEnd,
    required this.allDay,
    required this.minimumDate,
    required this.maximumDate,
    required this.confirmLabel,
    required this.cancelLabel,
  });

  final DateTime initialStart;
  final DateTime initialEnd;
  final bool allDay;
  final DateTime? minimumDate;
  final DateTime? maximumDate;
  final String confirmLabel;
  final String cancelLabel;

  @override
  State<_MoniqDateTimeRangePickerSheetBody> createState() =>
      _MoniqDateTimeRangePickerSheetBodyState();
}

class _MoniqDateTimeRangePickerSheetBodyState
    extends State<_MoniqDateTimeRangePickerSheetBody> {
  late DateTime _start;
  late DateTime _end;

  /// false면 시작, true면 종료를 편집 중.
  bool _editingEnd = false;

  /// 시작에서 값을 고르고 잠시 멈추면 종료 탭으로 자동 전환하는 타이머.
  /// 세션당 한 번만 — 사용자가 시작 탭으로 되돌아오면 다시 무장한다.
  Timer? _autoAdvanceTimer;
  bool _autoAdvanced = false;

  @override
  void initState() {
    super.initState();
    _start = widget.initialStart;
    _end = widget.initialEnd;
  }

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    super.dispose();
  }

  /// 종료 휠의 최소값 — 시간 모드는 시작 이하로 스크롤 자체가 안 되게 +1분.
  DateTime get _endMinimum =>
      widget.allDay ? _start : _start.add(const Duration(minutes: 1));

  String _labelOf(DateTime d) {
    final date = DateFormat('M.d (E)').format(d);
    if (widget.allDay) return date;
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$date $hh:$mm';
  }

  void _onStartChanged(DateTime v) {
    setState(() {
      _start = v;
      if (widget.allDay) {
        // 종일 — 시작이 종료보다 뒤로 가면 종료를 함께 밀어준다.
        if (_end.isBefore(_start)) _end = _start;
      } else {
        // 시간 사용 — 종료는 항상 시작 +1시간. 날짜 포함 DateTime이라
        // 자정을 넘어도 종료 일자가 자연히 따라간다.
        _end = _start.add(const Duration(hours: 1));
      }
    });
    _scheduleAutoAdvance();
  }

  void _scheduleAutoAdvance() {
    if (_autoAdvanced) return;
    _autoAdvanceTimer?.cancel();
    _autoAdvanceTimer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted || _editingEnd) return;
      setState(() {
        _editingEnd = true;
        _autoAdvanced = true;
      });
    });
  }

  void _switchTo({required bool end}) {
    _autoAdvanceTimer?.cancel();
    // 종료 탭을 직접 눌렀으면 자동 전환은 더 필요 없고,
    // 시작 탭으로 되돌아왔으면 자동 전환을 다시 무장한다.
    _autoAdvanced = end;
    if (_editingEnd == end) return;
    setState(() => _editingEnd = end);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // 탭 전환 시 휠을 새로 만들어 초기값/최소값을 편집 대상에 맞춘다.
    // (편집 중에는 값이 바뀌어도 휠을 다시 만들지 않는다)
    var endInitial = _end;
    if (endInitial.isBefore(_endMinimum)) endInitial = _endMinimum;
    final picker = CupertinoDatePicker(
      key: ValueKey(_editingEnd),
      mode: widget.allDay
          ? CupertinoDatePickerMode.date
          : CupertinoDatePickerMode.dateAndTime,
      backgroundColor: colorScheme.surfaceContainerLowest,
      initialDateTime: _editingEnd ? endInitial : _start,
      minimumDate: _editingEnd ? _endMinimum : widget.minimumDate,
      maximumDate: widget.maximumDate,
      onDateTimeChanged: (value) {
        final v = widget.allDay
            ? DateTime(value.year, value.month, value.day)
            : value;
        if (_editingEnd) {
          setState(() => _end = v);
        } else {
          _onStartChanged(v);
        }
      },
    );

    // 글자 크기를 키운 기기에서는 상한을 올려도 넘칠 수 있어 스크롤로 받는다.
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 시작/종료 헤더 탭 — 활성 쪽 강조, 탭으로 전환.
          Row(
            children: [
              Expanded(
                child: _RangeHeaderTab(
                  label: '시작',
                  value: _labelOf(_start),
                  active: !_editingEnd,
                  onTap: () => _switchTo(end: false),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Expanded(
                child: _RangeHeaderTab(
                  label: '종료',
                  value: _labelOf(_end),
                  active: _editingEnd,
                  onTap: () => _switchTo(end: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: AppRadius.borderRadiusMd,
            child: Container(
              height: 220,
              color: colorScheme.surfaceContainerLowest,
              child: CupertinoTheme(
                data: CupertinoThemeData(
                  brightness: theme.brightness,
                  primaryColor: colorScheme.primary,
                ),
                child: picker,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
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
                      side: BorderSide(color: colorScheme.outlineVariant),
                    ),
                    child: Text(widget.cancelLabel),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: () {
                      // 휠이 스냅백되는 중에 눌러도 종료<시작이 나가지 않게
                      // 최종 보정 후 두 값을 함께 반환한다.
                      var start = _start;
                      var end = _end;
                      if (widget.allDay) {
                        if (end.isBefore(start)) end = start;
                      } else if (!end.isAfter(start)) {
                        end = start.add(const Duration(hours: 1));
                      }
                      Navigator.pop(context, (start: start, end: end));
                    },
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.borderRadiusFull,
                      ),
                    ),
                    child: Text(widget.confirmLabel),
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

/// 통합 피커 상단의 시작/종료 탭 — 라벨 + 현재 값 두 줄.
/// 활성 쪽은 primary 톤(옅은 배경 + 테두리), 비활성은 회색으로 가라앉힌다.
class _RangeHeaderTab extends StatelessWidget {
  const _RangeHeaderTab({
    required this.label,
    required this.value,
    required this.active,
    required this.onTap,
  });

  final String label;
  final String value;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bg = active
        ? cs.primary.withValues(alpha: 0.10)
        : cs.surfaceContainerHigh;
    final borderColor = active ? cs.primary : Colors.transparent;

    return Material(
      color: bg,
      borderRadius: AppRadius.borderRadiusMd,
      child: InkWell(
        borderRadius: AppRadius.borderRadiusMd,
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: AppRadius.borderRadiusMd,
            border: Border.all(color: borderColor, width: 1.5),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: active ? cs.primary : cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: active ? cs.onSurface : cs.onSurfaceVariant,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoniqDateTimePickerSheetBody extends StatefulWidget {
  const _MoniqDateTimePickerSheetBody({
    required this.initialDateTime,
    required this.minimumDate,
    required this.maximumDate,
    required this.confirmLabel,
    required this.cancelLabel,
  });

  final DateTime initialDateTime;
  final DateTime? minimumDate;
  final DateTime? maximumDate;
  final String confirmLabel;
  final String cancelLabel;

  @override
  State<_MoniqDateTimePickerSheetBody> createState() =>
      _MoniqDateTimePickerSheetBodyState();
}

class _MoniqDateTimePickerSheetBodyState
    extends State<_MoniqDateTimePickerSheetBody> {
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialDateTime;
  }

  /// 요약 필드 라벨 — 예: `8.27 (목) 오후 6:00`.
  String get _label {
    final date = DateFormat('M.d (E)').format(_selected);
    final isAm = _selected.hour < 12;
    final hour12 = switch (_selected.hour % 12) {
      0 => 12,
      final h => h,
    };
    final minute = _selected.minute.toString().padLeft(2, '0');
    return '$date ${isAm ? '오전' : '오후'} $hour12:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // 글자 크기를 키운 기기에서는 상한을 올려도 넘칠 수 있어 스크롤로 받는다.
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLowest,
              borderRadius: AppRadius.borderRadiusMd,
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Row(
              children: [
                Text(
                  '선택 일시',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Text(
                  _label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: AppRadius.borderRadiusMd,
            child: Container(
              height: 220,
              color: colorScheme.surfaceContainerLowest,
              child: CupertinoTheme(
                data: CupertinoThemeData(
                  brightness: theme.brightness,
                  primaryColor: colorScheme.primary,
                ),
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.dateAndTime,
                  backgroundColor: colorScheme.surfaceContainerLowest,
                  initialDateTime: _selected,
                  minimumDate: widget.minimumDate,
                  maximumDate: widget.maximumDate,
                  onDateTimeChanged: (value) {
                    setState(() => _selected = value);
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
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
                      side: BorderSide(color: colorScheme.outlineVariant),
                    ),
                    child: Text(widget.cancelLabel),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: () {
                      // 휠이 minimum 미만으로 스냅백되는 중에 확인을 눌러도
                      // 시작 이전 값이 나가지 않게 최종 clamp.
                      var result = _selected;
                      final min = widget.minimumDate;
                      if (min != null && result.isBefore(min)) result = min;
                      Navigator.pop(context, result);
                    },
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.borderRadiusFull,
                      ),
                    ),
                    child: Text(widget.confirmLabel),
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
