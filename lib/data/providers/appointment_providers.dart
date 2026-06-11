import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/datasources/appointment_remote_data_source.dart';
import 'package:moniq/data/models/appointment_model.dart';
import 'package:moniq/data/providers/supabase_providers.dart';
import 'package:moniq/data/repositories/appointment_repository.dart';

final appointmentRemoteDataSourceProvider =
    Provider<AppointmentRemoteDataSource>(
      (ref) => AppointmentRemoteDataSource(
        client: ref.watch(supabaseClientProvider),
      ),
    );

final appointmentRepositoryProvider = Provider<AppointmentRepository>(
  (ref) => AppointmentRepository(
    dataSource: ref.watch(appointmentRemoteDataSourceProvider),
  ),
);

/// 팀의 약속 목록.
final teamAppointmentsProvider = FutureProvider.autoDispose
    .family<List<AppointmentModel>, String>(
      (ref, teamId) =>
          ref.watch(appointmentRepositoryProvider).getTeamAppointments(teamId),
    );

/// 내가 아직 결정하지 않은(invited) 약속 수 — AppBar 배지용.
final myInvitedAppointmentCountProvider = Provider.autoDispose
    .family<int, String>((ref, teamId) {
      final appointments = ref.watch(teamAppointmentsProvider(teamId));
      return appointments.maybeWhen(
        data: (list) => list.where((a) => a.myStatus == 'invited').length,
        orElse: () => 0,
      );
    });
