import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/datasources/schedule_remote_data_source.dart';
import 'package:moniq/data/providers/supabase_providers.dart';
import 'package:moniq/data/repositories/schedule_repository.dart';

final scheduleRemoteDataSourceProvider = Provider<ScheduleRemoteDataSource>(
  (ref) => ScheduleRemoteDataSource(
    client: ref.watch(supabaseClientProvider),
  ),
);

final scheduleRepositoryProvider = Provider<ScheduleRepository>(
  (ref) => ScheduleRepository(
    dataSource: ref.watch(scheduleRemoteDataSourceProvider),
  ),
);
