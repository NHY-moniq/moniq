import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/providers/auth_providers.dart';
import 'package:moniq/data/providers/notification_providers.dart';
import 'package:moniq/presentation/layout/adaptive_layout.dart';
import 'package:moniq/presentation/theme/shift_theme.dart';
import 'package:moniq/presentation/viewmodels/home_viewmodel.dart';
import 'package:moniq/presentation/widgets/common/moniq_app_bar.dart';
import 'package:moniq/core/utils/perf_trace.dart';
import 'package:moniq/presentation/widgets/common/moniq_error_view.dart';
import 'package:moniq/presentation/widgets/common/moniq_skeleton.dart';
import 'package:moniq/presentation/screens/home/home_body.dart';
import 'package:moniq/presentation/screens/home/home_widgets.dart';

// ── Screen ──

class HomeScreen extends HookConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendarAsync = ref.watch(homeViewModelProvider);
    final shiftTheme = ref.watch(todayShiftThemeProvider);

    final currentUser = ref.watch(currentUserProvider);
    final userMeta = currentUser?.userMetadata;
    final displayName = userMeta?['display_name'] as String?;
    final avatarUrl = userMeta?['avatar_url'] as String?;

    PreferredSizeWidget buildAppBar() {
      return MoniqAppBar(
        title: 'OnorOff',
        showBack: false,
        leading: GestureDetector(
          onTap: (avatarUrl != null && avatarUrl.isNotEmpty)
              ? () => _showAvatarDialog(context, avatarUrl)
              : null,
          child: HomeAvatar(
            url: avatarUrl,
            ringColor: shiftTheme.primary,
          ),
        ),
        trailing: _NotificationsBellButton(),
      );
    }

    return calendarAsync.when(
      // 백그라운드 갱신 중에는 이미 그려진 화면을 유지한다 (stale-while-revalidate).
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: () => Scaffold(
        backgroundColor: shiftTheme.scaffoldBackground,
        appBar: AdaptiveLayout.isWide(context)
            ? null
            : buildAppBar(),
        // 캐시가 없는 첫 실행에서만 도달 — 스피너 대신 화면 뼈대를 보여준다.
        body: const MoniqHomeSkeleton(),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: shiftTheme.scaffoldBackground,
        appBar: AdaptiveLayout.isWide(context)
            ? null
            : buildAppBar(),
        body: MoniqErrorView(
          message: '일정을 불러올 수 없습니다',
          onRetry: () => ref.read(homeViewModelProvider.notifier).refresh(),
        ),
      ),
      data: (state) {
        PerfTrace.mark('home first paint');
        return Scaffold(
          backgroundColor: shiftTheme.scaffoldBackground,
          appBar: AdaptiveLayout.isWide(context)
              ? null
              : buildAppBar(),
          body: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 120),
            child: HomeBody(
              displayName: displayName,
              monthlyShifts: state.monthlyShifts,
              shiftTheme: shiftTheme,
            ),
          ),
        );
      },
    );
  }

  void _showAvatarDialog(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: GestureDetector(
          onTap: () => Navigator.pop(ctx),
          child: CircleAvatar(
            radius: 100,
            backgroundColor:
                Theme.of(context).colorScheme.primaryContainer,
            backgroundImage: CachedNetworkImageProvider(url),
          ),
        ),
      ),
    );
  }
}

/// 홈 AppBar의 종 아이콘 — 읽지 않은 알림 수 뱃지 + 탭 시 /notifications 이동.
class _NotificationsBellButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationCountProvider).valueOrNull ?? 0;
    final cs = Theme.of(context).colorScheme;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: Icon(
            Icons.notifications_outlined,
            color: cs.onSurfaceVariant,
          ),
          onPressed: () {
            context.push('/notifications');
          },
        ),
        if (unread > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 5,
                vertical: 1,
              ),
              decoration: BoxDecoration(
                color: cs.error,
                borderRadius: BorderRadius.circular(999),
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                unread > 99 ? '99+' : '$unread',
                style: TextStyle(
                  color: cs.onError,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
