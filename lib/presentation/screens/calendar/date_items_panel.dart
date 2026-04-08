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

  /// 개인 일정 정렬: 종일(startTime null) 우선, 그다음 시간순.
  List<PersonalEvent> get _sortedEvents {
    final list = [...events];
    list.sort((a, b) {
      final aAllDay = a.startTime == null;
      final bAllDay = b.startTime == null;
      if (aAllDay != bAllDay) return aAllDay ? -1 : 1;
      if (aAllDay && bAllDay) return 0;
      return a.startTime!.compareTo(b.startTime!);
    });
    return list;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final events = _sortedEvents;
    final hasItems =
        shifts.isNotEmpty || events.isNotEmpty || notes.isNotEmpty;
    final weekday = _weekdays[date.weekday - 1];
    final totalItems = shifts.length + events.length + notes.length;
    final dateKey = DateTime(date.year, date.month, date.day);
    final isExpanded = ref.watch(dateExpandedProvider(dateKey));

    // 개인 일정 중 shift type과 이름 매칭되는 건 근무로 분류
    final shiftTypeNames = ref
        .watch(personalShiftTypesProvider)
        .map((st) => st.name)
        .toSet();
    final shiftEvents = events.where((e) => shiftTypeNames.contains(e.title)).toList();
    final normalEvents = events.where((e) => !shiftTypeNames.contains(e.title)).toList();

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

          // ── 근무 일정 섹션 ──
          if ((shifts.isNotEmpty || shiftEvents.isNotEmpty) && isExpanded) ...[
            const SizedBox(height: AppSpacing.lg),
            _buildSectionHeader(theme, '근무 일정'),
            const SizedBox(height: AppSpacing.sm),
            // 서버 근무
            ...shifts.map((s) {
              final shiftColor = parseHexColor(s.shiftType.color);
              return _buildShiftCard(
                theme: theme,
                shiftColor: shiftColor,
                code: s.shiftType.code,
                name: s.shiftType.name,
                startTime: s.shiftType.startTime,
                endTime: s.shiftType.endTime,
                teamName: s.teamName,
              );
            }),
            // 개인 캘린더 근무
            ...shiftEvents.map((event) {
              final originalIndex = events.indexOf(event);
              final eventColor = event.color != null
                  ? parseHexColor(event.color!)
                  : AppColors.shiftDay;
              final matchedType = ref
                  .read(personalShiftTypesProvider)
                  .where((st) => st.name == event.title)
                  .firstOrNull;
              return _buildShiftCard(
                theme: theme,
                shiftColor: eventColor,
                code: matchedType?.code ?? event.title.substring(0, 1),
                name: event.title,
                startTime: matchedType?.startTime ?? event.startTime,
                endTime: matchedType?.endTime ?? event.endTime,
                trailing: PopupMenuButton<String>(
                  icon: Icon(Icons.more_horiz,
                      size: 18, color: theme.colorScheme.onSurfaceVariant),
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('\uC218\uC815')),
                    const PopupMenuItem(value: 'delete', child: Text('\uC0AD\uC81C')),
                  ],
                  onSelected: (action) {
                    if (action == 'edit') {
                      showEventEditWithShiftTypes(context, ref, date, originalIndex, event);
                    } else if (action == 'delete') {
                      _deleteEvent(context, ref, originalIndex);
                    }
                  },
                ),
              );
            }),
          ],

          // ── 개인 일정 섹션 ──
          if (normalEvents.isNotEmpty && isExpanded) ...[
            const SizedBox(height: AppSpacing.lg),
            _buildSectionHeader(theme, '개인 일정'),
            const SizedBox(height: AppSpacing.sm),
            ...normalEvents.asMap().entries.map((entry) {
              final event = entry.value;
              final originalIndex = events.indexOf(event);
              final eventColor = event.color != null
                  ? parseHexColor(event.color!)
                  : AppColors.success;
              return _buildEventCard(
                  theme, ref, context, event, eventColor, originalIndex);
            }),
          ],

          // ── 메모 섹션 ──
          if (notes.isNotEmpty && isExpanded) ...[
            const SizedBox(height: AppSpacing.lg),
            _buildSectionHeader(theme, '메모'),
            const SizedBox(height: AppSpacing.sm),
            ...notes.asMap().entries.map((entry) {
              final index = entry.key;
              final note = entry.value;
              final noteKey = '${dateKey.toIso8601String()}-$index';
              final isNoteExpanded = ref.watch(noteExpandedProvider(noteKey));

              return GestureDetector(
                onTap: () => ref
                    .read(noteExpandedProvider(noteKey).notifier)
                    .state = !isNoteExpanded,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF3A3520).withValues(alpha: 0.6)
                        : const Color(0xFFFFF9C4).withValues(alpha: 0.6),
                    borderRadius: AppRadius.borderRadiusMd,
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF5C5330).withValues(alpha: 0.5)
                          : const Color(0xFFFFE082).withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.push_pin_rounded,
                        size: 14,
                        color: theme.colorScheme.secondary.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          note.content,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                            height: 1.4,
                          ),
                          maxLines: isNoteExpanded ? null : 1,
                          overflow: isNoteExpanded ? null : TextOverflow.ellipsis,
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_horiz,
                            size: 16, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
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
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  /// Shift card with colored background (matches home active shift style)
  Widget _buildShiftCard({
    required ThemeData theme,
    required Color shiftColor,
    required String code,
    required String name,
    String? startTime,
    String? endTime,
    String? teamName,
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            shiftColor.withValues(alpha: 0.15),
            shiftColor.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: AppRadius.borderRadiusMd,
        border: Border.all(
          color: shiftColor.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: shiftColor,
                    borderRadius: AppRadius.borderRadiusSm,
                  ),
                  child: Center(
                    child: Text(
                      code,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: ThemeData.estimateBrightnessForColor(shiftColor) ==
                                Brightness.dark
                            ? Colors.white
                            : Colors.black87,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (startTime != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm, vertical: 2),
                    decoration: BoxDecoration(
                      color: shiftColor.withValues(alpha: 0.12),
                      borderRadius: AppRadius.borderRadiusSm,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.access_time, size: 12, color: shiftColor),
                        const SizedBox(width: 3),
                        Text(
                          '$startTime ~ ${endTime ?? ''}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: shiftColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (teamName != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    teamName,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  /// Builds a card with a left color bar using BoxDecoration border
  /// instead of a separate Container + IntrinsicHeight for pixel-perfect
  /// alignment.
  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Text(
      title,
      style: theme.textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: theme.colorScheme.onSurfaceVariant,
        letterSpacing: 0.5,
      ),
    );
  }

  /// Full event card — same structure as shift card for alignment
  Widget _buildEventCard(ThemeData theme, WidgetRef ref,
      BuildContext context, PersonalEvent event, Color eventColor, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: eventColor.withValues(alpha: 0.06),
        borderRadius: AppRadius.borderRadiusMd,
        border: Border.all(
          color: eventColor.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: eventColor.withValues(alpha: 0.15),
                    borderRadius: AppRadius.borderRadiusSm,
                  ),
                  child: Icon(
                    Icons.event_outlined,
                    size: 16,
                    color: eventColor,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    event.title,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
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
              ],
            ),
          ),
          PopupMenuButton<String>(
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

