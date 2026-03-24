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
