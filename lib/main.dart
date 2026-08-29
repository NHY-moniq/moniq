import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:moniq/core/ads/ad_consent_manager.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:moniq/app.dart';
import 'package:moniq/core/constants/supabase_constants.dart';
import 'package:moniq/core/utils/perf_trace.dart';
import 'package:moniq/data/datasources/home_cache_local_data_source.dart';
import 'package:moniq/data/datasources/fcm_messaging_handler.dart';
import 'package:moniq/data/datasources/fcm_token_service.dart';
import 'package:moniq/data/datasources/notification_service.dart';
import 'package:moniq/firebase_options.dart';
import 'package:moniq/data/datasources/personal_event_local_data_source.dart';
import 'package:moniq/data/providers/settings_providers.dart';
import 'package:moniq/presentation/viewmodels/home_viewmodel.dart';
import 'package:moniq/presentation/viewmodels/team_calendar_viewmodel.dart';
import 'package:moniq/presentation/viewmodels/team_viewmodel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> main() async {
  PerfTrace.start();
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');
  await initializeDateFormatting('ko_KR');

  await Supabase.initialize(
    url: SupabaseConstants.url,
    anonKey: SupabaseConstants.publishKey,
  );
  // 세션 복원 진단용 — 콜드 스타트 시 디스크에 저장돼 있던 세션 유무 확인.
  debugPrint(
    '[boot] 복원된 세션: '
    '${Supabase.instance.client.auth.currentSession?.user.email ?? '없음'}',
  );
  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    debugPrint('[auth] event=${data.event} '
        'user=${data.session?.user.email ?? '없음'}');
  });

  // 소셜 로그인(카카오 등) OAuth 콜백 후 떠 있는 인앱 브라우저를 자동으로 닫는다.
  // supabase_flutter는 딥링크로 세션만 교환하고 브라우저는 닫지 않으므로 직접 처리.
  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    if (data.event == AuthChangeEvent.signedIn) {
      closeInAppWebView();
    }
  });

  final prefs = await SharedPreferences.getInstance();
  PerfTrace.mark('prefs ready');
  // 이전 스키마 버전으로 저장된 홈 캐시는 폐기한다 (포맷 변경 안전장치).
  unawaited(HomeCacheLocalDataSource.purgeStaleVersions(prefs));

  // 광고 동의(UMP) → 앱 추적 권한(ATT) → AdMob 초기화.
  // 실패해도 앱 진입을 막지 않도록 fire-and-forget.
  AdConsentManager.instance.gatherConsentAndInitialize();

  await NotificationService.instance.initialize();

  // Firebase 초기화 — 시뮬에서 hang 방지를 위해 timeout으로 감싼다.
  // init 실패해도 앱 진입은 절대 막지 않음.
  try {
    debugPrint('[boot] Firebase.initializeApp 시작');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 8));
    debugPrint('[boot] Firebase.initializeApp 완료');

    // 메시지 핸들러는 fire-and-forget — 시뮬에서 hang하더라도 앱 시작 막지 않음
    FcmMessagingHandler.instance.initialize().catchError((e) {
      debugPrint('[boot] FcmMessagingHandler.initialize 실패: $e');
    });

    FcmTokenService.instance.listenForRefresh();
    // FCM 토큰 동기화는 fire-and-forget — 시뮬레이터에서 hang해도 앱 시작 막지 않음
    FcmTokenService.instance.syncTokenForCurrentUser();
    if (Supabase.instance.client.auth.currentUser != null) {
      PersonalEventLocalDataSource(prefs: prefs).pullFromRemote();
    }
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn ||
          data.event == AuthChangeEvent.tokenRefreshed) {
        FcmTokenService.instance.syncTokenForCurrentUser();
        PersonalEventLocalDataSource(prefs: prefs).pullFromRemote();
      } else if (data.event == AuthChangeEvent.signedOut) {
        FcmTokenService.instance.clearTokenForCurrentUser();
      }
    });
  } catch (e) {
    debugPrint('[boot] Firebase init 실패 (앱은 푸시 없이 진행): $e');
  }
  debugPrint('[boot] runApp 호출');

  // 컨테이너를 직접 만들어 첫 프레임 **이전에** 홈/캘린더/팀 데이터를 워밍한다.
  // 세션은 이미 복원돼 있으므로, 캐시가 있으면 즉시 채워지고 네트워크 갱신은
  // 위젯 트리가 올라오는 동안 병렬로 진행된다.
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  if (Supabase.instance.client.auth.currentUser != null) {
    container.read(favoriteTeamProvider);
    container.read(homeViewModelProvider);
    container.read(teamViewModelProvider);
    PerfTrace.mark('providers warmed');
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const MoniqApp(),
    ),
  );
}
