import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:moniq/data/datasources/auth_remote_data_source.dart';

class AuthRepository {
  AuthRepository({required AuthRemoteDataSource dataSource})
      : _dataSource = dataSource;

  final AuthRemoteDataSource _dataSource;

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _dataSource.signInWithEmail(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) {
    return _dataSource.signUpWithEmail(
      email: email,
      password: password,
      displayName: displayName,
    );
  }

  Future<void> resetPassword(String email) {
    return _dataSource.resetPassword(email);
  }

  Future<AuthResponse> signInWithGoogle() {
    return _dataSource.signInWithGoogle();
  }

  Future<AuthResponse> signInWithApple() {
    return _dataSource.signInWithApple();
  }

  Future<void> signInWithKakao() {
    return _dataSource.signInWithKakao();
  }

  Future<void> signOut() {
    return _dataSource.signOut();
  }

  User? get currentUser => _dataSource.currentUser;

  Session? get currentSession => _dataSource.currentSession;

  Stream<AuthState> get authStateChanges => _dataSource.authStateChanges;
}
