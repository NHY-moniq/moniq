import 'package:flutter/material.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
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
    final activeColor = isHard ? AppColors.error : AppColors.primary;
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
                  : AppColors.textSecondaryLight
                      .withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              pattern,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: value
                    ? activeColor
                    : AppColors.textSecondaryLight,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondaryLight,
              ),
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: readOnly ? null : onChanged,
            activeColor: Theme.of(context).colorScheme.primary,
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
            activeColor: AppColors.primary,
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
          borderRadius: BorderRadius.circular(8),
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
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(
                  Icons.menu,
                  color: AppColors.textSecondaryLight,
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
    final isTop = rank == 1;
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isTop
            ? AppColors.primary.withValues(alpha: 0.15)
            : AppColors.surfaceContainer,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$rank',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: isTop
              ? AppColors.primary
              : AppColors.textSecondaryLight,
        ),
      ),
    );
  }
}
