/// 약속 참여자 (약속 × 사용자 단위 상태).
class AppointmentParticipant {
  const AppointmentParticipant({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.status, // invited | added | declined
  });

  final String userId;
  final String displayName;
  final String? avatarUrl;
  final String status;

  factory AppointmentParticipant.fromJson(Map<String, dynamic> json) {
    final user = json['users'] as Map<String, dynamic>?;
    return AppointmentParticipant(
      userId: json['user_id'] as String,
      displayName:
          (user?['display_name'] as String?) ?? (json['user_id'] as String),
      avatarUrl: user?['avatar_url'] as String?,
      status: (json['status'] as String?) ?? 'invited',
    );
  }
}

/// 개인 팀 약속 메타 + 내 참여 상태.
class AppointmentModel {
  const AppointmentModel({
    required this.id,
    required this.teamId,
    required this.title,
    required this.eventDate,
    this.startTime,
    this.endTime,
    this.color,
    this.createdBy,
    required this.myStatus,
    required this.participants,
  });

  final String id;
  final String teamId;
  final String title;
  final DateTime eventDate;
  final String? startTime;
  final String? endTime;
  final String? color;
  final String? createdBy;

  /// 현재 사용자의 상태: invited | added | declined | none(참여자 아님)
  final String myStatus;
  final List<AppointmentParticipant> participants;

  bool get isAllDay =>
      (startTime == null || startTime!.isEmpty) &&
      (endTime == null || endTime!.isEmpty);

  bool isCreator(String? userId) => userId != null && createdBy == userId;

  factory AppointmentModel.fromJson(
    Map<String, dynamic> json,
    String? currentUserId,
  ) {
    final rawParticipants =
        (json['personal_team_appointment_participants'] as List?) ?? const [];
    final participants = rawParticipants
        .map((p) => AppointmentParticipant.fromJson(p as Map<String, dynamic>))
        .toList();

    String myStatus = 'none';
    if (currentUserId != null) {
      for (final p in participants) {
        if (p.userId == currentUserId) {
          myStatus = p.status;
          break;
        }
      }
    }

    return AppointmentModel(
      id: json['id'] as String,
      teamId: json['team_id'] as String,
      title: (json['title'] as String?) ?? '',
      eventDate: DateTime.parse(json['event_date'] as String),
      startTime: json['start_time'] as String?,
      endTime: json['end_time'] as String?,
      color: json['color'] as String?,
      createdBy: json['created_by'] as String?,
      myStatus: myStatus,
      participants: participants,
    );
  }
}
