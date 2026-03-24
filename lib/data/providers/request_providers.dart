import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/datasources/request_remote_data_source.dart';
import 'package:moniq/data/providers/supabase_providers.dart';
import 'package:moniq/data/repositories/request_repository.dart';

final requestRemoteDataSourceProvider = Provider<RequestRemoteDataSource>(
  (ref) => RequestRemoteDataSource(
    client: ref.watch(supabaseClientProvider),
  ),
);

final requestRepositoryProvider = Provider<RequestRepository>(
  (ref) => RequestRepository(
    dataSource: ref.watch(requestRemoteDataSourceProvider),
  ),
);
