import 'package:moniq/data/datasources/feedback_remote_data_source.dart';

class FeedbackRepository {
  FeedbackRepository({required FeedbackRemoteDataSource dataSource})
      : _dataSource = dataSource;

  final FeedbackRemoteDataSource _dataSource;

  Future<Map<String, dynamic>?> getFeedback(String scheduleId) {
    return _dataSource.getFeedback(scheduleId);
  }

  Future<void> saveFeedback({
    required String scheduleId,
    required String teamId,
    required int overallRating,
    required Map<String, int> ruleRatings,
    String? notes,
  }) {
    return _dataSource.saveFeedback(
      scheduleId: scheduleId,
      teamId: teamId,
      overallRating: overallRating,
      ruleRatings: ruleRatings,
      notes: notes,
    );
  }
}
