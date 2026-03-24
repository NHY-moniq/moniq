import 'package:freezed_annotation/freezed_annotation.dart';

part 'request_model.freezed.dart';
part 'request_model.g.dart';

@freezed
class RequestModel with _$RequestModel {
  const factory RequestModel({
    required String id,
    @JsonKey(name: 'team_id') required String teamId,
    @JsonKey(name: 'requester_user_id') required String requesterUserId,
    @JsonKey(name: 'source_shift_id') String? sourceShiftId,
    @JsonKey(name: 'change_type') required String changeType,
    @JsonKey(name: 'requested_date') DateTime? requestedDate,
    @JsonKey(name: 'requested_shift_type_id') String? requestedShiftTypeId,
    String? reason,
    String? note,
    @Default('pending') String status,
    @JsonKey(name: 'reviewed_by') String? reviewedBy,
    @JsonKey(name: 'reviewed_at') DateTime? reviewedAt,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _RequestModel;

  factory RequestModel.fromJson(Map<String, dynamic> json) =>
      _$RequestModelFromJson(json);
}
