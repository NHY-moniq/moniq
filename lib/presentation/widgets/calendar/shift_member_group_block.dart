import 'package:flutter/material.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';

/// 근무 그룹에 표시할 멤버 칩 한 개의 데이터.
class ShiftMemberChipData {
  const ShiftMemberChipData({
    required this.displayName,
    this.avatarUrl,
    this.highlighted = false,
    this.onTap,
  });

  /// 칩에 노출할 이름. (예: 본인 표시가 필요하면 '홍길동 (나)' 형태로 직접 전달)
  final String displayName;
  final String? avatarUrl;

  /// 본인 등 강조 표시 여부 — 그룹 색으로 채워진다.
  final bool highlighted;

  /// 칩 탭 콜백. null이면 비활성(읽기 전용).
  final VoidCallback? onTap;
}

/// 근무 유형별 멤버 그룹 한 줄.
///
/// 왼쪽에 코드 배지 + 라벨, 가운데 인원 배지, 오른쪽에 멤버 칩을 표시한다.
/// 멤버 칩은 **기본 한 줄**만 노출하고, 폭을 넘치면 끝에 `+N` 버튼이 생긴다.
/// `+N`을 누르면 아래로 펼쳐 전체를 보여준다. (public / private / 멤버 근무 현황 공통)
class ShiftMemberGroupBlock extends StatelessWidget {
  const ShiftMemberGroupBlock({
    super.key,
    required this.code,
    required this.label,
    required this.color,
    required this.members,
  });

  /// 근무 코드(D/E/N 등). null이면 오프로 간주해 'O' 배지 + 중립 색으로 표시.
  final String? code;
  final String label;
  final Color color;
  final List<ShiftMemberChipData> members;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final isOff = code == null;
    final badgeColor = isOff ? cs.onSurfaceVariant : color;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: isOff
            ? cs.surfaceContainerHighest.withValues(alpha: 0.32)
            : color.withValues(alpha: 0.07),
        borderRadius: AppRadius.borderRadiusMd,
        border: Border.all(
          color: isOff
              ? cs.outlineVariant.withValues(alpha: 0.4)
              : color.withValues(alpha: 0.24),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width:76,
            child: Row(
              children: [
                _GroupCodeBadge(code: code ?? 'O', color: badgeColor),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLowest,
              borderRadius: AppRadius.borderRadiusFull,
            ),
            child: Text(
              '${members.length}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _OverflowMemberChips(members: members, color: color),
          ),
        ],
      ),
    );
  }
}

/// 멤버 칩을 한 줄로 배치하고, 넘치면 `+N` 버튼으로 펼치는 위젯.
class _OverflowMemberChips extends StatefulWidget {
  const _OverflowMemberChips({required this.members, required this.color});

  final List<ShiftMemberChipData> members;
  final Color color;

  @override
  State<_OverflowMemberChips> createState() => _OverflowMemberChipsState();
}

class _OverflowMemberChipsState extends State<_OverflowMemberChips> {
  static const double _spacing = AppSpacing.xs; // 칩 사이 간격
  static const double _maxNameWidth = 60; // 이름 최대 폭 (칩 내부)
  static const double _plusButtonWidth = 36; // +N / 접기 버튼 예약 폭

  bool _expanded = false;

  /// 단일 칩의 추정 폭 = 좌패딩4 + 아바타20 + 간격4 + 이름폭 + 우패딩7 + 보더2.
  double _chipWidth(ShiftMemberChipData m, TextStyle? style, TextScaler scaler) {
    final tp = TextPainter(
      text: TextSpan(text: m.displayName, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout();
    final textW = tp.width > _maxNameWidth ? _maxNameWidth : tp.width;
    return 4 + 20 + AppSpacing.xs + textW + 7 + 2;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nameStyle = theme.textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.w800,
    );
    final scaler = MediaQuery.textScalerOf(context);

    if (widget.members.isEmpty) return const SizedBox.shrink();

    if (_expanded) {
      // 접기 버튼은 행 맨 오른쪽에 고정, 칩은 왼쪽에서 줄바꿈.
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Wrap(
              spacing: _spacing,
              runSpacing: _spacing,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final m in widget.members)
                  _MemberChip(data: m, color: widget.color),
              ],
            ),
          ),
          const SizedBox(width: _spacing),
          _CollapseButton(
            color: widget.color,
            onTap: () => setState(() => _expanded = false),
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final widths = [
          for (final m in widget.members) _chipWidth(m, nameStyle, scaler),
        ];

        var count = 0;
        var used = 0.0;
        for (var i = 0; i < widths.length; i++) {
          final add = widths[i] + (count == 0 ? 0 : _spacing);
          if (used + add <= maxW) {
            used += add;
            count++;
          } else {
            break;
          }
        }

        // 전부 들어가면 그대로 한 줄.
        if (count >= widget.members.length) {
          return _chipRow(0, count, plus: null);
        }

        // 넘치면 +N 버튼 자리를 확보하기 위해 마지막 칩부터 줄인다.
        var needed = used + _spacing + _plusButtonWidth;
        while (count > 0 && needed > maxW) {
          used -= widths[count - 1] + (count == 1 ? 0 : _spacing);
          count--;
          needed = used + (count == 0 ? 0 : _spacing) + _plusButtonWidth;
        }
        final hidden = widget.members.length - count;
        return _chipRow(0, count, plus: hidden);
      },
    );
  }

  Widget _chipRow(int start, int end, {int? plus}) {
    final children = <Widget>[];
    for (var i = start; i < end; i++) {
      if (i > start) children.add(const SizedBox(width: _spacing));
      children.add(_MemberChip(data: widget.members[i], color: widget.color));
    }
    if (plus != null) {
      // +N 버튼은 행 맨 오른쪽에 고정 (이름 옆이 아니라 끝으로).
      children.add(const Spacer());
      children.add(
        _TogglePill(
          label: '+$plus',
          color: widget.color,
          onTap: () => setState(() => _expanded = true),
        ),
      );
    }
    return Row(children: children);
  }
}

/// 멤버 칩 — 아바타 + 이름.
class _MemberChip extends StatelessWidget {
  const _MemberChip({required this.data, required this.color});

  final ShiftMemberChipData data;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final highlighted = data.highlighted;

    final chip = Container(
      padding: const EdgeInsets.only(left: 4, right: 7, top: 3, bottom: 3),
      decoration: BoxDecoration(
        color: highlighted
            ? color.withValues(alpha: 0.18)
            : cs.surfaceContainerLowest,
        borderRadius: AppRadius.borderRadiusFull,
        border: Border.all(
          color: highlighted
              ? color.withValues(alpha: 0.35)
              : cs.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MemberAvatar(
            displayName: data.displayName,
            avatarUrl: data.avatarUrl,
            radius: 10,
          ),
          const SizedBox(width: AppSpacing.xs),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 60),
            child: Text(
              data.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: highlighted ? color : cs.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );

    if (data.onTap == null) return chip;
    return GestureDetector(onTap: data.onTap, child: chip);
  }
}

/// +N / 접기 버튼 (칩과 동일 높이의 알약 모양).
class _TogglePill extends StatelessWidget {
  const _TogglePill({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: AppRadius.borderRadiusFull,
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

/// 펼쳐진 상태에서 다시 접는 작은 아이콘 버튼 (위 화살표).
class _CollapseButton extends StatelessWidget {
  const _CollapseButton({required this.color, required this.onTap});

  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Icon(Icons.keyboard_arrow_up_rounded, size: 16, color: color),
      ),
    );
  }
}

class _GroupCodeBadge extends StatelessWidget {
  const _GroupCodeBadge({required this.code, required this.color});

  final String code;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 22,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: AppRadius.borderRadiusFull,
        border: Border.all(color: color.withValues(alpha: 0.42)),
      ),
      alignment: Alignment.center,
      child: Text(
        code,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _MemberAvatar extends StatelessWidget {
  const _MemberAvatar({
    required this.displayName,
    this.avatarUrl,
    this.radius = 16,
  });

  final String displayName;
  final String? avatarUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final initials = _initials(displayName);

    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: cs.primaryContainer,
        backgroundImage: NetworkImage(avatarUrl!),
        onBackgroundImageError: (_, __) {},
        child: null,
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: cs.primaryContainer,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: radius <= 12 ? 8 : 10,
          fontWeight: FontWeight.w700,
          color: cs.onPrimaryContainer,
        ),
      ),
    );
  }

  String _initials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    if (trimmed.length >= 2) {
      return trimmed.substring(0, 1).toUpperCase();
    }
    return trimmed.toUpperCase();
  }
}
