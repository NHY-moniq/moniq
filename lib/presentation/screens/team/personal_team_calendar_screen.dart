import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moniq/data/datasources/personal_event_local_data_source.dart';
import 'package:moniq/data/datasources/personal_event_remote_data_source.dart'
    show kPrivateTeamEventMarker, kPrivateTeamNoteMarker;
import 'package:moniq/data/models/personal_team_member_shift.dart';
import 'package:moniq/presentation/screens/calendar/calendar_dialogs.dart';
import 'package:moniq/presentation/screens/team/common_off_screen.dart'
    show AppointmentFormResult, AppointmentForm;
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/widgets/common/moniq_bottom_sheet.dart';
import 'package:moniq/presentation/viewmodels/personal_team_calendar_viewmodel.dart';
import 'package:moniq/presentation/screens/calendar/calendar_providers.dart';
import 'package:moniq/presentation/widgets/calendar/moniq_calendar.dart';
import 'package:moniq/presentation/widgets/calendar/view_mode_toggle.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:moniq/presentation/widgets/common/moniq_app_bar.dart';
import 'package:moniq/presentation/widgets/common/moniq_error_view.dart';
import 'package:moniq/presentation/widgets/common/moniq_loading_view.dart';

import 'personal_team_calendar_widgets.dart';

class PersonalTeamCalendarScreen extends ConsumerWidget {
  const PersonalTeamCalendarScreen({super.key, required this.teamId});

  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(personalTeamCalendarViewModelProvider(teamId));

    return Scaffold(
      appBar: MoniqAppBar(
        title: '멤버 근무 현황',
        onLeadingTap: () {
          if (Navigator.of(context).canPop()) {
            context.pop();
          } else {
            context.go('/teams');
          }
        },
      ),
      body: stateAsync.when(
        loading: () => const MoniqLoadingView(),
        error: (e, _) => MoniqErrorView(
          message: '근무 정보를 불러올 수 없습니다',
          onRetry: () =>
              ref.invalidate(personalTeamCalendarViewModelProvider(teamId)),
        ),
        data: (state) =>
            PersonalTeamCalendarBody(state: state, teamId: teamId),
      ),
    );
  }
}

class PersonalTeamCalendarBody extends ConsumerStatefulWidget {
  const PersonalTeamCalendarBody({
    super.key,
    required this.state,
    required this.teamId,
  });

  final PersonalTeamCalendarState state;
  final String teamId;

  @override
  ConsumerState<PersonalTeamCalendarBody> createState() =>
      _PersonalTeamCalendarBodyState();
}

class _PersonalTeamCalendarBodyState
    extends ConsumerState<PersonalTeamCalendarBody> {
  CalendarViewMode _viewMode = CalendarViewMode.month;
  final ScrollController _scrollCtrl = ScrollController();
  ({DateTime day, int at})? _lastTap; // 더블탭 감지

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final teamId = widget.teamId;
    final vm = ref.read(personalTeamCalendarViewModelProvider(teamId).notifier);
    final selectedShifts = state.shiftsForDate(state.selectedDate);

    // 범례 — 월 전체 shifts에서 근무 유형별 정렬.
    final legendBuckets = <String, _ShiftBucket>{};
    for (final list in state.monthlyData.values) {
      for (final s in list) {
        if (_isEducation(s.shiftCode, s.shiftName)) continue;
        if (s.shiftCode == null && s.shiftName == null) continue;
        final key = (s.shiftName ?? s.shiftCode ?? '?');
        legendBuckets.putIfAbsent(
          key,
          () => _ShiftBucket(
            code: s.shiftCode ?? key,
            name: s.shiftName ?? key,
            color: s.shiftColor ?? '#A0AEC0',
            count: 0,
          ),
        );
      }
    }
    final legendSorted = legendBuckets.values.toList()
      ..sort((a, b) => _shiftSortKey(a).compareTo(_shiftSortKey(b)));

    return SingleChildScrollView(
      controller: _scrollCtrl,
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.lg),
          MoniqCalendar(
            focusedDay: state.focusedMonth,
            selectedDay: state.selectedDate,
            rowHeight: 80,
            viewMode: _viewMode,
            onViewModeChanged: (m) => setState(() => _viewMode = m),
            calendarFormat: _viewMode == CalendarViewMode.month
                ? CalendarFormat.month
                : CalendarFormat.week,
            legendItems: legendSorted.map((info) {
              Color color = const Color(0xFFA0AEC0);
              try {
                final hex = info.color.replaceFirst('#', '');
                color = Color(int.parse('FF$hex', radix: 16));
              } catch (_) {}
              return (color: color, label: info.code.toUpperCase());
            }).toList(),
            eventLoader: (day) {
              final key = DateTime(day.year, day.month, day.day);
              return state.monthlyData[key] ?? [];
            },
            onDaySelected: (selected, focused) {
              final nowMs = DateTime.now().millisecondsSinceEpoch;
              final last = _lastTap;
              final sameDay = last != null &&
                  last.day.year == selected.year &&
                  last.day.month == selected.month &&
                  last.day.day == selected.day;
              final isDouble = sameDay && (nowMs - last.at) < 350;
              if (isDouble) {
                final cur = ref.read(dateExpandedProvider);
                final next = !cur;
                ref.read(dateExpandedProvider.notifier).state = next;
                _lastTap = null;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!_scrollCtrl.hasClients) return;
                  _scrollCtrl.animateTo(
                    next ? _scrollCtrl.position.maxScrollExtent : 0,
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                  );
                });
              } else {
                _lastTap = (day: selected, at: nowMs);
                vm.selectDate(selected);
              }
            },
            onPageChanged: (focused) => vm.changeMonth(focused),
            // 팀 캘린더와 동일한 표시: 근무 유형별 인원 수 컬러 동그라미
            markerBuilder: (context, date, events) {
              final dayShifts = events.cast<PersonalMemberShift>();
              if (dayShifts.isEmpty) return null;
              // 근무 유형별 카운트 집계 (이름 기준 + 교육 제외)
              final typeCount = <String, _ShiftBucket>{};
              for (final s in dayShifts) {
                if (_isEducation(s.shiftCode, s.shiftName)) continue;
                if (s.shiftCode == null && s.shiftName == null) continue;
                final key = (s.shiftName ?? s.shiftCode ?? '?');
                typeCount.putIfAbsent(
                  key,
                  () => _ShiftBucket(
                    code: s.shiftCode ?? key,
                    name: s.shiftName ?? key,
                    color: s.shiftColor ?? '#A0AEC0',
                    count: 0,
                  ),
                );
                typeCount[key]!.count++;
              }
              if (typeCount.isEmpty) return null;
              final sorted = typeCount.values.toList()
                ..sort((a, b) =>
                    _shiftSortKey(a).compareTo(_shiftSortKey(b)));
              final cs = Theme.of(context).colorScheme;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: sorted.take(3).map((info) {
                  Color color = cs.onSurfaceVariant;
                  try {
                    final hex = info.color.replaceFirst('#', '');
                    color = Color(int.parse('FF$hex', radix: 16));
                  } catch (_) {}
                  return Container(
                    width: 12,
                    height: 12,
                    margin: const EdgeInsets.symmetric(horizontal: 0.5),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${info.count}',
                        style: TextStyle(
                          fontSize: 6,
                          fontWeight: FontWeight.w700,
                          color: cs.surface,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
            // 셀 본문: 프라이빗 팀 일정만 plain text 로 표시 (메모는 캘린더에 표시 안 함).
            previewBuilder: (day) {
              final key = DateTime(day.year, day.month, day.day);
              final events =
                  ref.watch(monthlyEventsProvider(state.focusedMonth));
              final dayEvents = events[key] ?? const [];
              final eventMarker = '$kPrivateTeamEventMarker$teamId';
              final teamEvents = dayEvents
                  .where((e) =>
                      e.description != null &&
                      (e.description == eventMarker ||
                          e.description!.startsWith('$eventMarker\n')))
                  .toList();
              if (teamEvents.isEmpty) return const [];
              return teamEvents.take(2).map((e) {
                Color? c;
                try {
                  final hex = (e.color ?? '#F0C040').replaceFirst('#', '');
                  c = Color(int.parse('FF$hex', radix: 16));
                } catch (_) {}
                return CalendarPreview(
                  text: e.title,
                  color: c,
                  isWork: false,
                );
              }).toList();
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          // 펼친 상태에서 패널 빈 영역을 더블탭하면 접기 (개인/팀 캘린더와 동일)
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onDoubleTap: () {
              final cur = ref.read(dateExpandedProvider);
              if (!cur) return;
              ref.read(dateExpandedProvider.notifier).state = false;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!_scrollCtrl.hasClients) return;
                _scrollCtrl.animateTo(
                  0,
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                );
              });
            },
            child: Padding(
              padding: AppSpacing.screenHorizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PersonalDayDetailPanel(
                    date: state.selectedDate,
                    shifts: selectedShifts,
                    members: state.members,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _PrivateTeamEventsSection(
                    teamId: teamId,
                    date: state.selectedDate,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 160),
        ],
      ),
    );
  }
}

class _ShiftBucket {
  _ShiftBucket({
    required this.code,
    required this.name,
    required this.color,
    required this.count,
  });

  final String code;
  final String name;
  final String color;
  int count;
}

/// 근무유형 정렬 키: 데이(0) → 이브닝(1) → 나이트(2) → 기타(3)
int _shiftSortKey(_ShiftBucket info) {
  final c = info.code.toUpperCase();
  final n = info.name;
  if (c == 'D' || n.contains('데이') || n.toLowerCase().contains('day')) {
    return 0;
  }
  if (c == 'E' || n.contains('이브닝') || n.toLowerCase().contains('eve')) {
    return 1;
  }
  if (c == 'N' || n.contains('나이트') || n.toLowerCase().contains('night')) {
    return 2;
  }
  return 3;
}

bool _isEducation(String? code, String? name) {
  final c = (code ?? '').toUpperCase();
  if (c == 'ED' || c == 'EDU') return true;
  final n = name ?? '';
  if (n.contains('교육')) return true;
  final lower = n.toLowerCase();
  return lower.contains('education') || lower.contains('training');
}

/// 프라이빗 팀 일정/메모 추가 메뉴.
/// 프라이빗 팀 일정/메모 추가 메뉴 — 개인 캘린더 + 아이콘과 같은 UX.
void showPrivateTeamAddMenu({
  required BuildContext context,
  required WidgetRef ref,
  required String teamId,
  required DateTime date,
}) {
  showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.lg),
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: AppRadius.borderRadiusMd,
                ),
                child:
                    const Icon(Icons.event, color: AppColors.success),
              ),
              title: const Text('일정 추가'),
              subtitle: const Text('시간, 색상, 설명을 포함한 일정'),
              onTap: () {
                Navigator.pop(ctx);
                showEventForm(
                  context,
                  ref,
                  date,
                  null,
                  null,
                  descriptionMarker: '$kPrivateTeamEventMarker$teamId',
                );
              },
            ),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Theme.of(ctx)
                      .colorScheme
                      .tertiary
                      .withValues(alpha: 0.12),
                  borderRadius: AppRadius.borderRadiusMd,
                ),
                child: Icon(Icons.edit_note,
                    color: Theme.of(ctx).colorScheme.tertiary),
              ),
              title: const Text('메모 추가'),
              subtitle: const Text('간단한 텍스트 메모'),
              onTap: () {
                Navigator.pop(ctx);
                // 메모도 동일 폼 사용 (note 마커 prepend).
                showEventForm(
                  context,
                  ref,
                  date,
                  null,
                  null,
                  descriptionMarker: '$kPrivateTeamNoteMarker$teamId',
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}

Future<String?> _promptPrivateTitle(
  BuildContext context, {
  required String title,
  required String eyebrow,
  String hint = '제목',
}) {
  final controller = TextEditingController();
  return showMoniqBottomSheet<String>(
    context: context,
    title: title,
    eyebrow: eyebrow,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          autofocus: true,
          maxLength: 60,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainerHigh,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            onPressed: () => Navigator.of(context, rootNavigator: true)
                .pop(controller.text.trim()),
            child: const Text(
              '추가',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    ),
  );
}

class _AddOptionTile extends StatelessWidget {
  const _AddOptionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, size: 20, color: cs.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: cs.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 선택된 날짜의 프라이빗 팀 일정/메모 섹션.
class _PrivateTeamEventsSection extends ConsumerWidget {
  const _PrivateTeamEventsSection({
    required this.teamId,
    required this.date,
  });

  final String teamId;
  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(dateEventsProvider(date));
    final eventMarker = '$kPrivateTeamEventMarker$teamId';
    final noteMarker = '$kPrivateTeamNoteMarker$teamId';
    final teamEvents = events.where((e) {
      final d = e.description;
      if (d == null) return false;
      return d == eventMarker ||
          d.startsWith('$eventMarker\n') ||
          d == noteMarker ||
          d.startsWith('$noteMarker\n');
    }).toList();
    if (teamEvents.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.xs,
            bottom: AppSpacing.xs,
          ),
          child: Text(
            '팀 일정',
            style: theme.textTheme.labelMedium?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        for (final e in teamEvents) ...[
          _PrivateEventCard(
            event: e,
            teamId: teamId,
            isNote: e.description != null &&
                (e.description == noteMarker ||
                    e.description!.startsWith('$noteMarker\n')),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
      ],
    );
  }
}

class _PrivateEventCard extends ConsumerWidget {
  const _PrivateEventCard({
    required this.event,
    required this.teamId,
    required this.isNote,
  });

  final PersonalEvent event;
  final String teamId;
  final bool isNote;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    Color color = cs.primary;
    try {
      final hex = (event.color ?? '#F0C040').replaceFirst('#', '');
      color = Color(int.parse('FF$hex', radix: 16));
    } catch (_) {}

    return Material(
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () =>
            _showActionSheet(context, ref, event, teamId, isNote),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(
                  isNote
                      ? Icons.sticky_note_2_outlined
                      : Icons.event_outlined,
                  size: 18,
                  color: color,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  event.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showActionSheet(
    BuildContext context,
    WidgetRef ref,
    PersonalEvent event,
    String teamId,
    bool isNote,
  ) async {
    await showMoniqBottomSheet<void>(
      context: context,
      title: event.title,
      eyebrow: isNote ? 'TEAM NOTE' : 'TEAM EVENT',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PrivateActionTile(
            icon: Icons.edit_outlined,
            label: '수정',
            subtitle: isNote ? '메모 내용 변경' : '약속명·시간 변경',
            onTap: () async {
              Navigator.of(context, rootNavigator: true).pop();
              final result = await showMoniqBottomSheet<AppointmentFormResult>(
                context: context,
                title: isNote ? '메모 수정' : '일정 수정',
                eyebrow: isNote ? 'EDIT NOTE' : 'EDIT EVENT',
                child: AppointmentForm(
                  initial: AppointmentFormResult(
                    title: event.title,
                    startTime: event.startTime,
                    endTime: event.endTime,
                  ),
                ),
              );
              if (result == null) return;
              try {
                final ds = ref.read(personalEventDataSourceProvider);
                final allEvents = ds.getEvents(event.date);
                final idx = allEvents.indexWhere(
                  (e) => e.id == event.id || e.title == event.title,
                );
                if (idx < 0) return;
                await ds.updateEvent(
                  event.date,
                  idx,
                  PersonalEvent(
                    id: event.id,
                    date: event.date,
                    title: result.title,
                    startTime: result.startTime,
                    endTime: result.endTime,
                    color: event.color,
                    description: event.description, // 마커 유지
                    createdAt: event.createdAt,
                  ),
                );
                ref.read(eventRefreshProvider.notifier).state++;
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('수정 실패: $e')),
                  );
                }
              }
            },
          ),
          const SizedBox(height: 6),
          _PrivateActionTile(
            icon: Icons.ios_share_outlined,
            label: '개인 캘린더로 내보내기',
            subtitle: '내 개인 캘린더에 사본을 추가',
            onTap: () async {
              Navigator.of(context, rootNavigator: true).pop();
              try {
                final ds = ref.read(personalEventDataSourceProvider);
                await ds.addEvent(PersonalEvent(
                  date: event.date,
                  title: event.title,
                  startTime: event.startTime,
                  endTime: event.endTime,
                  color: event.color,
                  createdAt: DateTime.now(),
                  // 마커 없음 → 개인 캘린더에 노출
                ));
                ref.read(eventRefreshProvider.notifier).state++;
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('개인 캘린더로 내보냈어요'),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('내보내기 실패: $e')),
                  );
                }
              }
            },
          ),
          const SizedBox(height: 6),
          _PrivateActionTile(
            icon: Icons.delete_outline_rounded,
            label: '삭제',
            subtitle: '팀 일정에서 제거',
            destructive: true,
            onTap: () async {
              Navigator.of(context, rootNavigator: true).pop();
              try {
                final ds = ref.read(personalEventDataSourceProvider);
                final allEvents = ds.getEvents(event.date);
                final idx = allEvents.indexWhere(
                  (e) => e.id == event.id || e.title == event.title,
                );
                if (idx >= 0) {
                  await ds.removeEvent(event.date, idx);
                  ref.read(eventRefreshProvider.notifier).state++;
                }
              } catch (_) {}
            },
          ),
        ],
      ),
    );
  }
}

class _PrivateActionTile extends StatelessWidget {
  const _PrivateActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final fg = destructive ? cs.error : cs.onSurface;
    final bg = destructive
        ? cs.error.withValues(alpha: 0.08)
        : cs.surfaceContainerHigh;
    final iconBg = destructive
        ? cs.error.withValues(alpha: 0.16)
        : cs.primary.withValues(alpha: 0.12);
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
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
                  color: iconBg,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, size: 18, color: fg),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: fg,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
