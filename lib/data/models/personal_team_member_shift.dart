class PersonalTeamMember {
  const PersonalTeamMember({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
  });

  final String userId;
  final String displayName;
  final String? avatarUrl;
}

class PersonalMemberShift {
  const PersonalMemberShift({
    required this.userId,
    required this.date,
    this.shiftCode,
    this.shiftColor,
    this.shiftName,
  });

  final String userId;
  final DateTime date;
  final String? shiftCode; // null = 근무 없음
  final String? shiftColor; // hex string e.g. '#A0AEC0'
  final String? shiftName;
}
