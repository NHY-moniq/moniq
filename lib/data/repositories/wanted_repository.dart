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
    String wantedType = 'day_off',
  }) {
    return _dataSource.createWantedRequest(
      teamId: teamId,
      periodStart: periodStart,
      periodEnd: periodEnd,
      deadline: deadline,
      wantedType: wantedType,
    );
  }

  Future<List<WantedRequestModel>> getWantedRequests(String teamId) {
    return _dataSource.getWantedRequests(teamId);
  }

  Future<WantedRequestModel?> getActiveWantedRequest(
    String teamId, {
    String? wantedType,
  }) {
    return _dataSource.getActiveWantedRequest(teamId, wantedType: wantedType);
  }

  Future<List<WantedRequestModel>> getActiveWantedRequests(String teamId) {
    return _dataSource.getActiveWantedRequests(teamId);
  }

  Future<void> closeWantedRequest(String requestId) {
    return _dataSource.closeWantedRequest(requestId);
  }

  Future<void> closeWantedRequests(List<String> requestIds) {
    return _dataSource.closeWantedRequests(requestIds);
  }

  Future<void> reopenWantedRequest(
    String requestId, {
    required DateTime deadline,
  }) {
    return _dataSource.reopenWantedRequest(requestId, deadline: deadline);
  }

  Future<void> reopenWantedRequests(
    List<String> requestIds, {
    required DateTime deadline,
  }) {
    return _dataSource.reopenWantedRequests(requestIds, deadline: deadline);
  }

  Future<WantedEntryModel> addWantedEntry({
    required String wantedRequestId,
    required String teamId,
    required DateTime wantedDate,
    String? reason,
    int priority = 1,
    String? shiftTypeId,
  }) {
    return _dataSource.addWantedEntry(
      wantedRequestId: wantedRequestId,
      teamId: teamId,
      wantedDate: wantedDate,
      reason: reason,
      priority: priority,
      shiftTypeId: shiftTypeId,
    );
  }

  Future<List<WantedEntryModel>> getMyEntries(String wantedRequestId) {
    return _dataSource.getMyEntries(wantedRequestId);
  }

  Future<List<WantedEntryWithUser>> getAllEntries(String wantedRequestId) {
    return _dataSource.getAllEntries(wantedRequestId);
  }

  Future<List<WantedEntryModel>> getEntriesByRequestIds(
    List<String> requestIds,
  ) {
    return _dataSource.getEntriesByRequestIds(requestIds);
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
