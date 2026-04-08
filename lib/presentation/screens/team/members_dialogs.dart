import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/models/team_member_with_user.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/team_detail_viewmodel.dart';

// ── 숙련도 옵션 ──

class SkillOption {
  const SkillOption({
    required this.value,
    required this.label,
    required this.description,
  });

  final String? value;
  final String label;
  final String description;
}

const skillOptions = [
  SkillOption(
    value: null,
    label: '미지정',
    description: '숙련도를 설정하지 않음',
  ),
  SkillOption(
    value: 'junior',
    label: '신규',
    description: '신규 간호사',
  ),
  SkillOption(
    value: 'mid',
    label: '중간',
    description: '중간 경력 간호사',
  ),
  SkillOption(
    value: 'senior',
    label: '올드',
    description: '올드 간호사',
  ),
];

// ── 멤버 편집 바텀시트 ──

class MemberEditSheet extends ConsumerStatefulWidget {
  const MemberEditSheet({
    super.key,
    required this.teamId,
    required this.member,
    required this.state,
    this.scrollController,
  });

  final String teamId;
  final TeamMemberWithUser member;
  final TeamDetailState state;
  final ScrollController? scrollController;

  @override
  ConsumerState<MemberEditSheet> createState() =>
      _MemberEditSheetState();
}

class _MemberEditSheetState
    extends ConsumerState<MemberEditSheet> {
  bool _saving = false;

  // 멤버 속성 로컬 상태 (초기값은 현재 멤버값)
  late bool _nightExempt;
  late bool _dayOnly;
  late bool _nightDedicated;
  late String? _skillLevel;

  @override
  void initState() {
    super.initState();
    _nightExempt = widget.member.member.nightExempt;
    _dayOnly = widget.member.member.dayOnly;
    _nightDedicated = widget.member.member.nightDedicated;
    _skillLevel = widget.member.member.skillLevel;
  }

  Future<void> _saveAttrs({
    required bool nightExempt,
    required bool dayOnly,
    required bool nightDedicated,
  }) async {
    setState(() => _saving = true);
    try {
      await ref
          .read(teamDetailViewModelProvider(widget.teamId).notifier)
          .updateMemberAttrs(
            widget.member.userId,
            nightExempt: nightExempt,
            dayOnly: dayOnly,
            nightDedicated: nightDedicated,
          );
    } catch (e) {
      if (mounted) _showError('저장 중 오류가 발생했습니다: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changeRole() async {
    final m = widget.member;
    final newRole = m.role == 'admin' ? 'member' : 'admin';
    final adminCount =
        widget.state.members.where((x) => x.role == 'admin').length;
    final canDemote = !(m.role == 'admin' && adminCount <= 1);

    if (!canDemote) {
      _showError('관리자가 1명만 남아 있어 역할을 변경할 수 없습니다.');
      return;
    }

    setState(() => _saving = true);
    try {
      await ref
          .read(teamDetailViewModelProvider(widget.teamId).notifier)
          .updateMemberRole(m.userId, newRole);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) _showError('역할 변경 중 오류가 발생했습니다: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changeSkillLevel(String? skillLevel) async {
    setState(() {
      _skillLevel = skillLevel;
      _saving = true;
    });
    try {
      await ref
          .read(teamDetailViewModelProvider(widget.teamId).notifier)
          .updateMemberSkillLevel(widget.member.userId, skillLevel);
    } catch (e) {
      if (mounted) _showError('숙련도 변경 중 오류가 발생했습니다: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _confirmRemove() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('멤버 제거'),
        content:
            Text('${widget.member.displayName}님을 팀에서 제거하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (mounted) Navigator.pop(context);
              await ref
                  .read(
                    teamDetailViewModelProvider(
                      widget.teamId,
                    ).notifier,
                  )
                  .removeMember(widget.member.userId);
            },
            child:
                Text(
                  '제거',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = widget.member;
    final newRoleLabel =
        m.role == 'admin' ? '일반 멤버로 변경' : '관리자로 변경';
    // _skillLevel is local state, updated immediately on selection

    return SingleChildScrollView(
      controller: widget.scrollController,
      child: Padding(
        padding: EdgeInsets.only(
          top: AppSpacing.md,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor:
                        AppColors.primary.withValues(alpha: 0.1),
                    child: Text(
                      m.displayName.isNotEmpty
                          ? m.displayName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.displayName,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        m.user.email,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Divider(height: AppSpacing.lg),

            // 역할 변경
            ListTile(
              enabled: !_saving,
              leading: const Icon(Icons.swap_horiz),
              title: Text(newRoleLabel),
              subtitle: Text(
                m.role == 'admin'
                    ? '현재: 관리자'
                    : '현재: 일반 멤버',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondaryLight,
                ),
              ),
              onTap: _saving ? null : _changeRole,
            ),

            // 숙련도 섹션
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.xxs,
              ),
              child: Text(
                '숙련도',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondaryLight,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ...skillOptions.map(
              (opt) {
                final Color activeColor;
                switch (opt.value) {
                  case 'junior':
                    activeColor = AppColors.shiftDay;
                  case 'mid':
                    activeColor = AppColors.shiftEvening;
                  case 'senior':
                    activeColor = AppColors.shiftNight;
                  default:
                    activeColor = AppColors.primary;
                }
                return RadioListTile<String?>(
                  dense: true,
                  value: opt.value,
                  // ignore: deprecated_member_use
                  groupValue: _skillLevel,
                  title: Text(opt.label),
                  subtitle: Text(
                    opt.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                  // ignore: deprecated_member_use
                  activeColor: activeColor,
                  // ignore: deprecated_member_use
                  onChanged:
                      _saving ? null : (v) => _changeSkillLevel(v),
                );
              },
            ),

            const Divider(height: AppSpacing.lg),

            // 근무 속성 섹션
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.xxs,
              ),
              child: Text(
                '근무 속성',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondaryLight,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SwitchListTile.adaptive(
              dense: true,
              value: _nightDedicated,
              onChanged: _saving
                  ? null
                  : (v) {
                      final newNightExempt = v ? false : _nightExempt;
                      final newDayOnly = v ? false : _dayOnly;
                      setState(() {
                        _nightDedicated = v;
                        _nightExempt = newNightExempt;
                        _dayOnly = newDayOnly;
                      });
                      _saveAttrs(
                        nightExempt: newNightExempt,
                        dayOnly: newDayOnly,
                        nightDedicated: v,
                      );
                    },
              title: const Text('나이트 전담'),
              subtitle: const Text('나이트 근무만 배정'),
              // ignore: deprecated_member_use
              activeColor: AppColors.shiftNight,
            ),
            SwitchListTile.adaptive(
              dense: true,
              value: _nightExempt,
              onChanged: (_saving || _nightDedicated)
                  ? null
                  : (v) {
                      setState(() => _nightExempt = v);
                      _saveAttrs(
                        nightExempt: v,
                        dayOnly: _dayOnly,
                        nightDedicated: _nightDedicated,
                      );
                    },
              title: const Text('나이트 제외'),
              subtitle: const Text('나이트 근무 배정 안 함'),
              // ignore: deprecated_member_use
              activeColor: AppColors.primary,
            ),
            SwitchListTile.adaptive(
              dense: true,
              value: _dayOnly,
              onChanged: (_saving || _nightDedicated)
                  ? null
                  : (v) {
                      setState(() => _dayOnly = v);
                      _saveAttrs(
                        nightExempt: _nightExempt,
                        dayOnly: v,
                        nightDedicated: _nightDedicated,
                      );
                    },
              title: const Text('데이 전용'),
              subtitle: const Text('데이 근무만 배정'),
              // ignore: deprecated_member_use
              activeColor: AppColors.shiftDay,
            ),

            const Divider(height: AppSpacing.lg),

            // 멤버 제거
            ListTile(
              enabled: !_saving,
              leading: const Icon(
                Icons.person_remove,
                color: AppColors.error,
              ),
              title: const Text(
                '멤버 제거',
                style: TextStyle(color: AppColors.error),
              ),
              onTap: _saving ? null : _confirmRemove,
            ),
          ],
        ),
      ),
    );
  }
}
