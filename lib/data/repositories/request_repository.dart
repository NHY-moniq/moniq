import 'package:moniq/data/datasources/request_remote_data_source.dart';
import 'package:moniq/data/models/request_model.dart';

class RequestRepository {
  RequestRepository({required RequestRemoteDataSource dataSource})
      : _dataSource = dataSource;

  final RequestRemoteDataSource _dataSource;

  Future<RequestModel> createRequest({
    required String teamId,
    required String changeType,
    String? sourceShiftId,
    DateTime? requestedDate,
    String? requestedShiftTypeId,
    String? reason,
    String? note,
  }) {
    return _dataSource.createRequest(
      teamId: teamId,
      changeType: changeType,
      sourceShiftId: sourceShiftId,
      requestedDate: requestedDate,
      requestedShiftTypeId: requestedShiftTypeId,
      reason: reason,
      note: note,
    );
  }

  Future<List<RequestModel>> getTeamRequests(String teamId) {
    return _dataSource.getTeamRequests(teamId);
  }

  Future<List<RequestModel>> getMyRequests(String teamId) {
    return _dataSource.getMyRequests(teamId);
  }

  Future<void> updateRequestStatus(String requestId, String status) {
    return _dataSource.updateRequestStatus(requestId, status);
  }

  Future<void> cancelRequest(String requestId) {
    return _dataSource.cancelRequest(requestId);
  }
}
