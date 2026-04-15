import 'package:supabase_flutter/supabase_flutter.dart';

class PersonalShiftOverrideRemote {
  const PersonalShiftOverrideRemote({
    required this.shiftId,
    required this.shiftTypeId,
    required this.code,
    required this.name,
    required this.color,
    this.startTime,
    this.endTime,
  });

  final String shiftId;
  final String shiftTypeId;
  final String code;
  final String name;
  final String color;
  final String? startTime;
  final String? endTime;
}

class PersonalShiftOverrideRemoteDataSource {
  PersonalShiftOverrideRemoteDataSource({required SupabaseClient client})
      : _client = client;

  final SupabaseClient _client;

  String? get _userId => _client.auth.currentUser?.id;

  Future<Map<String, PersonalShiftOverrideRemote>> fetchMine() async {
    if (_userId == null) return {};
    final rows = await _client
        .from('personal_shift_overrides')
        .select()
        .eq('user_id', _userId!);

    final map = <String, PersonalShiftOverrideRemote>{};
    for (final r in (rows as List)) {
      final m = r as Map<String, dynamic>;
      map[m['shift_id'] as String] = PersonalShiftOverrideRemote(
        shiftId: m['shift_id'] as String,
        shiftTypeId: m['shift_type_id'] as String,
        code: m['code'] as String? ?? '',
        name: m['name'] as String? ?? '',
        color: m['color'] as String? ?? '#808080',
        startTime: m['start_time'] as String?,
        endTime: m['end_time'] as String?,
      );
    }
    return map;
  }

  Future<void> upsert(PersonalShiftOverrideRemote o) async {
    if (_userId == null) throw Exception('Not authenticated');
    await _client.from('personal_shift_overrides').upsert(
      {
        'user_id': _userId,
        'shift_id': o.shiftId,
        'shift_type_id': o.shiftTypeId,
        'code': o.code,
        'name': o.name,
        'color': o.color,
        'start_time': o.startTime,
        'end_time': o.endTime,
        'updated_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'user_id,shift_id',
    );
  }

  Future<void> remove(String shiftId) async {
    if (_userId == null) return;
    await _client
        .from('personal_shift_overrides')
        .delete()
        .eq('user_id', _userId!)
        .eq('shift_id', shiftId);
  }
}
