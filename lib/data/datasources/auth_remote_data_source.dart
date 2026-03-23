import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRemoteDataSource {
  AuthRemoteDataSource({
    required GoTrueClient auth,
    required SupabaseClient client,
  }) : _auth = auth,
       _client = client;

  final GoTrueClient _auth;
  final SupabaseClient _client;

  // Email / Password
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return _auth.signInWithPassword(email: email, password: password);
  }

  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    return _auth.signUp(
      email: email,
      password: password,
      data: {'display_name': displayName},
    );
  }

  Future<void> resetPassword(String email) async {
    await _auth.resetPasswordForEmail(email);
  }

  // Google Sign-In
  Future<AuthResponse> signInWithGoogle() async {
    if (kIsWeb) {
      final launched = await _auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: '${Uri.base.origin}/login',
      );

      if (!launched) {
        throw const AuthException('Google 로그인 페이지를 열 수 없습니다');
      }

      // 웹 OAuth는 리다이렉트 기반이므로 결과는 authStateChanges에서 반영된다.
      return AuthResponse(
        session: _auth.currentSession,
        user: _auth.currentUser,
      );
    }

    final googleSignIn = GoogleSignIn(scopes: ['email', 'profile', 'openid']);

    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) {
      throw const AuthException('Google 로그인이 취소되었습니다');
    }

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    final accessToken = googleAuth.accessToken;

    if (idToken == null) {
      throw const AuthException('Google ID 토큰을 가져올 수 없습니다');
    }

    return _auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
  }

  // Apple Sign-In
  Future<AuthResponse> signInWithApple() async {
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );

    final idToken = credential.identityToken;
    if (idToken == null) {
      throw const AuthException('Apple ID 토큰을 가져올 수 없습니다');
    }

    return _auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: idToken,
    );
  }

  // Kakao Sign-In (via Edge Function)
  // Supabase OAuth 기반. 실제 동작에는 Supabase Dashboard의 Kakao provider 설정이 필요하다.
  Future<void> signInWithKakao() async {
    final launched = await _auth.signInWithOAuth(
      OAuthProvider.kakao,
      redirectTo: kIsWeb ? '${Uri.base.origin}/login' : null,
    );

    if (!launched) {
      throw const AuthException('카카오 로그인 페이지를 열 수 없습니다');
    }
  }

  // Account deletion
  Future<void> deleteAccount() async {
    await _client.rpc('delete_my_account');
    try {
      await _auth.signOut();
    } catch (_) {
      // Session may already be invalidated after user deletion.
    }
  }

  // Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Profile
  Future<UserResponse> updateProfile({
    String? displayName,
    String? avatarUrl,
  }) async {
    final data = <String, dynamic>{};
    if (displayName != null) data['display_name'] = displayName;
    if (avatarUrl != null) data['avatar_url'] = avatarUrl;

    return _auth.updateUser(UserAttributes(data: data));
  }

  Future<bool> checkNicknameDuplicate(String nickname) async {
    final result = await _client.rpc('check_nickname_duplicate', params: {
      'p_nickname': nickname,
    });
    return result as bool;
  }

  Future<String> uploadAvatar(Uint8List bytes, String fileName) async {
    final userId = _auth.currentUser!.id;
    final path = '$userId/$fileName';

    await _client.storage.from('avatars').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );

    return _client.storage.from('avatars').getPublicUrl(path);
  }

  // Current user
  User? get currentUser => _auth.currentUser;

  Session? get currentSession => _auth.currentSession;

  Stream<AuthState> get authStateChanges => _auth.onAuthStateChange;
}
