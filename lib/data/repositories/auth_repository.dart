import 'dart:typed_data';

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
    return _dataSource.signInWithEmail(email: email, password: password);
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

  Future<void> signInWithKakao() {
    return _dataSource.signInWithKakao();
  }

  Future<AuthResponse> signInWithApple() {
    return _dataSource.signInWithApple();
  }

  Future<void> resendVerificationEmail(String email) {
    return _dataSource.resendVerificationEmail(email);
  }

  Future<void> signOut() {
    return _dataSource.signOut();
  }

  Future<UserResponse> updateProfile({
    String? displayName,
    String? avatarUrl,
  }) {
    return _dataSource.updateProfile(
      displayName: displayName,
      avatarUrl: avatarUrl,
    );
  }

  Future<bool> checkNicknameDuplicate(String nickname) {
    return _dataSource.checkNicknameDuplicate(nickname);
  }

  Future<String> uploadAvatar(Uint8List bytes, String fileName) {
    return _dataSource.uploadAvatar(bytes, fileName);
  }

  Future<void> deleteAccount() {
    return _dataSource.deleteAccount();
  }

  User? get currentUser => _dataSource.currentUser;

  Session? get currentSession => _dataSource.currentSession;

  Stream<AuthState> get authStateChanges => _dataSource.authStateChanges;
}
