import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/core/utils/color_utils.dart';
import 'package:moniq/core/utils/time_utils.dart';
import 'package:moniq/data/datasources/personal_event_local_data_source.dart';
import 'package:moniq/data/datasources/personal_note_local_data_source.dart';
import 'package:moniq/data/datasources/personal_shift_override_remote_data_source.dart';
import 'package:moniq/data/models/shift_with_type.dart';
import 'package:moniq/data/providers/settings_providers.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/widgets/common/moniq_bottom_sheet.dart';

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
    this.hasTeamSchedule = false,
  });

  final DateTime date;
  final List<ShiftWithType> shifts;
  final List<PersonalEvent> events;
  final List<PersonalNote> notes;

  /// 이번 달에 팀 근무 스케줄이 존재하는지 (true면 근무 없는 날 = 오프)
  final bool hasTeamSchedule;

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
    // "팀 근무 숨기기" 토글이 켜져 있으면 server-side 팀 로스터 근무를
    // 카드/카운트에서 모두 제외. 다른 팀에서 admin이 만든 근무가 거슬리는
    // 경우 사용자가 한 번에 가릴 수 있도록 함.
    final hideTeamShifts = ref.watch(hideTeamShiftsInPersonalProvider);
    final visibleShifts = hideTeamShifts ? const <ShiftWithType>[] : shifts;
    // 팀 스케줄이 있는데 이 날 근무가 없으면 오프로 간주 (숨김 모드면 무시)
    final isTeamOff =
        !hideTeamShifts && hasTeamSchedule && visibleShifts.isEmpty;
    final hasItems =
        visibleShifts.isNotEmpty ||
        isTeamOff ||
        events.isNotEmpty ||
        notes.isNotEmpty;
    final offCount = isTeamOff ? 1 : 0;
    final totalItems =
        visibleShifts.length + offCount + events.length + notes.length;
    final dateKey = DateTime(date.year, date.month, date.day);
    final isExpanded = ref.watch(dateExpandedProvider);

    // 개인 일정 중 shift type과 이름 매칭되는 건 근무로 분류
    final shiftTypeNames = ref
        .watch(personalShiftTypesProvider)
        .map((st) => st.name)
        .toSet();
    final shiftEvents = events
        .where((e) => shiftTypeNames.contains(e.title))
        .toList();
    final normalEvents = events
        .where((e) => !shiftTypeNames.contains(e.title))
        .toList();

    return Padding(
      padding: AppSpacing.screenHorizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // \uD3BC\uCE58\uAE30/\uB2EB\uAE30 \uD1A0\uAE00 \u2014 items\uAC00 \uC788\uC744 \uB54C\uB9CC \uB178\uCD9C.
          // \uC791\uC740 chevron pill\uC744 \uC911\uC559\uC5D0 \uBC30\uCE58\uD574 \uC2DC\uAC01\uC801 \uB178\uC774\uC988 \uCD5C\uC18C\uD654.
          if (totalItems > 0)
            Center(
              child: Material(
                color: theme.colorScheme.surfaceContainerHigh,
                shape: const StadiumBorder(),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: () => ref.read(dateExpandedProvider.notifier).state =
                      !isExpanded,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: 6,
                    ),
                    child: AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          if (!hasItems) ...[
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: Image.asset(
                      'assets/images/off.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 6),
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
          if ((visibleShifts.isNotEmpty ||
                  shiftEvents.isNotEmpty ||
                  isTeamOff) &&
              isExpanded) ...[
            const SizedBox(height: AppSpacing.lg),
            _buildSectionHeader(theme, '근무 일정'),
            const SizedBox(height: AppSpacing.sm),
            // 팀 스케줄 있는데 근무 없으면 오프 표시
            if (isTeamOff)
              _buildShiftCard(
                theme: theme,
                shiftColor: AppColors.onSurfaceVariant,
                code: 'O',
                name: '오프',
              ),
            // 서버 근무 (원격 오버라이드 적용)
            ...visibleShifts.map((s) {
              final overrides =
                  ref.watch(personalShiftOverridesProvider).valueOrNull ??
                  const <String, PersonalShiftOverrideRemote>{};
              final override = overrides[s.shift.id];
              final code = override?.code ?? s.shiftType.code;
              final name = override?.name ?? s.shiftType.name;
              final colorHex = override?.color ?? s.shiftType.color;
              final startTime = override?.startTime ?? s.shiftType.startTime;
              final endTime = override?.endTime ?? s.shiftType.endTime;
              final shiftColor = parseHexColor(colorHex);
              return _buildShiftCard(
                theme: theme,
                shiftColor: shiftColor,
                code: code,
                name: name,
                startTime: formatTimeString(startTime),
                endTime: formatTimeString(endTime),
                teamName: s.teamName,
                trailing: _CardActionButton(
                  title: '근무 수정',
                  actions: [
                    _ItemAction(
                      icon: Icons.edit_outlined,
                      label: '수정',
                      onTap: () =>
                          editTeamShiftAsPersonal(context, ref, date, s),
                    ),
                    if (override != null)
                      _ItemAction(
                        icon: Icons.restart_alt_rounded,
                        label: '팀 근무로 복원',
                        onTap: () => _resetShiftOverride(ref, s.shift.id, date),
                      ),
                  ],
                ),
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
                trailing: _CardActionButton(
                  title: '\uADFC\uBB34 \uC218\uC815',
                  actions: [
                    _ItemAction(
                      icon: Icons.edit_outlined,
                      label: '\uC218\uC815',
                      onTap: () => showEventForm(
                        context,
                        ref,
                        date,
                        originalIndex,
                        event,
                      ),
                    ),
                    _ItemAction(
                      icon: Icons.delete_outline_rounded,
                      label: '\uC0AD\uC81C',
                      destructive: true,
                      onTap: () => _deleteEvent(context, ref, originalIndex),
                    ),
                  ],
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
                theme,
                ref,
                context,
                event,
                eventColor,
                originalIndex,
              );
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
                onTap: () =>
                    ref.read(noteExpandedProvider(noteKey).notifier).state =
                        !isNoteExpanded,
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
                        color: theme.colorScheme.secondary.withValues(
                          alpha: 0.6,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          note.content,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.8,
                            ),
                            height: 1.4,
                          ),
                          maxLines: isNoteExpanded ? null : 1,
                          overflow: isNoteExpanded
                              ? null
                              : TextOverflow.ellipsis,
                        ),
                      ),
                      _CardActionButton(
                        title: '\uBA54\uBAA8 \uC218\uC815',
                        iconSize: 16,
                        iconAlpha: 0.5,
                        actions: [
                          _ItemAction(
                            icon: Icons.edit_outlined,
                            label: '\uC218\uC815',
                            onTap: () => showNoteForm(
                              context,
                              ref,
                              date,
                              index,
                              note.content,
                            ),
                          ),
                          _ItemAction(
                            icon: Icons.delete_outline_rounded,
                            label: '\uC0AD\uC81C',
                            destructive: true,
                            onTap: () => _deleteNote(ref, index),
                          ),
                        ],
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
        border: Border.all(color: shiftColor.withValues(alpha: 0.2)),
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
                      // OFF는 'O'로, 그 외 2글자 이상 코드는 첫 글자만 표시
                      _displayShiftCode(code, name),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color:
                            ThemeData.estimateBrightnessForColor(shiftColor) ==
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
                      horizontal: AppSpacing.sm,
                      vertical: 2,
                    ),
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
  Widget _buildEventCard(
    ThemeData theme,
    WidgetRef ref,
    BuildContext context,
    PersonalEvent event,
    Color eventColor,
    int index,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: eventColor.withValues(alpha: 0.06),
        borderRadius: AppRadius.borderRadiusMd,
        border: Border.all(color: eventColor.withValues(alpha: 0.15)),
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
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: eventColor.withValues(alpha: 0.12),
                    borderRadius: AppRadius.borderRadiusSm,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.access_time, size: 12, color: eventColor),
                      const SizedBox(width: 3),
                      Text(
                        event.timeRange,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: eventColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _CardActionButton(
            title: '\uC77C\uC815 \uC218\uC815',
            actions: [
              _ItemAction(
                icon: Icons.edit_outlined,
                label: '\uC218\uC815',
                onTap: () => showEventForm(context, ref, date, index, event),
              ),
              _ItemAction(
                icon: Icons.delete_outline_rounded,
                label: '\uC0AD\uC81C',
                destructive: true,
                onTap: () => _deleteEvent(context, ref, index),
              ),
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
      final choice = await showMoniqBottomSheet<String>(
        context: ctx,
        eyebrow: 'DELETE',
        title: '반복 일정 삭제',
        child: Builder(
          builder: (sheetCtx) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MoniqSheetOption(
                icon: Icons.event_busy_outlined,
                label: '이 날짜만 삭제',
                description: '선택한 날짜의 반복 일정만 삭제해요',
                onTap: () => Navigator.pop(sheetCtx, 'single'),
              ),
              MoniqSheetOption(
                icon: Icons.clear_all_rounded,
                label: '이후 일정 모두 삭제',
                description: '이 날짜 이후의 모든 반복 일정을 삭제해요',
                onTap: () => Navigator.pop(sheetCtx, 'future'),
              ),
            ],
          ),
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

  Future<void> _resetShiftOverride(
    WidgetRef ref,
    String shiftId,
    DateTime date,
  ) async {
    await ref.read(personalShiftOverrideRemoteProvider).remove(shiftId);
    refreshAll(ref, date);
  }
}

/// 근무 카드 라벨용 — OFF는 'O', 교육(ED)은 그대로, 그 외 2글자 이상 코드는 첫 글자만.
String _displayShiftCode(String code, String name) {
  final c = code.toUpperCase();
  if (c == 'OFF' || name.contains('오프') || name.toLowerCase().contains('off')) {
    return 'O';
  }
  // 교육(ED/EDU 등)은 단일 문자로 줄이지 않고 코드를 그대로 노출한다.
  if (c == 'ED' ||
      c == 'EDU' ||
      name.contains('교육') ||
      name.toLowerCase().contains('education') ||
      name.toLowerCase().contains('training')) {
    return c.isEmpty ? 'ED' : c;
  }
  if (c.isEmpty) {
    return name.isEmpty ? '?' : name[0].toUpperCase();
  }
  return c.length > 1 ? c[0] : c;
}

// ────────────────────────────────────────
// 액션 시트 (수정/삭제 등) — 세련된 바텀시트 형태
// ────────────────────────────────────────

class _ItemAction {
  const _ItemAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;
}

/// 카드(근무/일정/메모) 우측 ⋯ 버튼 — 탭하면 액션 바텀시트.
class _CardActionButton extends StatelessWidget {
  const _CardActionButton({
    required this.actions,
    this.title = '항목 옵션',
    this.iconSize = 18,
    this.iconAlpha = 1.0,
  });

  final List<_ItemAction> actions;
  final String title;
  final double iconSize;
  final double iconAlpha;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IconButton(
      icon: Icon(
        Icons.more_horiz,
        size: iconSize,
        color: cs.onSurfaceVariant.withValues(alpha: iconAlpha),
      ),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      visualDensity: VisualDensity.compact,
      onPressed: () => _showActionSheet(context, title, actions),
    );
  }
}

Future<void> _showActionSheet(
  BuildContext context,
  String title,
  List<_ItemAction> actions,
) async {
  await showMoniqBottomSheet<void>(
    context: context,
    title: title,
    eyebrow: 'ACTIONS',
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          _ActionSheetTile(action: actions[i]),
          if (i != actions.length - 1) const SizedBox(height: 6),
        ],
      ],
    ),
  );
}

class _ActionSheetTile extends StatelessWidget {
  const _ActionSheetTile({required this.action});
  final _ItemAction action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tone = action.destructive ? cs.error : cs.onSurface;
    final bg = action.destructive
        ? cs.error.withValues(alpha: 0.08)
        : cs.surfaceContainerHigh;
    final iconBg = action.destructive
        ? cs.error.withValues(alpha: 0.16)
        : cs.surfaceContainerHighest;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () {
          Navigator.of(context, rootNavigator: true).pop();
          action.onTap();
        },
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
                  color: iconBg,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(action.icon, size: 18, color: tone),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  action.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: tone,
                    fontWeight: FontWeight.w700,
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
