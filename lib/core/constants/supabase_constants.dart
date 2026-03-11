import 'package:flutter_dotenv/flutter_dotenv.dart';

abstract final class SupabaseConstants {
  static String get url => dotenv.env['SUPABASE_URL'] ?? '';
  static String get publishKey => dotenv.env['SUPABASE_PUBLISH_KEY'] ?? '';
  static String get kakaoNativeKey => dotenv.env['KAKAO_NATIVE_KEY'] ?? '';
}
