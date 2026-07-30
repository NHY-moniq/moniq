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
    final knobColor = on
        ? cs.onPrimary
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
        color: on ? cs.primary : cs.onSurfaceVariant.withValues(alpha: 0.22),
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

/// 시작/종료 한 줄 — 왼쪽 라벨 축 + 오른쪽 날짜·시간 값 필드.
/// 라벨을 행이 책임지므로 값 필드는 값만 보여주면 되고, 그만큼 테두리 박스가
/// 반복되던 무게가 사라진다.
class _EventDateTimeRow extends StatelessWidget {
  const _EventDateTimeRow({
    required this.label,
    required this.dateField,
    required this.timeField,
  });

  final String label;
  final Widget dateField;
  final Widget timeField;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: _eventRowLabelWidth,
            child: Padding(
              padding: const EdgeInsets.only(left: AppSpacing.xs),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(label, style: _eventRowLabelStyle(context)),
              ),
            ),
          ),
          Expanded(flex: 5, child: dateField),
          const SizedBox(width: AppSpacing.sm),
          Expanded(flex: 4, child: timeField),
        ],
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
    this.muted = false,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  /// 아직 정해지지 않은 값(`--:--`)일 때 톤을 낮춰 placeholder처럼 보이게 한다.
  final bool muted;

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
                  color: muted
                      ? cs.onSurfaceVariant.withValues(alpha: 0.55)
                      : cs.onSurface,
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

/// 반복 선택 — 다른 입력과 동일한 fill bg + radius로 통일.
class _RecurrenceField extends StatelessWidget {
  const _RecurrenceField({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String value;
  final List<(String, String)> options;
  final ValueChanged<String> onChanged;

  /// 각 옵션 값에 매핑되는 아이콘 — 빈도의 의미를 시각적으로 보조.
  IconData _iconFor(String val) {
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
      default:
        return Icons.repeat_rounded;
    }
  }

  String _labelFor(String val) {
    return options
        .firstWhere((o) => o.$1 == val, orElse: () => options.first)
        .$2;
  }

  Future<void> _openPicker(BuildContext context) async {
    final selected = await showMoniqBottomSheet<String>(
      context: context,
      title: '일정 반복',
      eyebrow: 'RECURRENCE',
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final opt in options) ...[
              _RecurrenceOptionTile(
                icon: _iconFor(opt.$1),
                label: opt.$2,
                selected: opt.$1 == value,
                onTap: () =>
                    Navigator.of(context, rootNavigator: true).pop(opt.$1),
              ),
              const SizedBox(height: 6),
            ],
          ],
        ),
      ),
    );
    if (selected != null && selected != value) onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 라벨은 폼의 다른 섹션과 같은 위젯을 써서 축·톤을 맞춘다.
        const _FormSectionLabel('반복'),
        Material(
          color: cs.surfaceContainerHigh,
          borderRadius: AppRadius.borderRadiusLg,
          child: InkWell(
            borderRadius: AppRadius.borderRadiusLg,
            onTap: () => _openPicker(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: [
                  Icon(_iconFor(value), size: 20, color: cs.onSurfaceVariant),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      _labelFor(value),
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
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
