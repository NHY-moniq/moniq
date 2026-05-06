import 'package:freezed_annotation/freezed_annotation.dart';

part 'team_member_model.freezed.dart';
part 'team_member_model.g.dart';

@freezed
class TeamMemberModel with _$TeamMemberModel {
  const factory TeamMemberModel({
    required String id,
    @JsonKey(name: 'team_id') required String teamId,
    @JsonKey(name: 'user_id') required String userId,
    @Default('member') String role,
    @JsonKey(name: 'skill_level') String? skillLevel,
    @JsonKey(name: 'night_exempt') @Default(false) bool nightExempt,
    @JsonKey(name: 'day_only') @Default(false) bool dayOnly,
    @JsonKey(name: 'night_dedicated') @Default(false) bool nightDedicated,
    @JsonKey(name: 'preferred_shifts', defaultValue: [])
    @Default([])
    List<String> preferredShifts,
    @JsonKey(name: 'is_favorite') @Default(false) bool isFavorite,
    @JsonKey(name: 'joined_at') DateTime? joinedAt,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
    @JsonKey(name: 'is_deleted') @Default(false) bool isDeleted,
  }) = _TeamMemberModel;

  factory TeamMemberModel.fromJson(Map<String, dynamic> json) =>
      _$TeamMemberModelFromJson(json);
}
