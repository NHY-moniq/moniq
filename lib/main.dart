import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:moniq/app.dart';
import 'package:moniq/core/constants/supabase_constants.dart';
import 'package:moniq/data/datasources/fcm_token_service.dart';
import 'package:moniq/data/datasources/notification_service.dart';
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

  // Firebase 초기화 (firebase_options.dart 또는 native config 필요).
  // 미설정 환경에서도 앱이 죽지 않도록 try/catch.
  try {
    await Firebase.initializeApp();
    FcmTokenService.instance.listenForRefresh();
    // 로그인 상태면 즉시 토큰 동기화 (비로그인은 로그인 후 별도 호출)
    await FcmTokenService.instance.syncTokenForCurrentUser();
    // 이후 인증 상태 변경 시마다 재시도
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn ||
          data.event == AuthChangeEvent.tokenRefreshed) {
        FcmTokenService.instance.syncTokenForCurrentUser();
      } else if (data.event == AuthChangeEvent.signedOut) {
        FcmTokenService.instance.clearTokenForCurrentUser();
      }
    });
  } catch (e) {
    // Firebase 미설정 또는 초기화 실패 — 푸시 비활성으로 진행
    debugPrint('Firebase init failed (push disabled): $e');
  }

  // TODO: Kakao SDK 호환 버전 나오면 복원
  // KakaoSdk.init(nativeAppKey: SupabaseConstants.kakaoNativeKey);

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const MoniqApp(),
    ),
  );
}
