import 'package:hooks_riverpod/hooks_riverpod.dart';

/// 팀 생성 직후 튜토리얼을 시작해야 할 팀 정보를 임시로 보관.
/// TeamDetailScreen에서 watch하다가 자신의 teamId와 일치하면 튜토리얼 시작.
// ignore: library_private_types_in_public_api
final tutorialPendingProvider =
    StateProvider<TutorialPending?>((_) => null);

class TutorialPending {
  const TutorialPending({
    required this.teamId,
    required this.teamType,
  });

  final String teamId;
  final String teamType;
}
