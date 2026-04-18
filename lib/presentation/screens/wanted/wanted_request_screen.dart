import 'package:flutter/material.dart';
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
    final stateAsync = ref.watch(wantedAdminViewModelProvider(teamId));

    return Scaffold(
      appBar: AppBar(title: const Text('원티드 수집')),
      body: stateAsync.when(
        loading: () => const MoniqLoadingView(),
        error: (e, _) => MoniqErrorView(
          message: '정보를 불러올 수 없습니다',
          onRetry: () =>
              ref.invalidate(wantedAdminViewModelProvider(teamId)),
        ),
        data: (state) {
          if (state.activeRequest != null) {
            return WantedRequestActiveView(
              teamId: teamId,
              teamName: teamName,
              state: state,
            );
          }
          return WantedRequestCreateView(
            teamId: teamId,
            teamName: teamName,
          );
        },
      ),
    );
  }
}
