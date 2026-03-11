import 'package:moniq/data/models/team_member_model.dart';
import 'package:moniq/data/models/user_model.dart';

class TeamMemberWithUser {
  const TeamMemberWithUser({
    required this.member,
    required this.user,
  });

  final TeamMemberModel member;
  final UserModel user;

  String get displayName => user.displayName ?? user.email;
  String get role => member.role;
  String get userId => member.userId;
}
