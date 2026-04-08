import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/datasources/feedback_remote_data_source.dart';
import 'package:moniq/data/providers/supabase_providers.dart';
import 'package:moniq/data/repositories/feedback_repository.dart';

final feedbackRepositoryProvider = Provider<FeedbackRepository>((ref) {
  return FeedbackRepository(
    dataSource: FeedbackRemoteDataSource(
      client: ref.watch(supabaseClientProvider),
    ),
  );
});
