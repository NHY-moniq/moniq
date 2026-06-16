import 'package:flutter_test/flutter_test.dart';
import 'package:moniq/data/models/shift_type_model.dart';

void main() {
  group('ShiftTypeModel.fromJson', () {
    test('snake_case 키를 매핑한다', () {
      final m = ShiftTypeModel.fromJson({
        'id': 'st-1',
        'team_id': 'team-1',
        'name': '데이',
        'code': 'D',
        'start_time': '09:00:00',
        'end_time': '17:00:00',
        'color': '#5A8BB5',
        'display_order': 2,
        'is_active': true,
      });

      expect(m.id, 'st-1');
      expect(m.teamId, 'team-1');
      expect(m.startTime, '09:00:00');
      expect(m.displayOrder, 2);
      expect(m.isActive, isTrue);
    });

    test('누락된 선택 필드는 기본값을 사용한다', () {
      final m = ShiftTypeModel.fromJson({
        'id': 'st-1',
        'team_id': 'team-1',
        'name': '오프',
        'code': 'OFF',
      });

      expect(m.startTime, isNull);
      expect(m.color, '#A0AEC0'); // @Default
      expect(m.displayOrder, 0);
      expect(m.isActive, isTrue);
    });
  });

  group('ShiftTypeModel.toJson', () {
    test('fromJson → toJson 라운드트립 키 유지', () {
      final json = {
        'id': 'st-1',
        'team_id': 'team-1',
        'name': '나이트',
        'code': 'N',
        'start_time': '23:00:00',
        'end_time': '07:00:00',
        'color': '#9F7AEA',
        'display_order': 1,
        'is_active': false,
        'created_at': null,
        'updated_at': null,
      };
      final round = ShiftTypeModel.fromJson(json).toJson();
      expect(round['team_id'], 'team-1');
      expect(round['start_time'], '23:00:00');
      expect(round['is_active'], false);
    });
  });
}
