import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/core/utils/auth_error_utils.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/auth_viewmodel.dart';
import 'package:url_launcher/url_launcher.dart';

/// Sign in with Apple 버튼 노출 대상: Apple 플랫폼 + 웹.
/// (Android에서는 네이티브 미구성이며 4.8 요건 대상도 아니므로 숨김)
bool get _showAppleButton =>
    kIsWeb ||
    defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.macOS;

class LoginScreen extends HookConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = useState(false);
    final errorMessage = useState<String?>(null);

    final authState = ref.watch(authViewModelProvider);

    ref.listen(authViewModelProvider, (prev, next) {
      next.whenOrNull(
        data: (user) {
          if (user != null) {
            context.go('/home');
          }
        },
        error: (error, _) {
          // 원인 진단용 — 콘솔에 raw 에러 출력(메시지 매핑 전).
          debugPrint('[login] raw auth error: $error');
          errorMessage.value = friendlyAuthError(error);
        },
      );
    });

    Future<void> handleSocialLogin(Future<void> Function() loginFn) async {
      errorMessage.value = null;
      isLoading.value = true;
      try {
        await loginFn();
      } catch (e) {
        errorMessage.value = e.toString();
      } finally {
        isLoading.value = false;
      }
    }

    // 진입 애니메이션: 히어로 → 150ms 지연 후 버튼 스택 (총 ~700ms, 1회)
    final entryController = useAnimationController(
      duration: const Duration(milliseconds: 700),
    );
    useEffect(() {
      entryController.forward();
      return null;
    }, const []);
    final heroAnimation = useMemoized(
      () => CurvedAnimation(
        parent: entryController,
        // 0 ~ 400ms
        curve: const Interval(0.0, 0.57, curve: Curves.easeOutCubic),
      ),
      [entryController],
    );
    final buttonsAnimation = useMemoized(
      () => CurvedAnimation(
        parent: entryController,
        // 150ms ~ 550ms
        curve: const Interval(0.21, 0.79, curve: Curves.easeOutCubic),
      ),
      [entryController],
    );

    final busy = isLoading.value || authState.isLoading;
    final notifier = ref.read(authViewModelProvider.notifier);

    return Scaffold(
      body: Stack(
        children: [
          // Decorative blob backgrounds
          const _BlobBackground(),

          // Main content — 상단 히어로 / 하단 버튼 앵커 구조
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                            ),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.stretch,
                              children: [
                                const Spacer(flex: 5),

                                // Brand hero
                                _FadeSlideIn(
                                  animation: heroAnimation,
                                  child: const _BrandSection(),
                                ),

                                const Spacer(flex: 4),

                                // Buttons stack (+ error banner)
                                _FadeSlideIn(
                                  animation: buttonsAnimation,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      if (errorMessage.value != null) ...[
                                        _ErrorBanner(
                                          message: errorMessage.value!,
                                        ),
                                        const SizedBox(
                                          height: AppSpacing.lg,
                                        ),
                                      ],
                                      _KakaoLoginButton(
                                        onPressed: busy
                                            ? null
                                            : () => handleSocialLogin(
                                                  notifier.signInWithKakao,
                                                ),
                                      ),
                                      const SizedBox(
                                        height: AppSpacing.md,
                                      ),
                                      _GoogleLoginButton(
                                        onPressed: busy
                                            ? null
                                            : () => handleSocialLogin(
                                                  notifier.signInWithGoogle,
                                                ),
                                      ),
                                      // Apple — Apple 플랫폼/웹에서만
                                      // 노출 (Guideline 4.8)
                                      if (_showAppleButton) ...[
                                        const SizedBox(
                                          height: AppSpacing.md,
                                        ),
                                        _AppleLoginButton(
                                          onPressed: busy
                                              ? null
                                              : () => handleSocialLogin(
                                                    notifier.signInWithApple,
                                                  ),
                                        ),
                                      ],
                                      const SizedBox(
                                        height: AppSpacing.xxl,
                                      ),
                                      const _LegalFooter(),
                                      const SizedBox(
                                        height: AppSpacing.xl,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 진입 애니메이션: opacity 0→1 + translateY 16→0
class _FadeSlideIn extends StatelessWidget {
  const _FadeSlideIn({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Opacity(
          opacity: animation.value,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - animation.value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// Playful blob background decoration
class _BlobBackground extends StatelessWidget {
  const _BlobBackground();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenHeight = MediaQuery.sizeOf(context).height;
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -80,
            left: -40,
            child: _Blob(
              size: 300,
              color: colorScheme.primaryContainer,
            ),
          ),
          Positioned(
            bottom: -40,
            right: -80,
            child: _Blob(
              size: 360,
              color: colorScheme.secondaryContainer,
            ),
          ),
          // 히어로와 버튼 스택 사이 우중단 빈 공간 — 배경 리듬용
          Positioned(
            top: screenHeight * 0.48,
            right: -50,
            child: _Blob(
              size: 140,
              color: colorScheme.tertiaryContainer,
              alpha: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color, this.alpha = 0.4});

  final double size;
  final Color color;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: alpha),
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Brand hero: logo + headline + tagline + shift badge chips
class _BrandSection extends StatelessWidget {
  const _BrandSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Logo
        Image.asset(
          'assets/images/app_logo.png',
          height: 180,
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          '근무표, 더 가볍게.',
          textAlign: TextAlign.center,
          style: theme.textTheme.displayMedium?.copyWith(
            color: theme.colorScheme.onSurface,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '간호사를 위한 근무표 관리',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        const _ShiftBadgeRow(),
      ],
    );
  }
}

/// 근무 뱃지 칩 row — 순수 장식 (D / E / N / OFF)
class _ShiftBadgeRow extends StatelessWidget {
  const _ShiftBadgeRow();

  static const _badges = [
    ('D', AppColors.shiftDay),
    ('E', AppColors.shiftEvening),
    ('N', AppColors.shiftNight),
    ('OFF', AppColors.shiftOff),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IgnorePointer(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final (index, (label, color)) in _badges.indexed) ...[
            if (index > 0) const SizedBox(width: AppSpacing.sm),
            _ShiftBadgeChip(label: label, color: color, isDark: isDark),
          ],
        ],
      ),
    );
  }
}

class _ShiftBadgeChip extends StatelessWidget {
  const _ShiftBadgeChip({
    required this.label,
    required this.color,
    required this.isDark,
  });

  final String label;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final background = color.withValues(alpha: isDark ? 0.22 : 0.15);
    final foreground = isDark
        ? color
        : Color.alphaBlend(Colors.black.withValues(alpha: 0.25), color);
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.borderRadiusFull,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          color: foreground,
        ),
      ),
    );
  }
}

/// 에러 메시지 배너 — 버튼 스택 바로 위
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.error.withValues(alpha: 0.1),
        borderRadius: AppRadius.borderRadiusFull,
      ),
      child: SelectableText.rich(
        TextSpan(
          text: message,
          style: TextStyle(
            color: theme.colorScheme.error,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// 카카오 로그인 버튼 — full-width, 공식 브랜드 컬러 고정 (다크모드 무관)
class _KakaoLoginButton extends StatelessWidget {
  const _KakaoLoginButton({required this.onPressed});

  final VoidCallback? onPressed;

  static const _kakaoYellow = Color(0xFFFEE500);
  static const _kakaoBrown = Color(0xFF3C1E1E);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: AppSizing.buttonHeight,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _kakaoYellow,
          foregroundColor: _kakaoBrown,
          disabledBackgroundColor: _kakaoYellow.withValues(alpha: 0.5),
          disabledForegroundColor: _kakaoBrown.withValues(alpha: 0.5),
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.borderRadiusFull,
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble, size: 20),
            SizedBox(width: AppSpacing.sm),
            Text(
              '카카오로 시작하기',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Google 로그인 버튼 — full-width, Google 아이덴티티 가이드 톤
class _GoogleLoginButton extends StatelessWidget {
  const _GoogleLoginButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF131314) : Colors.white;
    final foreground =
        isDark ? const Color(0xFFE3E3E3) : const Color(0xFF1F1F1F);
    final borderColor = isDark
        ? const Color(0xFF8E918F).withValues(alpha: 0.6)
        : Theme.of(context).colorScheme.outlineVariant;

    return SizedBox(
      width: double.infinity,
      height: AppSizing.buttonHeight,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          disabledBackgroundColor: background.withValues(alpha: 0.5),
          disabledForegroundColor: foreground.withValues(alpha: 0.5),
          side: BorderSide(color: borderColor),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.borderRadiusFull,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Center(
                child: Text(
                  'G',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: onPressed == null
                        ? foreground.withValues(alpha: 0.5)
                        : foreground,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Text(
              'Google로 계속하기',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Apple 로그인 버튼 — full-width, Apple HIG 표준
/// (라이트: 검정 버튼 / 다크: 흰 버튼, 브랜드 고정 컬러)
class _AppleLoginButton extends StatelessWidget {
  const _AppleLoginButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? Colors.white : Colors.black;
    final foreground = isDark ? Colors.black : Colors.white;

    return SizedBox(
      width: double.infinity,
      height: AppSizing.buttonHeight,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          disabledBackgroundColor: background.withValues(alpha: 0.5),
          disabledForegroundColor: foreground.withValues(alpha: 0.5),
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.borderRadiusFull,
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: 2),
              child: Icon(Icons.apple, size: 22),
            ),
            SizedBox(width: AppSpacing.sm),
            Text(
              'Apple로 계속하기',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 약관 동의 고지 — 소셜 로그인이 가입을 겸하므로 명시
class _LegalFooter extends StatefulWidget {
  const _LegalFooter();

  @override
  State<_LegalFooter> createState() => _LegalFooterState();
}

class _LegalFooterState extends State<_LegalFooter> {
  // 설정 화면의 정보 섹션과 동일한 링크 대상
  static const _termsUrl =
      'https://onoroff.notion.site/OnorOff-37c4dc2094dd80d1b788d31396f89a2c';
  static const _privacyUrl =
      'https://onoroff.notion.site/37c4dc2094dd80649df6eea031d388ac';

  late final TapGestureRecognizer _termsRecognizer;
  late final TapGestureRecognizer _privacyRecognizer;

  @override
  void initState() {
    super.initState();
    _termsRecognizer = TapGestureRecognizer()
      ..onTap = () => _openExternalUrl(_termsUrl);
    _privacyRecognizer = TapGestureRecognizer()
      ..onTap = () => _openExternalUrl(_privacyUrl);
  }

  @override
  void dispose() {
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  /// 외부 링크를 기본 브라우저로 열기. 실패 시 클립보드에 복사.
  Future<void> _openExternalUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    await Clipboard.setData(ClipboardData(text: url));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final baseStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      height: 1.6,
      color: colorScheme.onSurface.withValues(alpha: 0.45),
    );
    final linkStyle = TextStyle(
      fontWeight: FontWeight.w700,
      color: colorScheme.onSurface.withValues(alpha: 0.65),
    );

    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: [
          const TextSpan(text: '계속하면 OnorOff의 '),
          TextSpan(
            text: '이용약관',
            style: linkStyle,
            recognizer: _termsRecognizer,
          ),
          const TextSpan(text: ' 및\n'),
          TextSpan(
            text: '개인정보처리방침',
            style: linkStyle,
            recognizer: _privacyRecognizer,
          ),
          const TextSpan(text: '에 동의하게 됩니다'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
