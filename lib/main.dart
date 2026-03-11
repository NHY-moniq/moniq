import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:moniq/app.dart';
import 'package:moniq/core/constants/supabase_constants.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');
  await initializeDateFormatting('ko_KR');

  await Supabase.initialize(
    url: SupabaseConstants.url,
    anonKey: SupabaseConstants.publishKey,
  );

  // TODO: Kakao SDK 호환 버전 나오면 복원
  // KakaoSdk.init(nativeAppKey: SupabaseConstants.kakaoNativeKey);

  runApp(
    const ProviderScope(
      child: MoniqApp(),
    ),
  );
}
