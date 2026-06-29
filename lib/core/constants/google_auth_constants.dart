import 'package:flutter_dotenv/flutter_dotenv.dart';

abstract final class GoogleAuthConstants {
  /// iOS OAuth 2.0 client ID (Google Cloud Console의 iOS 유형 클라이언트).
  /// Info.plist의 reversed-client-id URL scheme과 짝을 이룬다.
  static String get iosClientId => dotenv.env['GOOGLE_IOS_CLIENT_ID'] ?? '';

  /// Web OAuth 2.0 client ID — Supabase Google provider에 등록된 값.
  /// signInWithIdToken의 audience가 이 값과 일치해야 Supabase가 토큰을 수락한다.
  static String get webClientId => dotenv.env['GOOGLE_WEB_CLIENT_ID'] ?? '';
}
