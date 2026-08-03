part of 'personal_team_calendar_screen.dart';

class _AppointmentEntryCard extends StatelessWidget {
  const _AppointmentEntryCard({
    required this.dateLabel,
    required this.participantCount,
    required this.overlapCount,
    required this.onTap,
  });

  final String dateLabel;
  final int participantCount;
  final int overlapCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.borderRadiusLg,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: cs.primaryContainer.withValues(alpha: 0.22),
            borderRadius: AppRadius.borderRadiusLg,
            border: Border.all(color: cs.primary.withValues(alpha: 0.24)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: AppRadius.borderRadiusMd,
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.event_available_outlined,
                  color: cs.onPrimary,
                  size: 21,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '이 날 약속 잡기',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          dateLabel,
                          style: textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        _AppointmentMetaPill(label: '$participantCount명 기준'),
                        if (overlapCount > 0)
                          _SelectedOverlapPill(count: overlapCount),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppointmentMetaPill extends StatelessWidget {
  const _AppointmentMetaPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: AppRadius.borderRadiusFull,
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.55)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: cs.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _SelectedOverlapPill extends StatelessWidget {
  const _SelectedOverlapPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.52),
        borderRadius: AppRadius.borderRadiusFull,
        border: Border.all(color: cs.error.withValues(alpha: 0.22)),
      ),
      child: Text(
        '겹침 $count명',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: cs.onErrorContainer,
        ),
      ),
    );
  }
}

class _AppointmentErrorBanner extends StatelessWidget {
  const _AppointmentErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.42),
        borderRadius: AppRadius.borderRadiusLg,
        border: Border.all(color: cs.error.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: cs.onErrorContainer,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: textTheme.bodySmall?.copyWith(
                color: cs.onErrorContainer,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AllDayCheckboxButton extends StatelessWidget {
  const _AllDayCheckboxButton({
    required this.selected,
    required this.onChanged,
  });

  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!selected),
        borderRadius: AppRadius.borderRadiusMd,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: selected ? cs.primary : cs.surface,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: selected
                        ? cs.primary
                        : cs.outlineVariant.withValues(alpha: 0.9),
                    width: 1.4,
                  ),
                ),
                alignment: Alignment.center,
                child: selected
                    ? Icon(Icons.check_rounded, size: 15, color: cs.onPrimary)
                    : null,
              ),
              const SizedBox(height: 4),
              Text(
                '종일',
                maxLines: 1,
                style: textTheme.labelSmall?.copyWith(
                  color: selected ? cs.primary : cs.onSurfaceVariant,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppointmentTimeButton extends StatelessWidget {
  const _AppointmentTimeButton({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.borderRadiusMd,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: AppRadius.borderRadiusMd,
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.62),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 13,
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: cs.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverlapControlChip extends StatelessWidget {
  const _OverlapControlChip({
    this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData? icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = selected
        ? cs.primaryContainer.withValues(alpha: 0.55)
        : cs.surfaceContainerLow;
    final borderColor = selected
        ? cs.primary.withValues(alpha: 0.5)
        : cs.outlineVariant.withValues(alpha: 0.8);
    final iconColor = selected ? cs.primary : cs.onSurfaceVariant;
    final fg = selected ? cs.onPrimaryContainer : cs.onSurface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.borderRadiusFull,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: AppRadius.borderRadiusFull,
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: iconColor),
                const SizedBox(width: AppSpacing.xs),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 전체 / 과반수만 2분할 토글 — "누르는 것"임을 직관적으로 보여준다.
class _OverlapScopeToggle extends StatelessWidget {
  const _OverlapScopeToggle({required this.showAll, required this.onChanged});

  final bool showAll;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget seg(String label, bool selected, VoidCallback onTap) {
      return GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: selected ? cs.primary : Colors.transparent,
            borderRadius: AppRadius.borderRadiusFull,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: selected ? cs.onPrimary : cs.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: AppRadius.borderRadiusFull,
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          seg('과반수', !showAll, () => onChanged(false)),
          seg('전체', showAll, () => onChanged(true)),
        ],
      ),
    );
  }
}

class _MemberSelectionTile extends StatelessWidget {
  const _MemberSelectionTile({
    required this.member,
    required this.selected,
    required this.onTap,
  });

  final PersonalTeamMember member;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.borderRadiusLg,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: selected
                ? cs.primaryContainer.withValues(alpha: 0.16)
                : cs.surface,
            borderRadius: AppRadius.borderRadiusMd,
            border: Border.all(
              color: selected
                  ? cs.primary.withValues(alpha: 0.38)
                  : cs.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: Row(
            children: [
              _MemberSelectionAvatar(member: member),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  member.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: selected ? cs.primary : cs.surfaceContainerHighest,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? cs.primary : cs.outlineVariant,
                  ),
                ),
                child: selected
                    ? Icon(Icons.check_rounded, size: 15, color: cs.onPrimary)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberSelectionAvatar extends StatelessWidget {
  const _MemberSelectionAvatar({required this.member});

  final PersonalTeamMember member;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final avatarUrl = member.avatarUrl;

    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 14,
        backgroundColor: cs.primaryContainer,
        backgroundImage: NetworkImage(avatarUrl),
        onBackgroundImageError: (_, __) {},
      );
    }

    return CircleAvatar(
      radius: 14,
      backgroundColor: cs.primaryContainer.withValues(alpha: 0.72),
      child: Text(
        _initials(member.displayName),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: cs.onPrimaryContainer,
        ),
      ),
    );
  }

  String _initials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.substring(0, 1).toUpperCase();
  }
}

class _OverlapDaySummary {
  const _OverlapDaySummary({required this.date, required this.count});

  final DateTime date;
  final int count;
}

class _OverlapDaySection extends StatefulWidget {
  const _OverlapDaySection({
    required this.count,
    required this.days,
    required this.dateFormat,
    required this.onSelectDate,
  });

  final int count;
  final List<_OverlapDaySummary> days;
  final DateFormat dateFormat;
  final ValueChanged<DateTime> onSelectDate;

  @override
  State<_OverlapDaySection> createState() => _OverlapDaySectionState();
}

class _OverlapDaySectionState extends State<_OverlapDaySection> {
  static const int _maxColumns = 3;
  static const int _previewLines = 1;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context).textTheme;
    final shouldCollapse = widget.days.length > (_maxColumns * _previewLines);
    final visibleCount = !_expanded && shouldCollapse
        ? _maxColumns * _previewLines
        : widget.days.length;
    final visibleDays = widget.days.take(visibleCount).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: AppRadius.borderRadiusFull,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '${widget.count}명 겹침',
              style: theme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              '${widget.days.length}일',
              style: theme.labelMedium?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (shouldCollapse)
              TextButton(
                onPressed: () {
                  setState(() => _expanded = !_expanded);
                },
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 0),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(_expanded ? '접기' : '펼치기'),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth =
                (constraints.maxWidth - (AppSpacing.sm * 2)) / _maxColumns;

            return Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final day in visibleDays)
                  SizedBox(
                    width: itemWidth,
                    child: _OverlapDayChip(
                      label: widget.dateFormat.format(day.date),
                      onTap: () => widget.onSelectDate(day.date),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _OverlapDayChip extends StatelessWidget {
  const _OverlapDayChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.borderRadiusFull,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: AppRadius.borderRadiusFull,
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.8)),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
