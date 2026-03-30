import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
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
          errorMessage.value = error.toString();
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
                padding: const EdgeInsets.symmetric(horizontal: 28),
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
                            color: AppColors.error.withValues(alpha: 0.1),
                            borderRadius: AppRadius.borderRadiusFull,
                          ),
                          child: SelectableText.rich(
                            TextSpan(
                              text: errorMessage.value,
                              style: const TextStyle(
                                color: AppColors.error,
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
                            color: AppColors.outline.withValues(alpha: 0.6),
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
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
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
                            color: AppColors.secondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxxl),

                      // Divider
                      _OrDivider(),
                      const SizedBox(height: AppSpacing.xxxl),

                      // Social login grid
                      Row(
                        children: [
                          Expanded(
                            child: _SocialPillButton(
                              onPressed: () => handleSocialLogin(
                                ref
                                    .read(authViewModelProvider.notifier)
                                    .signInWithGoogle,
                              ),
                              icon: Icons.g_mobiledata,
                              label: 'Google',
                            ),
                          ),
                          const SizedBox(width: AppSpacing.lg),
                          if (defaultTargetPlatform == TargetPlatform.iOS)
                            Expanded(
                              child: _SocialPillButton(
                                onPressed: () => handleSocialLogin(
                                  ref
                                      .read(authViewModelProvider.notifier)
                                      .signInWithApple,
                                ),
                                icon: Icons.apple,
                                label: 'Apple',
                              ),
                            )
                          else
                            Expanded(
                              child: _SocialPillButton(
                                onPressed: () => handleSocialLogin(
                                  ref
                                      .read(authViewModelProvider.notifier)
                                      .signInWithKakao,
                                ),
                                icon: Icons.chat_bubble,
                                label: '카카오',
                                backgroundColor: const Color(0xFFFEE500),
                              ),
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
                              color: AppColors.onSurface.withValues(alpha: 0.6),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.push('/signup'),
                            child: Text(
                              '회원가입',
                              style: TextStyle(
                                color: AppColors.tertiary,
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
    return const IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -80,
            left: -40,
            child: _Blob(
              size: 300,
              color: AppColors.primaryContainer,
            ),
          ),
          Positioned(
            bottom: -40,
            right: -80,
            child: _Blob(
              size: 360,
              color: AppColors.secondaryContainer,
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
            color: AppColors.onSurface.withValues(alpha: 0.6),
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
              color: AppColors.onSurface.withValues(alpha: 0.5),
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
              child: Icon(icon, color: AppColors.primary, size: 20),
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
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 2,
            color: AppColors.surfaceContainer,
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
              color: AppColors.outline.withValues(alpha: 0.4),
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 2,
            color: AppColors.surfaceContainer,
          ),
        ),
      ],
    );
  }
}

/// Social login pill button (grid style)
class _SocialPillButton extends StatelessWidget {
  const _SocialPillButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    this.backgroundColor,
  });

  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSizing.buttonHeight,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: backgroundColor ?? Colors.white,
          foregroundColor: AppColors.onSurfaceVariant,
          side: BorderSide(
            color: AppColors.surfaceContainer,
            width: 2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.borderRadiusFull,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22),
            const SizedBox(width: AppSpacing.sm),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
