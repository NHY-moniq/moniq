import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/datasources/shift_remote_data_source.dart';
import 'package:moniq/data/providers/supabase_providers.dart';
import 'package:moniq/data/repositories/shift_repository.dart';

final shiftRemoteDataSourceProvider = Provider<ShiftRemoteDataSource>(
  (ref) => ShiftRemoteDataSource(
    client: ref.watch(supabaseClientProvider),
  ),
);

final shiftRepositoryProvider = Provider<ShiftRepository>(
  (ref) => ShiftRepository(
    dataSource: ref.watch(shiftRemoteDataSourceProvider),
  ),
);
