import 'package:flutter/material.dart';

abstract final class AppSpacing {
  // 4px grid system
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 48;
  static const double massive = 64;

  // Common paddings (more generous for warm bubbly feel)
  static const screenHorizontal = EdgeInsets.symmetric(horizontal: xxl);
  static const screenAll = EdgeInsets.all(xxl);
  static const cardPadding = EdgeInsets.all(xxl);
  static const sectionGap = SizedBox(height: xxxl);
}

abstract final class AppRadius {
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 40;
  static const double full = 999;

  static final borderRadiusSm = BorderRadius.circular(sm);
  static final borderRadiusMd = BorderRadius.circular(md);
  static final borderRadiusLg = BorderRadius.circular(lg);
  static final borderRadiusXl = BorderRadius.circular(xl);
  static final borderRadiusXxl = BorderRadius.circular(xxl);
  static final borderRadiusFull = BorderRadius.circular(full);
}

abstract final class AppSizing {
  static const double buttonHeight = 52;
  static const double inputHeight = 52;
  static const double iconSm = 20;
  static const double iconMd = 24;
  static const double iconLg = 32;
  static const double avatarSm = 32;
  static const double avatarMd = 44;
  static const double avatarLg = 56;
  static const double bottomNavHeight = 72;
}
