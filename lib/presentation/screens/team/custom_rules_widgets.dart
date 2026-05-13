import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/models/custom_rule_model.dart';
import 'package:moniq/data/models/shift_type_model.dart';
import 'package:moniq/data/models/team_member_with_user.dart';
import 'package:moniq/data/providers/custom_rule_providers.dart';
import 'package:moniq/data/providers/supabase_providers.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/widgets/common/moniq_empty_state.dart';

// ──────────────────────────────────────────────
// Providers (package-visible for screen)
// ──────────────────────────────────────────────

final customRulesProvider =
    FutureProvider.autoDispose.family<List<CustomRuleModel>, String>(
  (ref, teamId) => ref.watch(customRuleRepositoryProvider).fetchRules(teamId),
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
        Expanded(
          child: rules.isEmpty
              ? CustomRulesEmptyState(
                  onAdd: () => _showAddSheet(context, ref),
                )
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
                            final newPriority =
                                rules[i].priority == 'hard' ? 'soft' : 'hard';
                            await ref
                                .read(customRuleRepositoryProvider)
                                .updatePriority(rules[i].id, priority: newPriority);
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
              child: FilledButton.icon(
                onPressed: () => _showAddSheet(context, ref),
                icon: const Icon(Icons.add_rounded),
                label: const Text('규칙 추가'),
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
// Confirm delete dialog
// ──────────────────────────────────────────────

Future<bool> confirmDeleteRule(BuildContext context) async {
  return await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('규칙 삭제'),
          content: const Text('이 규칙을 삭제하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.error,
              ),
              child: const Text('삭제'),
            ),
          ],
        ),
      ) ??
      false;
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
          child: Row(
            children: [
              CustomRuleTypeBadge(ruleType: rule.ruleType),
              const SizedBox(width: AppSpacing.sm),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
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
  const _PriorityToggle({
    required this.priority,
    this.onToggle,
  });

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

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final client = ref.read(supabaseClientProvider);

      // Edge Function 호출 -- 자연어 -> DSL 파싱
      final response = await client.functions.invoke(
        'parse-custom-rule',
        body: {
          'text': text,
          'teamMembers': widget.members
              .map((m) => {'id': m.userId, 'name': m.displayName})
              .toList(),
          'shiftTypes': widget.shiftTypes
              .map((s) => {'id': s.id, 'name': s.name, 'code': s.code})
              .toList(),
        },
      );

      final data = response.data as Map<String, dynamic>;

      if (data.containsKey('error')) {
        throw Exception(data['error']);
      }

      final ruleType = data['rule_type'] as String? ?? 'freeform';
      final ruleValue =
          (data['rule_value'] as Map<String, dynamic>?) ?? {'description': text};
      final parsedDsl = data['parsed_dsl'] as Map<String, dynamic>?;
      final priority = data['priority'] as String? ?? 'soft';

      await ref.read(customRuleRepositoryProvider).addRule(
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
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppColors.onSurfaceVariant),
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
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.error),
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
    '나이트 3연속이면 2일 쉬어야 해요',
    'A와 B는 같은 나이트를 서지 않게 해주세요',
    '신규가 있는 근무에는 올드 한 명은 꼭 있어야 해요',
  ];
}
