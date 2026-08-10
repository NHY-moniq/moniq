import 'package:flutter/material.dart';

Color parseHexColor(String hex) {
  final buffer = StringBuffer();
  if (hex.length == 6 || hex.length == 7) buffer.write('FF');
  buffer.write(hex.replaceFirst('#', ''));
  return Color(int.parse(buffer.toString(), radix: 16));
}

/// 밝은 배경 위에서 글자색으로 쓰기에 너무 옅은 색을 읽을 수 있게 어둡게 만든다.
///
/// 근무 유형 색은 "칠하는 색"(칩·박스 배경)이자 "글자색"으로 함께 쓰이는데,
/// 오프(#D5EBFF)처럼 파스텔 톤을 그대로 글자에 쓰면 흰 배경에서 보이지 않는다.
/// 색조(hue)와 채도는 유지한 채 명도만 [maxLightness] 이하로 낮춘다.
Color readableInk(Color color, {double maxLightness = 0.45}) {
  final hsl = HSLColor.fromColor(color);
  if (hsl.lightness <= maxLightness) return color;
  // 파스텔(밝고 옅은) 톤은 명도만 낮추면 탁해지므로 채도를 함께 올려 색을 살린다.
  final saturation = hsl.saturation < 0.5
      ? (hsl.saturation + 0.35).clamp(0.0, 1.0)
      : hsl.saturation;
  return hsl.withLightness(maxLightness).withSaturation(saturation).toColor();
}
