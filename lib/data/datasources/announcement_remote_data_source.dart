import 'dart:io';

import 'package:moniq/data/models/announcement_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AnnouncementRemoteDataSource {
  AnnouncementRemoteDataSource({required SupabaseClient client})
      : _client = client;

  final SupabaseClient _client;

  String? get _userId => _client.auth.currentUser?.id;

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
        .order('created_at');

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
    final rows = await _client
        .from('team_announcements')
        .select()
        .eq('team_id', teamId)
        .order('is_pinned', ascending: false)
        .order('created_at', ascending: false);

    return (rows as List)
        .map((r) => AnnouncementModel.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// 사용자가 속한 모든 팀의 최신 공지사항 (팀 이름 포함)
  Future<List<AnnouncementWithTeam>> getMyTeamsAnnouncements() async {
    if (_userId == null) throw Exception('Not authenticated');

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
        .select()
        .inFilter('team_id', teamMap.keys.toList())
        .order('created_at', ascending: false)
        .limit(10);

    return (rows as List).map((r) {
      final map = r as Map<String, dynamic>;
      final announcement = AnnouncementModel.fromJson(map);
      return AnnouncementWithTeam(
        announcement: announcement,
        teamName: teamMap[announcement.teamId] ?? '',
      );
    }).toList();
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
