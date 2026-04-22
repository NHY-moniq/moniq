import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:moniq/app.dart';
import 'package:moniq/core/constants/supabase_constants.dart';
import 'package:moniq/data/datasources/fcm_messaging_handler.dart';
import 'package:moniq/data/datasources/fcm_token_service.dart';
import 'package:moniq/data/datasources/notification_service.dart';
import 'package:moniq/firebase_options.dart';
import 'package:moniq/data/datasources/personal_event_local_data_source.dart';
import 'package:moniq/data/providers/settings_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');
  await initializeDateFormatting('ko_KR');

  await Supabase.initialize(
    url: SupabaseConstants.url,
    anonKey: SupabaseConstants.publishKey,
  );

  final prefs = await SharedPreferences.getInstance();

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

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const MoniqApp(),
    ),
  );
}
