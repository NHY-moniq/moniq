import 'package:freezed_annotation/freezed_annotation.dart';

part 'shift_type_model.freezed.dart';
part 'shift_type_model.g.dart';

@freezed
class ShiftTypeModel with _$ShiftTypeModel {
  const factory ShiftTypeModel({
    required String id,
    @JsonKey(name: 'team_id') required String teamId,
    required String name,
    required String code,
    @JsonKey(name: 'start_time') String? startTime,
    @JsonKey(name: 'end_time') String? endTime,
    @Default('#A0AEC0') String color,
    @JsonKey(name: 'display_order') @Default(0) int displayOrder,
    @JsonKey(name: 'is_active') @Default(true) bool isActive,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _ShiftTypeModel;

  factory ShiftTypeModel.fromJson(Map<String, dynamic> json) =>
      _$ShiftTypeModelFromJson(json);
}
