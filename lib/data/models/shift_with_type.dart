import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:moniq/data/models/shift_model.dart';
import 'package:moniq/data/models/shift_type_model.dart';

part 'shift_with_type.freezed.dart';

@freezed
class ShiftWithType with _$ShiftWithType {
  const factory ShiftWithType({
    required ShiftModel shift,
    required ShiftTypeModel shiftType,
    String? teamName,
  }) = _ShiftWithType;
}
