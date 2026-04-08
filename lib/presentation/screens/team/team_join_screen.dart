import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/providers/team_providers.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/team_calendar_viewmodel.dart';
import 'package:moniq/presentation/viewmodels/team_viewmodel.dart';

class TeamJoinScreen extends HookConsumerWidget {
  const TeamJoinScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final codeController = useTextEditingController();
    final formKey = useMemoized(GlobalKey<FormState>.new);
    final isLoading = useState(false);
    final errorMessage = useState<String?>(null);

    Future<void> handleJoin() async {
      if (!formKey.currentState!.validate()) return;
      errorMessage.value = null;
      isLoading.value = true;
      try {
        final result = await ref
            .read(teamViewModelProvider.notifier)
            .joinTeam(codeController.text.trim());

        // 즐겨찾기 팀이 없으면 참여한 팀을 즐겨찾기로 설정
        final teamId = result['team_id'] as String?;
        if (teamId != null) {
          final teamRepo = ref.read(teamRepositoryProvider);
          final favorite = await teamRepo.getFavoriteTeam();
          if (favorite == null) {
            await teamRepo.setFavoriteTeam(teamId);
            ref.invalidate(favoriteTeamProvider);
          }
        }

        if (context.mounted) {
          final teamName = result['team_name'] as String? ?? '팀';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$teamName에 참여했습니다!')),
          );
          context.go('/teams');
        }
      } catch (e) {
        errorMessage.value = e.toString();
      } finally {
        isLoading.value = false;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('팀 참여'),
      ),
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.screenAll,
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.xxl),
                Text(
                  '팀 관리자에게 받은\n초대 코드를 입력해주세요',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xxxl),

                // Error message
                if (errorMessage.value != null) ...[
                  SelectableText.rich(
                    TextSpan(
                      text: errorMessage.value,
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .error,
                      ),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],

                // Invite code field
                TextFormField(
                  controller: codeController,
                  decoration: const InputDecoration(
                    labelText: '초대 코드',
                    hintText: '코드를 입력하세요',
                    prefixIcon: Icon(Icons.vpn_key_outlined),
                  ),
                  textInputAction: TextInputAction.done,
                  textCapitalization: TextCapitalization.none,
                  onFieldSubmitted: (_) => handleJoin(),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '초대 코드를 입력해주세요';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.xxl),

                // Join button
                ElevatedButton(
                  onPressed: isLoading.value ? null : handleJoin,
                  child: isLoading.value
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimary,
                          ),
                        )
                      : const Text('참여하기'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
