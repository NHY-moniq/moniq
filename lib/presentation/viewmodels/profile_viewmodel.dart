import 'dart:typed_data';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/providers/auth_providers.dart';
import 'package:moniq/data/repositories/auth_repository.dart';

// Profile state
class ProfileState {
  const ProfileState({
    this.displayName,
    this.avatarUrl,
    this.isLoading = false,
    this.isSaving = false,
    this.isCheckingNickname = false,
    this.isNicknameDuplicate,
    this.error,
    this.savedSuccessfully = false,
  });

  final String? displayName;
  final String? avatarUrl;
  final bool isLoading;
  final bool isSaving;
  final bool isCheckingNickname;
  final bool? isNicknameDuplicate;
  final String? error;
  final bool savedSuccessfully;

  ProfileState copyWith({
    String? displayName,
    String? avatarUrl,
    bool? isLoading,
    bool? isSaving,
    bool? isCheckingNickname,
    bool? isNicknameDuplicate,
    String? error,
    bool? savedSuccessfully,
    bool clearError = false,
    bool clearNicknameCheck = false,
  }) {
    return ProfileState(
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      isCheckingNickname: isCheckingNickname ?? this.isCheckingNickname,
      isNicknameDuplicate:
          clearNicknameCheck ? null : (isNicknameDuplicate ?? this.isNicknameDuplicate),
      error: clearError ? null : (error ?? this.error),
      savedSuccessfully: savedSuccessfully ?? this.savedSuccessfully,
    );
  }
}

final profileViewModelProvider =
    AutoDisposeNotifierProvider<ProfileViewModel, ProfileState>(
  ProfileViewModel.new,
);

class ProfileViewModel extends AutoDisposeNotifier<ProfileState> {
  late AuthRepository _repository;

  @override
  ProfileState build() {
    _repository = ref.watch(authRepositoryProvider);
    final user = _repository.currentUser;
    final metadata = user?.userMetadata;

    return ProfileState(
      displayName: metadata?['display_name'] as String?,
      avatarUrl: metadata?['avatar_url'] as String?,
    );
  }

  Future<void> checkNicknameDuplicate(String nickname) async {
    if (nickname.isEmpty) {
      state = state.copyWith(clearNicknameCheck: true);
      return;
    }

    // Skip check if nickname hasn't changed
    final currentName = _repository.currentUser?.userMetadata?['display_name'] as String?;
    if (nickname == currentName) {
      state = state.copyWith(isNicknameDuplicate: false);
      return;
    }

    state = state.copyWith(isCheckingNickname: true, clearNicknameCheck: true);
    try {
      final isDuplicate = await _repository.checkNicknameDuplicate(nickname);
      state = state.copyWith(
        isCheckingNickname: false,
        isNicknameDuplicate: isDuplicate,
      );
    } catch (e) {
      state = state.copyWith(
        isCheckingNickname: false,
        error: '닉네임 확인 중 오류가 발생했습니다',
      );
    }
  }

  Future<void> uploadAvatar(Uint8List bytes, String fileName) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final url = await _repository.uploadAvatar(bytes, fileName);
      final response = await _repository.updateProfile(avatarUrl: url);
      state = state.copyWith(
        isLoading: false,
        avatarUrl: response.user?.userMetadata?['avatar_url'] as String? ?? url,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '이미지 업로드에 실패했습니다',
      );
    }
  }

  Future<void> saveProfile(String displayName) async {
    state = state.copyWith(isSaving: true, clearError: true, savedSuccessfully: false);
    try {
      await _repository.updateProfile(displayName: displayName);
      state = state.copyWith(
        isSaving: false,
        displayName: displayName,
        savedSuccessfully: true,
      );
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        error: '프로필 저장에 실패했습니다',
      );
    }
  }
}
