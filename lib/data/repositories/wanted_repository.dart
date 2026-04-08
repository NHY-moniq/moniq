import 'package:moniq/data/datasources/wanted_remote_data_source.dart';
import 'package:moniq/data/models/wanted_request_model.dart';

class WantedRepository {
  WantedRepository({required WantedRemoteDataSource dataSource})
      : _dataSource = dataSource;

  final WantedRemoteDataSource _dataSource;

  Future<WantedRequestModel> createWantedRequest({
    required String teamId,
    required DateTime periodStart,
    required DateTime periodEnd,
    DateTime? deadline,
  }) {
    return _dataSource.createWantedRequest(
      teamId: teamId,
      periodStart: periodStart,
      periodEnd: periodEnd,
      deadline: deadline,
    );
  }

  Future<List<WantedRequestModel>> getWantedRequests(String teamId) {
    return _dataSource.getWantedRequests(teamId);
  }

  Future<WantedRequestModel?> getActiveWantedRequest(String teamId) {
    return _dataSource.getActiveWantedRequest(teamId);
  }

  Future<void> closeWantedRequest(String requestId) {
    return _dataSource.closeWantedRequest(requestId);
  }

  Future<WantedEntryModel> addWantedEntry({
    required String wantedRequestId,
    required String teamId,
    required DateTime wantedDate,
    String? reason,
    int priority = 1,
  }) {
    return _dataSource.addWantedEntry(
      wantedRequestId: wantedRequestId,
      teamId: teamId,
      wantedDate: wantedDate,
      reason: reason,
      priority: priority,
    );
  }

  Future<List<WantedEntryModel>> getMyEntries(String wantedRequestId) {
    return _dataSource.getMyEntries(wantedRequestId);
  }

  Future<List<WantedEntryWithUser>> getAllEntries(String wantedRequestId) {
    return _dataSource.getAllEntries(wantedRequestId);
  }

  Future<void> deleteWantedEntry(String entryId) {
    return _dataSource.deleteWantedEntry(entryId);
  }

  Future<List<WantedEntryModel>> getEntriesForPeriod({
    required String teamId,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) {
    return _dataSource.getEntriesForPeriod(
      teamId: teamId,
      periodStart: periodStart,
      periodEnd: periodEnd,
    );
  }
}
