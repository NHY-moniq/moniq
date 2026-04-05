import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/core/utils/color_utils.dart';
import 'package:moniq/core/utils/time_utils.dart';
import 'package:moniq/data/models/shift_type_model.dart';
import 'package:moniq/presentation/screens/team/custom_shift_form.dart';
import 'package:moniq/presentation/screens/team/shift_template_data.dart';
import 'package:moniq/presentation/screens/team/shift_type_manage_widgets.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/team_detail_viewmodel.dart';

/// 근무 유형 목록 (등록된 카드 + 추가 버튼)
class ShiftTypesList extends ConsumerWidget {
  const ShiftTypesList({
    super.key,
    required this.shiftTypes,
    required this.isAdmin,
    required this.teamId,
  });

  final List<ShiftTypeModel> shiftTypes;
  final bool isAdmin;
  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (shiftTypes.isEmpty && isAdmin) {
      return EmptyShiftTypesView(
        teamId: teamId,
      );
    }

    if (shiftTypes.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Center(
            child: Text(
              '등록된 근무 유형이 없습니다',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant,
                  ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        ...shiftTypes.map((t) => ShiftTypeCard(
              shiftType: t,
              isAdmin: isAdmin,
              teamId: teamId,
            )),
        if (isAdmin) ...[
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showAddSheet(context, ref),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('근무 유형 추가'),
              style: OutlinedButton.styleFrom(
                foregroundColor:
                  Theme.of(context).colorScheme.primary,
                side: BorderSide(
                  color: Theme.of(context)
                      .colorScheme
                      .primary,
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.borderRadiusMd,
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.md,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _showAddSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      builder: (ctx) => ShiftTypeAddSheet(
        teamId: teamId,
        existingCodes: shiftTypes.map((t) => t.code).toSet(),
      ),
    );
  }
}

/// 빈 상태: 기본 근무 유형 템플릿 카드 3개
class EmptyShiftTypesView extends ConsumerStatefulWidget {
  const EmptyShiftTypesView({
    super.key,
    required this.teamId,
  });

  final String teamId;

  @override
  ConsumerState<EmptyShiftTypesView> createState() =>
      _EmptyShiftTypesViewState();
}

class _EmptyShiftTypesViewState
    extends ConsumerState<EmptyShiftTypesView> {
  bool _loading = false;

  Future<void> _addAllDefaults() async {
    setState(() => _loading = true);
    final notifier = ref.read(
      teamDetailViewModelProvider(widget.teamId).notifier,
    );

    for (var i = 0; i < defaultShiftTemplates.length; i++) {
      final t = defaultShiftTemplates[i];
      await notifier.createShiftType(
        name: t.name,
        code: t.code,
        startTime: t.startTime,
        endTime: t.endTime,
        color: t.color,
      );
    }
    if (mounted) setState(() => _loading = false);
  }

  void _showTemplateEditSheet(
      BuildContext context, ShiftTemplate template) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      builder: (ctx) => ShiftTypeCreateFromTemplateSheet(
        teamId: widget.teamId,
        template: template,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Text(
          '기본 근무 유형을 추가해보세요',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // 3개 템플릿 카드 (탭하면 편집 후 추가)
        Row(
          children: defaultShiftTemplates
              .map(
                (t) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                    ),
                    child: ShiftTemplateCard(
                      template: t,
                      onTap: () =>
                          _showTemplateEditSheet(
                              context, t),
                    ),
                  ),
                ),
              )
              .toList(),
        ),

        const SizedBox(height: AppSpacing.xl),

        // 한번에 추가 버튼
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _loading ? null : _addAllDefaults,
            icon: _loading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.onPrimary,
                    ),
                  )
                : const Icon(
                    Icons.auto_awesome_rounded,
                    size: 20,
                  ),
            label: Text(
              _loading ? '추가 중...' : '기본 3개 한번에 추가',
            ),
            style: FilledButton.styleFrom(
              backgroundColor:
                  theme.colorScheme.primary,
              foregroundColor:
                  theme.colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.md,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.borderRadiusMd,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 템플릿 미리보기 카드 (통통 튀는 애니메이션 아이콘)
class ShiftTemplateCard extends StatelessWidget {
  const ShiftTemplateCard({
    super.key,
    required this.template,
    required this.onTap,
  });

  final ShiftTemplate template;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = parseHexColor(template.color);

    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.borderRadiusLg,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.lg,
            horizontal: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: AppRadius.borderRadiusLg,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withValues(alpha: 0.15),
                color.withValues(alpha: 0.05),
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 애니메이션 아이콘
              BouncyShiftIcon(
                icon: template.icon,
                color: color,
                code: template.code,
              ),
              const SizedBox(height: AppSpacing.sm),

              // 이름
              Text(
                template.name,
                style:
                    theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),

              // 시간
              Text(
                template.description,
                style:
                    theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme
                      .onSurfaceVariant,
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: AppSpacing.xs),

              // 탭 힌트
              Text(
                '탭하여 편집',
                style:
                    theme.textTheme.labelSmall?.copyWith(
                  color: color.withValues(alpha: 0.6),
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 템플릿 기반 생성 시트 (편집 가능)
class ShiftTypeCreateFromTemplateSheet
    extends ConsumerStatefulWidget {
  const ShiftTypeCreateFromTemplateSheet({
    super.key,
    required this.teamId,
    required this.template,
  });

  final String teamId;
  final ShiftTemplate template;

  @override
  ConsumerState<ShiftTypeCreateFromTemplateSheet>
      createState() =>
          _ShiftTypeCreateFromTemplateSheetState();
}

class _ShiftTypeCreateFromTemplateSheetState
    extends ConsumerState<
        ShiftTypeCreateFromTemplateSheet> {
  late final TextEditingController _nameC;
  late final TextEditingController _codeC;
  late final TextEditingController _startC;
  late final TextEditingController _endC;
  late String _selectedColor;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final t = widget.template;
    _nameC = TextEditingController(text: t.name);
    _codeC = TextEditingController(text: t.code);
    _startC = TextEditingController(
      text: formatTimeString(t.startTime),
    );
    _endC = TextEditingController(
      text: formatTimeString(t.endTime),
    );
    _selectedColor = t.color;
  }

  @override
  void dispose() {
    _nameC.dispose();
    _codeC.dispose();
    _startC.dispose();
    _endC.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameC.text.trim();
    final code = _codeC.text.trim();
    if (name.isEmpty || code.isEmpty) return;

    setState(() => _saving = true);
    await ref
        .read(teamDetailViewModelProvider(widget.teamId)
            .notifier)
        .createShiftType(
          name: name,
          code: code,
          startTime: _startC.text.trim().isNotEmpty
              ? '${_startC.text.trim()}:00'
              : null,
          endTime: _endC.text.trim().isNotEmpty
              ? '${_endC.text.trim()}:00'
              : null,
          color: _selectedColor,
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = parseHexColor(widget.template.color);

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.xl,
        bottom:
            MediaQuery.of(context).viewInsets.bottom +
                AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 핸들
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius:
                    AppRadius.borderRadiusFull,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // 타이틀 + 아이콘
          Row(
            children: [
              BouncyShiftIcon(
                icon: widget.template.icon,
                color: color,
                code: widget.template.code,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.template.name} 근무 추가',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '기본값이 입력되어 있어요. 수정 후 추가하세요.',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(
                        color: theme.colorScheme
                            .onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),

          CustomShiftForm(
            nameC: _nameC,
            codeC: _codeC,
            startC: _startC,
            endC: _endC,
            selectedColor: _selectedColor,
            onColorChanged: (c) =>
                setState(() => _selectedColor = c),
          ),
          const SizedBox(height: AppSpacing.xl),

          FilledButton(
            onPressed: _saving ? null : _create,
            style: FilledButton.styleFrom(
              backgroundColor: color,
              foregroundColor:
                  theme.colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.md,
              ),
            ),
            child: _saving
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color:
                          theme.colorScheme.onPrimary,
                    ),
                  )
                : const Text('추가'),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}

/// 통통 튀는 아이콘 애니메이션
class BouncyShiftIcon extends StatefulWidget {
  const BouncyShiftIcon({
    super.key,
    required this.icon,
    required this.color,
    required this.code,
  });

  final IconData icon;
  final Color color;
  final String code;

  @override
  State<BouncyShiftIcon> createState() =>
      _BouncyShiftIconState();
}

class _BouncyShiftIconState extends State<BouncyShiftIcon>
    with TickerProviderStateMixin {
  late final AnimationController _bounceController;
  late final AnimationController _glowController;
  late final Animation<double> _bounceAnim;
  late final Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();

    // 바운스: 위아래로 통통
    _bounceController = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: widget.code == 'D'
            ? 1200
            : widget.code == 'E'
                ? 1500
                : 1800,
      ),
    )..repeat(reverse: true);

    _bounceAnim = Tween<double>(begin: 0, end: -8).animate(
      CurvedAnimation(
        parent: _bounceController,
        curve: Curves.easeInOut,
      ),
    );

    // 글로우: 빛나는 효과
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _glowAnim = Tween<double>(begin: 0.3, end: 0.8)
        .animate(CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(
          [_bounceController, _glowController]),
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _bounceAnim.value),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color
                  .withValues(alpha: 0.2),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(
                    alpha: _glowAnim.value,
                  ),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: _buildIcon(),
          ),
        );
      },
    );
  }

  Widget _buildIcon() {
    // 각 근무 유형별 다른 아이콘 스타일
    if (widget.code == 'D') {
      return _buildSunIcon();
    } else if (widget.code == 'E') {
      return _buildSunsetIcon();
    } else {
      return _buildMoonIcon();
    }
  }

  Widget _buildSunIcon() {
    return AnimatedBuilder(
      animation: _bounceController,
      builder: (context, _) {
        final rotation =
            _bounceController.value * 0.3;
        return Transform.rotate(
          angle: rotation,
          child: Icon(
            Icons.wb_sunny_rounded,
            size: 30,
            color: widget.color,
          ),
        );
      },
    );
  }

  Widget _buildSunsetIcon() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(
          Icons.wb_twilight_rounded,
          size: 30,
          color: widget.color,
        ),
        // 작은 반짝이
        AnimatedBuilder(
          animation: _glowController,
          builder: (context, _) {
            return Positioned(
              top: 10,
              right: 10,
              child: Opacity(
                opacity: _glowAnim.value,
                child: Icon(
                  Icons.auto_awesome,
                  size: 12,
                  color: widget.color
                      .withValues(alpha: 0.6),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMoonIcon() {
    return AnimatedBuilder(
      animation: _bounceController,
      builder: (context, _) {
        // 살짝 기울기 변화
        final tilt =
            (_bounceController.value - 0.5) * 0.2;
        return Transform.rotate(
          angle: tilt,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.nightlight_round,
                size: 28,
                color: widget.color,
              ),
              // 별 반짝임
              Positioned(
                top: 8,
                left: 10,
                child: Opacity(
                  opacity: (1 - _bounceController.value)
                      .clamp(0.2, 1.0),
                  child: const Icon(
                    Icons.star_rounded,
                    size: 10,
                    color: Color(0xFFFFD700),
                  ),
                ),
              ),
              Positioned(
                bottom: 10,
                right: 8,
                child: Opacity(
                  opacity: _bounceController.value
                      .clamp(0.2, 1.0),
                  child: const Icon(
                    Icons.star_rounded,
                    size: 8,
                    color: Color(0xFFFFD700),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
