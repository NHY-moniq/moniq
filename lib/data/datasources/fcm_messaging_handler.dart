import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// 백그라운드 푸시 핸들러는 top-level 함수여야 한다 (Firebase 요구).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // 백그라운드/종료 상태에서는 시스템이 notification 페이로드를 자동 표시하므로
  // 별도 작업이 필요 없다. data-only 메시지를 처리하려면 여기서 분기.
}

/// 포그라운드 / 탭 / 백그라운드 메시지 처리 통합.
///
/// 호출 시점: Firebase.initializeApp() 직후 1회.
class FcmMessagingHandler {
  FcmMessagingHandler._();
  static final instance = FcmMessagingHandler._();

  final _localNotifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// 안드로이드 포그라운드 알림 채널 (FCM이 자동으로 사용)
  static const _androidChannel = AndroidNotificationChannel(
    'moniq_push',
    'Moniq 푸시 알림',
    description: '팀/근무 변경 등 실시간 알림',
    importance: Importance.high,
  );

  Future<void> initialize() async {
    if (_initialized) return;
    if (kIsWeb) {
      _initialized = true;
      return;
    }

    // 1) 안드로이드 채널 등록 (앱 첫 실행 시)
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);

    // 2) iOS 포그라운드 표시 옵션 (배너/소리/뱃지)
    if (Platform.isIOS) {
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    // 3) 백그라운드 핸들러 등록
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 4) 포그라운드 메시지: 안드로이드는 시스템이 표시하지 않으므로 직접 표시
    FirebaseMessaging.onMessage.listen(_showLocalFromRemote);

    // 5) 알림 탭으로 앱이 열렸을 때
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // 6) 종료 상태에서 알림 탭으로 앱이 열린 경우
    final initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    _initialized = true;
  }

  Future<void> _showLocalFromRemote(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    // 안드로이드는 포그라운드에서 자동 표시되지 않음 → 로컬 알림으로 대체
    if (!Platform.isAndroid) return;

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: _encodePayload(message.data),
    );
  }

  /// 외부에서 탭 핸들러를 주입할 수 있도록 콜백 노출.
  /// (예: GoRouter 인스턴스에 접근하여 특정 라우트로 이동)
  void Function(RemoteMessage)? onTap;

  void _handleNotificationTap(RemoteMessage message) {
    // 앱 내 라우팅이 필요해지면 여기서 GoRouter로 deep link 처리.
    onTap?.call(message);
  }

  String _encodePayload(Map<String, dynamic> data) {
    if (data.isEmpty) return '';
    return data.entries.map((e) => '${e.key}=${e.value}').join('&');
  }
}
