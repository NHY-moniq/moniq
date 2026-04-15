import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:moniq/data/providers/auth_providers.dart';
import 'package:moniq/data/repositories/auth_repository.dart';

final authViewModelProvider = AsyncNotifierProvider<AuthViewModel, User?>(
  AuthViewModel.new,
);

class AuthViewModel extends AsyncNotifier<User?> {
  late AuthRepository _repository;

  @override
  Future<User?> build() async {
    _repository = ref.watch(authRepositoryProvider);
    return _repository.currentUser;
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final response = await _repository.signInWithEmail(
        email: email,
        password: password,
      );
      return response.user;
    });
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final response = await _repository.signUpWithEmail(
        email: email,
        password: password,
        displayName: displayName,
      );
      return response.user;
    });
  }

  Future<void> resetPassword(String email) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repository.resetPassword(email);
      return _repository.currentUser;
    });
  }

  Future<AuthResponse> signUpWithEmailRaw({
    required String email,
    required String password,
    required String displayName,
  }) {
    return _repository.signUpWithEmail(
      email: email,
      password: password,
      displayName: displayName,
    );
  }

  Future<void> resendVerificationEmail(String email) async {
    await _repository.resendVerificationEmail(email);
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final response = await _repository.signInWithGoogle();
      return response.user;
    });
  }

  Future<void> signInWithKakao() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repository.signInWithKakao();
      return _repository.currentUser;
    });
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repository.signOut();
      return null;
    });
  }

  Future<void> deleteAccount() async {
    state = const AsyncLoading();
    try {
      await _repository.deleteAccount();
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
}
