import 'package:flutter/material.dart';
import 'package:moniq/presentation/theme/app_colors.dart';

/// OnorOff 캐릭터 타입
enum CharacterType {
  /// 노랑이 — Day 근무, 즐겨찾기, 휴식
  yellow,

  /// 주황이 — Evening 근무, 활동 중
  orange,

  /// 파랑이 — Night 근무, 탐험
  blue,
}

/// OnorOff 캐릭터 blob 위젯.
/// 로고의 동글동글 캐릭터를 코드로 재현 (컬러 원 + 눈).
class CharacterBlob extends StatelessWidget {
  const CharacterBlob({
    super.key,
    required this.type,
    this.size = 44,
    this.showEyes = true,
  });

  final CharacterType type;
  final double size;
  final bool showEyes;

  Color get _color => switch (type) {
        CharacterType.yellow => AppColors.brandYellow,
        CharacterType.orange => AppColors.brandOrange,
        CharacterType.blue => AppColors.brandBlue,
      };

  Color get _shadowColor => switch (type) {
        CharacterType.yellow => AppColors.primary,
        CharacterType.orange => AppColors.secondary,
        CharacterType.blue => AppColors.tertiary,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.3, -0.3),
          radius: 0.8,
          colors: [
            _color,
            _color.withValues(alpha: 0.85),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: _shadowColor.withValues(alpha: 0.25),
            blurRadius: size * 0.3,
            offset: Offset(0, size * 0.1),
          ),
        ],
      ),
      child: showEyes
          ? CustomPaint(
              painter: _EyesPainter(size: size),
            )
          : null,
    );
  }
}

class _EyesPainter extends CustomPainter {
  _EyesPainter({required this.size});

  final double size;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final eyePaint = Paint()
      ..color = const Color(0xFF2A2A2A)
      ..style = PaintingStyle.fill;

    final eyeRadius = size * 0.06;
    final eyeY = size * 0.42;
    final eyeSpacing = size * 0.12;
    final centerX = size / 2;

    // Left eye
    canvas.drawCircle(
      Offset(centerX - eyeSpacing, eyeY),
      eyeRadius,
      eyePaint,
    );
    // Right eye
    canvas.drawCircle(
      Offset(centerX + eyeSpacing, eyeY),
      eyeRadius,
      eyePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 3캐릭터 그룹 (로고 스타일)
class CharacterGroup extends StatelessWidget {
  const CharacterGroup({
    super.key,
    this.size = 32,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    final overlap = size * 0.3;
    return SizedBox(
      width: size * 3 - overlap * 2,
      height: size,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            child: CharacterBlob(
              type: CharacterType.yellow,
              size: size,
            ),
          ),
          Positioned(
            left: size - overlap,
            child: CharacterBlob(
              type: CharacterType.orange,
              size: size,
            ),
          ),
          Positioned(
            left: (size - overlap) * 2,
            child: CharacterBlob(
              type: CharacterType.blue,
              size: size,
            ),
          ),
        ],
      ),
    );
  }
}

/// 근무 타입에 매핑되는 캐릭터 도트
class ShiftCharacterDot extends StatelessWidget {
  const ShiftCharacterDot({
    super.key,
    required this.color,
    this.size = 8,
  });

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 2,
          ),
        ],
      ),
    );
  }
}
