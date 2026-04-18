import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/auth_viewmodel.dart';

class EmailVerificationScreen extends HookConsumerWidget {
  const EmailVerificationScreen({required this.email, super.key});

  final String email;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cooldown = useState(0);
    final isSending = useState(false);

    useEffect(() {
      if (cooldown.value <= 0) return null;
      final timer = Timer.periodic(const Duration(seconds: 1), (_) {
        cooldown.value--;
      });
      return timer.cancel;
    }, [cooldown.value > 0]);

    Future<void> handleResend() async {
      isSending.value = true;
      try {
        await ref.read(authViewModelProvider.notifier).resendVerificationEmail(email);
        cooldown.value = 60;
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('이메일 발송에 실패했습니다. 잠시 후 다시 시도해주세요.')),
          );
        }
      } finally {
        isSending.value = false;
      }
    }

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.screenAll,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.mark_email_read_outlined,
                size: 80,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text(
                '인증 이메일을 발송했습니다',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                email,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                '위 이메일로 발송된 인증 링크를 클릭하면\n회원가입이 완료됩니다.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xxxl),
              SizedBox(
                width: double.infinity,
                height: AppSizing.buttonHeight,
                child: OutlinedButton(
                  onPressed: cooldown.value > 0 || isSending.value
                      ? null
                      : handleResend,
                  child: Text(
                    cooldown.value > 0
                        ? '재발송 (${cooldown.value}초)'
                        : '인증 메일 재발송',
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                height: AppSizing.buttonHeight,
                child: ElevatedButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('로그인으로 돌아가기'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
