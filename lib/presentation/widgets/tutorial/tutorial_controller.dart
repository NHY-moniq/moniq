import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'tutorial_overlay.dart';
import 'tutorial_step.dart';

class TutorialController {
  TutorialController({required this.steps, this.onComplete});

  final List<TutorialStep> steps;
  final VoidCallback? onComplete;

  int _index = 0;
  OverlayEntry? _entry;

  bool get isActive => _entry != null;
  int get currentIndex => _index;
  int get total => steps.length;
  TutorialStep get current => steps[_index];

  void start(BuildContext context) {
    _index = 0;
    _insertOverlay(context);
  }

  void next() {
    if (_index < steps.length - 1) {
      _index++;
      _entry?.markNeedsBuild();
    } else {
      dismiss(completed: true);
    }
  }

  void dismiss({bool completed = false}) {
    _entry?.remove();
    _entry = null;
    if (completed) onComplete?.call();
  }

  void _insertOverlay(BuildContext context) {
    final overlay = Overlay.of(context);
    _entry = OverlayEntry(
      builder: (_) => TutorialOverlayWidget(controller: this),
    );
    // postFrame으로 insert해야 위젯이 렌더된 뒤 위치를 가져올 수 있음
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_entry != null) overlay.insert(_entry!);
    });
  }

  void dispose() {
    _entry?.remove();
    _entry = null;
  }
}
