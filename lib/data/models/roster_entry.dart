import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:moniq/data/models/shift_type_model.dart';
import 'package:moniq/data/models/user_model.dart';

part 'roster_entry.freezed.dart';

@freezed
class RosterEntry with _$RosterEntry {
  const factory RosterEntry({
    required ShiftTypeModel shiftType,
    required List<RosterWorker> workers,
  }) = _RosterEntry;
}

@freezed
class RosterWorker with _$RosterWorker {
  const factory RosterWorker({
    required UserModel user,
    String? shiftId,
    String? note,
  }) = _RosterWorker;
}
