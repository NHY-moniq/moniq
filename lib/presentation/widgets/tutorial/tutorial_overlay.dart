import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'tutorial_controller.dart';
import 'tutorial_step.dart';

class TutorialOverlayWidget extends StatefulWidget {
  const TutorialOverlayWidget({super.key, required this.controller});

  final TutorialController controller;

  @override
  State<TutorialOverlayWidget> createState() => _TutorialOverlayWidgetState();
}

class _TutorialOverlayWidgetState extends State<TutorialOverlayWidget> {
  Rect _targetRect = Rect.zero;
  int _lastIndex = -1;

  @override
  void initState() {
    super.initState();
    _scheduleRectUpdate();
  }

  @override
  void didUpdateWidget(TutorialOverlayWidget old) {
    super.didUpdateWidget(old);
    final idx = widget.controller.currentIndex;
    if (idx != _lastIndex) {
      setState(() => _targetRect = Rect.zero);
      _scheduleRectUpdate();
    }
  }

  void _scheduleRectUpdate({int retryCount = 0}) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final idx = widget.controller.currentIndex;
      final step = widget.controller.steps[idx];
      final rect = _rectFromKey(step.key);
      if (rect != null) {
        setState(() {
          _targetRect = rect;
          _lastIndex = idx;
        });
      } else if (retryCount < 10) {
        // 위젯이 아직 레이아웃되지 않았으면 다음 프레임에 재시도
        _scheduleRectUpdate(retryCount: retryCount + 1);
      }
    });
  }

  Rect? _rectFromKey(GlobalKey key) {
    final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return null;
    final offset = renderBox.localToGlobal(Offset.zero);
    return offset & renderBox.size;
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    // 아직 rect 계산 중
    if (_targetRect == Rect.zero) return const SizedBox.shrink();

    final step = controller.current;
    final size = MediaQuery.sizeOf(context);
    final screenHeight = size.height;
    const cardHeight = 180.0;
    const cardMarginH = 16.0;

    final spaceBelow = screenHeight - _targetRect.bottom - 16;
    final showAbove = !step.preferBelow || spaceBelow < 220;
    final cardTop = showAbove
        ? (_targetRect.top - cardHeight - 16)
            .clamp(8.0, screenHeight - cardHeight - 8)
        : _targetRect.bottom + 16;

    final isLast = controller.currentIndex == controller.total - 1;

    return Stack(
      children: [
        // Scrim + spotlight
        Positioned.fill(
          child: GestureDetector(
            onTap: controller.next,
            child: CustomPaint(
              painter: _SpotlightPainter(targetRect: _targetRect),
            ),
          ),
        ),

        // 말풍선 카드
        Positioned(
          left: cardMarginH,
          right: cardMarginH,
          top: cardTop,
          child: _TutorialCard(
            step: step,
            currentIndex: controller.currentIndex,
            total: controller.total,
            isLast: isLast,
            onNext: controller.next,
            onDismiss: () => controller.dismiss(),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Spotlight Painter
// ---------------------------------------------------------------------------

class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter({required this.targetRect});

  final Rect targetRect;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xCC000000);
    final r = targetRect;

    // Top
    canvas.drawRect(Rect.fromLTRB(0, 0, size.width, r.top), paint);
    // Left
    canvas.drawRect(Rect.fromLTRB(0, r.top, r.left, r.bottom), paint);
    // Right
    canvas.drawRect(
      Rect.fromLTRB(r.right, r.top, size.width, r.bottom),
      paint,
    );
    // Bottom
    canvas.drawRect(
      Rect.fromLTRB(0, r.bottom, size.width, size.height),
      paint,
    );

    // 타깃 테두리 (흰 반투명 outline)
    canvas.drawRRect(
      RRect.fromRectAndRadius(r.inflate(4), const Radius.circular(14)),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) => old.targetRect != targetRect;
}

// ---------------------------------------------------------------------------
// Tutorial Card
// ---------------------------------------------------------------------------

class _TutorialCard extends StatelessWidget {
  const _TutorialCard({
    required this.step,
    required this.currentIndex,
    required this.total,
    required this.isLast,
    required this.onNext,
    required this.onDismiss,
  });

  final TutorialStep step;
  final int currentIndex;
  final int total;
  final bool isLast;
  final VoidCallback onNext;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      color: colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 제목 + 단계 표시
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text('💡', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    step.title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${currentIndex + 1} / $total',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // 메시지
            Text(
              step.message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 16),

            // 버튼 행
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: onDismiss,
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.onSurfaceVariant,
                  ),
                  child: const Text('건너뛰기'),
                ),
                FilledButton(
                  onPressed: onNext,
                  child: Text(isLast ? '완료' : '다음 →'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
