part of 'wanted_request_widgets.dart';

class WantedEntryDisplayItem {
  const WantedEntryDisplayItem({
    required this.date,
    this.priority = 1,
    this.shiftTypeId,
    this.reason,
  });
  final DateTime date;
  final int priority;
  final String? shiftTypeId;
  final String? reason;
}

class WantedRequestUserEntryGroup {
  WantedRequestUserEntryGroup({
    required this.userId,
    required this.displayName,
    required this.items,
  });
  final String userId;
  final String displayName;
  final List<WantedEntryDisplayItem> items;
}

class WantedEntryPill extends StatelessWidget {
  const WantedEntryPill({
    super.key,
    required this.color,
    required this.avatarLabel,
    required this.label,
  });

  final Color color;
  final String avatarLabel;
  final Widget label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 36,
      padding: const EdgeInsets.fromLTRB(2, 2, AppSpacing.md, 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: AppRadius.borderRadiusFull,
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.22),
              shape: BoxShape.circle,
            ),
            child: Text(
              avatarLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          label,
        ],
      ),
    );
  }
}

class WantedModeTabs extends StatelessWidget {
  const WantedModeTabs({
    super.key,
    required this.isNight,
    required this.onWanted,
    required this.onNight,
  });

  final bool isNight;
  final VoidCallback onWanted;
  final VoidCallback onNight;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: AppRadius.borderRadiusFull,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _WantedModeTabButton(
            label: '원티드',
            icon: Icons.check_rounded,
            selected: !isNight,
            onTap: onWanted,
          ),
          const SizedBox(width: AppSpacing.xs),
          _WantedModeTabButton(
            label: '나이트 전담',
            icon: Icons.nightlight_round,
            selected: isNight,
            onTap: onNight,
          ),
        ],
      ),
    );
  }
}

class _WantedModeTabButton extends StatelessWidget {
  const _WantedModeTabButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final foreground = selected
        ? AppColors.onPrimaryContainer
        : colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.borderRadiusFull,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryContainer : Colors.transparent,
          borderRadius: AppRadius.borderRadiusFull,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: foreground),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WantedStatusPill extends StatelessWidget {
  const _WantedStatusPill({
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: AppRadius.borderRadiusFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: color),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _WantedMissingMembersSheet extends StatefulWidget {
  const _WantedMissingMembersSheet({
    required this.teamId,
    required this.teamName,
    required this.request,
    required this.missingMembers,
  });

  final String teamId;
  final String teamName;
  final WantedRequestModel request;
  final List<TeamMemberWithUser> missingMembers;

  @override
  State<_WantedMissingMembersSheet> createState() =>
      _WantedMissingMembersSheetState();
}

class _WantedMissingMembersSheetState
    extends State<_WantedMissingMembersSheet> {
  bool _isSending = false;

  Future<void> _sendReminder() async {
    if (_isSending || widget.missingMembers.isEmpty) return;
    setState(() => _isSending = true);

    await PushService.instance.sendToUsers(
      userIds: widget.missingMembers.map((member) => member.userId).toList(),
      title: '원티드 입력 요청',
      body: '${widget.teamName} 원티드 수집에 아직 응답하지 않았습니다. 마감 전 입력해주세요.',
      data: {
        'type': 'wanted_request',
        'teamId': widget.teamId,
        'requestId': widget.request.id,
      },
    );

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isSending = false);
    Navigator.of(context).pop();
    messenger.showSnackBar(const SnackBar(content: Text('미응답자에게 알림을 보냈습니다')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dateFormat = DateFormat('yyyy.MM.dd');
    final deadline = widget.request.deadline;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          deadline == null
              ? '아직 응답하지 않은 팀원입니다.'
              : '마감 ${dateFormat.format(deadline)} 전까지 입력이 필요합니다.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (widget.missingMembers.isEmpty)
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.successLight.withValues(alpha: 0.45),
              borderRadius: AppRadius.borderRadiusMd,
            ),
            child: Text(
              '모든 팀원이 응답했습니다',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.success,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: widget.missingMembers.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.xs),
              itemBuilder: (context, index) {
                final member = widget.missingMembers[index];
                final initial = member.displayName.isNotEmpty
                    ? member.displayName[0]
                    : '?';
                return Container(
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
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: colorScheme.primary.withValues(
                          alpha: 0.14,
                        ),
                        child: Text(
                          initial,
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          member.displayName,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton.icon(
          onPressed: widget.missingMembers.isEmpty || _isSending
              ? null
              : _sendReminder,
          icon: _isSending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.notifications_active_outlined),
          label: Text(
            _isSending
                ? '알림 보내는 중...'
                : '미응답자에게 알림 보내기 (${widget.missingMembers.length}명)',
          ),
        ),
      ],
    );
  }
}

class _WantedMetricChip extends StatelessWidget {
  const _WantedMetricChip({
    required this.icon,
    required this.label,
    this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final resolvedColor = color ?? colorScheme.onSurfaceVariant;

    final chip = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: AppRadius.borderRadiusFull,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: resolvedColor),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: resolvedColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return chip;

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.borderRadiusFull,
      child: chip,
    );
  }
}

Future<DateTime?> _showWantedReopenSheet(BuildContext context) {
  final now = DateTime.now();
  final minDate = DateTime(now.year, now.month, now.day);
  final maxDate = DateTime(now.year + 1, now.month, now.day);
  final initialDate = minDate.add(const Duration(days: 7));

  return showMoniqBottomSheet<DateTime>(
    context: context,
    title: '수집 재개',
    eyebrow: 'REOPEN',
    child: _WantedReopenSheetBody(
      initialDate: initialDate,
      minDate: minDate,
      maxDate: maxDate,
    ),
  );
}

class _WantedReopenSheetBody extends StatefulWidget {
  const _WantedReopenSheetBody({
    required this.initialDate,
    required this.minDate,
    required this.maxDate,
  });

  final DateTime initialDate;
  final DateTime minDate;
  final DateTime maxDate;

  @override
  State<_WantedReopenSheetBody> createState() => _WantedReopenSheetBodyState();
}

class _WantedReopenSheetBodyState extends State<_WantedReopenSheetBody> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dateLabel = DateFormat('yyyy.MM.dd (E)').format(_selectedDate);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '마감된 수집을 다시 열어 팀원이 입력할 수 있도록 합니다.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
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
                '새 마감일',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                dateLabel,
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
                mode: CupertinoDatePickerMode.date,
                initialDateTime: _selectedDate,
                minimumDate: widget.minDate,
                maximumDate: widget.maxDate,
                onDateTimeChanged: (value) {
                  setState(() {
                    _selectedDate = DateTime(
                      value.year,
                      value.month,
                      value.day,
                    );
                  });
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
                  child: const Text('취소'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, _selectedDate),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.borderRadiusFull,
                    ),
                  ),
                  child: const Text('재개'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── reason helpers ───────────────────────────────────────────────────────────

/// 시스템 reason 태그를 사람이 읽기 좋은 레이블로 변환한다.
String _reasonDisplayLabel(String reason) {
  switch (reason) {
    case '#생리휴가':
      return '생리휴가';
    case '#연차':
      return '연차';
    case '#필수교육':
      return '필수교육';
    default:
      return reason;
  }
}

/// 사유가 있는 원티드 칩을 탭하면 칩 근처에 작은 툴팁 카드를 띄운다.
///
/// AlertDialog 대신 OverlayEntry + CompositedTransformFollower를 사용해
/// 칩 바로 아래에 인라인 카드를 표시한다. 외부 탭 시 자동으로 닫힌다.
class WantedReasonChip extends StatefulWidget {
  const WantedReasonChip({super.key, required this.chip, required this.reason});

  /// 실제로 렌더링할 Chip 위젯
  final Widget chip;

  /// 원시 reason 문자열 (레이블 변환은 내부에서 처리)
  final String reason;

  @override
  State<WantedReasonChip> createState() => _WantedReasonChipState();
}

class _WantedReasonChipState extends State<WantedReasonChip> {
  final _link = LayerLink();
  OverlayEntry? _entry;

  void _show() {
    if (_entry != null) {
      _hide();
      return;
    }
    final label = _reasonDisplayLabel(widget.reason);
    final overlay = Overlay.of(context);
    _entry = OverlayEntry(
      builder: (_) =>
          _ReasonOverlay(link: _link, label: label, onDismiss: _hide),
    );
    overlay.insert(_entry!);
  }

  void _hide() {
    _entry?.remove();
    _entry = null;
  }

  @override
  void dispose() {
    _hide();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: GestureDetector(onTap: _show, child: widget.chip),
    );
  }
}

/// 칩 아래에 위치하는 오버레이 카드.
///
/// 배경 배리어를 탭하면 [onDismiss]를 호출한다.
class _ReasonOverlay extends StatelessWidget {
  const _ReasonOverlay({
    required this.link,
    required this.label,
    required this.onDismiss,
  });

  final LayerLink link;
  final String label;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Stack(
      children: [
        // 배경 배리어: 탭하면 닫힘
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: onDismiss,
            child: const SizedBox.expand(),
          ),
        ),
        // 칩 아래 카드
        CompositedTransformFollower(
          link: link,
          showWhenUnlinked: false,
          offset: const Offset(0, 28),
          child: Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              color: colorScheme.surfaceContainerHigh,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      label,
                      style: textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class WantedRequestDatePickerRow extends StatelessWidget {
  const WantedRequestDatePickerRow({
    super.key,
    required this.label,
    this.date,
    required this.dateFormat,
    required this.onTap,
  });

  final String label;
  final DateTime? date;
  final DateFormat dateFormat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Row(
            children: [
              Text(
                date != null ? dateFormat.format(date!) : '선택',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(Icons.calendar_today, size: 18, color: colorScheme.primary),
            ],
          ),
        ],
      ),
    );
  }
}
