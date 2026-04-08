import 'package:flutter/material.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';

// ── 우선순위 항목 모델 ──

class ScheduleRulePriorityItem {
  ScheduleRulePriorityItem({required this.key, required this.label});

  final String key;
  final String label;
}

// ── 공통 위젯 ──

class ScheduleRuleSectionHeader extends StatelessWidget {
  const ScheduleRuleSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
  });

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            subtitle!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class ScheduleRuleCard extends StatelessWidget {
  const ScheduleRuleCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Column(children: children),
      ),
    );
  }
}

class ScheduleRulePatternToggleRow extends StatelessWidget {
  const ScheduleRulePatternToggleRow({
    super.key,
    required this.pattern,
    required this.description,
    required this.value,
    required this.isHard,
    required this.readOnly,
    required this.onChanged,
  });

  final String pattern;
  final String description;
  final bool value;
  final bool isHard;
  final bool readOnly;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final activeColor =
        isHard ? colorScheme.error : colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xxs,
            ),
            decoration: BoxDecoration(
              color: value
                  ? activeColor.withValues(alpha: 0.12)
                  : colorScheme.onSurfaceVariant
                      .withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
            child: Text(
              pattern,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: value
                    ? activeColor
                    : colorScheme.onSurfaceVariant,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: readOnly ? null : onChanged,
            activeTrackColor: colorScheme.primary,
          ),
        ],
      ),
    );
  }
}

class ScheduleRuleToggleRow extends StatelessWidget {
  const ScheduleRuleToggleRow({
    super.key,
    required this.label,
    this.description,
    required this.value,
    required this.readOnly,
    required this.onChanged,
  });

  final String label;
  final String? description;
  final bool value;
  final bool readOnly;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (description != null)
                  Text(
                    description!,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: readOnly ? null : onChanged,
            activeTrackColor: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }
}

// ── 우선순위 reorder 카드 ──

class ScheduleRulePriorityReorderCard extends StatelessWidget {
  const ScheduleRulePriorityReorderCard({
    super.key,
    required this.items,
    required this.onReorder,
  });

  final List<ScheduleRulePriorityItem> items;
  final ReorderCallback onReorder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        itemCount: items.length,
        onReorder: onReorder,
        proxyDecorator: (child, index, animation) => Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(AppRadius.xs),
          child: child,
        ),
        itemBuilder: (context, index) {
          final item = items[index];
          final rank = index + 1;
          return ListTile(
            key: ValueKey(item.key),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
            ),
            leading: ScheduleRuleRankBadge(rank: rank),
            title: Text(
              item.label,
              style: theme.textTheme.bodyMedium,
            ),
            trailing: ReorderableDragStartListener(
              index: index,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xs),
                child: Icon(
                  Icons.menu,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class ScheduleRulePriorityReadRow extends StatelessWidget {
  const ScheduleRulePriorityReadRow({
    super.key,
    required this.rank,
    required this.label,
  });

  final int rank;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          ScheduleRuleRankBadge(rank: rank),
          const SizedBox(width: AppSpacing.md),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class ScheduleRuleRankBadge extends StatelessWidget {
  const ScheduleRuleRankBadge({super.key, required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isTop = rank == 1;
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isTop
            ? colorScheme.primary.withValues(alpha: 0.15)
            : colorScheme.surfaceContainer,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$rank',
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: isTop
              ? colorScheme.primary
              : colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
