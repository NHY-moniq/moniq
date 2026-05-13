import 'package:moniq/data/models/shift_type_model.dart';
import 'package:moniq/data/models/shift_with_type.dart';

/// Supabase TIME "HH:mm:ss" → "HH:mm"
String formatTimeString(String? timeStr) {
  if (timeStr == null || timeStr.length < 5) return '';
  return timeStr.substring(0, 5);
}

/// `"HH:mm"` 또는 `"HH:mm:ss"` 문자열을 minutes(int)로.
int? parseTimeToMinutes(String? timeStr) {
  if (timeStr == null || timeStr.length < 4) return null;
  final parts = timeStr.split(':');
  if (parts.length < 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  return h * 60 + m;
}

// 내부 alias (기존 호출 호환)
int? _parseTimeToMinutes(String? s) => parseTimeToMinutes(s);

/// 현재 시각이 shiftType의 startTime~endTime 범위에 속하는지.
/// 야간 교대(end <= start)는 자정을 넘기는 것으로 간주.
bool isNowInShiftRange(ShiftTypeModel t, DateTime now) {
  if (t.code.toUpperCase() == 'OFF') return false;
  final startMin = parseTimeToMinutes(t.startTime);
  final endMin = parseTimeToMinutes(t.endTime);
  if (startMin == null || endMin == null) return false;
  final nowMin = now.hour * 60 + now.minute;
  if (endMin > startMin) {
    return nowMin >= startMin && nowMin < endMin;
  }
  // 야간 교대 (예: 23:00 ~ 07:00)
  return nowMin >= startMin || nowMin < endMin;
}

/// ShiftType의 startTime/endTime으로 근무 시간(시간 단위, double)을 계산.
/// - OFF(code=='OFF') 또는 시작/종료 시간 없음 → 0
/// - 야간 교대(end <= start) → 24h 감안 (+1일)
double shiftTypeHours(ShiftTypeModel shiftType) {
  if (shiftType.code.toUpperCase() == 'OFF') return 0;
  final startMin = _parseTimeToMinutes(shiftType.startTime);
  final endMin = _parseTimeToMinutes(shiftType.endTime);
  if (startMin == null || endMin == null) return 0;

  var diff = endMin - startMin;
  if (diff <= 0) diff += 24 * 60;
  return diff / 60.0;
}

/// 특정 월에 속한 shifts의 근무 시간 합계(double, 시간).
double monthlyWorkedHours(
  Map<DateTime, List<ShiftWithType>> monthlyShifts,
  DateTime month,
) {
  double total = 0;
  monthlyShifts.forEach((date, shifts) {
    if (date.year != month.year || date.month != month.month) return;
    for (final s in shifts) {
      total += shiftTypeHours(s.shiftType);
    }
  });
  return total;
}
