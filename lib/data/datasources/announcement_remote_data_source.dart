import 'dart:io';

import 'package:moniq/data/models/announcement_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AnnouncementRemoteDataSource {
  AnnouncementRemoteDataSource({required SupabaseClient client})
      : _client = client;

  final SupabaseClient _client;

  String? get _userId => _client.auth.currentUser?.id;

  /// 공지 조회용 select 절.
  ///
  /// - `users(...)`: 작성자(`created_by`) 프로필을 조인. 작성자가 탈퇴/삭제돼
  ///   더 이상 존재하지 않으면 null이 되므로 left join이 되도록 `!inner`를
  ///   쓰지 않는다.
  /// - `announcement_comments(count)`: 공지별 댓글 수를 집계로 한 번에 조회.
  static const String _announcementSelect = '''
        *,
        author:users!team_announcements_created_by_fkey(display_name, avatar_url),
        announcement_comments(count)
      ''';

  /// 조인된 공지 row를 flat한 [AnnouncementModel]로 변환한다.
  ///
  /// Supabase는 조인 결과를 중첩 객체/배열로 돌려주므로,
  /// 작성자 정보와 댓글 수를 모델이 기대하는 평탄한 key로 펼친다.
  AnnouncementModel _mapAnnouncementRow(Map<String, dynamic> row) {
    final author = row['author'] as Map<String, dynamic>?;

    // announcement_comments(count) → [{count: N}] 형태 (없으면 빈 배열)
    var commentCount = 0;
    final commentsAgg = row['announcement_comments'];
    if (commentsAgg is List && commentsAgg.isNotEmpty) {
      final first = commentsAgg.first;
      if (first is Map<String, dynamic>) {
        commentCount = (first['count'] as num?)?.toInt() ?? 0;
      }
    }

    final flat = <String, dynamic>{
      ...row,
      'author_name': author?['display_name'],
      'author_avatar_url': author?['avatar_url'],
      'comment_count': commentCount,
    }
      ..remove('author')
      ..remove('announcement_comments');

    return AnnouncementModel.fromJson(flat);
  }

  Future<AnnouncementModel> create({
    required String teamId,
    required String title,
    String? content,
    bool isPinned = false,
    List<String> attachmentUrls = const [],
  }) async {
    if (_userId == null) throw Exception('Not authenticated');

    final row = await _client
        .from('team_announcements')
        .insert({
          'team_id': teamId,
          'title': title,
          'content': content,
          'created_by': _userId,
          'is_pinned': isPinned,
          'attachment_urls': attachmentUrls,
        })
        .select()
        .single();

    return AnnouncementModel.fromJson(row);
  }

  /// 첨부파일 업로드 → public URL 반환
  Future<String> uploadAttachment({
    required String teamId,
    required File file,
    required String filename,
  }) async {
    if (_userId == null) throw Exception('Not authenticated');
    final ts = DateTime.now().millisecondsSinceEpoch;
    final path = '$teamId/${ts}_$filename';
    await _client.storage.from('announcements').upload(path, file);
    return _client.storage.from('announcements').getPublicUrl(path);
  }

  // ─── 댓글 ───

  Future<AnnouncementCommentModel> addComment({
    required String announcementId,
    required String teamId,
    required String content,
  }) async {
    if (_userId == null) throw Exception('Not authenticated');
    final row = await _client
        .from('announcement_comments')
        .insert({
          'announcement_id': announcementId,
          'team_id': teamId,
          'user_id': _userId,
          'content': content,
        })
        .select()
        .single();
    return AnnouncementCommentModel.fromJson(row);
  }

  Future<List<AnnouncementCommentWithUser>> getComments(
      String announcementId) async {
    final rows = await _client
        .from('announcement_comments')
        .select('*, users!inner(display_name)')
        .eq('announcement_id', announcementId)
        // 오래된 댓글이 상단에 오도록 오름차순 정렬(기본값은 내림차순).
        .order('created_at', ascending: true);

    return (rows as List).map((r) {
      final map = r as Map<String, dynamic>;
      final displayName =
          (map['users'] as Map<String, dynamic>?)?['display_name'] as String? ??
              '알 수 없음';
      return AnnouncementCommentWithUser(
        comment: AnnouncementCommentModel.fromJson(map),
        displayName: displayName,
      );
    }).toList();
  }

  Future<void> deleteComment(String commentId) async {
    await _client.from('announcement_comments').delete().eq('id', commentId);
  }

  Future<List<AnnouncementModel>> getByTeam(String teamId) async {
    try {
      final rows = await _client
          .from('team_announcements')
          .select(_announcementSelect)
          .eq('team_id', teamId)
          .order('is_pinned', ascending: false)
          .order('created_at', ascending: false);

      return (rows as List)
          .map((r) => _mapAnnouncementRow(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('팀 공지사항을 불러오지 못했습니다: $e');
    }
  }

  /// 단건 공지 조회 (작성자 정보 + 댓글 수 포함).
  Future<AnnouncementModel> getById(String id) async {
    try {
      final row = await _client
          .from('team_announcements')
          .select(_announcementSelect)
          .eq('id', id)
          .single();
      return _mapAnnouncementRow(row);
    } catch (e) {
      throw Exception('공지사항을 불러오지 못했습니다: $e');
    }
  }

  /// 사용자가 속한 모든 팀의 최신 공지사항 (팀 이름 포함)
  Future<List<AnnouncementWithTeam>> getMyTeamsAnnouncements() async {
    if (_userId == null) throw Exception('Not authenticated');

    try {
      // 내 팀 ID + 팀 이름 조회
      final memberRows = await _client
          .from('team_members')
          .select('team_id, teams(name)')
          .eq('user_id', _userId!)
          .eq('is_deleted', false);

      final teamMap = <String, String>{};
      for (final r in (memberRows as List)) {
        final teamId = r['team_id'] as String;
        final teamJoin = r['teams'] as Map<String, dynamic>?;
        // 팀이 삭제됐거나 조회 실패한 멤버십은 제외 (is_deleted 누락 방어)
        if (teamJoin == null) continue;
        final teamName = teamJoin['name'] as String? ?? '';
        teamMap[teamId] = teamName;
      }
      if (teamMap.isEmpty) return [];

      final rows = await _client
          .from('team_announcements')
          .select(_announcementSelect)
          .inFilter('team_id', teamMap.keys.toList())
          .order('created_at', ascending: false)
          .limit(10);

      return (rows as List).map((r) {
        final announcement = _mapAnnouncementRow(r as Map<String, dynamic>);
        return AnnouncementWithTeam(
          announcement: announcement,
          teamName: teamMap[announcement.teamId] ?? '',
        );
      }).toList();
    } catch (e) {
      throw Exception('내 팀 공지사항을 불러오지 못했습니다: $e');
    }
  }

  Future<void> update(String id, {String? title, String? content, bool? isPinned}) async {
    final updates = <String, dynamic>{};
    if (title != null) updates['title'] = title;
    if (content != null) updates['content'] = content;
    if (isPinned != null) updates['is_pinned'] = isPinned;

    await _client.from('team_announcements').update(updates).eq('id', id);
  }

  Future<void> delete(String id) async {
    await _client.from('team_announcements').delete().eq('id', id);
  }
}
