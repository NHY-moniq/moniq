import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moniq/data/datasources/personal_event_local_data_source.dart';
import 'package:moniq/data/datasources/personal_event_remote_data_source.dart'
    show kPrivateTeamEventMarker;
import 'package:moniq/data/models/shift_model.dart';
import 'package:moniq/data/models/team_member_with_user.dart';
import 'package:moniq/data/models/user_model.dart';
import 'package:moniq/data/providers/shift_providers.dart';
import 'package:moniq/data/providers/supabase_providers.dart';
import 'package:moniq/data/providers/team_providers.dart';
import 'package:moniq/presentation/screens/calendar/calendar_dialogs.dart'
    show parseTime, formatTime, showCupertinoTimePicker;
import 'package:moniq/presentation/screens/calendar/calendar_providers.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/widgets/common/moniq_app_bar.dart';
import 'package:moniq/presentation/widgets/common/moniq_bottom_sheet.dart';
import 'package:moniq/presentation/widgets/common/moniq_empty_state.dart';
import 'package:moniq/presentation/widgets/common/moniq_error_view.dart';
import 'package:moniq/presentation/widgets/common/moniq_loading_view.dart';

/// 개인팀의 선택된 멤버들이 각자의 즐겨찾기 팀에서 공통으로 OFF인 날짜를 찾는 화면.
class CommonOffScreen extends ConsumerStatefulWidget {
  const CommonOffScreen({super.key, required this.teamId});

  final String teamId;

  @override
  ConsumerState<CommonOffScreen> createState() => _CommonOffScreenState();
}

class _CommonOffScreenState extends ConsumerState<CommonOffScreen> {
  late Future<_LoadedData> _future;
  Set<String>? _selectedUserIds; // null이면 전체 선택과 동일

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_LoadedData> _load() async {
    final teamRepo = ref.read(teamRepositoryProvider);
    final client = ref.read(supabaseClientProvider);

    final membersWithUsers =
        await teamRepo.getTeamMembersWithUsers(widget.teamId);
    if (membersWithUsers.isEmpty) {
      return const _LoadedData(
        members: [],
        memberShiftDates: {},
        memberDayDates: {},
        favTeamIdByUser: {},
        dateRangeStart: null,
        dateRangeEnd: null,
      );
    }

    final userIds = membersWithUsers.map((m) => m.user.id).toList();
    final favRows = await client
        .from('team_members')
        .select('user_id, team_id')
        .inFilter('user_id', userIds)
        .eq('is_favorite', true)
        .eq('is_deleted', false);
    final userIdToFavTeam = <String, String>{};
    for (final row in (favRows as List)) {
      final m = row as Map<String, dynamic>;
      userIdToFavTeam[m['user_id'] as String] = m['team_id'] as String;
    }

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 2, 0);

    final favTeamIds = userIdToFavTeam.values.toSet();
    final teamShifts = <String, List<ShiftModel>>{};
    // teamId → typeId → isDay
    final teamDayTypeIds = <String, Set<String>>{};
    for (final tid in favTeamIds) {
      try {
        final list = await client
            .from('shifts')
            .select()
            .eq('team_id', tid)
            .gte('shift_date', _dateStr(start))
            .lte('shift_date', _dateStr(end));
        teamShifts[tid] = (list as List)
            .map((r) => ShiftModel.fromJson(r as Map<String, dynamic>))
            .toList();
      } catch (_) {
        teamShifts[tid] = const [];
      }
      try {
        final types = await client
            .from('shift_types')
            .select('id, code, name')
            .eq('team_id', tid);
        teamDayTypeIds[tid] = <String>{};
        for (final t in (types as List)) {
          final m = t as Map<String, dynamic>;
          final code = ((m['code'] as String?) ?? '').toUpperCase();
          final name = ((m['name'] as String?) ?? '').toLowerCase();
          final isDay = code == 'D' ||
              code == 'DAY' ||
              name.contains('day') ||
              name.contains('데이');
          if (isDay) teamDayTypeIds[tid]!.add(m['id'] as String);
        }
      } catch (_) {
        teamDayTypeIds[tid] = const {};
      }
    }

    final memberShiftDates = <String, Set<DateTime>>{};
    final memberDayDates = <String, Set<DateTime>>{};
    for (final mu in membersWithUsers) {
      final favTid = userIdToFavTeam[mu.user.id];
      if (favTid == null) {
        memberShiftDates[mu.user.id] = <DateTime>{};
        memberDayDates[mu.user.id] = <DateTime>{};
        continue;
      }
      final shifts = teamShifts[favTid] ?? const [];
      final dayTypes = teamDayTypeIds[favTid] ?? const <String>{};
      memberShiftDates[mu.user.id] = shifts
          .where((s) => s.userId == mu.user.id)
          .map((s) => DateTime(
                s.shiftDate.year,
                s.shiftDate.month,
                s.shiftDate.day,
              ))
          .toSet();
      memberDayDates[mu.user.id] = shifts
          .where((s) =>
              s.userId == mu.user.id && dayTypes.contains(s.shiftTypeId))
          .map((s) => DateTime(
                s.shiftDate.year,
                s.shiftDate.month,
                s.shiftDate.day,
              ))
          .toSet();
    }

    return _LoadedData(
      members: membersWithUsers,
      memberShiftDates: memberShiftDates,
      memberDayDates: memberDayDates,
      favTeamIdByUser: userIdToFavTeam,
      dateRangeStart: start,
      dateRangeEnd: end,
    );
  }

  String _dateStr(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  /// 선택된 멤버 집합으로 공통 OFF 날짜 계산.
  List<DateTime> _computeCommonOff(_LoadedData data, Set<String> selectedIds) {
    if (selectedIds.isEmpty || data.dateRangeStart == null) return const [];
    final result = <DateTime>[];
    for (var d = data.dateRangeStart!;
        !d.isAfter(data.dateRangeEnd!);
        d = d.add(const Duration(days: 1))) {
      final dateKey = DateTime(d.year, d.month, d.day);
      final allOff = selectedIds.every(
        (uid) => !(data.memberShiftDates[uid]?.contains(dateKey) ?? false),
      );
      if (allOff) result.add(dateKey);
    }
    return result;
  }

  /// 겹침 많은 날: 각 날짜에 OFF 멤버 수를 집계.
  /// 인원수 desc, 같으면 날짜 asc 로 정렬. 상위 5개만 반환.
  List<_OverlapDay> _computeOverlapDays(
    _LoadedData data,
    Set<String> selectedIds,
  ) {
    if (selectedIds.isEmpty || data.dateRangeStart == null) return const [];
    final result = <_OverlapDay>[];
    for (var d = data.dateRangeStart!;
        !d.isAfter(data.dateRangeEnd!);
        d = d.add(const Duration(days: 1))) {
      final dateKey = DateTime(d.year, d.month, d.day);
      var count = 0;
      for (final uid in selectedIds) {
        final hasShift =
            data.memberShiftDates[uid]?.contains(dateKey) ?? false;
        if (!hasShift) count++;
      }
      if (count > 0) result.add(_OverlapDay(date: dateKey, count: count));
    }
    result.sort((a, b) {
      final byCount = b.count.compareTo(a.count);
      if (byCount != 0) return byCount;
      return a.date.compareTo(b.date);
    });
    return result.take(5).toList();
  }

  /// 특정 날짜에 약속(개인 일정) 추가 다이얼로그.
  Future<void> _addAppointmentForDate(
    BuildContext context,
    WidgetRef ref,
    DateTime date,
  ) async {
    final result = await showMoniqBottomSheet<AppointmentFormResult>(
      context: context,
      title: '약속 추가',
      eyebrow:
          '${DateFormat('yyyy.MM.dd (E)', 'ko').format(date)} · APPOINTMENT',
      child: const AppointmentForm(),
    );
    if (result == null || result.title.isEmpty) return;
    try {
      final ds = ref.read(personalEventDataSourceProvider);
      await ds.addEvent(PersonalEvent(
        date: DateTime(date.year, date.month, date.day),
        title: result.title,
        startTime: result.startTime,
        endTime: result.endTime,
        color: '#F0C040', // brand yellow
        createdAt: DateTime.now(),
        // 프라이빗 팀 마커 — 개인 캘린더에선 숨김, 해당 팀에만 노출.
        description: '$kPrivateTeamEventMarker${widget.teamId}',
      ));
      ref.read(eventRefreshProvider.notifier).state++;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${DateFormat('M월 d일', 'ko').format(date)} 약속이 추가됐어요',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('약속 추가 실패: $e')),
        );
      }
    }
  }

  Future<void> _openMemberPicker(_LoadedData data) async {
    final initial = _selectedUserIds ??
        data.members.map((m) => m.user.id).toSet();
    final result = await showMoniqBottomSheet<Set<String>>(
      context: context,
      title: '대상 멤버',
      eyebrow: 'MEMBERS',
      child: _MemberPicker(
        members: data.members,
        initialSelected: initial,
      ),
    );
    if (result != null) {
      setState(() => _selectedUserIds = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const MoniqAppBar(
        title: '공통 휴무 찾기',
        eyebrow: 'COMMON OFF',
        showBack: true,
      ),
      body: FutureBuilder<_LoadedData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const MoniqLoadingView();
          }
          if (snap.hasError) {
            return MoniqErrorView(
              message: '공통 휴무를 계산할 수 없어요',
              onRetry: () => setState(() => _future = _load()),
            );
          }
          final data = snap.data!;
          if (data.members.isEmpty) {
            return MoniqEmptyState.peaceful(
              title: '멤버가 없어요',
              message: '개인팀에 팀원을 먼저 추가해주세요',
            );
          }
          final selected =
              _selectedUserIds ?? data.members.map((m) => m.user.id).toSet();
          final commonOff = _computeCommonOff(data, selected);
          final overlap = _computeOverlapDays(data, selected);
          return _CommonOffBody(
            data: data,
            selectedIds: selected,
            commonOffDates: commonOff,
            overlapDays: overlap,
            onOpenMemberPicker: () => _openMemberPicker(data),
            onAddAppointment: (date) =>
                _addAppointmentForDate(context, ref, date),
          );
        },
      ),
    );
  }
}

class _LoadedData {
  const _LoadedData({
    required this.members,
    required this.memberShiftDates,
    required this.memberDayDates,
    required this.favTeamIdByUser,
    required this.dateRangeStart,
    required this.dateRangeEnd,
  });

  final List<TeamMemberWithUser> members;
  final Map<String, Set<DateTime>> memberShiftDates;
  final Map<String, Set<DateTime>> memberDayDates;
  final Map<String, String> favTeamIdByUser;
  final DateTime? dateRangeStart;
  final DateTime? dateRangeEnd;
}

class _CommonOffBody extends StatelessWidget {
  const _CommonOffBody({
    required this.data,
    required this.selectedIds,
    required this.commonOffDates,
    required this.overlapDays,
    required this.onOpenMemberPicker,
    required this.onAddAppointment,
  });

  final _LoadedData data;
  final Set<String> selectedIds;
  final List<DateTime> commonOffDates;
  final List<_OverlapDay> overlapDays;
  final VoidCallback onOpenMemberPicker;
  final ValueChanged<DateTime> onAddAppointment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final dateFmt = DateFormat('yyyy.MM.dd (E)', 'ko');

    final selectedMembers = data.members
        .where((m) => selectedIds.contains(m.user.id))
        .toList();
    final unsetMembers = selectedMembers
        .where((m) => !data.favTeamIdByUser.containsKey(m.user.id))
        .toList();

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        // 대상 멤버 카드 (탭 → 선택 시트)
        Material(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: onOpenMemberPicker,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '대상 멤버 ${selectedMembers.length} / ${data.members.length}명',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.tune_rounded,
                        size: 18,
                        color: cs.onSurfaceVariant,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    selectedMembers.isEmpty
                        ? '멤버를 선택해주세요'
                        : selectedMembers
                            .map((m) => _displayName(m.user))
                            .join(', '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (unsetMembers.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.brandOrange
                            .withValues(alpha: 0.10),
                        borderRadius:
                            BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 14,
                            color: AppColors.brandOrange,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '즐겨찾기 팀이 없는 멤버: '
                              '${unsetMembers.map((m) => _displayName(m.user)).join(', ')}\n'
                              '해당 멤버는 항상 OFF로 간주됩니다.',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppColors.brandOrange,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // 겹침 많은 날 패널
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '오프 겹침 TOP 5',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '가장 많은 멤버가 오프인 날 상위 5일',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (overlapDays.isEmpty)
                Text(
                  '해당하는 날이 없어요.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                )
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final o in overlapDays)
                        Padding(
                          padding:
                              const EdgeInsets.only(right: AppSpacing.sm),
                          child: ActionChip(
                            label: Text(
                              '${DateFormat('M.d (E)', 'ko').format(o.date)} · ${o.count}명',
                            ),
                            onPressed: () => onAddAppointment(o.date),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // 공통 휴무 리스트
        Text(
          '공통 휴무 (이번달·다음달)',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (commonOffDates.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: MoniqEmptyState.peaceful(
              title: '공통으로 쉬는 날이 없어요',
              message: '대상 멤버나 기간을 조정해보세요',
            ),
          )
        else
          ...commonOffDates.map(
            (d) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Material(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  onTap: () => _showOffMembers(
                    context: context,
                    date: d,
                    members: selectedMembers,
                    memberShiftDates: data.memberShiftDates,
                    onAddAppointment: () => onAddAppointment(d),
                  ),
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
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color:
                                AppColors.shiftOff.withValues(alpha: 0.18),
                            borderRadius:
                                BorderRadius.circular(AppRadius.sm),
                          ),
                          child: const Text(
                            'O',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.shiftOff,
                              height: 1,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            dateFmt.format(d),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
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
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _showOffMembers({
    required BuildContext context,
    required DateTime date,
    required List<TeamMemberWithUser> members,
    required Map<String, Set<DateTime>> memberShiftDates,
    required VoidCallback onAddAppointment,
  }) async {
    final dateKey = DateTime(date.year, date.month, date.day);
    final offMembers = members
        .where((m) =>
            !(memberShiftDates[m.user.id]?.contains(dateKey) ?? false))
        .toList();

    await showMoniqBottomSheet<void>(
      context: context,
      title: DateFormat('yyyy.MM.dd (E)', 'ko').format(date),
      eyebrow: 'OFF MEMBERS',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Text(
              '이 날 휴무인 멤버 ${offMembers.length}명',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          for (final m in offMembers) ...[
            _OffMemberTile(member: m),
            const SizedBox(height: 6),
          ],
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.of(context, rootNavigator: true).pop();
                onAddAppointment();
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                '이 날 약속 추가',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _displayName(UserModel u) {
    if ((u.displayName ?? '').isNotEmpty) return u.displayName!;
    return u.id.length >= 8 ? '사용자(${u.id.substring(0, 8)})' : '사용자';
  }
}

class _OffMemberTile extends StatelessWidget {
  const _OffMemberTile({required this.member});

  final TeamMemberWithUser member;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final name = (member.user.displayName ?? '').isNotEmpty
        ? member.user.displayName!
        : '사용자(${member.user.id.substring(0, 8)})';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Text(
              initial,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: cs.primary,
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
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: AppColors.shiftOff.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: const Text(
              'OFF',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppColors.shiftOff,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 멤버 선택 바텀시트 컨텐츠 — 체크박스 토글, 하단에 적용 버튼.
class _MemberPicker extends StatefulWidget {
  const _MemberPicker({
    required this.members,
    required this.initialSelected,
  });

  final List<TeamMemberWithUser> members;
  final Set<String> initialSelected;

  @override
  State<_MemberPicker> createState() => _MemberPickerState();
}

class _MemberPickerState extends State<_MemberPicker> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = {...widget.initialSelected};
  }

  void _toggle(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selected = widget.members.map((m) => m.user.id).toSet();
    });
  }

  void _clearAll() {
    setState(() => _selected.clear());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 전체 선택/해제 액션
        Row(
          children: [
            Expanded(
              child: TextButton.icon(
                onPressed: _selectAll,
                icon: const Icon(Icons.select_all_rounded, size: 18),
                label: const Text('전체 선택'),
              ),
            ),
            Expanded(
              child: TextButton.icon(
                onPressed: _clearAll,
                icon: const Icon(Icons.deselect_rounded, size: 18),
                label: const Text('전체 해제'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        for (final m in widget.members) ...[
          _MemberCheckTile(
            member: m,
            selected: _selected.contains(m.user.id),
            onTap: () => _toggle(m.user.id),
          ),
          const SizedBox(height: 6),
        ],
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            onPressed: () => Navigator.of(context, rootNavigator: true)
                .pop(_selected),
            child: Text(
              '${_selected.length}명 적용',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }
}

class _MemberCheckTile extends StatelessWidget {
  const _MemberCheckTile({
    required this.member,
    required this.selected,
    required this.onTap,
  });

  final TeamMemberWithUser member;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final name = (member.user.displayName ?? '').isNotEmpty
        ? member.user.displayName!
        : '사용자(${member.user.id.substring(0, 8)})';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final bg = selected
        ? cs.primary.withValues(alpha: 0.10)
        : cs.surfaceContainerHigh;
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
                  color: cs.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  initial,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: cs.primary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight:
                        selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? cs.primary : cs.onSurface,
                  ),
                ),
              ),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? cs.primary : cs.outline,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverlapDay {
  const _OverlapDay({required this.date, required this.count});
  final DateTime date;
  final int count;
}

/// 약속 입력 폼 결과 — 제목 + (선택) 시작/종료 시간.
class AppointmentFormResult {
  const AppointmentFormResult({
    required this.title,
    this.startTime,
    this.endTime,
  });
  final String title;
  final String? startTime; // 'HH:mm' 또는 null
  final String? endTime;
}

class AppointmentForm extends StatefulWidget {
  const AppointmentForm({this.initial});

  /// 수정 모드일 때의 초기값. null이면 추가 모드.
  final AppointmentFormResult? initial;

  @override
  State<AppointmentForm> createState() => AppointmentFormState();
}

class AppointmentFormState extends State<AppointmentForm> {
  late final TextEditingController _controller;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial?.title ?? '');
    final s = widget.initial?.startTime;
    final e = widget.initial?.endTime;
    if (s != null) _startTime = parseTime(s);
    if (e != null) _endTime = parseTime(e);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final t = _controller.text.trim();
    if (t.isEmpty) return;
    Navigator.of(context, rootNavigator: true).pop(
      AppointmentFormResult(
        title: t,
        startTime: _startTime != null ? formatTime(_startTime!) : null,
        endTime: _endTime != null ? formatTime(_endTime!) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '약속명',
          style: theme.textTheme.labelSmall?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _controller,
          autofocus: widget.initial == null,
          maxLength: 30,
          decoration: InputDecoration(
            hintText: '예: 단합 모임, 점심 약속',
            filled: true,
            fillColor: cs.surfaceContainerHigh,
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
        const SizedBox(height: AppSpacing.sm),
        // 시간 선택 (선택 사항)
        Row(
          children: [
            Expanded(
              child: _TimeField(
                label: '시작',
                value: _startTime != null
                    ? formatTime(_startTime!)
                    : '종일',
                isPlaceholder: _startTime == null,
                onTap: () {
                  showCupertinoTimePicker(
                    context: context,
                    initialHour: _startTime?.hour ?? 9,
                    initialMinute: _startTime?.minute ?? 0,
                    onChanged: (h, m) {
                      setState(
                          () => _startTime = TimeOfDay(hour: h, minute: m));
                    },
                  );
                },
                onClear: _startTime != null
                    ? () => setState(() => _startTime = null)
                    : null,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _TimeField(
                label: '종료',
                value: _endTime != null ? formatTime(_endTime!) : '-',
                isPlaceholder: _endTime == null,
                onTap: () {
                  showCupertinoTimePicker(
                    context: context,
                    initialHour: _endTime?.hour ?? (_startTime?.hour ?? 9) + 1,
                    initialMinute:
                        _endTime?.minute ?? _startTime?.minute ?? 0,
                    onChanged: (h, m) {
                      setState(
                          () => _endTime = TimeOfDay(hour: h, minute: m));
                    },
                  );
                },
                onClear: _endTime != null
                    ? () => setState(() => _endTime = null)
                    : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            onPressed: _submit,
            child: Text(
              widget.initial == null ? '추가' : '저장',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.value,
    required this.isPlaceholder,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final String value;
  final bool isPlaceholder;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isPlaceholder
                            ? cs.onSurfaceVariant
                            : cs.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              if (onClear != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  icon: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: cs.onSurfaceVariant,
                  ),
                  onPressed: onClear,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
