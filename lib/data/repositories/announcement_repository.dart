import 'dart:io';

import 'package:moniq/data/datasources/announcement_remote_data_source.dart';
import 'package:moniq/data/models/announcement_model.dart';

class AnnouncementRepository {
  AnnouncementRepository({required AnnouncementRemoteDataSource dataSource})
      : _dataSource = dataSource;

  final AnnouncementRemoteDataSource _dataSource;

  Future<AnnouncementModel> create({
    required String teamId,
    required String title,
    String? content,
    bool isPinned = false,
    List<String> attachmentUrls = const [],
  }) =>
      _dataSource.create(
        teamId: teamId,
        title: title,
        content: content,
        isPinned: isPinned,
        attachmentUrls: attachmentUrls,
      );

  Future<List<AnnouncementModel>> getByTeam(String teamId) =>
      _dataSource.getByTeam(teamId);

  Future<AnnouncementModel> getById(String id) => _dataSource.getById(id);

  Future<List<AnnouncementWithTeam>> getMyTeamsAnnouncements() =>
      _dataSource.getMyTeamsAnnouncements();

  Future<void> update(String id, {String? title, String? content, bool? isPinned}) =>
      _dataSource.update(id, title: title, content: content, isPinned: isPinned);

  Future<void> delete(String id) => _dataSource.delete(id);

  Future<String> uploadAttachment({
    required String teamId,
    required File file,
    required String filename,
  }) =>
      _dataSource.uploadAttachment(
          teamId: teamId, file: file, filename: filename);

  Future<AnnouncementCommentModel> addComment({
    required String announcementId,
    required String teamId,
    required String content,
  }) =>
      _dataSource.addComment(
        announcementId: announcementId,
        teamId: teamId,
        content: content,
      );

  Future<List<AnnouncementCommentWithUser>> getComments(String announcementId) =>
      _dataSource.getComments(announcementId);

  Future<void> deleteComment(String commentId) =>
      _dataSource.deleteComment(commentId);
}
