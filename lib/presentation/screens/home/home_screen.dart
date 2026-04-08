import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/providers/auth_providers.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/theme/shift_theme.dart';
import 'package:moniq/presentation/viewmodels/home_viewmodel.dart';
import 'package:moniq/presentation/widgets/common/moniq_error_view.dart';
import 'package:moniq/presentation/widgets/common/moniq_loading_view.dart';
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

    Widget buildAppBar() {
      return AppBar(
        backgroundColor: shiftTheme.background,
        surfaceTintColor: Colors.transparent,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: (avatarUrl != null && avatarUrl.isNotEmpty)
                  ? () => _showAvatarDialog(context, avatarUrl)
                  : null,
              child: HomeAvatar(
                url: avatarUrl,
                ringColor: shiftTheme.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              'OnorOff',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: shiftTheme.primary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.notifications_outlined,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            onPressed: () {},
          ),
          const SizedBox(width: 4),
        ],
      );
    }

    return calendarAsync.when(
      loading: () => Scaffold(
        backgroundColor: shiftTheme.background,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: buildAppBar(),
        ),
        body: const MoniqLoadingView(),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: shiftTheme.background,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: buildAppBar(),
        ),
        body: MoniqErrorView(
          message: '일정을 불러올 수 없습니다',
          onRetry: () => ref.read(homeViewModelProvider.notifier).refresh(),
        ),
      ),
      data: (state) {
        return Scaffold(
          backgroundColor: shiftTheme.background,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(kToolbarHeight),
            child: buildAppBar(),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HomeBody(
                  displayName: displayName,
                  monthlyShifts: state.monthlyShifts,
                  shiftTheme: shiftTheme,
                ),
              ],
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
