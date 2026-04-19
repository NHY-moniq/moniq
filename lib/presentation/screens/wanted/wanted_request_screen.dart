import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/presentation/screens/wanted/wanted_request_widgets.dart';
import 'package:moniq/presentation/viewmodels/wanted_viewmodel.dart';
import 'package:moniq/presentation/widgets/common/moniq_error_view.dart';
import 'package:moniq/presentation/widgets/common/moniq_loading_view.dart';

/// 관리자: 원티드 수집 요청 생성 및 현황 관리
class WantedRequestScreen extends HookConsumerWidget {
  const WantedRequestScreen({
    super.key,
    required this.teamId,
    required this.teamName,
  });

  final String teamId;
  final String teamName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 화면 진입 시 최신 수집 상태/응답을 강제 재조회
    useEffect(() {
      Future.microtask(
        () => ref.invalidate(wantedAdminViewModelProvider(teamId)),
      );
      return null;
    }, const []);

    final stateAsync = ref.watch(wantedAdminViewModelProvider(teamId));

    return Scaffold(
      appBar: AppBar(title: const Text('원티드 수집')),
      body: stateAsync.when(
        loading: () => const MoniqLoadingView(),
        error: (e, _) => MoniqErrorView(
          message: '정보를 불러올 수 없습니다',
          onRetry: () => ref.invalidate(wantedAdminViewModelProvider(teamId)),
        ),
        data: (state) {
          if (state.activeRequests.isNotEmpty) {
            return WantedRequestActiveView(
              teamId: teamId,
              teamName: teamName,
              state: state,
            );
          }
          if (state.lastClosedRequests.isNotEmpty) {
            return WantedRequestClosedView(
              teamId: teamId,
              teamName: teamName,
              state: state,
            );
          }
          return WantedRequestCreateView(teamId: teamId, teamName: teamName);
        },
      ),
    );
  }
}
