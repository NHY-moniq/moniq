import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/core/ads/ad_consent_manager.dart';
import 'package:moniq/core/ads/ad_helper.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/theme/shift_theme.dart';
import 'package:moniq/presentation/theme/app_typography.dart';

/// 적응형(anchored adaptive) 배너 광고 위젯.
///
/// - Android / iOS에서만 동작한다. 웹·데스크톱에서는 빈 위젯을 반환한다.
/// - 부모가 주는 실제 가로 제약(LayoutBuilder)에 맞춰 광고 폭을 계산하므로
///   화면 어느 위치(패딩 안/밖)에 놓아도 정확히 들어맞는다.
/// - 로드 실패·미지원 시 공간을 차지하지 않는다 (빈 위젯).
/// - 홈 카드 패밀리와 동일한 크림 카드 스타일로 감싼다.
class BannerAdWidget extends ConsumerStatefulWidget {
  const BannerAdWidget({super.key});

  @override
  ConsumerState<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends ConsumerState<BannerAdWidget> {
  /// 로드 실패 시 재시도 횟수 상한. 초기화 지연·일시적 무응답을 흡수하는 용도.
  static const int _maxAttempts = 4;

  BannerAd? _bannerAd;
  bool _isLoaded = false;
  bool _didRequest = false;
  int _attempts = 0;
  Timer? _retryTimer;

  Future<void> _loadAd(double maxWidth) async {
    // 컨테이너 안쪽 좌우 padding(xs*2)을 뺀 폭으로 adaptive 사이즈를 계산한다.
    final width = (maxWidth - AppSpacing.xs * 2).truncate();
    if (width <= 0) return;

    // MobileAds 초기화(UMP 동의·ATT 팝업 뒤에 완료)보다 먼저 load하면 무조건
    // 실패하므로 초기화 완료를 기다린다. 이미 완료됐으면 즉시 통과한다.
    await AdConsentManager.instance.gatherConsentAndInitialize();
    if (!mounted) return;

    final size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
      width,
    );
    if (!mounted) return;
    if (size == null) {
      debugPrint('[ads] adaptive 배너 사이즈 계산 실패');
      return;
    }

    _attempts++;
    final ad = BannerAd(
      adUnitId: AdHelper.bannerAdUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (!mounted) return;
          setState(() => _isLoaded = true);
        },
        onAdFailedToLoad: (failedAd, error) {
          debugPrint('[ads] 배너 로드 실패($_attempts/$_maxAttempts): $error');
          failedAd.dispose();
          if (identical(_bannerAd, failedAd)) _bannerAd = null;
          if (!mounted || _attempts >= _maxAttempts) return;
          _scheduleRetry(maxWidth);
        },
      ),
    );

    // load() 이전에 참조를 확정한다 — onAdLoaded가 먼저 도착해도
    // build가 광고를 그릴 수 있고, 중도 dispose 시 누수도 없다.
    _bannerAd = ad;
    await ad.load();
  }

  /// 지수 백오프로 재시도한다 (15s, 30s, 60s).
  ///
  /// 간격을 짧게 잡으면 AdMob이 동일 광고 단위의 연속 실패 요청을 차단해
  /// ("Too many recently failed requests", code 0) 오히려 재시도가 무의미해진다.
  /// no fill은 즉시 해소되는 문제도 아니므로 넉넉히 띄운다.
  void _scheduleRetry(double maxWidth) {
    _retryTimer?.cancel();
    final delay = Duration(seconds: 15 * (1 << (_attempts - 1)));
    _retryTimer = Timer(delay, () {
      if (!mounted) return;
      _loadAd(maxWidth);
    });
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AdHelper.isSupported) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // 부모 제약이 확정되면 한 번만 로드한다.
        if (!_didRequest && constraints.maxWidth.isFinite) {
          _didRequest = true;
          _loadAd(constraints.maxWidth);
        }

        final ad = _bannerAd;
        if (!_isLoaded || ad == null) {
          return const SizedBox.shrink();
        }

        final cs = Theme.of(context).colorScheme;
        final isDark = cs.brightness == Brightness.dark;
        final shift = ref.watch(todayShiftThemeProvider);

        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.lg),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs, // 좌우 4 크림 프레임
            vertical: AppSpacing.xxs, // 상하 2 (높이 축소)
          ),
          decoration: BoxDecoration(
            color: shift.scaffoldBackground,
            borderRadius: AppRadius.borderRadiusLg, // 24
            border: Border.all(
              // 테두리도 배경 톤을 따라가야 프레임이 겉돌지 않는다.
              color: isDark
                  ? AppColors.outlineVariantDark
                  : shift.elevatedSurface,
              width: 1,
            ),
            boxShadow: isDark
                ? const []
                : [
                    BoxShadow(
                      color: AppColors.secondary.withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 광고 구분 라벨 (AdMob 정책: 콘텐츠 위장 방지) — 라벨 행 최소화
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.xs),
                child: Text(
                  'AD',
                  style: AppTypography.captionSmall.copyWith(
                    color: cs.outline,
                    height: 1.0,
                  ),
                ),
              ),
              ClipRRect(
                borderRadius: AppRadius.borderRadiusMd, // 16 (중첩 라운딩)
                child: SizedBox(
                  width: ad.size.width.toDouble(),
                  height: ad.size.height.toDouble(),
                  child: AdWidget(ad: ad),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
