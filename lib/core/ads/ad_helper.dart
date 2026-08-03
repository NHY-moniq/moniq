import 'package:flutter/foundation.dart';

/// AdMob 광고 단위 ID 모음.
///
/// 개발 중에는 Google이 제공하는 "공식 테스트 광고 단위 ID"만 사용한다.
/// (실제 광고를 직접 클릭하면 정책 위반으로 계정이 정지될 수 있음 —
///  https://support.google.com/admob/answer/6128543 참고)
///
/// 릴리스 빌드는 실제 광고 단위 ID로 실광고를 노출한다 (iOS/Android 모두 적용됨).
class AdHelper {
  AdHelper._();

  /// true면 항상 테스트 광고를 노출한다.
  /// 디버그 빌드에서는 무조건 테스트 광고를 쓰고,
  /// 릴리스에서는 실제 광고 단위 ID가 채워진 플랫폼만 실광고를 노출한다.
  static const bool useTestAds = false;

  // ── Google 공식 테스트 배너 광고 단위 ID ──
  // https://developers.google.com/admob/flutter/test-ads
  static const String _testBannerAndroid =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _testBannerIos =
      'ca-app-pub-3940256099942544/2934735716';

  // ── 실제 배너 광고 단위 ID ──
  static const String _prodBannerAndroid =
      'ca-app-pub-9945303286843241/3040393587';
  static const String _prodBannerIos =
      'ca-app-pub-9945303286843241/1201389262';

  /// 현재 플랫폼에 맞는 배너 광고 단위 ID.
  /// 웹은 google_mobile_ads를 지원하지 않으므로 호출하면 안 된다.
  static String get bannerAdUnitId {
    final useTest = useTestAds || kDebugMode;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        final prod = _prodBannerAndroid;
        return (useTest || prod.isEmpty) ? _testBannerAndroid : prod;
      case TargetPlatform.iOS:
        final prod = _prodBannerIos;
        return (useTest || prod.isEmpty) ? _testBannerIos : prod;
      default:
        // 그 외 플랫폼은 광고를 띄우지 않음 — 안전하게 테스트 ID 반환.
        return _testBannerAndroid;
    }
  }

  /// 광고를 지원하는 플랫폼인지 여부 (Android / iOS만 지원, 웹·데스크톱 제외).
  static bool get isSupported {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }
}
