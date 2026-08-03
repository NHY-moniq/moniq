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
      // 세그먼트를 폭 전체로 늘려 두 탭의 터치 영역을 동일하게 맞춘다
      child: Row(
        children: [
          Expanded(
            child: _WantedModeTabButton(
              label: '원티드',
              icon: Icons.check_rounded,
              selected: !isNight,
              onTap: onWanted,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: _WantedModeTabButton(
              label: '나이트 전담',
              icon: Icons.nightlight_round,
              selected: isNight,
              onTap: onNight,
            ),
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
    // 고정 색(AppColors.primaryContainer) 대신 시프트 테마를 따르는 primary를 쓴다.
    // 고정 색은 나이트/오프의 쿨톤 배경이나 다크 모드에서 겉돌았다.
    final foreground = selected
        ? colorScheme.onPrimary
        : colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.borderRadiusFull,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: selected ? colorScheme.primary : Colors.transparent,
          borderRadius: AppRadius.borderRadiusFull,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: foreground),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w800,
                ),
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
          // 상태 라벨이 길어져도(예: '나이트 전담 수집 중') 배지가 넘치지 않게 한다
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
              ),
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

/// 수집 현황 헤더 카드.
///
/// 배지·제목·기간·칩이 같은 무게로 4단 쌓여 위계가 없던 구조를 카드 하나로 묶는다.
/// 화면 폭 전체에 배경색을 깔지 않고 본문과 같은 배경 위에 카드로 띄워,
/// 헤더만 색이 깔려 본문과 잘려 보이던 문제를 없앤다.
class _WantedHeaderCard extends StatelessWidget {
  const _WantedHeaderCard({
    required this.statusLabel,
    required this.statusColor,
    this.statusIcon,
    this.trailingPill,
    required this.metric,
    this.footRows = const <Widget>[],
  });

  final String statusLabel;
  final Color statusColor;
  final IconData? statusIcon;

  /// 우측 상단 보조 배지 (D-day 등)
  final Widget? trailingPill;

  /// 카드의 주인공 지표 영역
  final Widget metric;

  /// 지표 아래로 내려가는 부가 정보 (기간·마감 등)
  final List<Widget> footRows;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: AppRadius.borderRadiusLg,
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              // 상태 배지는 내용만큼만 차지하고 D-day 배지는 오른쪽 끝에 붙인다
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: _WantedStatusPill(
                    label: statusLabel,
                    color: statusColor,
                    icon: statusIcon,
                  ),
                ),
                if (trailingPill != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  trailingPill!,
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            metric,
            if (footRows.isNotEmpty) ...[
              Divider(
                height: AppSpacing.xxl,
                color: colorScheme.outlineVariant,
              ),
              for (var i = 0; i < footRows.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSpacing.sm),
                footRows[i],
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// 헤더 카드 하단의 부가 정보 한 줄 (라벨 좌 · 값 우).
///
/// 칩을 나열하면 모두 같은 무게로 읽히므로, 부가 정보는 표처럼 정렬해
/// 지표보다 한 단계 아래로 내린다.
class _WantedHeaderFootRow extends StatelessWidget {
  const _WantedHeaderFootRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: theme.textTheme.labelMedium?.copyWith(
              color: valueColor ?? colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

/// 헤더 카드 안의 숫자 지표 한 칸 (라벨 + 큰 값 + 단위).
class _WantedStatBlock extends StatelessWidget {
  const _WantedStatBlock({
    required this.label,
    required this.value,
    required this.unit,
    this.valueColor,
    this.emphasized = false,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final String unit;
  final Color? valueColor;

  /// 카드에서 가장 중요한 지표인지 (글자 크기로 위계를 만든다)
  final bool emphasized;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final valueStyle =
        (emphasized
                ? theme.textTheme.headlineLarge
                : theme.textTheme.headlineMedium)
            ?.copyWith(
              color: valueColor ?? colorScheme.onSurface,
              fontWeight: FontWeight.w900,
            );

    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value, style: valueStyle),
            const SizedBox(width: AppSpacing.xxs),
            Text(
              unit,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 응답 현황 게이지.
///
/// "n명 중 m명 응답"이 다른 칩들과 같은 무게로 묻히던 문제를 해결하기 위해
/// 응답률을 카드의 주인공 지표로 올리고 진행 바로 한눈에 보이게 한다.
/// 탭하면 기존 미응답자 시트가 열린다.
class _WantedResponseMeter extends StatelessWidget {
  const _WantedResponseMeter({
    required this.respondedCount,
    required this.totalMemberCount,
    required this.entryCount,
    required this.onTap,
  });

  final int respondedCount;
  final int totalMemberCount;
  final int entryCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // 데이 시프트의 primary(밝은 금색)는 옅은 면 위에서 대비가 모자란다.
    // onPrimaryContainer는 시프트별 '강조 텍스트' 색이라 모든 시프트·모드에서 읽힌다.
    final accent = colorScheme.onPrimaryContainer;
    final missingCount = totalMemberCount - respondedCount > 0
        ? totalMemberCount - respondedCount
        : 0;
    final progress = totalMemberCount > 0
        ? respondedCount / totalMemberCount
        : 0.0;

    final String hintLabel;
    if (totalMemberCount == 0) {
      hintLabel = '팀원 정보를 불러오는 중이에요';
    } else if (missingCount == 0) {
      hintLabel = '모든 팀원이 응답했어요';
    } else {
      hintLabel = '미응답 $missingCount명에게 알림 보내기';
    }
    final hasMissing = missingCount > 0;

    // 카드 배경(불투명 Container) 위에서도 잉크 반응이 보이도록 투명 Material을 둔다
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.borderRadiusMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: _WantedStatBlock(
                    label: '응답 현황',
                    value: totalMemberCount > 0
                        ? '$respondedCount/$totalMemberCount'
                        : '$respondedCount',
                    unit: '명',
                    valueColor: accent,
                    emphasized: true,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                _WantedStatBlock(
                  label: '수집된 원티드',
                  value: '$entryCount',
                  unit: '건',
                  alignEnd: true,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: AppRadius.borderRadiusFull,
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(accent),
                semanticsLabel: '응답률',
                semanticsValue: '${(progress * 100).round()}%',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Icon(
                  hasMissing
                      ? Icons.notifications_active_outlined
                      : Icons.check_circle_outline_rounded,
                  size: 14,
                  color: hasMissing ? accent : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    hintLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: hasMissing ? accent : colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ],
        ),
      ),
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
    // 220px 날짜 휠 + 요약 + 버튼이라 기본 상한(0.56)으로는 하단이 잘린다.
    maxHeightFactor: 0.78,
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

    // 글자 크기를 키운 기기에서는 상한을 올려도 넘칠 수 있어 스크롤로 받는다.
    return SingleChildScrollView(
      child: Column(
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
      ),
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
