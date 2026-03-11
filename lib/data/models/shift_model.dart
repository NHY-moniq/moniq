import 'package:freezed_annotation/freezed_annotation.dart';

part 'shift_model.freezed.dart';
part 'shift_model.g.dart';

@freezed
class ShiftModel with _$ShiftModel {
  const factory ShiftModel({
    required String id,
    @JsonKey(name: 'schedule_id') required String scheduleId,
    @JsonKey(name: 'team_id') required String teamId,
    @JsonKey(name: 'user_id') required String userId,
    @JsonKey(name: 'shift_date') required DateTime shiftDate,
    @JsonKey(name: 'shift_type_id') required String shiftTypeId,
    String? note,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _ShiftModel;

  factory ShiftModel.fromJson(Map<String, dynamic> json) =>
      _$ShiftModelFromJson(json);
}
