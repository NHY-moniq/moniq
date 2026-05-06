import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// FCM 푸시 토큰을 발급받아 users.fcm_token에 저장한다.
///
/// 호출 시점:
/// - 앱 시작 후 로그인 직후 ([syncTokenForCurrentUser])
/// - 토큰 갱신 시 자동 ([listenForRefresh])
class FcmTokenService {
  FcmTokenService._();
  static final instance = FcmTokenService._();

  StreamSubscription<String>? _refreshSub;

  /// 알림 권한 요청 + 토큰 발급 + DB 저장.
  /// 로그인되지 않은 상태면 스킵. 시뮬레이터에서 APNs 토큰이 영원히 안 와서
  /// hang하는 경우를 대비해 모든 await에 timeout을 둔다.
  Future<void> syncTokenForCurrentUser() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        debugPrint('[fcm] 로그인 안됨 → 토큰 발급 스킵');
        return;
      }
      debugPrint('[fcm] 토큰 동기화 시작 user=${user.id}');

      final messaging = FirebaseMessaging.instance;

      // iOS 알림 권한 (다이얼로그) — timeout 5초
      try {
        final settings = await messaging
            .requestPermission(alert: true, badge: true, sound: true)
            .timeout(const Duration(seconds: 5));
        debugPrint('[fcm] 권한 상태=${settings.authorizationStatus}');
      } catch (e) {
        debugPrint('[fcm] 권한 요청 실패: $e');
      }

      // APNs 토큰 (시뮬레이터에선 절대 안 옴 → timeout 3초)
      try {
        final apns = await messaging
            .getAPNSToken()
            .timeout(const Duration(seconds: 3));
        debugPrint('[fcm] APNs 토큰=${apns?.substring(0, 16) ?? "null"}...');
      } catch (e) {
        debugPrint('[fcm] APNs 토큰 조회 실패(iOS만 의미있음): $e');
      }

      // FCM 토큰 — timeout 5초
      String? token;
      try {
        token = await messaging
            .getToken()
            .timeout(const Duration(seconds: 5));
        debugPrint('[fcm] FCM 토큰 발급=${token?.substring(0, 24) ?? "null"}...');
      } catch (e) {
        debugPrint('[fcm] FCM 토큰 발급 실패: $e');
      }
      if (token == null || token.isEmpty) {
        debugPrint('[fcm] 토큰 비어있음 → DB 저장 스킵');
        return;
      }

      await _saveToken(user.id, token);
      debugPrint('[fcm] DB 저장 완료');
    } catch (e) {
      debugPrint('[fcm] syncTokenForCurrentUser 예외: $e');
    }
  }

  /// 토큰 갱신 이벤트 구독. main.dart에서 1회 호출.
  void listenForRefresh() {
    _refreshSub?.cancel();
    _refreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null || token.isEmpty) return;
      _saveToken(user.id, token);
    });
  }

  Future<void> _saveToken(String userId, String token) async {
    try {
      await Supabase.instance.client
          .from('users')
          .update({'fcm_token': token}).eq('id', userId);
    } catch (_) {}
  }

  /// 로그아웃 시 호출 권장 — 토큰 비우기.
  Future<void> clearTokenForCurrentUser() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      await Supabase.instance.client
          .from('users')
          .update({'fcm_token': null}).eq('id', user.id);
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
  }
}
