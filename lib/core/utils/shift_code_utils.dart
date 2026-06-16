/// 근무 유형 코드/이름 정규화 공용 유틸.
///
/// 여러 화면에서 반복되던 D/E/N 판별·정렬 로직을 한곳으로 모은다.
library;

/// 근무 유형 코드/이름을 표준 코드(D/E/N)로 정규화한다.
/// 매칭되지 않으면 입력 코드의 대문자를 그대로 반환한다(예: 'ED').
///
/// 데이/주간/Day → D, 이브닝/저녁/Eve → E, 나이트/야간/Night → N.
String canonicalShiftCode(String code, String name) {
  final c = code.toUpperCase();
  final lower = name.toLowerCase();
  if (c == 'D' ||
      name.contains('데이') ||
      name.contains('주간') ||
      lower.contains('day')) {
    return 'D';
  }
  if (c == 'E' ||
      name.contains('이브닝') ||
      name.contains('저녁') ||
      lower.contains('eve')) {
    return 'E';
  }
  if (c == 'N' ||
      name.contains('나이트') ||
      name.contains('야간') ||
      lower.contains('night')) {
    return 'N';
  }
  return c;
}
