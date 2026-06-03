import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moniq/data/models/request_model.dart';
import 'package:moniq/presentation/screens/request/request_list_screen.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/request_viewmodel.dart';
import 'package:moniq/presentation/widgets/common/moniq_app_bar.dart';
import 'package:moniq/presentation/widgets/common/moniq_empty_state.dart';
import 'package:moniq/presentation/widgets/common/moniq_error_view.dart';
import 'package:moniq/presentation/widgets/common/moniq_loading_view.dart';

/// 근무 변경 요청 히스토리 — 최근 6개월. 그 이전 기록은 자동 삭제.
class RequestHistoryScreen extends ConsumerStatefulWidget {
  const RequestHistoryScreen({super.key, required this.teamId});

  final String teamId;

  @override
  ConsumerState<RequestHistoryScreen> createState() =>
      _RequestHistoryScreenState();
}

class _RequestHistoryScreenState extends ConsumerState<RequestHistoryScreen> {
  bool _purgedOldRecords = false;

  /// 6개월보다 오래된 요청을 정리한다. 권한이 없는 건은 RLS가 막아 무시됨.
  Future<void> _purgeStale(List<RequestModel> requests) async {
    if (_purgedOldRecords) return;
    _purgedOldRecords = true;

    final cutoff = _sixMonthsAgo();
    final oldIds = requests
        .where((r) {
          final d = r.requestedDate ?? r.createdAt;
          return d != null && d.isBefore(cutoff);
        })
        .map((r) => r.id)
        .toList();

    if (oldIds.isEmpty) return;
    try {
      await ref
          .read(requestListViewModelProvider(widget.teamId).notifier)
          .deleteRequests(oldIds);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final stateAsync = ref.watch(requestListViewModelProvider(widget.teamId));

    return Scaffold(
      appBar: MoniqAppBar(
        title: '요청 히스토리',
        showBack: true,
        trailing: MoniqAppBarAction(
          icon: Icons.refresh_rounded,
          onTap: () =>
              ref.invalidate(requestListViewModelProvider(widget.teamId)),
        ),
      ),
      body: stateAsync.when(
        loading: () => const MoniqLoadingView(),
        error: (e, _) => MoniqErrorView(
          message: '히스토리를 불러올 수 없습니다',
          onRetry: () =>
              ref.invalidate(requestListViewModelProvider(widget.teamId)),
        ),
        data: (state) {
          // 첫 진입 시 오래된 기록 정리
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _purgeStale(state.requests);
          });

          final history = _historyItems(state.requests);
          if (history.isEmpty) {
            return MoniqEmptyState.peaceful(
              title: '히스토리가 없어요',
              message: '최근 6개월의 요청만 보관돼요',
            );
          }

          // 6개월 이내 요청을 그룹화한 뒤 월별 섹션으로 분리.
          final groups = groupHistoryRequests(history);

          final monthMap = <String, List<RequestGroup>>{};
          final yearMonthFormat = DateFormat('yyyy년 M월', 'ko');
          for (final g in groups) {
            final d = g.createdAt ?? g.primary.requestedDate!;
            final key = yearMonthFormat.format(DateTime(d.year, d.month));
            monthMap.putIfAbsent(key, () => []).add(g);
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            itemCount: monthMap.length,
            itemBuilder: (context, index) {
              final monthLabel = monthMap.keys.elementAt(index);
              final items = monthMap[monthLabel]!;
              return _MonthSection(
                label: monthLabel,
                groups: items,
                userNames: state.userNames,
              );
            },
          );
        },
      ),
    );
  }
}

DateTime _sixMonthsAgo() {
  final now = DateTime.now();
  return DateTime(now.year, now.month - 6, now.day);
}

/// 최근 6개월 이내, 신청일 기준 내림차순
List<RequestModel> _historyItems(List<RequestModel> all) {
  final cutoff = _sixMonthsAgo();
  final items = all.where((r) {
    final d = r.createdAt ?? r.requestedDate;
    return d != null && !d.isBefore(cutoff);
  }).toList();
  items.sort((a, b) {
    final da = a.createdAt ?? a.requestedDate!;
    final db = b.createdAt ?? b.requestedDate!;
    return db.compareTo(da);
  });
  return items;
}

class _MonthSection extends StatelessWidget {
  const _MonthSection({
    required this.label,
    required this.groups,
    required this.userNames,
  });

  final String label;
  final List<RequestGroup> groups;
  final Map<String, String> userNames;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.sm,
            ),
            child: Text(
              '$label · ${groups.length}건',
              style: theme.textTheme.labelLarge?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ...groups.map(
            (g) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: RequestCard(
                group: g,
                userNames: userNames,
                onTap: () {},
              ),
            ),
          ),
        ],
      ),
    );
  }
}
