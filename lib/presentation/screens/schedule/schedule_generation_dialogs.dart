part of 'schedule_generation_screen.dart';

void _showShiftTypesDialog(
  BuildContext context,
  ScheduleGenerationState state,
) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;
  final defaultShiftTypes = _defaultShiftTypes(state.shiftTypes);

  showMoniqBottomSheet<void>(
    context: context,
    title: '근무 유형 (${defaultShiftTypes.length}개)',
    eyebrow: 'SHIFT TYPES',
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
            borderRadius: AppRadius.borderRadiusMd,
          ),
          child: Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  defaultShiftTypes.isEmpty
                      ? '기본 근무 유형이 없습니다'
                      : '총 ${defaultShiftTypes.length}개 기본 근무 유형이 반영됩니다',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (defaultShiftTypes.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
            alignment: Alignment.center,
            child: Text(
              '설정된 기본 근무 유형이 없어요',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        if (defaultShiftTypes.isNotEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 420),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: defaultShiftTypes.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, i) {
                final t = defaultShiftTypes[i];
                final color = parseHexColor(t.color);

                return _ShiftTypeOverviewTile(
                  name: t.name,
                  code: t.code,
                  color: color,
                  timeText: _formatShiftTypeTimeText(t.startTime, t.endTime),
                  badgeLabel: '기본',
                );
              },
            ),
          ),
      ],
    ),
  );
}

const _defaultShiftTypeCodes = {'D', 'E', 'N', 'ED'};

List<ShiftTypeModel> _defaultShiftTypes(List<ShiftTypeModel> shiftTypes) {
  return shiftTypes
      .where(
        (t) => _defaultShiftTypeCodes.contains(t.code.trim().toUpperCase()),
      )
      .toList();
}

class _ShiftTypeOverviewTile extends StatelessWidget {
  const _ShiftTypeOverviewTile({
    required this.name,
    required this.code,
    required this.color,
    required this.timeText,
    required this.badgeLabel,
  });

  final String name;
  final String code;
  final Color color;
  final String timeText;
  final String badgeLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: AppRadius.borderRadiusMd,
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: AppRadius.borderRadiusMd,
            ),
            alignment: Alignment.center,
            child: Text(
              code,
              style: TextStyle(
                color: colorScheme.surface,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  timeText,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xxs,
            ),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: AppRadius.borderRadiusFull,
            ),
            child: Text(
              badgeLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatShiftTypeTimeText(String? startTime, String? endTime) {
  final start = _formatClock(startTime);
  final end = _formatClock(endTime);
  if (start.isEmpty && end.isEmpty) return '시간 미설정';
  if (start.isEmpty) return '~ $end';
  if (end.isEmpty) return '$start ~';
  return '$start ~ $end';
}

String _formatClock(String? time) {
  if (time == null || time.trim().isEmpty) return '';
  final parts = time.trim().split(':');
  if (parts.length < 2) return '';
  final hour = parts[0].padLeft(2, '0');
  final minute = parts[1].padLeft(2, '0');
  return '$hour:$minute';
}

String? _skillDisplayLabel(String? skillLevel) {
  switch (skillLevel) {
    case 'junior':
      return '신규';
    case 'mid':
      return '중간';
    case 'senior':
      return '올드';
    default:
      return null;
  }
}

void _showMembersDialog(
  BuildContext context,
  WidgetRef ref,
  ScheduleGenerationState state,
  String teamId,
) {
  final theme = Theme.of(context);
  final colorScheme = Theme.of(context).colorScheme;

  showMoniqBottomSheet<void>(
    context: context,
    title: '멤버 (${state.members.length}명)',
    eyebrow: 'MEMBERS',
    child: StatefulBuilder(
      builder: (sheetCtx, setLocal) {
        // 최신 state는 ref에서 읽음 (토글 즉시 반영)
        final current =
            ref.read(scheduleGenerationViewModelProvider(teamId)).valueOrNull ??
            state;
        final excluded = current.excludedMemberIds;
        final activeCount = current.members.length - excluded.length;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.45,
                ),
                borderRadius: AppRadius.borderRadiusMd,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.groups_rounded,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '$activeCount명 참여 · ${excluded.length}명 제외',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // 고정 높이 대신 Flexible — 셸 최대 높이 캡 안에서 스크롤되어
            // 작은 화면에서도 오버플로우가 발생하지 않는다.
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.sm),
                itemCount: current.members.length,
                itemBuilder: (_, i) {
                  final m = current.members[i];
                  final isExcluded = excluded.contains(m.userId);
                  return _MemberSwitchTile(
                    member: m,
                    isExcluded: isExcluded,
                    onToggle: () {
                      ref
                          .read(
                            scheduleGenerationViewModelProvider(
                              teamId,
                            ).notifier,
                          )
                          .toggleMemberExclusion(m.userId);
                      setLocal(() {}); // 시트 내 즉시 갱신
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                context
                    .push('/teams/$teamId/members')
                    .then(
                      (_) => ref.invalidate(
                        scheduleGenerationViewModelProvider(teamId),
                      ),
                    );
              },
              child: const Text('멤버 설정'),
            ),
          ],
        );
      },
    ),
  );
}

const _priorityKeyLabels = <String, String>{
  'annual_leave': '연차/법정휴가',
  'night_dedicated': '나이트전담 우선',
  'fairness_rest': '휴무배려',
  'fairness_equal': '균등배분',
  'wanted': '원티드 반영',
  'avoid_pattern': '기피패턴 처리',
  'preferred_shift': '선호근무 반영',
  'skill_placement': '숙련도 배치',
};

const _ruleTypeLabels = <String, String>{
  'min_staffing': '최소 인원',
  'max_staffing': '최대 인원',
  'max_consecutive_work_days': '최대 연속 근무',
  'max_monthly_shifts': '월 최대 근무',
  'max_monthly_night_shifts': '월 최대 야간',
  'max_consecutive_night_shifts': '최대 연속 야간',
  'min_weekly_off_days': '주 최소 오프',
  'no_night_then_day': 'ND 금지',
  'no_night_then_evening': 'NE 금지',
  'no_evening_then_day': 'ED 금지',
  'nod_disabled': 'NOD 금지',
  'avoid_nood': 'NOOD 기피',
  'avoid_noe': 'NOE 기피',
  'avoid_eod': 'EOD 기피',
  'wanted_p1_limit': '1순위 최대 신청',
  'wanted_p2_limit': '2순위 최대 신청',
  'wanted_priority_order': '원티드 우선순위',
  'scheduling_priority_order': '우선순위',
  'consider_skill_level': '숙련도 배치',
};

const _ruleCategorySpecs = <_RuleCategorySpec>[
  _RuleCategorySpec(
    key: 'staffing',
    title: '인력 설정',
    icon: Icons.groups_rounded,
    ruleTypes: {'min_staffing', 'max_staffing'},
  ),
  _RuleCategorySpec(
    key: 'workload',
    title: '근무량 제한',
    icon: Icons.calendar_month_rounded,
    ruleTypes: {'max_monthly_shifts', 'max_monthly_night_shifts'},
  ),
  _RuleCategorySpec(
    key: 'required',
    title: '필수 규칙',
    icon: Icons.rule_rounded,
    ruleTypes: {
      'max_consecutive_work_days',
      'max_consecutive_night_shifts',
      'min_weekly_off_days',
    },
  ),
  _RuleCategorySpec(
    key: 'blocked_pattern',
    title: '금지 패턴',
    icon: Icons.block_rounded,
    ruleTypes: {
      'no_night_then_day',
      'no_night_then_evening',
      'no_evening_then_day',
      'nod_disabled',
    },
  ),
  _RuleCategorySpec(
    key: 'avoid_pattern',
    title: '기피 패턴',
    icon: Icons.tune_rounded,
    ruleTypes: {'avoid_nood', 'avoid_noe', 'avoid_eod'},
  ),
  _RuleCategorySpec(
    key: 'scheduling',
    title: '스케줄링 우선순위',
    icon: Icons.auto_graph_rounded,
    ruleTypes: {'scheduling_priority_order', 'consider_skill_level'},
  ),
];

const _otherRuleCategorySpec = _RuleCategorySpec(
  key: 'other',
  title: '기타 규칙',
  icon: Icons.rule_folder_rounded,
  ruleTypes: <String>{},
);

class _RuleCategorySpec {
  const _RuleCategorySpec({
    required this.key,
    required this.title,
    required this.icon,
    required this.ruleTypes,
  });

  final String key;
  final String title;
  final IconData icon;
  final Set<String> ruleTypes;
}

class _AppliedRuleSummary {
  const _AppliedRuleSummary({required this.title, required this.icon});

  final String title;
  final IconData icon;
}

class _RuleSummaryGroup {
  const _RuleSummaryGroup({required this.spec, required this.rules});

  final _RuleCategorySpec spec;
  final List<_AppliedRuleSummary> rules;
}

/// null이 포함되는 규칙은 null 반환 -> 다이얼로그에서 숨김
String? _ruleValueSummary(
  String ruleType,
  Map<String, dynamic> rv, {
  Map<String, ShiftTypeModel> shiftTypeLookup = const {},
}) {
  switch (ruleType) {
    case 'max_consecutive_work_days':
      final days = rv['days'];
      if (days == null) return null;
      return '최대 연속 근무: $days일';
    case 'max_monthly_shifts':
      final count = rv['count'];
      if (count == null) return null;
      return '월 최대 근무: $count회';
    case 'max_monthly_night_shifts':
      final count = rv['count'];
      if (count == null) return null;
      return '월 최대 야간: $count회';
    case 'max_consecutive_night_shifts':
      // team_settings에서 {'days': value}로 저장됨
      final days = rv['days'];
      if (days == null) return null;
      return '최대 연속 야간: $days일';
    case 'min_weekly_off_days':
      final days = rv['days'];
      if (days == null) return null;
      return '주 최소 오프: $days일';
    case 'wanted_p1_limit':
    case 'wanted_p2_limit':
      return null;
    case 'min_staffing':
    case 'max_staffing':
      return _staffingRuleValueSummary(
        ruleType,
        rv,
        shiftTypeLookup: shiftTypeLookup,
      );
    case 'wanted_priority_order':
      return null;
    case 'scheduling_priority_order':
      final order = rv['order'] as List?;
      if (order == null || order.isEmpty) return null;
      return '${_ruleTypeLabels[ruleType]}: '
          '${order.map((k) => _priorityKeyLabels[k] ?? k).join(' > ')}';
    default:
      final enabled = rv['enabled'];
      if (enabled == null) return null;
      return '${_ruleTypeLabels[ruleType] ?? ruleType}: '
          '${enabled == true ? '활성화' : '비활성화'}';
  }
}

Map<String, ShiftTypeModel> _buildShiftTypeLookup(
  List<ShiftTypeModel> shiftTypes,
) {
  final lookup = <String, ShiftTypeModel>{};
  for (final type in shiftTypes) {
    lookup[type.id] = type;
    lookup[type.code] = type;
    lookup[type.code.toUpperCase()] = type;
  }
  return lookup;
}

String _shiftTypeSummaryLabel(String key, ShiftTypeModel? type) {
  final code = type?.code.trim();
  if (code != null && code.isNotEmpty) return code.toUpperCase();
  final name = type?.name.trim();
  if (name != null && name.isNotEmpty) return name;
  return key;
}

String? _staffingRuleValueSummary(
  String ruleType,
  Map<String, dynamic> rv, {
  required Map<String, ShiftTypeModel> shiftTypeLookup,
}) {
  final counts = rv['counts'] is Map ? rv['counts'] as Map : rv;
  final entries =
      counts.entries
          .map((entry) {
            final key = entry.key.toString();
            final count = entry.value is num ? (entry.value as num).toInt() : 0;
            final shiftType =
                shiftTypeLookup[key] ?? shiftTypeLookup[key.toUpperCase()];
            return (key: key, count: count, shiftType: shiftType);
          })
          .where((entry) => entry.count > 0)
          .toList()
        ..sort((a, b) {
          final orderA = a.shiftType?.displayOrder ?? 999;
          final orderB = b.shiftType?.displayOrder ?? 999;
          if (orderA != orderB) return orderA.compareTo(orderB);
          return _shiftTypeSummaryLabel(
            a.key,
            a.shiftType,
          ).compareTo(_shiftTypeSummaryLabel(b.key, b.shiftType));
        });

  if (entries.isEmpty) return null;
  final detail = entries
      .map((entry) {
        final label = _shiftTypeSummaryLabel(entry.key, entry.shiftType);
        return '$label ${entry.count}명';
      })
      .join(' · ');
  return '${_ruleTypeLabels[ruleType]}: $detail';
}

_RuleCategorySpec _ruleCategorySpecFor(String ruleType) {
  for (final spec in _ruleCategorySpecs) {
    if (spec.ruleTypes.contains(ruleType)) return spec;
  }
  return _otherRuleCategorySpec;
}

List<_RuleSummaryGroup> _buildRuleSummaryGroups(
  List<ShiftRuleModel> rules,
  Map<String, ShiftTypeModel> shiftTypeLookup,
) {
  final grouped = <String, List<_AppliedRuleSummary>>{};
  final specsByKey = <String, _RuleCategorySpec>{
    for (final spec in _ruleCategorySpecs) spec.key: spec,
    _otherRuleCategorySpec.key: _otherRuleCategorySpec,
  };

  for (final rule in rules) {
    final summary = _ruleValueSummary(
      rule.ruleType,
      rule.ruleValue,
      shiftTypeLookup: shiftTypeLookup,
    );
    if (summary == null) continue;
    final spec = _ruleCategorySpecFor(rule.ruleType);
    grouped
        .putIfAbsent(spec.key, () => [])
        .add(
          _AppliedRuleSummary(
            title: summary,
            icon: _ruleTypeIcon(rule.ruleType),
          ),
        );
  }

  return [
    for (final spec in [..._ruleCategorySpecs, _otherRuleCategorySpec])
      if ((grouped[spec.key] ?? const <_AppliedRuleSummary>[]).isNotEmpty)
        _RuleSummaryGroup(
          spec: specsByKey[spec.key]!,
          rules: grouped[spec.key]!,
        ),
  ];
}

void _showRulesDialog(BuildContext context, ScheduleGenerationState state) {
  final shiftTypeLookup = _buildShiftTypeLookup(state.shiftTypes);
  // null 요약인 규칙은 숨김
  final visibleRules = state.rules
      .where(
        (r) =>
            _ruleValueSummary(
              r.ruleType,
              r.ruleValue,
              shiftTypeLookup: shiftTypeLookup,
            ) !=
            null,
      )
      .toList();
  final ruleGroups = _buildRuleSummaryGroups(visibleRules, shiftTypeLookup);
  final expandedGroupKeys = ruleGroups.map((g) => g.spec.key).toSet();

  showMoniqBottomSheet<void>(
    context: context,
    title: '적용 규칙 (${visibleRules.length}개)',
    eyebrow: 'RULES',
    child: visibleRules.isEmpty
        ? const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Text('설정된 규칙이 없어요'),
          )
        : StatefulBuilder(
            builder: (ctx, setSheetState) {
              // 고정 높이 대신 shrinkWrap 리스트 — 셸의 최대 높이 캡 안에서
              // 스크롤되어 작은 화면에서도 오버플로우가 발생하지 않는다.
              return ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: ruleGroups.length,
                itemBuilder: (_, index) {
                  final group = ruleGroups[index];
                  final isExpanded = expandedGroupKeys.contains(group.spec.key);
                  return _RuleCategoryCard(
                    group: group,
                    isExpanded: isExpanded,
                    onToggle: () {
                      setSheetState(() {
                        if (isExpanded) {
                          expandedGroupKeys.remove(group.spec.key);
                        } else {
                          expandedGroupKeys.add(group.spec.key);
                        }
                      });
                    },
                  );
                },
              );
            },
          ),
  );
}

void _showCustomRulesDialog(
  BuildContext context,
  ScheduleGenerationState state,
) {
  final theme = Theme.of(context);
  final colorScheme = Theme.of(context).colorScheme;
  final active = state.customRules.where((r) => r.isActive).toList();
  final inactive = state.customRules.where((r) => !r.isActive).toList();
  final all = [...active, ...inactive];

  showMoniqBottomSheet<void>(
    context: context,
    title: '커스텀 규칙 (${active.length}개 적용 중)',
    eyebrow: 'CUSTOM RULES',
    child: all.isEmpty
        ? const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Text('등록된 커스텀 규칙이 없어요'),
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.45,
                  ),
                  borderRadius: AppRadius.borderRadiusMd,
                ),
                child: Text(
                  '${all.length}개 중 ${active.length}개 적용 · ${inactive.length}개 비활성',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 420),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: all.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, i) {
                    final rule = all[i];
                    return _CustomRuleSummaryTile(rule: rule);
                  },
                ),
              ),
            ],
          ),
  );
}

void _showWantedDetailSheet(
  BuildContext context,
  ScheduleGenerationState state,
) {
  final nameMap = {for (final m in state.members) m.userId: m.displayName};
  final shiftTypeMap = {for (final t in state.shiftTypes) t.id: t};

  final grouped = <String, List<_WantedEntryRow>>{};
  for (final e in state.wantedEntries) {
    grouped
        .putIfAbsent(e.userId, () => [])
        .add(
          _WantedEntryRow(
            date: e.wantedDate,
            priority: e.priority,
            shiftTypeId: e.shiftTypeId,
            reason: e.reason,
          ),
        );
  }
  for (final entries in grouped.values) {
    entries.sort((a, b) => a.date.compareTo(b.date));
  }

  final sortedUserIds = grouped.keys.toList()
    ..sort((a, b) => (nameMap[a] ?? a).compareTo(nameMap[b] ?? b));
  final expandedUserIds = sortedUserIds.toSet();

  showMoniqBottomSheet<void>(
    context: context,
    title: '원티드 현황',
    eyebrow: 'WANTED',
    child: StatefulBuilder(
      builder: (ctx, setSheetState) {
        final theme = Theme.of(ctx);
        final colorScheme = theme.colorScheme;
        final dateFormat = DateFormat('MM.dd');

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${state.wantedEntries.length}건 · ${grouped.length}명',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 520),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: sortedUserIds.length,
                itemBuilder: (_, i) {
                  final uid = sortedUserIds[i];
                  final name = nameMap[uid] ?? uid;
                  final entries = grouped[uid]!;
                  final isExpanded = expandedUserIds.contains(uid);

                  return Card(
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            onTap: () {
                              setSheetState(() {
                                if (isExpanded) {
                                  expandedUserIds.remove(uid);
                                } else {
                                  expandedUserIds.add(uid);
                                }
                              });
                            },
                            borderRadius: AppRadius.borderRadiusSm,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.xxs,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: colorScheme.primary.withValues(
                                        alpha: 0.1,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.person,
                                      color: colorScheme.primary,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                  Text(
                                    '${entries.length}건',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.w600,
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
                              padding: const EdgeInsets.only(
                                top: AppSpacing.md,
                              ),
                              child: Wrap(
                                spacing: AppSpacing.xs,
                                runSpacing: AppSpacing.xs,
                                children: entries.map((e) {
                                  final shiftType = e.shiftTypeId != null
                                      ? shiftTypeMap[e.shiftTypeId]
                                      : null;
                                  final Color chipColor;
                                  final String avatarLabel;
                                  if (shiftType != null) {
                                    chipColor = parseHexColor(shiftType.color);
                                    avatarLabel = shiftType.code;
                                  } else {
                                    chipColor = AppColors.shiftOff;
                                    avatarLabel = 'O';
                                  }
                                  final hasReason =
                                      e.reason != null && e.reason!.isNotEmpty;
                                  final chip = WantedEntryPill(
                                    color: chipColor,
                                    avatarLabel: avatarLabel,
                                    label: Text(
                                      '${dateFormat.format(e.date)} · '
                                      '${e.priority}순위',
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  );
                                  if (!hasReason) return chip;
                                  return WantedReasonChip(
                                    chip: chip,
                                    reason: e.reason!,
                                  );
                                }).toList(),
                              ),
                            ),
                            secondChild: const SizedBox.shrink(),
                            alignment: Alignment.topLeft,
                            sizeCurve: Curves.easeOutCubic,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    ),
  );
}

// ────────────────────────────────────────
// 멤버 바텀시트 — 개별 멤버 타일
// ────────────────────────────────────────
