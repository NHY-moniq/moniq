import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/datasources/auth_remote_data_source.dart';
import 'package:moniq/data/providers/supabase_providers.dart';
import 'package:moniq/data/repositories/auth_repository.dart';

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>(
  (ref) => AuthRemoteDataSource(
    auth: ref.watch(goTrueClientProvider),
    client: ref.watch(supabaseClientProvider),
  ),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    dataSource: ref.watch(authRemoteDataSourceProvider),
  ),
);
