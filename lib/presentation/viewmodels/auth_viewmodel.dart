import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:moniq/data/providers/auth_providers.dart';
import 'package:moniq/data/providers/home_cache_providers.dart';
import 'package:moniq/data/providers/settings_providers.dart';
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

  Future<void> signInWithApple() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final response = await _repository.signInWithApple();
      return response.user;
    });
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    try {
      await _repository.signOut();
      await _clearHomeCaches();
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> deleteAccount() async {
    state = const AsyncLoading();
    try {
      await _repository.deleteAccount();
      await _clearHomeCaches();
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  /// 로그아웃/계정 삭제 시 로컬 홈 캐시를 폐기한다.
  /// 다음 로그인 사용자에게 이전 사용자의 근무가 보이면 안 된다.
  Future<void> _clearHomeCaches() async {
    try {
      await clearHomeCaches(ref.read(sharedPreferencesProvider));
    } catch (e) {
      debugPrint('[cache] 홈 캐시 삭제 실패: $e');
    }
  }
}
