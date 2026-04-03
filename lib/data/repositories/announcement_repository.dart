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
  }) => _dataSource.create(teamId: teamId, title: title, content: content, isPinned: isPinned);

  Future<List<AnnouncementModel>> getByTeam(String teamId) =>
      _dataSource.getByTeam(teamId);

  Future<List<AnnouncementWithTeam>> getMyTeamsAnnouncements() =>
      _dataSource.getMyTeamsAnnouncements();

  Future<void> update(String id, {String? title, String? content, bool? isPinned}) =>
      _dataSource.update(id, title: title, content: content, isPinned: isPinned);

  Future<void> delete(String id) => _dataSource.delete(id);
}
