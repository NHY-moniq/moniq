import 'package:moniq/data/models/notification_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationRepository {
  NotificationRepository({required SupabaseClient client}) : _client = client;

  final SupabaseClient _client;

  String? get _userId => _client.auth.currentUser?.id;

  /// 30일 이전 알림은 자동 만료. 클라이언트에서 노출/카운트 모두 cutoff 적용.
  static const _retentionDays = 30;

  DateTime get _cutoff =>
      DateTime.now().toUtc().subtract(const Duration(days: _retentionDays));

  /// 본인 알림 최신순 조회 (기본 100건, 30일 이내).
  Future<List<NotificationModel>> getMyNotifications({int limit = 100}) async {
    if (_userId == null) return [];
    final rows = await _client
        .from('notifications')
        .select()
        .eq('user_id', _userId!)
        .gte('created_at', _cutoff.toIso8601String())
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .map((r) => NotificationModel.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// 읽지 않은 알림 개수 (종 아이콘 뱃지용, 30일 이내).
  Future<int> getUnreadCount() async {
    if (_userId == null) return 0;
    final rows = await _client
        .from('notifications')
        .select('id')
        .eq('user_id', _userId!)
        .gte('created_at', _cutoff.toIso8601String())
        .isFilter('read_at', null);
    return (rows as List).length;
  }

  Future<void> markAsRead(String notificationId) async {
    await _client
        .from('notifications')
        .update({'read_at': DateTime.now().toIso8601String()})
        .eq('id', notificationId);
  }

  Future<void> markAllAsRead() async {
    if (_userId == null) return;
    await _client
        .from('notifications')
        .update({'read_at': DateTime.now().toIso8601String()})
        .eq('user_id', _userId!)
        .isFilter('read_at', null);
  }

  Future<void> delete(String notificationId) async {
    await _client.from('notifications').delete().eq('id', notificationId);
  }
}
