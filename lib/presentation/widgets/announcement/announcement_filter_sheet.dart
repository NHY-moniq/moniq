import 'package:flutter/material.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/theme/app_typography.dart';
import 'package:moniq/presentation/widgets/common/moniq_bottom_sheet.dart';

/// 공지사항 화면 공용 필터 옵션.
///
/// 셀렉터 한 줄(칩 형태)로 노출하고, 탭하면 [showAnnouncementFilterSheet]
/// 가 [MoniqBottomSheet]를 띄워 옵션을 고르게 한다.
class AnnouncementFilterOption<T> {
  const AnnouncementFilterOption({
    required this.value,
    required this.label,
    this.icon,
  });

  final T value;
  final String label;
  final IconData? icon;
}

/// 모달 바텀시트로 필터 옵션을 고른다.
///
/// 선택 시 해당 값을, 닫기만 하면 `null`을 반환한다. 호출부는
/// `null`(취소)과 "전체"(값이 `null`인 옵션)를 구분해야 하므로
/// 옵션 값에 nullable을 직접 쓰지 말고 sentinel을 사용한다.
Future<AnnouncementFilterOption<T>?> showAnnouncementFilterSheet<T>({
  required BuildContext context,
  required String title,
  required List<AnnouncementFilterOption<T>> options,
  required T selectedValue,
}) {
  return showMoniqBottomSheet<AnnouncementFilterOption<T>>(
    context: context,
    title: title,
    eyebrow: 'FILTER',
    child: _AnnouncementFilterSheetBody<T>(
      options: options,
      selectedValue: selectedValue,
    ),
  );
}

class _AnnouncementFilterSheetBody<T> extends StatelessWidget {
  const _AnnouncementFilterSheetBody({
    required this.options,
    required this.selectedValue,
  });

  final List<AnnouncementFilterOption<T>> options;
  final T selectedValue;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final option in options)
          _FilterOptionRow<T>(
            option: option,
            selected: option.value == selectedValue,
            accent: cs.primary,
            onTap: () => Navigator.pop(context, option),
          ),
      ],
    );
  }
}

class _FilterOptionRow<T> extends StatelessWidget {
  const _FilterOptionRow({
    required this.option,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final AnnouncementFilterOption<T> option;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.borderRadiusLg,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.lg,
          ),
          child: Row(
            children: [
              if (option.icon != null) ...[
                Icon(
                  option.icon,
                  size: 20,
                  color: selected ? accent : cs.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(
                child: Text(
                  option.label,
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight:
                        selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? cs.onSurface : cs.onSurfaceVariant,
                  ),
                ),
              ),
              if (selected)
                Icon(
                  Icons.check_rounded,
                  size: 20,
                  color: accent,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 바텀시트 필터를 여는 칩 형태의 셀렉터.
///
/// 기존 `DropdownButton`/`PopupMenuButton` UI를 대체한다.
class AnnouncementFilterChip extends StatelessWidget {
  const AnnouncementFilterChip({
    super.key,
    required this.label,
    required this.onTap,
    this.icon = Icons.tune_rounded,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.borderRadiusFull,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: AppRadius.borderRadiusFull,
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: cs.onSurfaceVariant),
              const SizedBox(width: AppSpacing.xs),
              Text(
                label,
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.expand_more_rounded,
                size: 16,
                color: cs.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
