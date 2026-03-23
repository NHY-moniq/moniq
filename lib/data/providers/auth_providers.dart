import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/datasources/auth_remote_data_source.dart';
import 'package:moniq/data/providers/supabase_providers.dart';
import 'package:moniq/data/repositories/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>(
  (ref) => AuthRemoteDataSource(
    auth: ref.watch(goTrueClientProvider),
    client: ref.watch(supabaseClientProvider),
  ),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(dataSource: ref.watch(authRemoteDataSourceProvider)),
);

/// Increment to force currentUserProvider to re-read
final userProfileVersionProvider = StateProvider<int>((ref) => 0);

/// Reactive current user - watches version counter to detect profile changes
final currentUserProvider = Provider<User?>((ref) {
  ref.watch(userProfileVersionProvider);
  return ref.watch(authRepositoryProvider).currentUser;
});
