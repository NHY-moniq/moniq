import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/models/team_model.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/team_viewmodel.dart';

class TeamCreateScreen extends HookConsumerWidget {
  const TeamCreateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nameController = useTextEditingController();
    final descriptionController = useTextEditingController();
    final formKey = useMemoized(GlobalKey<FormState>.new);
    final isLoading = useState(false);
    final errorMessage = useState<String?>(null);
    final createdTeam = useState<TeamModel?>(null);
    final selectedIcon = useState<String>('groups');

    final iconOptions = [
      ('groups', Icons.groups),
      ('local_hospital', Icons.local_hospital),
      ('business', Icons.business),
      ('school', Icons.school),
      ('store', Icons.store),
      ('engineering', Icons.engineering),
    ];

    Future<void> handleCreate() async {
      if (!formKey.currentState!.validate()) return;
      errorMessage.value = null;
      isLoading.value = true;
      try {
        final team =
            await ref.read(teamViewModelProvider.notifier).createTeam(
                  name: nameController.text.trim(),
                  icon: selectedIcon.value,
                  description: descriptionController.text.trim().isNotEmpty
                      ? descriptionController.text.trim()
                      : null,
                );
        createdTeam.value = team;
      } catch (e) {
        errorMessage.value = e.toString();
      } finally {
        isLoading.value = false;
      }
    }

    // Success state: show invite code
    if (createdTeam.value != null) {
      final team = createdTeam.value!;
      return Scaffold(
        appBar: AppBar(
          title: const Text('팀 생성 완료'),
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: Padding(
            padding: AppSpacing.screenAll,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 72,
                  color: AppColors.success,
                ),
                const SizedBox(height: AppSpacing.xxl),
                Text(
                  '${team.name} 팀이 생성되었습니다!',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xxxl),

                // Invite code card
                Card(
                  child: Padding(
                    padding: AppSpacing.cardPadding,
                    child: Column(
                      children: [
                        Text(
                          '초대 코드',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        SelectableText(
                          team.inviteCode ?? '',
                          style: Theme.of(context)
                              .textTheme
                              .headlineLarge
                              ?.copyWith(
                                letterSpacing: 4,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        OutlinedButton.icon(
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(
                                text: team.inviteCode ?? '',
                              ),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('초대 코드가 복사되었습니다'),
                              ),
                            );
                          },
                          icon: const Icon(Icons.copy),
                          label: const Text('코드 복사'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxxl),

                ElevatedButton(
                  onPressed: () => context.go('/teams'),
                  child: const Text('팀으로 이동'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Create form
    return Scaffold(
      appBar: AppBar(
        title: const Text('팀 만들기'),
      ),
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
                      style: const TextStyle(color: AppColors.error),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],

                // Icon selection
                Text(
                  '팀 아이콘',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: iconOptions
                      .map(
                        (option) => ChoiceChip(
                          label: Icon(
                            option.$2,
                            color: selectedIcon.value == option.$1
                                ? AppColors.onPrimary
                                : null,
                          ),
                          selected: selectedIcon.value == option.$1,
                          selectedColor: AppColors.primary,
                          onSelected: (_) =>
                              selectedIcon.value = option.$1,
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: AppSpacing.xxl),

                // Team name
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '팀 이름',
                    hintText: '예: 내과 3병동',
                    prefixIcon: Icon(Icons.groups_outlined),
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '팀 이름을 입력해주세요';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),

                // Description
                TextFormField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: '설명 (선택)',
                    hintText: '팀에 대한 간단한 설명',
                    prefixIcon: Icon(Icons.description_outlined),
                  ),
                  maxLines: 3,
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: AppSpacing.xxxl),

                // Create button
                ElevatedButton(
                  onPressed: isLoading.value ? null : handleCreate,
                  child: isLoading.value
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('팀 만들기'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
