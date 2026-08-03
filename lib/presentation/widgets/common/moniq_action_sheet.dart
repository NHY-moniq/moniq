import 'package:flutter/material.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/widgets/common/moniq_bottom_sheet.dart';

// ────────────────────────────────────────
// 액션 시트 (수정/삭제 등) — 카드 ⋯ 버튼용 공용 위젯
// date_items_panel의 검증된 패턴을 공용화한 것.
// ────────────────────────────────────────

class MoniqActionItem {
  const MoniqActionItem({
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

/// 카드 우측 ⋯ 버튼 — 탭하면 액션 바텀시트를 띄운다.
class MoniqCardActionButton extends StatelessWidget {
  const MoniqCardActionButton({
    super.key,
    required this.actions,
    this.title = '항목 옵션',
    this.iconSize = 18,
    this.iconAlpha = 1.0,
  });

  final List<MoniqActionItem> actions;
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
      onPressed: () => showMoniqActionSheet(
        context: context,
        title: title,
        actions: actions,
      ),
    );
  }
}

/// 액션 바텀시트 — 아이콘 칩 + 라벨 타일, destructive는 error 톤.
Future<void> showMoniqActionSheet({
  required BuildContext context,
  required String title,
  String eyebrow = 'ACTIONS',
  required List<MoniqActionItem> actions,
}) async {
  await showMoniqBottomSheet<void>(
    context: context,
    title: title,
    eyebrow: eyebrow,
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

  final MoniqActionItem action;

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
