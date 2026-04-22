import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/models/notification_model.dart';
import 'package:moniq/data/providers/supabase_providers.dart';
import 'package:moniq/data/repositories/notification_repository.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(client: ref.watch(supabaseClientProvider));
});

/// 내 알림 리스트 (최신 100건).
final myNotificationsProvider =
    FutureProvider<List<NotificationModel>>((ref) async {
  ref.watch(authStateChangesProvider);
  final repo = ref.watch(notificationRepositoryProvider);
  return repo.getMyNotifications();
});

/// 읽지 않은 알림 수 (종 아이콘 뱃지용).
final unreadNotificationCountProvider = FutureProvider<int>((ref) async {
  ref.watch(authStateChangesProvider);
  final repo = ref.watch(notificationRepositoryProvider);
  return repo.getUnreadCount();
});
