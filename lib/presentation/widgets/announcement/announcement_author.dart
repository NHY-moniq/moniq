import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/theme/app_typography.dart';

/// 공지/게시글 작성자 한 줄 표시 (아바타 + 이름).
///
/// 카드, 익명 게시판, 상세 페이지에서 공용으로 쓴다. 작성자 정보가
/// 아직 확인되지 않았으면 placeholder 이름을 노출한다.
class AnnouncementAuthor extends StatelessWidget {
  const AnnouncementAuthor({
    super.key,
    required this.name,
    this.avatarUrl,
    this.trailing,
    this.avatarRadius = 12,
    this.dense = false,
  });

  final String name;
  final String? avatarUrl;
  final Widget? trailing;
  final double avatarRadius;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final initial = name.trim().isNotEmpty ? name.trim()[0] : '?';

    return Row(
      children: [
        AuthorAvatar(
          name: name,
          avatarUrl: avatarUrl,
          radius: avatarRadius,
          initial: initial,
        ),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            name,
            style: (dense
                    ? AppTypography.captionSmall
                    : AppTypography.caption)
                .copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: AppSpacing.sm),
          trailing!,
        ],
      ],
    );
  }
}

/// 작성자 아바타 — 원격 이미지 우선, 실패/없음 시 이니셜 폴백.
class AuthorAvatar extends StatelessWidget {
  const AuthorAvatar({
    super.key,
    required this.name,
    required this.initial,
    this.avatarUrl,
    this.radius = 12,
  });

  final String name;
  final String initial;
  final String? avatarUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fallbackColor = cs.primary.withValues(alpha: 0.15);

    Widget initialBadge() => CircleAvatar(
          radius: radius,
          backgroundColor: fallbackColor,
          child: Text(
            initial,
            style: TextStyle(
              fontSize: radius * 0.8,
              fontWeight: FontWeight.w800,
              color: cs.primary,
            ),
          ),
        );

    final url = avatarUrl;
    if (url == null || url.isEmpty) {
      return initialBadge();
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        placeholder: (_, __) => initialBadge(),
        errorWidget: (_, __, ___) => initialBadge(),
      ),
    );
  }
}
