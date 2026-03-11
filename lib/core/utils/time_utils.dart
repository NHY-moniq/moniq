/// Supabase TIME "HH:mm:ss" → "HH:mm"
String formatTimeString(String? timeStr) {
  if (timeStr == null || timeStr.length < 5) return '';
  return timeStr.substring(0, 5);
}
