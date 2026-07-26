import 'dart:async';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// 광고 동의(UMP) → 앱 추적 권한(ATT) → AdMob 초기화를 순서대로 처리한다.
///
/// - **UMP**: EU/UK 등 GDPR 지역 사용자에게 Google User Messaging Platform
///   동의 폼을 표시(필요 시). 동의 설정은 AdMob 콘솔에서 구성해야 실제 폼이 뜬다.
/// - **ATT**: iOS 14+에서 맞춤형 광고(IDFA)를 위한 앱 추적 권한 요청.
///   거부해도 앱은 정상 동작하며 비개인화 광고가 노출된다.
///
/// 모든 단계는 실패해도 앱 시작을 막지 않도록 best-effort로 처리한다.
class AdConsentManager {
  AdConsentManager._();
  static final AdConsentManager instance = AdConsentManager._();

  bool _mobileAdsInitialized = false;

  bool get isMobileAdsReady => _mobileAdsInitialized;

  /// 동의 수집 후 AdMob을 초기화한다. (모바일 전용, 웹/데스크톱은 no-op)
  Future<void> gatherConsentAndInitialize() async {
    if (kIsWeb) return;
    final isMobile =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    if (!isMobile) return;

    // 1) UMP(GDPR) 동의 — 폼이 필요하면 표시
    try {
      await _requestUmpConsent();
    } catch (e) {
      debugPrint('[ads] UMP 동의 처리 실패(무시): $e');
    }

    // 2) ATT(iOS) — 미결정 상태일 때만 시스템 팝업. 포그라운드 보장을 위해 약간 지연.
    try {
      await _requestAttIfNeeded();
    } catch (e) {
      debugPrint('[ads] ATT 요청 실패(무시): $e');
    }

    // 3) AdMob 초기화
    try {
      await MobileAds.instance.initialize();
      _mobileAdsInitialized = true;
      debugPrint('[ads] MobileAds 초기화 완료');
    } catch (e) {
      debugPrint('[ads] MobileAds 초기화 실패(무시): $e');
    }
  }

  Future<void> _requestUmpConsent() async {
    final completer = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () async {
        try {
          final available = await ConsentInformation.instance
              .isConsentFormAvailable();
          if (available) {
            ConsentForm.loadAndShowConsentFormIfRequired((formError) {
              if (formError != null) {
                debugPrint('[ads] UMP 폼 오류(무시): ${formError.message}');
              }
              if (!completer.isCompleted) completer.complete();
            });
          } else {
            if (!completer.isCompleted) completer.complete();
          }
        } catch (e) {
          if (!completer.isCompleted) completer.complete();
        }
      },
      (error) {
        debugPrint('[ads] UMP 정보 갱신 실패(무시): ${error.message}');
        if (!completer.isCompleted) completer.complete();
      },
    );
    await completer.future;
  }

  Future<void> _requestAttIfNeeded() async {
    final status = await AppTrackingTransparency.trackingAuthorizationStatus;
    if (status == TrackingStatus.notDetermined) {
      // 시스템 팝업이 포그라운드에서 뜨도록 짧게 대기.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await AppTrackingTransparency.requestTrackingAuthorization();
    }
  }
}
