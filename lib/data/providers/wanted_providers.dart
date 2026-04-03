import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/datasources/wanted_remote_data_source.dart';
import 'package:moniq/data/providers/supabase_providers.dart';
import 'package:moniq/data/repositories/wanted_repository.dart';

final wantedRemoteDataSourceProvider = Provider<WantedRemoteDataSource>(
  (ref) => WantedRemoteDataSource(
    client: ref.watch(supabaseClientProvider),
  ),
);

final wantedRepositoryProvider = Provider<WantedRepository>(
  (ref) => WantedRepository(
    dataSource: ref.watch(wantedRemoteDataSourceProvider),
  ),
);
