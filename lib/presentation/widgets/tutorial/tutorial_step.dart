import 'package:flutter/material.dart';

class TutorialStep {
  const TutorialStep({
    required this.key,
    required this.title,
    required this.message,
    this.preferBelow = true,
  });

  final GlobalKey key;
  final String title;
  final String message;

  /// 말풍선을 타깃 아래에 표시할지
  final bool preferBelow;
}
