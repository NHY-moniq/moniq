import 'package:flutter/material.dart';
import 'package:moniq/presentation/theme/app_colors.dart';

/// OnorOff 캐릭터 타입
enum CharacterType {
  /// 노랑이 — Day 근무
  yellow,

  /// 주황이 — Evening 근무
  orange,

  /// 파랑이 — Night 근무
  blue,

  /// 회색 — Off / 휴무
  grey,

  /// 초록이
  green,

  /// 분홍이
  pink,

  /// 보라
  purple,

  /// 코랄(빨강/주홍)
  coral,
}

/// OnorOff 캐릭터 blob 위젯.
/// 로고의 동글동글 캐릭터를 코드로 재현 (컬러 원 + 눈).
class CharacterBlob extends StatelessWidget {
  const CharacterBlob({
    super.key,
    required this.type,
    this.size = 44,
    this.showEyes = true,
    this.sleeping = false,
  });

  final CharacterType type;
  final double size;
  final bool showEyes;
  final bool sleeping;

  Color get _color => switch (type) {
        CharacterType.yellow => AppColors.brandYellow,
        CharacterType.orange => AppColors.brandOrange,
        CharacterType.blue => AppColors.brandBlue,
        CharacterType.grey => AppColors.shiftOff,
        CharacterType.green => const Color(0xFF81C784),
        CharacterType.pink => const Color(0xFFF48FB1),
        CharacterType.purple => const Color(0xFFB39DDB),
        CharacterType.coral => const Color(0xFFFF8A65),
      };

  Color get _shadowColor => switch (type) {
        CharacterType.yellow => AppColors.primary,
        CharacterType.orange => AppColors.secondary,
        CharacterType.blue => AppColors.tertiary,
        CharacterType.grey => AppColors.outline,
        CharacterType.green => const Color(0xFF4CAF50),
        CharacterType.pink => const Color(0xFFE91E63),
        CharacterType.purple => const Color(0xFF7E57C2),
        CharacterType.coral => const Color(0xFFFF5722),
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
              painter: sleeping
                  ? _SleepingEyesPainter(size: size)
                  : _EyesPainter(size: size),
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

/// 잠자는 눈 (─ ─) 스타일
class _SleepingEyesPainter extends CustomPainter {
  _SleepingEyesPainter({required this.size});

  final double size;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final eyePaint = Paint()
      ..color = const Color(0xFF2A2A2A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.03
      ..strokeCap = StrokeCap.round;

    final eyeY = size * 0.44;
    final eyeSpacing = size * 0.12;
    final eyeWidth = size * 0.06;
    final centerX = size / 2;

    // Left eye (─)
    canvas.drawLine(
      Offset(centerX - eyeSpacing - eyeWidth, eyeY),
      Offset(centerX - eyeSpacing + eyeWidth, eyeY),
      eyePaint,
    );
    // Right eye (─)
    canvas.drawLine(
      Offset(centerX + eyeSpacing - eyeWidth, eyeY),
      Offset(centerX + eyeSpacing + eyeWidth, eyeY),
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

/// 근무 컬러 → 캐릭터 타입 매핑.
/// Day 계열(노란/amber) → yellow, Evening 계열(주황/orange) → orange,
/// Night 계열(파랑/blue) → blue, 나머지(off/grey) → grey.
CharacterType characterTypeFromColor(Color color) {
  final hue = HSLColor.fromColor(color).hue;
  final saturation = HSLColor.fromColor(color).saturation;

  // 무채색(off)
  if (saturation < 0.15) return CharacterType.grey;

  // 브랜드 컬러 직접 비교 (최우선)
  final argb = color.toARGB32();
  if (argb == AppColors.shiftDay.toARGB32() ||
      argb == AppColors.brandYellow.toARGB32()) {
    return CharacterType.yellow;
  }
  if (argb == AppColors.shiftEvening.toARGB32() ||
      argb == AppColors.brandOrange.toARGB32()) {
    return CharacterType.orange;
  }
  if (argb == AppColors.shiftNight.toARGB32() ||
      argb == AppColors.brandBlue.toARGB32()) {
    return CharacterType.blue;
  }

  // hue 기반 분류 (fallback)
  if (hue >= 43 && hue < 70) return CharacterType.yellow;    // Day (노란)
  if (hue >= 15 && hue < 43) return CharacterType.orange;    // Evening (주황)
  if (hue >= 190 && hue < 260) return CharacterType.blue;    // Night (파란)
  if (hue >= 80 && hue < 170) return CharacterType.green;    // 초록
  if (hue >= 0 && hue < 15) return CharacterType.coral;      // 코랄/주홍
  if (hue >= 330 && hue <= 360) return CharacterType.pink;   // 분홍
  if (hue >= 260 && hue < 330) return CharacterType.purple;  // 보라

  return CharacterType.grey;
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
