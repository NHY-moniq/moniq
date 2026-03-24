import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/profile_viewmodel.dart';

class ProfileEditScreen extends HookConsumerWidget {
  const ProfileEditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(profileViewModelProvider);
    final vm = ref.read(profileViewModelProvider.notifier);
    final theme = Theme.of(context);

    final nicknameController = useTextEditingController(
      text: profileState.displayName ?? '',
    );
    final debounceTimer = useRef<Timer?>(null);
    final hasChecked = useState(false);

    // Listen for save success
    ref.listen(profileViewModelProvider, (prev, next) {
      if (next.savedSuccessfully && !(prev?.savedSuccessfully ?? false)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('프로필이 저장되었습니다')),
        );
        context.go('/settings');
      }
      if (next.error != null && next.error != prev?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!)),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('프로필 편집'),
        actions: [
          TextButton(
            onPressed: profileState.isSaving ||
                    profileState.isNicknameDuplicate == true ||
                    profileState.isCheckingNickname
                ? null
                : () {
                    final name = nicknameController.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('닉네임을 입력해주세요')),
                      );
                      return;
                    }
                    if (!hasChecked.value) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('닉네임 중복확인을 해주세요')),
                      );
                      return;
                    }
                    vm.saveProfile(name);
                  },
            child: profileState.isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('저장'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.xl),

            // Avatar section
            _AvatarSection(
              avatarUrl: profileState.avatarUrl,
              isLoading: profileState.isLoading,
              onPickImage: () => _pickAndUploadImage(context, vm),
            ),

            const SizedBox(height: AppSpacing.xxxl),

            // Nickname section
            Text(
              '닉네임',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: nicknameController,
                    decoration: InputDecoration(
                      hintText: '닉네임을 입력해주세요',
                      suffixIcon: profileState.isCheckingNickname
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : profileState.isNicknameDuplicate == false
                              ? const Icon(Icons.check_circle, color: Colors.green)
                              : profileState.isNicknameDuplicate == true
                                  ? Icon(Icons.cancel, color: AppColors.error)
                                  : null,
                      errorText: profileState.isNicknameDuplicate == true
                          ? '이미 사용 중인 닉네임입니다'
                          : null,
                    ),
                    maxLength: 20,
                    onChanged: (_) {
                      hasChecked.value = false;
                      // Reset duplicate check state on change
                      debounceTimer.value?.cancel();
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: FilledButton.tonal(
                    onPressed: profileState.isCheckingNickname
                        ? null
                        : () {
                            final name = nicknameController.text.trim();
                            if (name.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('닉네임을 입력해주세요')),
                              );
                              return;
                            }
                            if (name.length < 2) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('닉네임은 2자 이상이어야 합니다')),
                              );
                              return;
                            }
                            hasChecked.value = true;
                            vm.checkNicknameDuplicate(name);
                          },
                    child: const Text('중복확인'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.sm),
            Text(
              '2~20자, 다른 사용자와 중복되지 않는 닉네임을 설정해주세요.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadImage(
    BuildContext context,
    ProfileViewModel vm,
  ) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );

    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final extension = picked.name.split('.').last;
    final fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.$extension';

    vm.uploadAvatar(bytes, fileName);
  }
}

class _AvatarSection extends StatelessWidget {
  const _AvatarSection({
    required this.avatarUrl,
    required this.isLoading,
    required this.onPickImage,
  });

  final String? avatarUrl;
  final bool isLoading;
  final VoidCallback onPickImage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        GestureDetector(
          onTap: isLoading ? null : onPickImage,
          child: Stack(
            children: [
              CircleAvatar(
                radius: 56,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                backgroundImage: avatarUrl != null && avatarUrl!.isNotEmpty
                    ? CachedNetworkImageProvider(avatarUrl!)
                    : null,
                child: avatarUrl == null || avatarUrl!.isEmpty
                    ? Icon(
                        Icons.person,
                        size: 56,
                        color: theme.colorScheme.onSurfaceVariant,
                      )
                    : null,
              ),
              if (isLoading)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black38,
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    ),
                  ),
                ),
              if (!isLoading)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.colorScheme.surface,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.camera_alt,
                      size: 18,
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '프로필 사진 변경',
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondaryLight,
          ),
        ),
      ],
    );
  }
}
