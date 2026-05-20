import 'package:flutter/material.dart';
import 'package:moniq/core/utils/color_utils.dart';

/// 팀 아이콘 형식:
/// - 이모지+색상: "🏥|#5A8BB5"
/// - 이미지 URL: "image|https://..."
/// - 레거시: "groups", "local_hospital" 등

const defaultEmoji = '🏥';

const teamColors = [
  '#5A8BB5', // blue
  '#48BB78', // green
  '#ED64A6', // pink
  '#F0C040', // yellow
  '#E8923A', // orange
  '#9F7AEA', // purple
  '#ED8936', // amber
  '#A0AEC0', // gray
  '#FC8181', // red
  '#63B3ED', // light blue
  '#68D391', // light green
  '#B794F4', // light purple
];

class TeamIconData {
  const TeamIconData({
    this.emoji,
    required this.color,
    this.imageUrl,
  });

  final String? emoji;
  final String color;
  final String? imageUrl;

  bool get isImage => imageUrl != null && imageUrl!.isNotEmpty;

  String encode() {
    if (isImage) return 'image|$imageUrl';
    return '${emoji ?? defaultEmoji}|$color';
  }

  static TeamIconData decode(String? icon) {
    if (icon == null || icon.isEmpty) {
      return const TeamIconData(
        emoji: defaultEmoji,
        color: '#5A8BB5',
      );
    }

    // 이미지 형식: "image|url"
    if (icon.startsWith('image|')) {
      return TeamIconData(
        color: '#5A8BB5',
        imageUrl: icon.substring(6),
      );
    }

    // 새 형식: "emoji|#color"
    if (icon.contains('|')) {
      final parts = icon.split('|');
      return TeamIconData(
        emoji: parts[0],
        color: parts.length > 1 ? parts[1] : '#5A8BB5',
      );
    }

    // 레거시: Material 아이콘 이름
    return TeamIconData(
      emoji: _legacyIconToEmoji(icon),
      color: '#5A8BB5',
    );
  }
}

String _legacyIconToEmoji(String iconName) {
  switch (iconName) {
    case 'local_hospital':
      return '🏥';
    case 'business':
      return '🏢';
    case 'school':
      return '📋';
    case 'store':
      return '⭐';
    case 'engineering':
      return '👩‍⚕️';
    case 'groups':
    default:
      return '👥';
  }
}

/// 팀 프로필이 비어있거나 사용자가 아무것도 지정하지 않은 기본 상태인지.
/// 이 경우엔 moniq 마스코트(off.png)를 표시한다.
bool _isUnsetIcon(String? icon) {
  if (icon == null || icon.isEmpty) return true;
  // 신규 폼 기본값 ('🏥' + 첫 번째 색)
  if (icon == '$defaultEmoji|#5A8BB5') return true;
  // 레거시 Material 아이콘 이름들 — 직접 emoji를 고른 게 아니어서 기본 취급.
  const legacyPlaceholders = {
    'groups',
    'local_hospital',
    'business',
    'school',
    'store',
    'engineering',
  };
  if (legacyPlaceholders.contains(icon)) return true;
  return false;
}

/// 팀 프로필 아바타 위젯
class TeamProfileAvatar extends StatelessWidget {
  const TeamProfileAvatar({
    super.key,
    required this.icon,
    this.radius = 28,
  });

  final String? icon;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // 아이콘 미지정 → moniq 마스코트
    if (_isUnsetIcon(icon)) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: cs.surfaceContainerHigh,
        child: ClipOval(
          child: Padding(
            padding: EdgeInsets.all(radius * 0.18),
            child: Image.asset(
              'assets/images/off.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
      );
    }

    final data = TeamIconData.decode(icon);

    if (data.isImage) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(data.imageUrl!),
        backgroundColor: Colors.grey.withValues(alpha: 0.2),
      );
    }

    final bgColor = parseHexColor(data.color);
    return CircleAvatar(
      radius: radius,
      backgroundColor: bgColor.withValues(alpha: 0.25),
      child: Text(
        data.emoji ?? defaultEmoji,
        style: TextStyle(fontSize: radius * 0.75),
      ),
    );
  }
}
