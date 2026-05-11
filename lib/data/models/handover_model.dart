/// shift_handovers 테이블 한 행.
class HandoverModel {
  const HandoverModel({
    required this.id,
    required this.teamId,
    required this.shiftTypeId,
    required this.shiftDate,
    required this.body,
    required this.createdBy,
    required this.createdAt,
    this.updatedAt,
    this.isDeleted = false,
  });

  final String id;
  final String teamId;
  final String shiftTypeId;
  final DateTime shiftDate;
  final String body;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isDeleted;

  factory HandoverModel.fromJson(Map<String, dynamic> json) {
    return HandoverModel(
      id: json['id'] as String,
      teamId: json['team_id'] as String,
      shiftTypeId: json['shift_type_id'] as String,
      shiftDate: DateTime.parse(json['shift_date'] as String),
      body: json['body'] as String,
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      isDeleted: (json['is_deleted'] as bool?) ?? false,
    );
  }
}

/// 표시용 — 작성자/시프트 정보 join 결과.
class HandoverWithMeta {
  const HandoverWithMeta({
    required this.handover,
    required this.authorName,
    this.authorAvatarUrl,
    required this.shiftName,
    this.shiftColor,
  });

  final HandoverModel handover;
  final String authorName;
  final String? authorAvatarUrl;
  final String shiftName;
  final String? shiftColor;
}
