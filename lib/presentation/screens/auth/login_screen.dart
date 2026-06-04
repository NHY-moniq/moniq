import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/core/utils/auth_error_utils.dart';
import 'package:moniq/presentation/layout/adaptive_layout.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/auth_viewmodel.dart';

class LoginScreen extends HookConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emailController = useTextEditingController();
    final passwordController = useTextEditingController();
    final formKey = useMemoized(GlobalKey<FormState>.new);
    final isLoading = useState(false);
    final errorMessage = useState<String?>(null);
    final obscurePassword = useState(true);

    final authState = ref.watch(authViewModelProvider);

    ref.listen(authViewModelProvider, (prev, next) {
      next.whenOrNull(
        data: (user) {
          if (user != null) {
            context.go('/home');
          }
        },
        error: (error, _) {
          errorMessage.value = friendlyAuthError(error);
        },
      );
    });

    Future<void> handleEmailLogin() async {
      if (!formKey.currentState!.validate()) return;
      errorMessage.value = null;
      isLoading.value = true;
      try {
        await ref.read(authViewModelProvider.notifier).signInWithEmail(
              email: emailController.text.trim(),
              password: passwordController.text,
            );
      } catch (e) {
        errorMessage.value = e.toString();
      } finally {
        isLoading.value = false;
      }
    }

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

    final theme = Theme.of(context);
    final busy = isLoading.value || authState.isLoading;

    return Scaffold(
      body: Stack(
        children: [
          // Decorative blob backgrounds
          const _BlobBackground(),

          // Main content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: AdaptiveLayout.isWide(context) ? 0 : 28,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal:
                            AdaptiveLayout.isWide(context) ? 0 : 0,
                        vertical: AdaptiveLayout.isWide(context) ? 32 : 0,
                      ),
                      child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Mascot & Branding
                      const _BrandSection(),
                      const SizedBox(height: AppSpacing.huge),

                      // Error message
                      if (errorMessage.value != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: AppSpacing.md,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.error
                                .withValues(alpha: 0.1),
                            borderRadius: AppRadius.borderRadiusFull,
                          ),
                          child: SelectableText.rich(
                            TextSpan(
                              text: errorMessage.value,
                              style: TextStyle(
                                color: theme.colorScheme.error,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],

                      // Email field
                      _PillTextField(
                        controller: emailController,
                        label: '이메일',
                        hint: 'nurse.joy@hospital.com',
                        icon: Icons.mail_outline,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return '이메일을 입력해주세요';
                          }
                          if (!value.contains('@')) {
                            return '올바른 이메일 형식을 입력해주세요';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // Password field
                      _PillTextField(
                        controller: passwordController,
                        label: '비밀번호',
                        hint: '••••••••',
                        icon: Icons.lock_outline,
                        obscureText: obscurePassword.value,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => handleEmailLogin(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword.value
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: theme.colorScheme.outline
                                .withValues(alpha: 0.6),
                            size: 20,
                          ),
                          onPressed: () =>
                              obscurePassword.value = !obscurePassword.value,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '비밀번호를 입력해주세요';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.xxl),

                      // Login button
                      SizedBox(
                        width: double.infinity,
                        height: AppSizing.buttonHeight,
                        child: ElevatedButton(
                          onPressed: busy ? null : handleEmailLogin,
                          child: busy
                              ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: theme.colorScheme.onPrimary,
                                  ),
                                )
                              : const Text('로그인'),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Forgot password
                      TextButton(
                        onPressed: () => context.push('/forgot-password'),
                        child: Text(
                          '비밀번호를 잊으셨나요?',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.secondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxxl),

                      // Divider
                      _OrDivider(),
                      const SizedBox(height: AppSpacing.xxxl),

                      // 카카오 (primary, full-width)
                      _KakaoLoginButton(
                        onPressed: () => handleSocialLogin(
                          ref
                              .read(authViewModelProvider.notifier)
                              .signInWithKakao,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // 보조 소셜 버튼 (작은 아이콘)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _SmallSocialButton(
                            onPressed: () => handleSocialLogin(
                              ref
                                  .read(authViewModelProvider.notifier)
                                  .signInWithGoogle,
                            ),
                            icon: Icons.g_mobiledata,
                            tooltip: 'Google로 로그인',
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xxxl),

                      // Sign up link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'OnorOff가 처음이신가요?',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.push('/signup'),
                            child: Text(
                              '회원가입',
                              style: TextStyle(
                                color: theme.colorScheme.tertiary,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                    ],
                  ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Playful blob background decoration
class _BlobBackground extends StatelessWidget {
  const _BlobBackground();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.4),
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Brand section with logo and tagline
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
          height: 160,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          '간호사를 위한 근무표 관리',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface
                .withValues(alpha: 0.6),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Pill-shaped text field matching design HTML
class _PillTextField extends StatelessWidget {
  const _PillTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onFieldSubmitted,
    this.suffixIcon,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final Widget? suffixIcon;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 24, bottom: 8),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.0,
              color: colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onFieldSubmitted: onFieldSubmitted,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 20, right: 8),
              child: Icon(icon, color: colorScheme.primary, size: 20),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 48,
            ),
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }
}

/// "또는" divider
class _OrDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 2,
            color: colorScheme.surfaceContainer,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Text(
            '또는',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.0,
              color: colorScheme.outline.withValues(alpha: 0.4),
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 2,
            color: colorScheme.surfaceContainer,
          ),
        ),
      ],
    );
  }
}

/// 카카오 로그인 버튼 — full-width, 공식 브랜드 컬러 고정 (다크모드 무관)
class _KakaoLoginButton extends StatelessWidget {
  const _KakaoLoginButton({required this.onPressed});

  final VoidCallback onPressed;

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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble, size: 20, color: _kakaoBrown),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '카카오로 시작하기',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: _kakaoBrown,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 보조 소셜 로그인 — 작은 원형 아이콘 버튼
class _SmallSocialButton extends StatelessWidget {
  const _SmallSocialButton({
    required this.onPressed,
    required this.icon,
    required this.tooltip,
  });

  final VoidCallback onPressed;
  final IconData icon;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 52,
        height: 52,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            backgroundColor: cs.surface,
            foregroundColor: cs.onSurface,
            side: BorderSide(color: cs.outlineVariant),
            shape: const CircleBorder(),
            padding: EdgeInsets.zero,
          ),
          child: Icon(icon, size: 24),
        ),
      ),
    );
  }
}
