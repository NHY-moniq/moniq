import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/datasources/custom_rule_remote_data_source.dart';
import 'package:moniq/data/providers/supabase_providers.dart';
import 'package:moniq/data/repositories/custom_rule_repository.dart';

final customRuleRemoteDataSourceProvider =
    Provider<CustomRuleRemoteDataSource>(
  (ref) => CustomRuleRemoteDataSource(
    client: ref.watch(supabaseClientProvider),
  ),
);

final customRuleRepositoryProvider = Provider<CustomRuleRepository>(
  (ref) => CustomRuleRepository(
    dataSource: ref.watch(customRuleRemoteDataSourceProvider),
  ),
);
