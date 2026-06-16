import 'dart:typed_data';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/providers/auth_providers.dart' show authRepositoryProvider, userProfileVersionProvider;
import 'package:moniq/data/repositories/auth_repository.dart';

// Profile state
class ProfileState {
  const ProfileState({
    this.displayName,
    this.avatarUrl,
    this.pendingAvatarBytes,
    this.pendingAvatarFileName,
    this.avatarCleared = false,
    this.isLoading = false,
    this.isSaving = false,
    this.isCheckingNickname = false,
    this.isNicknameDuplicate,
    this.error,
    this.savedSuccessfully = false,
  });

  final String? displayName;

  /// 서버에 저장된 현재 아바타 URL.
  final String? avatarUrl;

  /// 저장 전 선택한(아직 업로드하지 않은) 새 아바타 바이트. null이면 변경 없음.
  final Uint8List? pendingAvatarBytes;
  final String? pendingAvatarFileName;

  /// 저장 시 기본 이미지(없음)로 되돌릴지 여부 (보류 상태).
  final bool avatarCleared;

  final bool isLoading;
  final bool isSaving;
  final bool isCheckingNickname;
  final bool? isNicknameDuplicate;
  final String? error;
  final bool savedSuccessfully;

  /// 저장 시 적용해야 할 아바타 변경이 보류 중인지.
  bool get hasPendingAvatar => pendingAvatarBytes != null || avatarCleared;

  ProfileState copyWith({
    String? displayName,
    String? avatarUrl,
    Uint8List? pendingAvatarBytes,
    String? pendingAvatarFileName,
    bool? avatarCleared,
    bool? isLoading,
    bool? isSaving,
    bool? isCheckingNickname,
    bool? isNicknameDuplicate,
    String? error,
    bool? savedSuccessfully,
    bool clearError = false,
    bool clearNicknameCheck = false,
    bool clearPendingAvatar = false,
  }) {
    return ProfileState(
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      pendingAvatarBytes: clearPendingAvatar
          ? null
          : (pendingAvatarBytes ?? this.pendingAvatarBytes),
      pendingAvatarFileName: clearPendingAvatar
          ? null
          : (pendingAvatarFileName ?? this.pendingAvatarFileName),
      avatarCleared: avatarCleared ?? this.avatarCleared,
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

  /// 새 아바타를 미리보기로만 선택(보류). 저장 시 업로드된다.
  void selectAvatar(Uint8List bytes, String fileName) {
    state = state.copyWith(
      pendingAvatarBytes: bytes,
      pendingAvatarFileName: fileName,
      avatarCleared: false,
      clearError: true,
    );
  }

  /// 기본 이미지(없음)로 되돌리기를 보류 선택. 저장 시 적용된다.
  void markAvatarDefault() {
    state = state.copyWith(
      avatarCleared: true,
      clearPendingAvatar: true,
      clearError: true,
    );
  }

  Future<void> saveProfile(String displayName) async {
    state = state.copyWith(isSaving: true, clearError: true, savedSuccessfully: false);
    try {
      // 보류 중인 아바타 변경을 저장 시점에 함께 반영한다.
      // null = 변경 없음, '' = 기본 이미지로, 그 외 = 새 업로드 URL.
      String? newAvatarUrl;
      if (state.pendingAvatarBytes != null) {
        newAvatarUrl = await _repository.uploadAvatar(
          state.pendingAvatarBytes!,
          state.pendingAvatarFileName!,
        );
      } else if (state.avatarCleared) {
        newAvatarUrl = '';
      }

      await _repository.updateProfile(
        displayName: displayName,
        avatarUrl: newAvatarUrl,
      );
      // Bump version so currentUserProvider re-reads the updated user
      ref.read(userProfileVersionProvider.notifier).state++;
      state = state.copyWith(
        isSaving: false,
        displayName: displayName,
        avatarUrl: newAvatarUrl ?? state.avatarUrl,
        avatarCleared: false,
        clearPendingAvatar: true,
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
