import 'package:flutter/foundation.dart';

/// 콜드 스타트 계측 — 앱 시작(=[start] 호출) 시점부터의 경과 시간을 남긴다.
///
/// 같은 라벨은 한 번만 출력한다. 첫 화면이 그려지는 순간처럼 "처음 한 번"이
/// 의미 있는 지점을 재는 용도라, 매 프레임 호출돼도 로그가 늘지 않는다.
/// 릴리스 빌드에서는 [debugPrint]가 no-op에 가깝고 문자열 조합도 하지 않는다.
class PerfTrace {
  PerfTrace._();

  static final Stopwatch _stopwatch = Stopwatch();
  static final Set<String> _seen = <String>{};

  /// main() 진입 직후 한 번 호출한다.
  static void start() {
    if (_stopwatch.isRunning) return;
    _stopwatch.start();
  }

  /// [label] 지점의 경과 시간(ms)을 기록한다. 같은 라벨의 두 번째 호출은 무시.
  static void mark(String label) {
    if (!kDebugMode) return;
    if (!_stopwatch.isRunning) return;
    if (!_seen.add(label)) return;
    debugPrint('[perf] $label: ${_stopwatch.elapsedMilliseconds}ms');
  }

  /// 지금까지의 경과 시간(ms). 계측이 시작되지 않았으면 null.
  static int? get elapsedMs =>
      _stopwatch.isRunning ? _stopwatch.elapsedMilliseconds : null;

  @visibleForTesting
  static void reset() {
    _seen.clear();
    _stopwatch
      ..stop()
      ..reset();
  }
}
