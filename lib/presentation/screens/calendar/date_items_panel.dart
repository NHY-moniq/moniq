import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/core/utils/color_utils.dart';
import 'package:moniq/data/datasources/personal_event_local_data_source.dart';
import 'package:moniq/data/datasources/personal_note_local_data_source.dart';
import 'package:moniq/data/models/shift_with_type.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';

import 'calendar_dialogs.dart';
import 'calendar_providers.dart';

// -- Date items panel (brand feel UI) --

class DateItemsPanel extends ConsumerWidget {
  const DateItemsPanel({
    super.key,
    required this.date,
    required this.shifts,
    required this.events,
    required this.notes,
  });

  final DateTime date;
  final List<ShiftWithType> shifts;
  final List<PersonalEvent> events;
  final List<PersonalNote> notes;

  static const _weekdays = ['\uC6D4', '\uD654', '\uC218', '\uBAA9', '\uAE08', '\uD1A0', '\uC77C'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final hasItems =
        shifts.isNotEmpty || events.isNotEmpty || notes.isNotEmpty;
    final weekday = _weekdays[date.weekday - 1];
    final totalItems = shifts.length + events.length + notes.length;
    final dateKey = DateTime(date.year, date.month, date.day);
    final isExpanded = ref.watch(dateExpandedProvider(dateKey));

    return Padding(
      padding: AppSpacing.screenHorizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date header
          GestureDetector(
            onTap: totalItems > 0
                ? () => ref
                    .read(dateExpandedProvider(dateKey).notifier)
                    .state = !isExpanded
                : null,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.brandYellow.withValues(alpha: 0.15),
                    AppColors.brandOrange.withValues(alpha: 0.10),
                    AppColors.brandBlue.withValues(alpha: 0.08),
                  ],
                ),
                borderRadius: AppRadius.borderRadiusMd,
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.brandOrange,
                          AppColors.brandYellow,
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color:
                              AppColors.brandOrange.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        '${date.day}',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: theme.colorScheme.onPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${date.month}\uC6D4 ${date.day}\uC77C $weekday\uC694\uC77C',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasItems
                            ? [
                                if (shifts.isNotEmpty)
                                  '\uADFC\uBB34 ${shifts.length}\uAC74',
                                if (events.isNotEmpty)
                                  '\uC77C\uC815 ${events.length}\uAC74',
                                if (notes.isNotEmpty)
                                  '\uBA54\uBAA8 ${notes.length}\uAC74',
                              ].join(' \u00B7 ')
                            : '\uB4F1\uB85D\uB41C \uD56D\uBAA9\uC774 \uC5C6\uC2B5\uB2C8\uB2E4',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  if (totalItems > 0) ...[
                    const Spacer(),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ],
              ),
            ),
          ),

          if (!hasItems) ...[
            const SizedBox(height: AppSpacing.lg),
            Center(
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.brandBlue.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '\u00B7  \u00B7',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color:
                              AppColors.brandBlue.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '+ \uBC84\uD2BC\uC73C\uB85C \uC77C\uC815\uC774\uB098 \uBA54\uBAA8\uB97C \uCD94\uAC00\uD574\uBCF4\uC138\uC694',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Shift list
          if (shifts.isNotEmpty && isExpanded) ...[
            const SizedBox(height: AppSpacing.md),
            ...shifts.map((s) {
              final shiftColor = parseHexColor(s.shiftType.color);
              return _buildColorBarCard(
                theme: theme,
                context: context,
                barColor: shiftColor,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm, vertical: 2),
                      decoration: BoxDecoration(
                        color: shiftColor.withValues(alpha: 0.15),
                        borderRadius: AppRadius.borderRadiusSm,
                      ),
                      child: Text(
                        s.shiftType.code,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: shiftColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      s.shiftType.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (s.shiftType.startTime != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        '${s.shiftType.startTime} ~ ${s.shiftType.endTime ?? ''}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (s.teamName != null) ...[
                      const Spacer(),
                      Text(
                        s.teamName!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
            if (events.isNotEmpty)
              _buildEventPreviewCard(theme, events.first),
          ],

          // Events when no shifts
          if (events.isNotEmpty && shifts.isEmpty && isExpanded) ...[
            const SizedBox(height: AppSpacing.md),
            ...events.asMap().entries.map((entry) {
              final index = entry.key;
              final event = entry.value;
              final eventColor = event.color != null
                  ? parseHexColor(event.color!)
                  : AppColors.success;
              return _buildEventCard(
                  theme, ref, context, event, eventColor, index);
            }),
          ],

          // Remaining events when shifts exist
          if (events.length > 1 && shifts.isNotEmpty && isExpanded) ...[
            const SizedBox(height: AppSpacing.md),
            ...events
                .asMap()
                .entries
                .where((e) => e.key > 0)
                .map((entry) {
              final index = entry.key;
              final event = entry.value;
              final eventColor = event.color != null
                  ? parseHexColor(event.color!)
                  : AppColors.success;
              return _buildEventCard(
                  theme, ref, context, event, eventColor, index);
            }),
          ],

          // Notes list
          if (notes.isNotEmpty && isExpanded) ...[
            if (events.isNotEmpty || shifts.isNotEmpty)
              const SizedBox(height: AppSpacing.xs),
            ...notes.asMap().entries.map((entry) {
              final index = entry.key;
              final note = entry.value;

              return _buildColorBarCard(
                theme: theme,
                context: context,
                barColor: theme.colorScheme.tertiary,
                trailing: PopupMenuButton<String>(
                  icon: Icon(Icons.more_horiz,
                      size: 18, color: theme.colorScheme.onSurfaceVariant),
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                        value: 'edit', child: Text('\uC218\uC815')),
                    const PopupMenuItem(
                        value: 'delete', child: Text('\uC0AD\uC81C')),
                  ],
                  onSelected: (action) {
                    if (action == 'edit') {
                      showNoteForm(
                          context, ref, date, index, note.content);
                    } else if (action == 'delete') {
                      _deleteNote(ref, index);
                    }
                  },
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color:
                            theme.colorScheme.tertiary.withValues(alpha: 0.12),
                        borderRadius: AppRadius.borderRadiusSm,
                      ),
                      child: Text(
                        '\uBA54\uBAA8',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.tertiary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        note.content,
                        style: theme.textTheme.bodyMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  /// Builds a card with a left color bar using BoxDecoration border
  /// instead of a separate Container + IntrinsicHeight for pixel-perfect
  /// alignment.
  Widget _buildColorBarCard({
    required ThemeData theme,
    required BuildContext context,
    required Color barColor,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: AppRadius.borderRadiusMd,
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 5,
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppRadius.md),
                  bottomLeft: Radius.circular(AppRadius.md),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.md,
                ),
                child: child,
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  /// Event preview card (single, compact)
  Widget _buildEventPreviewCard(ThemeData theme, PersonalEvent event) {
    final eventColor =
        event.color != null ? parseHexColor(event.color!) : AppColors.success;
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: eventColor.withValues(alpha: 0.08),
        borderRadius: AppRadius.borderRadiusSm,
        border: Border.all(color: eventColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.event, size: 14, color: eventColor),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              '${event.title}  ${event.timeRange}',
              style: TextStyle(
                fontSize: 12,
                color: eventColor,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Full event card
  Widget _buildEventCard(ThemeData theme, WidgetRef ref,
      BuildContext context, PersonalEvent event, Color eventColor, int index) {
    return _buildColorBarCard(
      theme: theme,
      context: context,
      barColor: eventColor,
      trailing: PopupMenuButton<String>(
        icon: Icon(Icons.more_horiz,
            size: 18, color: theme.colorScheme.onSurfaceVariant),
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'edit', child: Text('\uC218\uC815')),
          const PopupMenuItem(value: 'delete', child: Text('\uC0AD\uC81C')),
        ],
        onSelected: (action) {
          if (action == 'edit') {
            showEventEditWithShiftTypes(context, ref, date, index, event);
          } else if (action == 'delete') {
            _deleteEvent(context, ref, index);
          }
        },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(event.title,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: 2),
                decoration: BoxDecoration(
                  color: eventColor.withValues(alpha: 0.12),
                  borderRadius: AppRadius.borderRadiusSm,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.access_time, size: 12, color: eventColor),
                    const SizedBox(width: 3),
                    Text(event.timeRange,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: eventColor)),
                  ],
                ),
              ),
              if (event.description != null &&
                  event.description!.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(event.description!,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _deleteEvent(BuildContext context, WidgetRef ref, int index) async {
    final ds = ref.read(personalEventDataSourceProvider);
    final events = ds.getEvents(date);
    if (index < 0 || index >= events.length) return;

    final event = events[index];

    // 반복 일정이면 선택 다이얼로그
    if (event.recurrence != null && event.recurrence != 'none') {
      final ctx = context;
      final choice = await showDialog<String>(
        context: ctx,
        builder: (dCtx) => SimpleDialog(
          title: const Text('반복 일정 삭제'),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dCtx, 'single'),
              child: const Text('해당 일자 반복일정만 삭제'),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dCtx, 'future'),
              child: const Text('해당일정 이후 일정 모두 삭제'),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dCtx, 'cancel'),
              child: const Text('취소'),
            ),
          ],
        ),
      );

      if (choice == 'single') {
        await ds.removeEvent(date, index);
        refreshAll(ref, date);
      } else if (choice == 'future') {
        await ds.removeRecurringEventsFrom(
          date: date,
          title: event.title,
          recurrence: event.recurrence!,
        );
        refreshAll(ref, date);
      }
      return;
    }

    await ds.removeEvent(date, index);
    refreshAll(ref, date);
  }

  void _deleteNote(WidgetRef ref, int index) async {
    final ds = ref.read(personalNoteDataSourceProvider);
    await ds.removeNote(date, index);
    refreshAll(ref, date);
  }
}
