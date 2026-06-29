import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:moniq/core/constants/google_auth_constants.dart';
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

    final iosClientId = GoogleAuthConstants.iosClientId;
    final webClientId = GoogleAuthConstants.webClientId;
    if (iosClientId.isEmpty || webClientId.isEmpty) {
      throw const AuthException(
        'Google 로그인 설정이 누락되었습니다. .env의 '
        'GOOGLE_IOS_CLIENT_ID / GOOGLE_WEB_CLIENT_ID를 확인하세요.',
      );
    }

    // clientId: iOS 클라이언트 / serverClientId: Supabase에 등록된 Web 클라이언트.
    // serverClientId가 있어야 idToken의 audience가 Supabase 기대값과 일치한다.
    final googleSignIn = GoogleSignIn(
      clientId: iosClientId,
      serverClientId: webClientId,
      scopes: const ['email', 'profile', 'openid'],
    );

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
  // 네이티브(iOS/macOS)는 Apple 자격증명을 직접 받아 nonce 검증과 함께
  // Supabase signInWithIdToken으로 교환한다. 웹은 OAuth 리다이렉트 사용.
  Future<AuthResponse> signInWithApple() async {
    if (kIsWeb) {
      final launched = await _auth.signInWithOAuth(
        OAuthProvider.apple,
        redirectTo: '${Uri.base.origin}/login',
      );

      if (!launched) {
        throw const AuthException('Apple 로그인 페이지를 열 수 없습니다');
      }

      // 웹 OAuth는 리다이렉트 기반이므로 결과는 authStateChanges에서 반영된다.
      return AuthResponse(
        session: _auth.currentSession,
        user: _auth.currentUser,
      );
    }

    // raw nonce를 만들고, Apple에는 SHA-256 해시를 전달한다.
    final rawNonce = _generateRawNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );

    final idToken = credential.identityToken;
    if (idToken == null) {
      throw const AuthException('Apple ID 토큰을 가져올 수 없습니다');
    }

    final response = await _auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: idToken,
      nonce: rawNonce,
    );

    // 계정 삭제 시 Apple 토큰 폐기를 위해 refresh token을 서버에 저장한다.
    // (저장 실패가 로그인 자체를 막지 않도록 best-effort 처리)
    final authCode = credential.authorizationCode;
    if (authCode.isNotEmpty) {
      try {
        await _client.functions.invoke(
          'apple-account',
          body: {
            'action': 'store',
            'authorizationCode': authCode,
            'appleSub': credential.userIdentifier,
          },
        );
      } catch (_) {
        // ignore
      }
    }

    return response;
  }

  String _generateRawNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  // Kakao Sign-In (via Edge Function)
  // Supabase OAuth 기반. 실제 동작에는 Supabase Dashboard의 Kakao provider 설정이 필요하다.
  Future<void> signInWithKakao() async {
    final launched = await _auth.signInWithOAuth(
      OAuthProvider.kakao,
      redirectTo: kIsWeb
          ? '${Uri.base.origin}/login'
          : 'com.moniq.moniq://login-callback',
      // 인앱 브라우저(SFSafariViewController)는 콜백 후 자동으로 닫히지 않아
      // 외부 브라우저로 띄운다. 리다이렉트 시 앱으로 자동 복귀하고 브라우저는
      // 백그라운드로 빠지므로 시트가 앱 위에 남지 않는다.
      authScreenLaunchMode:
          kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
    );

    if (!launched) {
      throw const AuthException('카카오 로그인 페이지를 열 수 없습니다');
    }
  }

  // Email verification
  Future<void> resendVerificationEmail(String email) async {
    await _auth.resend(type: OtpType.signup, email: email);
  }

  // Account deletion
  Future<void> deleteAccount() async {
    // Apple 로그인 사용자는 삭제 전에 Apple 토큰을 폐기한다.
    // (refresh token 조회에 유효한 세션이 필요하므로 계정 삭제보다 먼저 수행)
    // Apple 미사용자는 Edge Function이 no-op으로 통과한다.
    try {
      await _client.functions.invoke(
        'apple-account',
        body: {'action': 'revoke'},
      );
    } catch (_) {
      // 폐기 실패가 계정 삭제를 막지 않도록 한다.
    }

    await _client.rpc('delete_my_account');
    try {
      await _auth.signOut();
    } catch (_) {
      // Session may already be invalidated after user deletion.
    }
  }

  // Sign Out
  Future<void> signOut() async {
    await _auth.signOut(scope: SignOutScope.local);
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
    final result = await _client.rpc(
      'check_nickname_duplicate',
      params: {'p_nickname': nickname},
    );
    return result as bool;
  }

  Future<String> uploadAvatar(Uint8List bytes, String fileName) async {
    final userId = _auth.currentUser!.id;
    final path = '$userId/$fileName';

    await _client.storage
        .from('avatars')
        .uploadBinary(
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
