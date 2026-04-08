import 'package:supabase_flutter/supabase_flutter.dart';

/// FCM 푸시 발송 (Edge Function 'send-push' 호출).
///
/// 로컬 알림(NotificationService)과 별도이며, 다른 사용자 기기에 도달한다.
/// 발송 실패는 호출부에서 무시 가능 (메인 동작 차단 금지).
class PushService {
  PushService._();
  static final instance = PushService._();

  SupabaseClient get _client => Supabase.instance.client;

  /// 팀 멤버 전원에게 푸시 발송. [excludeSelf]가 true이면 발신자 본인 제외.
  Future<void> sendToTeam({
    required String teamId,
    required String title,
    required String body,
    bool excludeSelf = true,
    Map<String, String>? data,
  }) async {
    final selfId = _client.auth.currentUser?.id;
    await _invoke({
      'teamId': teamId,
      if (excludeSelf && selfId != null) 'excludeUserId': selfId,
      'title': title,
      'body': body,
      if (data != null) 'data': data,
    });
  }

  /// 특정 사용자들에게 푸시 발송.
  Future<void> sendToUsers({
    required List<String> userIds,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    if (userIds.isEmpty) return;
    await _invoke({
      'userIds': userIds,
      'title': title,
      'body': body,
      if (data != null) 'data': data,
    });
  }

  Future<void> _invoke(Map<String, dynamic> payload) async {
    try {
      await _client.functions.invoke('send-push', body: payload);
    } catch (_) {
      // 푸시 실패는 침묵 — 메인 동작 보장
    }
  }
}
