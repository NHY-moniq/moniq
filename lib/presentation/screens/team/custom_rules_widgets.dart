import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/models/custom_rule_model.dart';
import 'package:moniq/data/models/shift_type_model.dart';
import 'package:moniq/data/models/team_member_with_user.dart';
import 'package:moniq/data/providers/custom_rule_providers.dart';
import 'package:moniq/data/providers/supabase_providers.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/widgets/common/moniq_bottom_sheet.dart';
import 'package:moniq/presentation/widgets/common/moniq_empty_state.dart';

// ──────────────────────────────────────────────
// Providers (package-visible for screen)
// ──────────────────────────────────────────────

final customRulesProvider = FutureProvider.autoDispose
    .family<List<CustomRuleModel>, String>(
      (ref, teamId) =>
          ref.watch(customRuleRepositoryProvider).fetchRules(teamId),
    );

/// 팀당 커스텀 규칙 "생성 시도" 누적 한도 (무료 버전 비용 보호).
/// 저장 개수가 아니라 누적 시도 횟수라, 삭제→추가를 반복해도 한도를 우회할 수 없다.
const kMaxCustomRuleAttempts = 20;

/// 팀의 누적 생성 시도 횟수 (한도 표시/차단용).
final customRuleAttemptsProvider = FutureProvider.autoDispose
    .family<int, String>(
      (ref, teamId) =>
          ref.watch(customRuleRepositoryProvider).getParseAttempts(teamId),
    );

// ──────────────────────────────────────────────
// Body
// ──────────────────────────────────────────────

class CustomRulesBody extends ConsumerWidget {
  const CustomRulesBody({
    super.key,
    required this.teamId,
    required this.rules,
    required this.shiftTypes,
    required this.members,
  });

  final String teamId;
  final List<CustomRuleModel> rules;
  final List<ShiftTypeModel> shiftTypes;
  final List<TeamMemberWithUser> members;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        const _RuleGuideBanner(),
        Expanded(
          child: rules.isEmpty
              ? CustomRulesEmptyState(onAdd: () => _showAddSheet(context, ref))
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: rules.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, i) => CustomRuleCard(
                    rule: rules[i],
                    onToggle: (val) async {
                      await ref
                          .read(customRuleRepositoryProvider)
                          .toggleActive(rules[i].id, isActive: val);
                      ref.invalidate(customRulesProvider(teamId));
                    },
                    onTogglePriority: rules[i].ruleType == 'freeform'
                        ? null
                        : () async {
                            final newPriority = rules[i].priority == 'hard'
                                ? 'soft'
                                : 'hard';
                            await ref
                                .read(customRuleRepositoryProvider)
                                .updatePriority(
                                  rules[i].id,
                                  priority: newPriority,
                                );
                            ref.invalidate(customRulesProvider(teamId));
                          },
                    onDelete: () async {
                      final ok = await confirmDeleteRule(context);
                      if (!ok) return;
                      await ref
                          .read(customRuleRepositoryProvider)
                          .deleteRule(rules[i].id);
                      ref.invalidate(customRulesProvider(teamId));
                    },
                  ),
                ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: SizedBox(
              width: double.infinity,
              child: Builder(
                builder: (context) {
                  final attempts =
                      ref.watch(customRuleAttemptsProvider(teamId)).valueOrNull ??
                      0;
                  final atLimit = attempts >= kMaxCustomRuleAttempts;
                  return FilledButton.icon(
                    onPressed: atLimit
                        ? null
                        : () => _showAddSheet(context, ref),
                    icon: const Icon(Icons.add_rounded),
                    label: Text(
                      atLimit
                          ? '생성 한도 도달 (최대 $kMaxCustomRuleAttempts회)'
                          : '규칙 추가',
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showAddSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => CustomRuleAddSheet(
        teamId: teamId,
        shiftTypes: shiftTypes,
        members: members,
        onSaved: () => ref.invalidate(customRulesProvider(teamId)),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// 규칙 분류 안내 배너 (접기/펼치기)
// ──────────────────────────────────────────────

class _RuleGuideBanner extends StatefulWidget {
  const _RuleGuideBanner();

  @override
  State<_RuleGuideBanner> createState() => _RuleGuideBannerState();
}

class _RuleGuideBannerState extends State<_RuleGuideBanner> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bodyStyle = theme.textTheme.labelSmall?.copyWith(
      color: cs.onPrimaryContainer,
      height: 1.5,
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        0,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(Icons.auto_awesome_rounded, size: 15, color: cs.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'AI가 규칙을 분석해 자동으로 분류해요',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: cs.onPrimaryContainer.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              '• 내부 유형(근무 금지·동시 배정 금지·함께 배정·날짜 오프·'
              '나이트 후 오프·숙련도 조건·숙련도 균형)으로 분류돼요. '
              '해당 없으면 ‘자유형’(소프트 전용).',
              style: bodyStyle,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '• 자유형은 자동 반영되지 않아요. 발행 후 ‘AI 분석’에서 적용 방안을 제안해요.',
              style: bodyStyle,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '• 하드: 최우선 적용(일부 위반 가능) / 소프트: 가능한 한 맞추는 선호',
              style: bodyStyle,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '• 추가되었으면 하는 더 좋은 유형이 있다면 언제든 문의해주세요.',
              style: bodyStyle,
            ),
          ],
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Confirm delete dialog
// ──────────────────────────────────────────────

Future<bool> confirmDeleteRule(BuildContext context) async {
  return showMoniqConfirmSheet(
    context: context,
    title: '규칙 삭제',
    message: '이 규칙을 삭제하시겠습니까?',
    confirmLabel: '삭제',
    destructive: true,
  );
}

// ──────────────────────────────────────────────
// Rule card
// ──────────────────────────────────────────────

class CustomRuleCard extends StatelessWidget {
  const CustomRuleCard({
    super.key,
    required this.rule,
    required this.onToggle,
    required this.onDelete,
    this.onTogglePriority,
  });

  final CustomRuleModel rule;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;
  final VoidCallback? onTogglePriority;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isHard = rule.priority == 'hard';

    return Container(
      decoration: BoxDecoration(
        color: rule.isActive
            ? theme.colorScheme.surface
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHard
              ? AppColors.error.withValues(alpha: 0.5)
              : AppColors.outlineVariant,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        leading: Icon(
          _iconForType(rule.ruleType),
          color: !rule.isActive
              ? AppColors.outline
              : isHard
              ? AppColors.error
              : AppColors.secondary,
          size: 22,
        ),
        title: Text(
          rule.originalText,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: rule.isActive ? null : AppColors.outline,
            decoration: rule.isActive ? null : TextDecoration.lineThrough,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              CustomRuleTypeBadge(ruleType: rule.ruleType),
              _PriorityToggle(
                priority: rule.priority,
                onToggle: onTogglePriority,
              ),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: rule.isActive,
              onChanged: onToggle,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              color: AppColors.error,
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'member_shift_ban':
        return Icons.block_rounded;
      case 'anti_pair':
        return Icons.people_alt_outlined;
      case 'require_pair':
        return Icons.supervisor_account_outlined;
      case 'date_off':
        return Icons.event_busy_outlined;
      case 'post_night_off':
        return Icons.bedtime_outlined;
      case 'skill_condition':
        return Icons.workspace_premium_outlined;
      case 'skill_balance':
        return Icons.balance_outlined;
      default:
        return Icons.notes_rounded;
    }
  }
}

// ──────────────────────────────────────────────
// Badges
// ──────────────────────────────────────────────

class CustomRuleTypeBadge extends StatelessWidget {
  const CustomRuleTypeBadge({super.key, required this.ruleType});

  final String ruleType;

  @override
  Widget build(BuildContext context) {
    final label = _label(ruleType);
    // 테마(colorScheme) 기반으로 다크모드에서도 어울리게 한다.
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
      ),
    );
  }

  String _label(String type) {
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
      case 'skill_balance':
        return '숙련도 균형';
      default:
        return '자유형';
    }
  }
}

class _PriorityToggle extends StatelessWidget {
  const _PriorityToggle({required this.priority, this.onToggle});

  final String priority;
  final VoidCallback? onToggle; // null = freeform (비활성)

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSoft = priority == 'soft';
    final isFreeform = onToggle == null;

    Widget toggle = GestureDetector(
      onTap: isFreeform ? null : onToggle,
      child: Container(
        height: 24,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isFreeform
                ? theme.colorScheme.outline.withValues(alpha: 0.3)
                : isSoft
                ? theme.colorScheme.secondary
                : AppColors.error,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Segment(
              label: '소프트',
              selected: isSoft,
              selectedColor: theme.colorScheme.secondary,
              isLeft: true,
            ),
            Container(
              width: 1,
              color: isFreeform
                  ? theme.colorScheme.outline.withValues(alpha: 0.3)
                  : isSoft
                  ? theme.colorScheme.secondary
                  : AppColors.error,
            ),
            _Segment(
              label: '하드',
              selected: !isSoft,
              selectedColor: AppColors.error,
              isLeft: false,
            ),
          ],
        ),
      ),
    );

    if (isFreeform) {
      return Opacity(opacity: 0.4, child: toggle);
    }
    return toggle;
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.isLeft,
  });

  final String label;
  final bool selected;
  final Color selectedColor;
  final bool isLeft;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: selected ? selectedColor : Colors.transparent,
        borderRadius: BorderRadius.horizontal(
          left: isLeft ? const Radius.circular(4) : Radius.zero,
          right: !isLeft ? const Radius.circular(4) : Radius.zero,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: selected
              ? Colors.white
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Empty state
// ──────────────────────────────────────────────

class CustomRulesEmptyState extends StatelessWidget {
  const CustomRulesEmptyState({super.key, required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return MoniqEmptyState.peaceful(
      title: '등록된 커스텀 규칙이 없어요',
      message: '팀 상황에 맞는 규칙을 자연어로 입력하면\nAI가 자동으로 분석합니다.',
    );
  }
}

// ──────────────────────────────────────────────
// Add rule bottom sheet
// ──────────────────────────────────────────────

class CustomRuleAddSheet extends ConsumerStatefulWidget {
  const CustomRuleAddSheet({
    super.key,
    required this.teamId,
    required this.shiftTypes,
    required this.members,
    required this.onSaved,
  });

  final String teamId;
  final List<ShiftTypeModel> shiftTypes;
  final List<TeamMemberWithUser> members;
  final VoidCallback onSaved;

  @override
  ConsumerState<CustomRuleAddSheet> createState() => _CustomRuleAddSheetState();
}

class _CustomRuleAddSheetState extends ConsumerState<CustomRuleAddSheet> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final repo = ref.read(customRuleRepositoryProvider);

    // 비용 보호: 돈이 드는 AI 파싱 전에 누적 "생성 시도" 한도를 확인한다.
    // (저장 개수가 아니라 누적 시도라 삭제→추가로 우회 불가)
    final attempts = await repo.getParseAttempts(widget.teamId);
    if (attempts >= kMaxCustomRuleAttempts) {
      setState(() {
        _error =
            '무료 버전은 팀당 규칙 생성 $kMaxCustomRuleAttempts회까지예요.\n'
            '(삭제 후 재추가를 포함한 누적 횟수)';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final client = ref.read(supabaseClientProvider);

      // Edge Function 호출 -- 자연어 -> DSL 파싱.
      // 누적 호출수 증가/한도 검사는 서버(Edge Function)에서 처리한다(우회 방지).
      final response = await client.functions.invoke(
        'parse-custom-rule',
        body: {
          'text': text,
          'teamId': widget.teamId,
          'teamMembers': widget.members
              .map((m) => {'id': m.userId, 'name': m.displayName})
              .toList(),
          'shiftTypes': widget.shiftTypes
              .map((s) => {'id': s.id, 'name': s.name, 'code': s.code})
              .toList(),
        },
      );

      // 서버가 카운터를 증가시켰으니 표시값 갱신
      ref.invalidate(customRuleAttemptsProvider(widget.teamId));

      final data = response.data as Map<String, dynamic>;

      if (data['error'] == 'limit_reached') {
        setState(() {
          _loading = false;
          _error =
              '무료 버전은 팀당 규칙 생성 $kMaxCustomRuleAttempts회까지예요.\n'
              '(삭제 후 재추가를 포함한 누적 횟수)';
        });
        return;
      }
      if (data.containsKey('error')) {
        throw Exception(data['error']);
      }

      final ruleType = data['rule_type'] as String? ?? 'freeform';
      final ruleValue =
          (data['rule_value'] as Map<String, dynamic>?) ??
          {'description': text};
      final parsedDsl = data['parsed_dsl'] as Map<String, dynamic>?;
      final priority = data['priority'] as String? ?? 'soft';

      await ref
          .read(customRuleRepositoryProvider)
          .addRule(
            teamId: widget.teamId,
            ruleType: ruleType,
            ruleValue: ruleValue,
            originalText: text,
            parsedDsl: parsedDsl,
            priority: priority,
          );

      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _error = 'AI 파싱 중 오류가 발생했습니다: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            Text('규칙 추가', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '자연어로 입력하면 AI가 자동으로 분석합니다.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Example chips
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: _examples.map((ex) {
                return ActionChip(
                  label: Text(ex, style: theme.textTheme.bodySmall),
                  onPressed: () {
                    _controller.text = ex;
                    _controller.selection = TextSelection.fromPosition(
                      TextPosition(offset: ex.length),
                    );
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: AppSpacing.md),

            TextField(
              controller: _controller,
              maxLength: 200,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: '예: 홍길동은 나이트 서지 않아요',
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
              enabled: !_loading,
            ),

            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.errorLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.md),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('AI로 규칙 등록'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const _examples = [
    '데이에 올드 1명 필수',
    '신규끼리만 같은 근무 서지 않게 해주세요',
    '나이트 3연속이면 2일 쉬어야 해요',
    'A와 B는 같은 나이트를 서지 않게 해주세요',
  ];
}
