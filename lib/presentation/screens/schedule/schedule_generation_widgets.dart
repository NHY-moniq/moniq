part of 'schedule_generation_screen.dart';

class _MemberSwitchTile extends StatelessWidget {
  const _MemberSwitchTile({
    required this.member,
    required this.isExcluded,
    required this.onToggle,
  });

  final TeamMemberWithUser member;
  final bool isExcluded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final skillLabel = _skillDisplayLabel(member.member.skillLevel);
    final m = member.member;
    final avatarText = member.displayName.isNotEmpty
        ? member.displayName[0].toUpperCase()
        : '?';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggle,
        borderRadius: AppRadius.borderRadiusMd,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: AppRadius.borderRadiusMd,
            border: Border.all(
              color: isExcluded
                  ? colorScheme.outlineVariant
                  : colorScheme.primary.withValues(alpha: 0.24),
            ),
            color: isExcluded
                ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.25)
                : colorScheme.surface,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: colorScheme.primary.withValues(alpha: 0.14),
                backgroundImage: member.user.avatarUrl != null
                    ? NetworkImage(member.user.avatarUrl!)
                    : null,
                child: member.user.avatarUrl == null
                    ? Text(
                        avatarText,
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            member.displayName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: isExcluded
                                  ? colorScheme.onSurfaceVariant
                                  : colorScheme.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (skillLabel != null)
                          _MemberTag(
                            label: skillLabel,
                            backgroundColor:
                                colorScheme.surfaceContainerHighest,
                            foregroundColor: colorScheme.onSurfaceVariant,
                          ),
                        if (m.nightDedicated)
                          const _MemberTag(
                            label: '나이트전담',
                            backgroundColor: Color(
                              0xFFB3E5FC,
                            ), // tertiaryContainer
                            foregroundColor: Color(0xFF2196F3), // shiftNight
                          ),
                        if (m.nightExempt)
                          const _MemberTag(
                            label: '나이트제외',
                            backgroundColor: Color(0xFFFFE5C2),
                            foregroundColor: Color(0xFFB65F00),
                          ),
                        if (m.dayOnly)
                          const _MemberTag(
                            label: '데이전용',
                            backgroundColor: Color(
                              0xFFFFECB3,
                            ), // primaryContainer
                            foregroundColor: Color(
                              0xFF5B4B00,
                            ), // onPrimaryContainer
                          ),
                        for (final code in m.preferredShifts)
                          _PreferredShiftChip(code: code),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Transform.scale(
                scale: 0.84,
                child: Switch.adaptive(
                  value: !isExcluded,
                  onChanged: (_) => onToggle(),
                  activeTrackColor: colorScheme.primary,
                  activeThumbColor: colorScheme.surface,
                  inactiveTrackColor: colorScheme.outlineVariant.withValues(
                    alpha: 0.9,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RuleSummaryTile extends StatelessWidget {
  const _RuleSummaryTile({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: AppRadius.borderRadiusMd,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.13),
              borderRadius: AppRadius.borderRadiusSm,
            ),
            child: Icon(icon, size: 18, color: colorScheme.primary),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RuleSummaryList extends StatelessWidget {
  const _RuleSummaryList({required this.rules});

  final List<_AppliedRuleSummary> rules;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < rules.length; index++)
          Padding(
            padding: EdgeInsets.only(top: index == 0 ? 0 : AppSpacing.sm),
            child: _RuleSummaryTile(
              title: rules[index].title,
              icon: rules[index].icon,
            ),
          ),
      ],
    );
  }
}

class _RuleCategoryCard extends StatelessWidget {
  const _RuleCategoryCard({
    required this.group,
    required this.isExpanded,
    required this.onToggle,
  });

  final _RuleSummaryGroup group;
  final bool isExpanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: AppRadius.borderRadiusSm,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.sm,
                horizontal: AppSpacing.xs,
              ),
              child: Row(
                children: [
                  Icon(group.spec.icon, color: colorScheme.primary, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      group.spec.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    '${group.rules.length}개',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState: isExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: _RuleSummaryList(rules: group.rules),
            ),
            secondChild: const SizedBox.shrink(),
            alignment: Alignment.topLeft,
            sizeCurve: Curves.easeOutCubic,
          ),
        ],
      ),
    );
  }
}

class _CustomRuleSummaryTile extends StatelessWidget {
  const _CustomRuleSummaryTile({required this.rule});

  final CustomRuleModel rule;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final priorityColor = rule.priority == 'hard'
        ? colorScheme.error
        : colorScheme.secondary;

    return Opacity(
      opacity: rule.isActive ? 1 : 0.6,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: rule.isActive
              ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.32)
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
          borderRadius: AppRadius.borderRadiusMd,
          border: Border.all(
            color: rule.isActive
                ? priorityColor.withValues(alpha: 0.3)
                : colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              rule.isActive
                  ? Icons.check_circle_rounded
                  : Icons.pause_circle_outline_rounded,
              size: 20,
              color: rule.isActive ? priorityColor : colorScheme.outline,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rule.originalText,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: rule.isActive
                          ? colorScheme.onSurface
                          : colorScheme.onSurfaceVariant,
                      decoration: rule.isActive
                          ? null
                          : TextDecoration.lineThrough,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      _MemberTag(
                        label: rule.priority == 'hard' ? '하드' : '소프트',
                        backgroundColor: priorityColor.withValues(alpha: 0.15),
                        foregroundColor: priorityColor,
                      ),
                      _MemberTag(
                        label: _customRuleTypeLabel(rule.ruleType),
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        foregroundColor: colorScheme.onSurfaceVariant,
                      ),
                      if (!rule.isActive)
                        _MemberTag(
                          label: '비활성',
                          backgroundColor: colorScheme.surfaceContainerHighest,
                          foregroundColor: colorScheme.outline,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _ruleTypeIcon(String type) {
  switch (type) {
    case 'min_staffing':
      return Icons.group_add_rounded;
    case 'max_staffing':
      return Icons.groups_rounded;
    case 'max_consecutive_work_days':
      return Icons.calendar_view_week_rounded;
    case 'max_monthly_shifts':
      return Icons.calendar_month_rounded;
    case 'max_monthly_night_shifts':
      return Icons.nightlight_round;
    case 'max_consecutive_night_shifts':
      return Icons.bedtime_rounded;
    case 'min_weekly_off_days':
      return Icons.event_available_rounded;
    case 'scheduling_priority_order':
      return Icons.priority_high_rounded;
    default:
      return Icons.rule_folder_rounded;
  }
}

class _MemberTag extends StatelessWidget {
  const _MemberTag({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: foregroundColor,
        ),
      ),
    );
  }
}

class _PreferredShiftChip extends StatelessWidget {
  const _PreferredShiftChip({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final String label;

    switch (code) {
      case 'D':
        bg = AppColors.shiftDay.withValues(alpha: 0.15);
        fg = AppColors.shiftDay.withValues(alpha: 0.9);
        label = '데이';
      case 'E':
        bg = AppColors.shiftEvening.withValues(alpha: 0.15);
        fg = AppColors.shiftEvening.withValues(alpha: 0.9);
        label = '이브닝';
      case 'N':
        bg = AppColors.shiftNight.withValues(alpha: 0.15);
        fg = AppColors.shiftNight.withValues(alpha: 0.9);
        label = '나이트';
      default:
        bg = Colors.grey.withValues(alpha: 0.15);
        fg = Colors.grey;
        label = code;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

class _WantedEntryRow {
  _WantedEntryRow({
    required this.date,
    required this.priority,
    this.shiftTypeId,
    this.reason,
  });
  final DateTime date;
  final int priority;
  final String? shiftTypeId;
  final String? reason;
}

String _customRuleTypeLabel(String type) {
  switch (type) {
    case 'member_shift_ban':
      return '근무 금지';
    case 'anti_pair':
      return '동시 배정 금지';
    case 'require_pair':
      return '함께 배정';
    case 'date_off':
      return '날짜 오프';
    case 'post_night_off':
      return '나이트 후 오프';
    case 'skill_condition':
      return '숙련도 조건';
    default:
      return '자유형';
  }
}
