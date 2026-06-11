import 'package:moniq/data/models/appointment_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppointmentRemoteDataSource {
  AppointmentRemoteDataSource({required SupabaseClient client})
    : _client = client;

  final SupabaseClient _client;

  /// 팀의 약속 목록 (참여자 + 내 상태 포함).
  Future<List<AppointmentModel>> getTeamAppointments(String teamId) async {
    final currentUserId = _client.auth.currentUser?.id;
    final rows = await _client
        .from('personal_team_appointments')
        .select(
          '*, personal_team_appointment_participants(user_id, status, '
          'users(display_name, avatar_url))',
        )
        .eq('team_id', teamId)
        .order('event_date');

    return (rows as List)
        .map(
          (r) => AppointmentModel.fromJson(
            r as Map<String, dynamic>,
            currentUserId,
          ),
        )
        .toList();
  }

  /// 내 캘린더에 추가 (invited → added).
  Future<void> addToMyCalendar(String appointmentId) async {
    await _client.rpc(
      'add_appointment_to_my_calendar',
      params: {'p_appointment_id': appointmentId},
    );
  }

  /// 내 캘린더에서 빼기 (added → invited).
  Future<void> removeFromMyCalendar(String appointmentId) async {
    await _client.rpc(
      'remove_appointment_from_my_calendar',
      params: {'p_appointment_id': appointmentId},
    );
  }

  /// 약속 삭제 (생성자만).
  Future<void> deleteAppointment(String appointmentId) async {
    await _client.rpc(
      'delete_personal_team_appointment',
      params: {'p_appointment_id': appointmentId},
    );
  }
}
