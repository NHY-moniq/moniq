import 'package:flutter/material.dart';

/// 1024px 이상을 웹/와이드 레이아웃으로 간주한다.
/// 768px는 가로 모드 스마트폰이 걸려 웹 레이아웃이 의도치 않게 활성화되므로
/// 1024px(일반적인 태블릿/노트북 기준)로 상향 조정.
const double kWebBreakpoint = 1024;

/// 화면 너비에 따라 모바일 / 웹 위젯을 전환하는 레이아웃 헬퍼.
///
/// ```dart
/// AdaptiveLayout(
///   mobile: MobileView(),
///   web: WebView(),
/// )
/// ```
class AdaptiveLayout extends StatelessWidget {
  const AdaptiveLayout({
    super.key,
    required this.mobile,
    required this.web,
  });

  final Widget mobile;
  final Widget web;

  /// 현재 컨텍스트가 웹/와이드 레이아웃인지 여부.
  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= kWebBreakpoint;

  @override
  Widget build(BuildContext context) =>
      isWide(context) ? web : mobile;
}

/// 단일 위젯에 웹 전용 max-width 제약을 적용한다.
/// 폼/설정 화면 등에서 콘텐츠가 과도하게 늘어나지 않도록 중앙 정렬.
class MaxWidthLayout extends StatelessWidget {
  const MaxWidthLayout({
    super.key,
    required this.child,
    this.maxWidth = 640,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    if (!AdaptiveLayout.isWide(context)) return child;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
