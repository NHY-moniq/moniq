import 'package:flutter_test/flutter_test.dart';
import 'package:moniq/data/models/appointment_model.dart';

Map<String, dynamic> _json() => {
      'id': 'apt-1',
      'team_id': 'team-1',
      'title': '회식',
      'event_date': '2026-06-20',
      'start_time': '19:00:00',
      'end_time': '21:00:00',
      'created_by': 'user-A',
      'personal_team_appointment_participants': [
        {
          'user_id': 'user-A',
          'status': 'added',
          'users': {'display_name': '앨리스', 'avatar_url': null},
        },
        {
          'user_id': 'user-B',
          'status': 'invited',
          'users': {'display_name': '밥'},
        },
      ],
    };

void main() {
  group('AppointmentModel.fromJson', () {
    test('참여자 목록과 메타 정보를 파싱한다', () {
      final m = AppointmentModel.fromJson(_json(), 'user-A');
      expect(m.id, 'apt-1');
      expect(m.title, '회식');
      expect(m.eventDate, DateTime(2026, 6, 20));
      expect(m.participants.length, 2);
      expect(m.participants.first.displayName, '앨리스');
    });

    test('currentUserId 기준으로 내 상태(myStatus)를 계산한다', () {
      expect(AppointmentModel.fromJson(_json(), 'user-A').myStatus, 'added');
      expect(AppointmentModel.fromJson(_json(), 'user-B').myStatus, 'invited');
      // 참여자가 아니면 none
      expect(AppointmentModel.fromJson(_json(), 'user-Z').myStatus, 'none');
      expect(AppointmentModel.fromJson(_json(), null).myStatus, 'none');
    });

    test('display_name 누락 시 user_id 로 폴백', () {
      final json = _json();
      (json['personal_team_appointment_participants'] as List).add({
        'user_id': 'user-C',
        'status': 'invited',
      });
      final m = AppointmentModel.fromJson(json, 'user-C');
      final c = m.participants.firstWhere((p) => p.userId == 'user-C');
      expect(c.displayName, 'user-C');
    });
  });

  group('AppointmentModel 계산 속성', () {
    test('isAllDay: 시작/종료 시간이 모두 비어있으면 종일', () {
      final base = AppointmentModel.fromJson(_json(), 'user-A');
      expect(base.isAllDay, isFalse);

      final allDayJson = _json()
        ..['start_time'] = null
        ..['end_time'] = null;
      expect(AppointmentModel.fromJson(allDayJson, 'user-A').isAllDay, isTrue);
    });

    test('isCreator: 생성자 본인만 true', () {
      final m = AppointmentModel.fromJson(_json(), 'user-A');
      expect(m.isCreator('user-A'), isTrue);
      expect(m.isCreator('user-B'), isFalse);
      expect(m.isCreator(null), isFalse);
    });
  });
}
