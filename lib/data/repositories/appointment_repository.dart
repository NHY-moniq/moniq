import 'package:moniq/data/datasources/appointment_remote_data_source.dart';
import 'package:moniq/data/models/appointment_model.dart';

class AppointmentRepository {
  AppointmentRepository({required AppointmentRemoteDataSource dataSource})
    : _ds = dataSource;

  final AppointmentRemoteDataSource _ds;

  Future<List<AppointmentModel>> getTeamAppointments(String teamId) =>
      _ds.getTeamAppointments(teamId);

  Future<void> addToMyCalendar(String appointmentId) =>
      _ds.addToMyCalendar(appointmentId);

  Future<void> removeFromMyCalendar(String appointmentId) =>
      _ds.removeFromMyCalendar(appointmentId);

  Future<void> deleteAppointment(String appointmentId) =>
      _ds.deleteAppointment(appointmentId);
}
