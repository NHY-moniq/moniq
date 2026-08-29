import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:moniq/data/datasources/home_cache_local_data_source.dart';
import 'package:moniq/data/providers/settings_providers.dart';
import 'package:moniq/data/providers/supabase_providers.dart';

/// 현재 사용자 id — **동기적으로** 얻는다.
///
/// [authStateChangesProvider]는 스트림이라 콜드 스타트 첫 빌드에서는 아직
/// loading이다. 그동안 userId를 null로 보면 캐시 키를 만들 수 없어 첫 화면을
/// 캐시로 그릴 수 없다. 세션은 `Supabase.initialize`에서 이미 디스크에서
/// 복원돼 있으므로 GoTrue의 currentUser를 폴백으로 함께 본다.
final currentUserIdProvider = Provider<String?>((ref) {
  final authState = ref.watch(authStateChangesProvider);
  final auth = ref.watch(goTrueClientProvider);
  return authState.whenOrNull(data: (s) => s.session?.user.id) ??
      auth.currentUser?.id;
});

/// 홈/캘린더/팀 탭의 로컬 캐시. 로그인 전이면 null.
final homeCacheProvider = Provider<HomeCacheLocalDataSource?>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  try {
    return HomeCacheLocalDataSource(
      prefs: ref.watch(sharedPreferencesProvider),
      userId: userId,
    );
  } catch (e) {
    // SharedPreferences override가 없는 환경(일부 위젯 테스트 등)에서는
    // 캐시 없이 동작한다 — 기능이 막히면 안 된다.
    debugPrint('[cache] SharedPreferences 미준비 — 캐시 비활성: $e');
    return null;
  }
});

/// 로그아웃/계정 삭제 시 모든 사용자의 홈 캐시를 폐기한다.
Future<void> clearHomeCaches(SharedPreferences prefs) =>
    HomeCacheLocalDataSource.clearAll(prefs);
