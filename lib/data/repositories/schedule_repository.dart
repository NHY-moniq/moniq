import 'package:moniq/data/datasources/schedule_remote_data_source.dart';
import 'package:moniq/data/models/schedule_model.dart';
import 'package:moniq/data/models/shift_model.dart';

class ScheduleRepository {
  ScheduleRepository({required ScheduleRemoteDataSource dataSource})
      : _dataSource = dataSource;

  final ScheduleRemoteDataSource _dataSource;

  Future<ScheduleModel> createSchedule({
    required String teamId,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) {
    return _dataSource.createSchedule(
      teamId: teamId,
      periodStart: periodStart,
      periodEnd: periodEnd,
    );
  }

  Future<void> insertShifts(List<Map<String, dynamic>> shifts) {
    return _dataSource.insertShifts(shifts);
  }

  Future<void> publishSchedule(String scheduleId) {
    return _dataSource.publishSchedule(scheduleId);
  }

  Future<void> deleteSchedule(String scheduleId) {
    return _dataSource.deleteSchedule(scheduleId);
  }

  Future<List<ShiftModel>> getShiftsBySchedule(String scheduleId) {
    return _dataSource.getShiftsBySchedule(scheduleId);
  }

  Future<List<ScheduleModel>> getSchedules(String teamId) {
    return _dataSource.getSchedules(teamId);
  }
}
