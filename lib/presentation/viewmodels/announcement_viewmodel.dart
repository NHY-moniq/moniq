import 'package:moniq/data/models/announcement_model.dart';

/// 공지 작성자 표시용 경량 모델 (이름 + 아바타).
class AnnouncementAuthorInfo {
  const AnnouncementAuthorInfo({
    required this.displayName,
    this.avatarUrl,
  });

  final String displayName;
  final String? avatarUrl;

  static const unknown = AnnouncementAuthorInfo(displayName: '알 수 없음');

  /// 공지 모델에 담긴 작성자 정보를 표시용 모델로 변환한다.
  ///
  /// 공지 쿼리가 `users` 조인으로 작성자 이름/아바타를 함께 가져오므로
  /// 별도 팀 멤버 목록 조회가 필요 없다. 작성자가 탈퇴/삭제돼 이름이
  /// 비어 있으면 [unknown].
  factory AnnouncementAuthorInfo.fromAnnouncement(AnnouncementModel a) {
    final name = a.authorName;
    if (name == null || name.isEmpty) return unknown;
    return AnnouncementAuthorInfo(
      displayName: name,
      avatarUrl: a.authorAvatarUrl,
    );
  }
}
