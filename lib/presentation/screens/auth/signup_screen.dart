import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/auth_viewmodel.dart';

class SignupScreen extends HookConsumerWidget {
  const SignupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nameController = useTextEditingController();
    final emailController = useTextEditingController();
    final passwordController = useTextEditingController();
    final confirmPasswordController = useTextEditingController();
    final formKey = useMemoized(GlobalKey<FormState>.new);
    final isLoading = useState(false);
    final errorMessage = useState<String?>(null);

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

    Future<void> handleSignup() async {
      if (!formKey.currentState!.validate()) return;
      errorMessage.value = null;
      isLoading.value = true;
      try {
        await ref
            .read(authViewModelProvider.notifier)
            .signUpWithEmail(
              email: emailController.text.trim(),
              password: passwordController.text,
              displayName: nameController.text.trim(),
            );
      } catch (e) {
        errorMessage.value = e.toString();
      } finally {
        isLoading.value = false;
      }
    }

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('회원가입')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.screenAll,
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Error message
                if (errorMessage.value != null) ...[
                  SelectableText.rich(
                    TextSpan(
                      text: errorMessage.value,
                      style: TextStyle(
                        color: theme.colorScheme.error,
                      ),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],

                // Name field
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '이름',
                    hintText: '홍길동',
                    prefixIcon: Icon(Icons.person_outlined),
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '이름을 입력해주세요';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),

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
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '비밀번호를 입력해주세요';
                    }
                    if (value.length < 6) {
                      return '비밀번호는 최소 6자 이상이어야 합니다';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),

                // Confirm password field
                TextFormField(
                  controller: confirmPasswordController,
                  decoration: const InputDecoration(
                    labelText: '비밀번호 확인',
                    prefixIcon: Icon(Icons.lock_outlined),
                  ),
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => handleSignup(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '비밀번호를 다시 입력해주세요';
                    }
                    if (value != passwordController.text) {
                      return '비밀번호가 일치하지 않습니다';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.xxl),

                // Signup button
                ElevatedButton(
                  onPressed: isLoading.value ? null : handleSignup,
                  child: isLoading.value
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.onPrimary,
                          ),
                        )
                      : const Text('회원가입'),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Privacy policy
                Text(
                  '회원가입 시 개인정보 처리방침에 동의합니다.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xxl),

                // Already have an account
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '이미 계정이 있으신가요?',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    TextButton(
                      onPressed: () => context.pop(),
                      child: const Text('로그인'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
