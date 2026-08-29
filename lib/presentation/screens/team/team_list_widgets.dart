import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:moniq/core/utils/team_icon_utils.dart';
import 'package:moniq/data/models/team_model.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/theme/shift_theme.dart' show shiftFillOf;

/// 팀 목록 섹션 헤더 — 구분 라벨 + 개수 + 한 줄 안내.
///
/// 예전에는 화면 최상단에 즐겨찾기 설명 배너가 따로 있었는데,
/// 한 번 읽으면 되는 정보가 화면에서 가장 큰 요소가 되는 문제가 있었다.
/// 설명을 해당 섹션의 보조 캡션으로 내려 문맥과 붙이고 무게를 낮춘다.
class TeamListSectionHeader extends StatelessWidget {
  const TeamListSectionHeader({
    super.key,
    required this.label,
    required this.icon,
    required this.count,
    this.hint,
    this.hintIcon,
    this.emphasizeHint = false,
  });

  final String label;
  final IconData icon;
  final int count;

  /// 섹션 아래 한 줄 안내. 없으면 렌더링하지 않는다.
  final String? hint;
  final IconData? hintIcon;

  /// 아직 행동이 필요한 상태(예: 즐겨찾기 미설정)면 안내를 primary 톤으로 올린다.
  final bool emphasizeHint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final hintColor = emphasizeHint ? cs.onPrimaryContainer : cs.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: cs.onSurfaceVariant),
              const SizedBox(width: AppSpacing.sm),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // 영문 서브라벨(PUBLIC/PRIVATE) 대신 개수를 둔다.
              // 한글+영문이 겹치는 표기를 없애면서 정보량은 오히려 늘린다.
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 1,
                ),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh,
                  borderRadius: AppRadius.borderRadiusFull,
                ),
                child: Text(
                  '$count',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (hint != null)
            Padding(
              // 아이콘(16) + 간격(8)만큼 들여써 라벨과 왼쪽 축을 맞춘다.
              padding: const EdgeInsets.only(top: AppSpacing.xs, left: 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    hintIcon ?? Icons.info_outline_rounded,
                    size: 13,
                    color: hintColor.withValues(alpha: 0.85),
                  ),
                  const SizedBox(width: AppSpacing.xs + 1),
                  Expanded(
                    child: Text(
                      hint!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: hintColor,
                        height: 1.4,
                        fontWeight:
                            emphasizeHint ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 팀 목록의 한 행 — 스와이프로 설정/나가기, 탭으로 상세 진입.
class TeamListTile extends StatelessWidget {
  const TeamListTile({
    super.key,
    required this.index,
    required this.team,
    required this.isFavorite,
    required this.showDragHandle,
    required this.onFavorite,
    required this.onDetail,
    required this.onLeave,
  });

  final int index;
  final TeamModel team;
  final bool isFavorite;

  /// 항목이 하나뿐이면 재정렬할 대상이 없으므로 손잡이를 숨긴다.
  /// 액션이 하나만 남아 "무엇을 누르는 행인지"가 명확해진다.
  final bool showDragHandle;

  final VoidCallback onFavorite;
  final VoidCallback onDetail;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final description = team.description;
    final hasDesc = description != null && description.isNotEmpty;
    final isPersonal = team.teamType == 'personal';

    // 즐겨찾기 카드는 primaryContainer를 옅게 깔아 강조한다.
    // 시프트마다 primary가 통째로 바뀌므로 알파만 다르게 두고
    // 전경색은 항상 M3 짝(onPrimaryContainer)을 써 대비를 보장한다.
    final cardColor = isFavorite
        ? Color.alphaBlend(
            cs.primaryContainer.withValues(alpha: isDark ? 0.45 : 0.55),
            cs.surfaceContainerLow,
          )
        : cs.surfaceContainerLow;
    final borderColor = isFavorite
        ? cs.primary.withValues(alpha: isDark ? 0.5 : 0.35)
        : cs.outlineVariant.withValues(alpha: isDark ? 0.5 : 0.7);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: ClipRRect(
        // 카드와 슬라이드 액션의 모서리를 맞춰 둥근 느낌을 유지.
        borderRadius: AppRadius.borderRadiusLg,
        child: Slidable(
          endActionPane: ActionPane(
            motion: const BehindMotion(),
            extentRatio: 0.4,
            children: [
              SlidableAction(
                onPressed: (_) => onDetail(),
                backgroundColor: shiftFillOf(context).fill,
                foregroundColor: shiftFillOf(context).onFill,
                icon: Icons.settings_outlined,
                label: '설정',
              ),
              SlidableAction(
                onPressed: (_) => onLeave(),
                backgroundColor: cs.error,
                foregroundColor: cs.onError,
                icon: Icons.exit_to_app,
                label: '나가기',
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onDetail,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm + 2,
                  // 손잡이가 있으면 자체 터치 영역이 여백을 대신한다.
                  showDragHandle ? AppSpacing.xs : AppSpacing.md,
                  AppSpacing.sm + 2,
                ),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: AppRadius.borderRadiusLg,
                  border: Border.all(
                    color: borderColor,
                    width: isFavorite ? 1.4 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    // 아바타 — 은은한 링으로 입체감.
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: cs.outlineVariant.withValues(alpha: 0.5),
                        ),
                      ),
                      child: TeamProfileAvatar(icon: team.icon, radius: 22),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            team.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: cs.onSurface,
                            ),
                          ),
                          if (isFavorite || hasDesc) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Row(
                              children: [
                                // 별의 의미를 카드 안에서 바로 설명한다.
                                // 상단 안내 배너를 없앨 수 있었던 이유.
                                if (isFavorite) ...[
                                  const _FavoriteChip(),
                                  if (hasDesc)
                                    const SizedBox(width: AppSpacing.xs + 2),
                                ],
                                if (hasDesc)
                                  Expanded(
                                    child: Text(
                                      description,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: cs.onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    if (!isPersonal)
                      _FavoriteToggle(
                        isFavorite: isFavorite,
                        onTap: onFavorite,
                      ),
                    if (showDragHandle) ...[
                      const SizedBox(width: AppSpacing.xxs),
                      ReorderableDragStartListener(
                        index: index,
                        child: Semantics(
                          label: '순서 변경 손잡이',
                          child: SizedBox(
                            width: 32,
                            height: 40,
                            child: Icon(
                              Icons.drag_indicator_rounded,
                              size: 18,
                              color: cs.outline.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 즐겨찾기 토글 — 채워진 원형 버튼으로 "누를 수 있는 것"임을 분명히 한다.
///
/// 예전에는 별과 드래그 손잡이가 같은 무게의 맨 아이콘으로 나란히 있어
/// 무엇이 탭 대상인지 모호했다. 별만 버튼 형태로 올리고 손잡이는
/// 대비를 낮춰 역할을 분리한다.
class _FavoriteToggle extends StatelessWidget {
  const _FavoriteToggle({required this.isFavorite, required this.onTap});

  final bool isFavorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: isFavorite,
      label: isFavorite ? '캘린더 기본 팀 해제' : '캘린더 기본 팀으로 설정',
      child: Material(
        // 시프트가 바뀌어도 대비가 유지되는 M3 짝(container/onContainer) 사용.
        color: isFavorite ? cs.primaryContainer : cs.surfaceContainerHigh,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            // 44px에 가까운 터치 영역 — 별이 실제로 누를 수 있는 크기여야 한다.
            width: 40,
            height: 40,
            child: Icon(
              isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
              size: 20,
              color: isFavorite ? cs.onPrimaryContainer : cs.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// 즐겨찾기 팀임을 설명하는 마이크로 칩.
class _FavoriteChip extends StatelessWidget {
  const _FavoriteChip();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 1,
      ),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: AppRadius.borderRadiusFull,
      ),
      child: Text(
        '캘린더 기본',
        style: theme.textTheme.labelSmall?.copyWith(
          color: cs.onPrimaryContainer,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// 목록 끝의 팀 추가 유도 행.
///
/// 팀이 한두 개면 아래가 통째로 비어 화면이 휑했다. 앱바의 + 버튼과
/// 같은 시트를 여는 어포던스를 목록 끝에 두어 여백에 목적을 준다.
class TeamListAddTile extends StatelessWidget {
  const TeamListAddTile({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.borderRadiusLg,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.borderRadiusLg,
          child: Ink(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              borderRadius: AppRadius.borderRadiusLg,
              // 채워진 팀 카드와 구분되도록 배경 없이 테두리만 둔다.
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: isDark ? 0.5 : 0.8),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cs.surfaceContainerHigh,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.add_rounded,
                    size: 20,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '팀 추가하기',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        '새로 만들거나 초대 코드로 참여해요',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
