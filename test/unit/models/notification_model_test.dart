import 'package:flutter_test/flutter_test.dart';
import 'package:moniq/data/models/notification_model.dart';

void main() {
  group('NotificationModel.fromJson', () {
    test('필수/선택 필드를 파싱한다', () {
      final m = NotificationModel.fromJson({
        'id': 'noti-1',
        'user_id': 'user-1',
        'team_id': 'team-1',
        'title': '근무 변경',
        'body': '내일 근무가 변경되었습니다',
        'data': {'route': '/calendar'},
        'read_at': null,
        'created_at': '2026-06-16T10:00:00Z',
      });

      expect(m.id, 'noti-1');
      expect(m.teamId, 'team-1');
      expect(m.data['route'], '/calendar');
      expect(m.createdAt, DateTime.parse('2026-06-16T10:00:00Z'));
    });

    test('data 누락 시 빈 맵으로 처리', () {
      final m = NotificationModel.fromJson({
        'id': 'noti-2',
        'user_id': 'user-1',
        'title': 't',
        'body': 'b',
        'created_at': '2026-06-16T10:00:00Z',
      });
      expect(m.data, isEmpty);
      expect(m.teamId, isNull);
    });
  });

  group('isRead', () {
    test('read_at 이 있으면 읽음', () {
      final m = NotificationModel.fromJson({
        'id': 'noti-3',
        'user_id': 'user-1',
        'title': 't',
        'body': 'b',
        'read_at': '2026-06-16T11:00:00Z',
        'created_at': '2026-06-16T10:00:00Z',
      });
      expect(m.isRead, isTrue);
    });

    test('read_at 이 null 이면 안 읽음', () {
      final m = NotificationModel.fromJson({
        'id': 'noti-4',
        'user_id': 'user-1',
        'title': 't',
        'body': 'b',
        'created_at': '2026-06-16T10:00:00Z',
      });
      expect(m.isRead, isFalse);
    });
  });
}
