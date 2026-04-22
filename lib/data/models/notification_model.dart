/// 알림 히스토리 — notifications 테이블 한 행.
class NotificationModel {
  const NotificationModel({
    required this.id,
    required this.userId,
    this.teamId,
    required this.title,
    required this.body,
    required this.data,
    this.readAt,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String? teamId;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isRead => readAt != null;

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      teamId: json['team_id'] as String?,
      title: json['title'] as String,
      body: json['body'] as String,
      data: (json['data'] as Map?)?.cast<String, dynamic>() ?? const {},
      readAt: json['read_at'] != null
          ? DateTime.parse(json['read_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
