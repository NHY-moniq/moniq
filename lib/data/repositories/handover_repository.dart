import 'package:moniq/data/datasources/handover_remote_data_source.dart';
import 'package:moniq/data/models/handover_model.dart';

class HandoverRepository {
  HandoverRepository({required HandoverRemoteDataSource dataSource})
      : _dataSource = dataSource;

  final HandoverRemoteDataSource _dataSource;

  Future<List<HandoverWithMeta>> getTeamDayHandovers({
    required String teamId,
    required DateTime date,
  }) {
    return _dataSource.getTeamDayHandovers(teamId: teamId, date: date);
  }

  Future<int> countTeamDayHandovers({
    required String teamId,
    required DateTime date,
  }) {
    return _dataSource.countTeamDayHandovers(teamId: teamId, date: date);
  }

  Future<HandoverModel> create({
    required String teamId,
    required String shiftTypeId,
    required DateTime date,
    required String body,
  }) {
    return _dataSource.create(
      teamId: teamId,
      shiftTypeId: shiftTypeId,
      date: date,
      body: body,
    );
  }

  Future<void> softDelete(String id) {
    return _dataSource.softDelete(id);
  }
}
