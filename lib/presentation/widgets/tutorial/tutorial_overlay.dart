import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'tutorial_controller.dart';
import 'tutorial_step.dart';

/// 튜토리얼 스포트라이트 오버레이.
///
/// 단계가 바뀌면 (1) 대상 위젯이 화면에 들어오도록 먼저 스크롤하고,
/// (2) 스크롤이 끝난 뒤 위치를 재고, (3) 설명 카드의 **실제 높이**를 재서
/// 화면(세이프 영역) 안에 들어가도록 위/아래를 고른다.
/// 예전에는 카드 높이를 180으로 가정하고 배치해, 문구가 길거나 대상이
/// 화면 아래쪽이면 카드와 하이라이트가 잘렸다.
class TutorialOverlayWidget extends StatefulWidget {
  const TutorialOverlayWidget({super.key, required this.controller});

  final TutorialController controller;

  @override
  State<TutorialOverlayWidget> createState() => _TutorialOverlayWidgetState();
}

class _TutorialOverlayWidgetState extends State<TutorialOverlayWidget> {
  /// 대상 위젯의 화면 좌표. null이면 아직 준비 중(스크롤/측정).
  Rect? _targetRect;
  int _lastIndex = -1;

  final _cardKey = GlobalKey();

  /// 설명 카드의 실측 높이. 첫 프레임은 추정치로 그리고 바로 보정한다.
  double _cardHeight = 180;

  static const _gap = 14.0;
  static const _cardMarginH = 16.0;

  @override
  void initState() {
    super.initState();
    _prepareStep();
  }

  @override
  void didUpdateWidget(TutorialOverlayWidget old) {
    super.didUpdateWidget(old);
    if (widget.controller.currentIndex != _lastIndex) _prepareStep();
  }

  /// 대상이 화면 밖이면 스크롤해서 들여온 뒤 위치를 잰다.
  Future<void> _prepareStep() async {
    final index = widget.controller.currentIndex;
    _lastIndex = index;
    if (_targetRect != null) setState(() => _targetRect = null);

    final targetContext = widget.controller.steps[index].key.currentContext;
    if (targetContext != null && Scrollable.maybeOf(targetContext) != null) {
      // alignment 0.25 — 대상을 화면 위쪽 1/4 지점에 두어 아래에 카드 자리를 남긴다.
      await Scrollable.ensureVisible(
        targetContext,
        alignment: 0.25,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
    if (!mounted) return;
    _scheduleRectUpdate();
  }

  void _scheduleRectUpdate({int retryCount = 0}) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final step = widget.controller.current;
      final rect = _rectFromKey(step.key);
      if (rect != null) {
        setState(() => _targetRect = rect);
      } else if (retryCount < 10) {
        // 위젯이 아직 레이아웃되지 않았으면 다음 프레임에 재시도
        _scheduleRectUpdate(retryCount: retryCount + 1);
      }
    });
  }

  Rect? _rectFromKey(GlobalKey key) {
    final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return null;
    return renderBox.localToGlobal(Offset.zero) & renderBox.size;
  }

  /// 그려진 카드의 실제 높이를 반영 (문구 길이에 따라 달라진다).
  void _measureCard() {
    final box = _cardKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    if ((box.size.height - _cardHeight).abs() < 1) return;
    setState(() => _cardHeight = box.size.height);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final target = _targetRect;
    // 스크롤/측정이 끝나기 전에는 그리지 않는다 — 엉뚱한 위치에 잠깐 뜨는 걸 방지.
    if (target == null) return const SizedBox.shrink();

    SchedulerBinding.instance.addPostFrameCallback((_) => _measureCard());

    final media = MediaQuery.of(context);
    final safeTop = media.padding.top + 8;
    final safeBottom = media.size.height - media.padding.bottom - 8;
    final maxCardHeight = safeBottom - safeTop;
    final cardHeight = _cardHeight.clamp(0.0, maxCardHeight);

    // 아래 → 위 순으로 들어갈 자리를 찾고, 둘 다 안 되면 화면 안으로 밀어 넣는다.
    final belowTop = target.bottom + _gap;
    final aboveTop = target.top - _gap - cardHeight;
    final fitsBelow = belowTop + cardHeight <= safeBottom;
    final fitsAbove = aboveTop >= safeTop;

    final double cardTop;
    if (controller.current.preferBelow && fitsBelow) {
      cardTop = belowTop;
    } else if (fitsAbove) {
      cardTop = aboveTop;
    } else if (fitsBelow) {
      cardTop = belowTop;
    } else {
      cardTop = (safeBottom - cardHeight).clamp(safeTop, safeBottom);
    }

    final isLast = controller.currentIndex == controller.total - 1;

    return Stack(
      children: [
        // Scrim + spotlight
        Positioned.fill(
          child: GestureDetector(
            onTap: controller.next,
            child: CustomPaint(
              painter: _SpotlightPainter(targetRect: target),
            ),
          ),
        ),

        // 설명 카드
        Positioned(
          left: _cardMarginH,
          right: _cardMarginH,
          top: cardTop,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxCardHeight),
            child: _TutorialCard(
              key: _cardKey,
              step: controller.current,
              currentIndex: controller.currentIndex,
              total: controller.total,
              isLast: isLast,
              onNext: controller.next,
              onDismiss: () => controller.dismiss(),
            ),
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

  /// 하이라이트 구멍의 모서리 반경 — 메뉴 카드와 같은 둥근 톤.
  static const _radius = Radius.circular(20);

  @override
  void paint(Canvas canvas, Size size) {
    final hole = RRect.fromRectAndRadius(targetRect.inflate(6), _radius);

    // 화면 전체에서 하이라이트 영역만 도려낸 어두운 막.
    // 사각형 4장을 따로 그리면 모서리가 각져 보여서 path 차집합으로 판다.
    final scrim = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()..addRRect(hole),
    );
    canvas.drawPath(scrim, Paint()..color = const Color(0xCC000000));

    // 타깃 테두리 (흰 반투명 outline)
    canvas.drawRRect(
      hole,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.32)
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
    super.key,
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
      borderRadius: BorderRadius.circular(20),
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

            // 메시지 — 문구가 길어도 카드가 화면을 넘지 않도록 내부 스크롤.
            Flexible(
              child: SingleChildScrollView(
                child: Text(
                  step.message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
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
