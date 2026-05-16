import 'dart:async';

import 'package:flutter/material.dart';

class MoniqLoadingView extends StatefulWidget {
  const MoniqLoadingView({super.key, this.message, this.size = 112});

  final String? message;
  final double size;

  @override
  State<MoniqLoadingView> createState() => _MoniqLoadingViewState();
}

class _MoniqLoadingViewState extends State<MoniqLoadingView> {
  static const int _frameCount = 121;
  static const Duration _frameInterval = Duration(milliseconds: 70);

  static final List<String> _frameAssets = List.generate(
    _frameCount,
    (i) =>
        'assets/images/loading/frame_${(i + 1).toString().padLeft(3, '0')}.png',
  );

  int _frameIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_frameInterval, (_) {
      if (!mounted) return;
      setState(() {
        _frameIndex = (_frameIndex + 1) % _frameAssets.length;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: widget.size,
            height: widget.size,
            child: Image.asset(
              _frameAssets[_frameIndex],
              fit: BoxFit.contain,
              gaplessPlayback: true,
              filterQuality: FilterQuality.medium,
              errorBuilder: (context, error, stackTrace) {
                return const Center(child: CircularProgressIndicator());
              },
            ),
          ),
          if (widget.message != null) ...[
            const SizedBox(height: 16),
            Text(widget.message!, style: theme.textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}
