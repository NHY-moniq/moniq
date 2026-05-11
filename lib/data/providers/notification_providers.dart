import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/models/notification_model.dart';
import 'package:moniq/data/providers/supabase_providers.dart';
import 'package:moniq/data/repositories/notification_repository.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(client: ref.watch(supabaseClientProvider));
});

/// 내 알림 리스트 (최신 100건, 30일 이내).
final myNotificationsProvider =
    FutureProvider<List<NotificationModel>>((ref) async {
  ref.watch(authStateChangesProvider);
  final repo = ref.watch(notificationRepositoryProvider);
  return repo.getMyNotifications();
});

/// 읽지 않은 알림 수 (종 아이콘 뱃지용, 30일 이내).
final unreadNotificationCountProvider = FutureProvider<int>((ref) async {
  ref.watch(authStateChangesProvider);
  final repo = ref.watch(notificationRepositoryProvider);
  return repo.getUnreadCount();
});

/// 알림함 화면용 — 선택된 팀 필터 (null = 전체)
final selectedNotificationTeamFilterProvider =
    StateProvider<String?>((_) => null);

/// 알림함 화면용 — 안 읽음만 보기 토글
final notificationUnreadOnlyProvider = StateProvider<bool>((_) => false);

/// 알림함 화면용 — 팀/읽음 필터가 적용된 리스트
final filteredNotificationsProvider =
    FutureProvider<List<NotificationModel>>((ref) async {
  final teamId = ref.watch(selectedNotificationTeamFilterProvider);
  final unreadOnly = ref.watch(notificationUnreadOnlyProvider);
  final all = await ref.watch(myNotificationsProvider.future);
  return all.where((n) {
    if (teamId != null && n.teamId != teamId) return false;
    if (unreadOnly && n.isRead) return false;
    return true;
  }).toList();
});
