import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/providers/supabase_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moniq/presentation/router/app_shell.dart';
import 'package:moniq/presentation/screens/auth/forgot_password_screen.dart';
import 'package:moniq/presentation/screens/auth/login_screen.dart';
import 'package:moniq/presentation/screens/auth/email_verification_screen.dart';
import 'package:moniq/presentation/screens/auth/signup_screen.dart';
import 'package:moniq/presentation/screens/calendar/calendar_screen.dart';
import 'package:moniq/presentation/screens/notifications/notifications_screen.dart';
import 'package:moniq/presentation/screens/home/home_screen.dart';
import 'package:moniq/presentation/screens/request/request_create_screen.dart';
import 'package:moniq/presentation/screens/request/request_history_screen.dart';
import 'package:moniq/presentation/screens/request/request_list_screen.dart';
import 'package:moniq/presentation/screens/schedule/schedule_generation_screen.dart';
import 'package:moniq/presentation/screens/schedule/schedule_history_screen.dart';
import 'package:moniq/presentation/screens/settings/profile_edit_screen.dart';
import 'package:moniq/presentation/screens/settings/settings_screen.dart';
import 'package:moniq/presentation/screens/team/members_screen.dart';
import 'package:moniq/presentation/screens/team/team_create_screen.dart';
import 'package:moniq/presentation/screens/team/team_detail_screen.dart';
import 'package:moniq/presentation/screens/team/team_join_screen.dart';
import 'package:moniq/presentation/screens/team/team_list_screen.dart';
import 'package:moniq/presentation/screens/team/team_screen.dart';
import 'package:moniq/presentation/screens/team/team_settings_screen.dart';
import 'package:moniq/presentation/screens/team/schedule_rules_screen.dart';
import 'package:moniq/presentation/screens/team/custom_rules_screen.dart';
import 'package:moniq/presentation/screens/announcement/announcement_screen.dart';
import 'package:moniq/presentation/screens/announcement/my_announcements_screen.dart';
import 'package:moniq/presentation/screens/wanted/wanted_request_screen.dart';
import 'package:moniq/presentation/screens/wanted/wanted_day_off_screen.dart';
import 'package:moniq/presentation/screens/wanted/wanted_history_screen.dart';
import 'package:moniq/presentation/screens/team/personal_team_calendar_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _homeNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'home');
final _calendarNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'calendar');
final _teamNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'team');
final _settingsNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'settings');

final appRouterProvider = Provider<GoRouter>((ref) {
  final authNotifier = ValueNotifier<AsyncValue<AuthState>>(
    ref.read(authStateChangesProvider),
  );
  ref.listen<AsyncValue<AuthState>>(authStateChangesProvider, (_, next) {
    authNotifier.value = next;
  });
  ref.onDispose(() => authNotifier.dispose());

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/login',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final isLoggedIn = authNotifier.value.whenOrNull(
            data: (auth) => auth.session != null,
          ) ??
          false;

      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/signup' ||
          state.matchedLocation == '/forgot-password' ||
          state.matchedLocation == '/verify-email';

      if (!isLoggedIn && !isAuthRoute) {
        return '/login';
      }

      if (isLoggedIn && isAuthRoute) {
        return '/home';
      }

      return null;
    },
    routes: [
      // Auth routes (outside shell)
      GoRoute(
        path: '/login',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/verify-email',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => EmailVerificationScreen(
          email: state.extra as String? ?? '',
        ),
      ),

      // App Shell with bottom navigation
      StatefulShellRoute.indexedStack(
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state, navigationShell) => AppShell(
          navigationShell: navigationShell,
        ),
        branches: [
          // Home tab
          StatefulShellBranch(
            navigatorKey: _homeNavigatorKey,
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),

          // Calendar tab
          StatefulShellBranch(
            navigatorKey: _calendarNavigatorKey,
            routes: [
              GoRoute(
                path: '/calendar',
                builder: (context, state) => const CalendarScreen(),
              ),
            ],
          ),

          // Team tab
          StatefulShellBranch(
            navigatorKey: _teamNavigatorKey,
            routes: [
              GoRoute(
                path: '/teams',
                builder: (context, state) => const TeamScreen(),
              ),
            ],
          ),

          // Settings tab
          StatefulShellBranch(
            navigatorKey: _settingsNavigatorKey,
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
                routes: [
                  GoRoute(
                    path: 'profile',
                    builder: (context, state) => const ProfileEditScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),

      // Team management routes (outside shell)
      GoRoute(
        path: '/teams/list',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const TeamListScreen(),
      ),
      GoRoute(
        path: '/teams/create',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const TeamCreateScreen(),
      ),
      GoRoute(
        path: '/teams/join',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const TeamJoinScreen(),
      ),

      // Team detail routes (outside shell)
      GoRoute(
        path: '/teams/:teamId/detail',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => TeamDetailScreen(
          teamId: state.pathParameters['teamId']!,
        ),
      ),
      GoRoute(
        path: '/teams/:teamId/members',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => MembersScreen(
          teamId: state.pathParameters['teamId']!,
        ),
      ),
      GoRoute(
        path: '/teams/:teamId/settings',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => TeamSettingsScreen(
          teamId: state.pathParameters['teamId']!,
        ),
      ),
      GoRoute(
        path: '/teams/:teamId/schedule-rules',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => ScheduleRulesScreen(
          teamId: state.pathParameters['teamId']!,
        ),
      ),
      GoRoute(
        path: '/teams/:teamId/custom-rules',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => CustomRulesScreen(
          teamId: state.pathParameters['teamId']!,
        ),
      ),

      // My Announcements (홈에서 진입)
      GoRoute(
        path: '/announcements',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const MyAnnouncementsScreen(),
      ),

      // 알림 히스토리 (홈 종 아이콘에서 진입)
      GoRoute(
        path: '/notifications',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const NotificationsScreen(),
      ),

      // Team Announcements (팀 관리에서 진입)
      GoRoute(
        path: '/teams/:teamId/announcements',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => AnnouncementScreen(
          teamId: state.pathParameters['teamId']!,
        ),
      ),

      // Schedule generation
      GoRoute(
        path: '/teams/:teamId/schedule/generate',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => ScheduleGenerationScreen(
          teamId: state.pathParameters['teamId']!,
        ),
      ),

      // Schedule history
      GoRoute(
        path: '/teams/:teamId/schedule/history',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => ScheduleHistoryScreen(
          teamId: state.pathParameters['teamId']!,
        ),
      ),
      GoRoute(
        path: '/teams/:teamId/schedule/history/:scheduleId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => ScheduleVersionDetailScreen(
          teamId: state.pathParameters['teamId']!,
          scheduleId: state.pathParameters['scheduleId']!,
        ),
      ),

      // Wanted (희망 휴무)
      GoRoute(
        path: '/teams/:teamId/wanted',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => WantedRequestScreen(
          teamId: state.pathParameters['teamId']!,
          teamName: state.uri.queryParameters['teamName'] ?? '',
        ),
      ),
      GoRoute(
        path: '/teams/:teamId/wanted/entry',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => WantedDayOffScreen(
          teamId: state.pathParameters['teamId']!,
        ),
      ),
      GoRoute(
        path: '/teams/:teamId/wanted/history',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => WantedHistoryScreen(
          teamId: state.pathParameters['teamId']!,
          isAdmin: state.uri.queryParameters['isAdmin'] == 'true',
        ),
      ),

      // Requests (교환/변경 요청)
      GoRoute(
        path: '/teams/:teamId/requests',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => RequestListScreen(
          teamId: state.pathParameters['teamId']!,
        ),
      ),
      GoRoute(
        path: '/teams/:teamId/requests/create',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => RequestCreateScreen(
          teamId: state.pathParameters['teamId']!,
        ),
      ),
      GoRoute(
        path: '/teams/:teamId/requests/history',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => RequestHistoryScreen(
          teamId: state.pathParameters['teamId']!,
        ),
      ),

      // Personal team calendar
      GoRoute(
        path: '/teams/:teamId/personal-calendar',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => PersonalTeamCalendarScreen(
          teamId: state.pathParameters['teamId']!,
        ),
      ),
    ],
  );
});
