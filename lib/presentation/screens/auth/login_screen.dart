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

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: AppSpacing.screenAll,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo
                  Image.asset(
                    'assets/images/logo.png',
                    height: 120,
                  ),
                  const SizedBox(height: AppSpacing.huge),

                  // Error message
                  if (errorMessage.value != null) ...[
                    SelectableText.rich(
                      TextSpan(
                        text: errorMessage.value,
                        style: const TextStyle(color: AppColors.error),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  // Email field
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: '이메일',
                      hintText: 'example@email.com',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
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
                  TextFormField(
                    controller: passwordController,
                    decoration: const InputDecoration(
                      labelText: '비밀번호',
                      prefixIcon: Icon(Icons.lock_outlined),
                    ),
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => handleEmailLogin(),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '비밀번호를 입력해주세요';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  // Login button
                  ElevatedButton(
                    onPressed: isLoading.value || authState.isLoading
                        ? null
                        : handleEmailLogin,
                    child: isLoading.value || authState.isLoading
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
                  const SizedBox(height: AppSpacing.xxl),

                  // Divider
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                        ),
                        child: Text(
                          '또는',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondaryLight,
                                  ),
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  // Social login buttons
                  if (defaultTargetPlatform == TargetPlatform.iOS) ...[
                    _SocialLoginButton(
                      onPressed: () => handleSocialLogin(
                        ref
                            .read(authViewModelProvider.notifier)
                            .signInWithApple,
                      ),
                      icon: Icons.apple,
                      label: 'Apple로 계속하기',
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],

                  _SocialLoginButton(
                    onPressed: () => handleSocialLogin(
                      ref
                          .read(authViewModelProvider.notifier)
                          .signInWithGoogle,
                    ),
                    icon: Icons.g_mobiledata,
                    label: 'Google로 계속하기',
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    borderColor: AppColors.borderLight,
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  _SocialLoginButton(
                    onPressed: () => handleSocialLogin(
                      ref
                          .read(authViewModelProvider.notifier)
                          .signInWithKakao,
                    ),
                    icon: Icons.chat_bubble,
                    label: '카카오로 계속하기',
                    backgroundColor: const Color(0xFFFEE500),
                    foregroundColor: Colors.black87,
                  ),
                  const SizedBox(height: AppSpacing.xxxl),

                  // Footer links
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: () => context.push('/signup'),
                        child: const Text('회원가입'),
                      ),
                      const Text('|'),
                      TextButton(
                        onPressed: () => context.push('/forgot-password'),
                        child: const Text('비밀번호 찾기'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SocialLoginButton extends StatelessWidget {
  const _SocialLoginButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    this.borderColor,
  });

  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSizing.buttonHeight,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          side: BorderSide(
            color: borderColor ?? backgroundColor,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.borderRadiusMd,
          ),
        ),
        icon: Icon(icon, size: 24),
        label: Text(label),
      ),
    );
  }
}
