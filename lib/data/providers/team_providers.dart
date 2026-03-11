import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/datasources/team_remote_data_source.dart';
import 'package:moniq/data/providers/supabase_providers.dart';
import 'package:moniq/data/repositories/team_repository.dart';

final teamRemoteDataSourceProvider = Provider<TeamRemoteDataSource>(
  (ref) => TeamRemoteDataSource(
    client: ref.watch(supabaseClientProvider),
  ),
);

final teamRepositoryProvider = Provider<TeamRepository>(
  (ref) => TeamRepository(
    dataSource: ref.watch(teamRemoteDataSourceProvider),
  ),
);
