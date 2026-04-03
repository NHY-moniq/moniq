import 'package:freezed_annotation/freezed_annotation.dart';

part 'wanted_request_model.freezed.dart';
part 'wanted_request_model.g.dart';

/// 관리자가 생성하는 희망 휴무 수집 요청
@freezed
class WantedRequestModel with _$WantedRequestModel {
  const factory WantedRequestModel({
    required String id,
    @JsonKey(name: 'team_id') required String teamId,
    @JsonKey(name: 'period_start') required DateTime periodStart,
    @JsonKey(name: 'period_end') required DateTime periodEnd,
    DateTime? deadline,
    @Default('collecting') String status, // collecting, closed
    @JsonKey(name: 'created_by') required String createdBy,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  }) = _WantedRequestModel;

  factory WantedRequestModel.fromJson(Map<String, dynamic> json) =>
      _$WantedRequestModelFromJson(json);
}

/// 팀원이 입력한 희망 휴무일 엔트리
@freezed
class WantedEntryModel with _$WantedEntryModel {
  const factory WantedEntryModel({
    required String id,
    @JsonKey(name: 'wanted_request_id') required String wantedRequestId,
    @JsonKey(name: 'team_id') required String teamId,
    @JsonKey(name: 'user_id') required String userId,
    @JsonKey(name: 'wanted_date') required DateTime wantedDate,
    String? reason,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  }) = _WantedEntryModel;

  factory WantedEntryModel.fromJson(Map<String, dynamic> json) =>
      _$WantedEntryModelFromJson(json);
}

/// 관리자 조회용: 엔트리 + 사용자 이름
class WantedEntryWithUser {
  WantedEntryWithUser({required this.entry, required this.displayName});

  final WantedEntryModel entry;
  final String displayName;
}
