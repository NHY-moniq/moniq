import 'package:flutter/foundation.dart';

/// AdMob 광고 단위 ID 모음.
///
/// 개발 중에는 Google이 제공하는 "공식 테스트 광고 단위 ID"만 사용한다.
/// (실제 광고를 직접 클릭하면 정책 위반으로 계정이 정지될 수 있음 —
///  https://support.google.com/admob/answer/6128543 참고)
///
/// 출시 직전에 아래 `_prod*` 값을 실제 AdMob 광고 단위 ID로 교체하고,
/// `useTestAds`를 false로 내리면 된다.
class AdHelper {
  AdHelper._();

  /// true면 항상 테스트 광고를 노출한다.
  /// 디버그 빌드에서는 무조건 테스트 광고를 쓰고,
  /// 릴리스에서도 실제 ID를 채우기 전까지는 테스트 광고를 유지한다.
  static const bool useTestAds = true;

  // ── Google 공식 테스트 배너 광고 단위 ID ──
  // https://developers.google.com/admob/flutter/test-ads
  static const String _testBannerAndroid =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _testBannerIos =
      'ca-app-pub-3940256099942544/2934735716';

  // ── 실제 배너 광고 단위 ID (출시 전 교체) ──
  static const String _prodBannerAndroid = '';
  static const String _prodBannerIos = '';

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
