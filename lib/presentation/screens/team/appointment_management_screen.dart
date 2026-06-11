import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moniq/core/utils/color_utils.dart';
import 'package:moniq/data/models/appointment_model.dart';
import 'package:moniq/data/providers/appointment_providers.dart';
import 'package:moniq/data/providers/supabase_providers.dart';
import 'package:moniq/presentation/screens/calendar/calendar_providers.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/widgets/common/moniq_app_bar.dart';
import 'package:moniq/presentation/widgets/common/moniq_bottom_sheet.dart';
import 'package:moniq/presentation/widgets/common/moniq_empty_state.dart';
import 'package:moniq/presentation/widgets/common/moniq_error_view.dart';
import 'package:moniq/presentation/widgets/common/moniq_loading_view.dart';

/// 약속 관리 화면 — 팀 약속을 예정/지난으로 보고, 각자 내 캘린더에 추가/빼기.
class AppointmentManagementScreen extends ConsumerStatefulWidget {
  const AppointmentManagementScreen({super.key, required this.teamId});

  final String teamId;

  @override
  ConsumerState<AppointmentManagementScreen> createState() =>
      _AppointmentManagementScreenState();
}

class _AppointmentManagementScreenState
    extends ConsumerState<AppointmentManagementScreen> {
  bool _showPast = false;
  String? _busyId; // 처리 중인 약속 id (버튼 로딩)
  // 낙관적 업데이트: 서버 응답 전에 내 상태를 즉시 반영 (appointmentId → status)
  final Map<String, String> _statusOverride = {};

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  Future<void> _refresh() async {
    ref.invalidate(teamAppointmentsProvider(widget.teamId));
    await ref.read(personalEventDataSourceProvider).pullFromRemote();
    if (mounted) ref.read(eventRefreshProvider.notifier).state++;
  }

  /// 홈 캘린더 동기화 — 배지 갱신을 막지 않도록 백그라운드로 실행.
  void _syncPersonalEvents() {
    unawaited(() async {
      await ref.read(personalEventDataSourceProvider).pullFromRemote();
      if (mounted) ref.read(eventRefreshProvider.notifier).state++;
    }());
  }

  Future<void> _addToMyCalendar(AppointmentModel a) async {
    // 낙관적: 탭 즉시 '추가됨'으로 보이게 한 뒤 서버 반영.
    setState(() => _statusOverride[a.id] = 'added');
    try {
      await ref.read(appointmentRepositoryProvider).addToMyCalendar(a.id);
      ref.invalidate(teamAppointmentsProvider(widget.teamId));
      _syncPersonalEvents();
    } catch (_) {
      if (mounted) setState(() => _statusOverride.remove(a.id)); // 롤백
      _toast('처리에 실패했어요. 다시 시도해주세요.');
    }
  }

  Future<void> _removeFromMyCalendar(AppointmentModel a) async {
    setState(() => _statusOverride[a.id] = 'invited');
    try {
      await ref.read(appointmentRepositoryProvider).removeFromMyCalendar(a.id);
      ref.invalidate(teamAppointmentsProvider(widget.teamId));
      _syncPersonalEvents();
    } catch (_) {
      if (mounted) setState(() => _statusOverride.remove(a.id));
      _toast('처리에 실패했어요. 다시 시도해주세요.');
    }
  }

  Future<void> _delete(AppointmentModel a) async {
    final ok = await showMoniqConfirmSheet(
      context: context,
      title: '약속 삭제',
      message: '이 약속을 삭제하면 참여자 전원의 캘린더에서도 제거돼요.',
      confirmLabel: '삭제',
      destructive: true,
    );
    if (ok != true) return;
    setState(() => _busyId = a.id);
    try {
      await ref.read(appointmentRepositoryProvider).deleteAppointment(a.id);
      await _refresh();
      _toast('약속을 삭제했어요');
    } catch (_) {
      _toast('삭제에 실패했어요. 생성자만 삭제할 수 있어요.');
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _showParticipants(AppointmentModel a) async {
    // 낙관적 override를 참여자 목록(내 항목)에도 반영해 카드와 일치시킨다.
    final myId = ref.read(supabaseClientProvider).auth.currentUser?.id;
    final override = _statusOverride[a.id];
    final participants = (override == null || myId == null)
        ? a.participants
        : [
            for (final p in a.participants)
              if (p.userId == myId)
                AppointmentParticipant(
                  userId: p.userId,
                  displayName: p.displayName,
                  avatarUrl: p.avatarUrl,
                  status: override,
                )
              else
                p,
          ];
    await showMoniqBottomSheet<void>(
      context: context,
      eyebrow: 'APPOINTMENT',
      title: a.title,
      child: _ParticipantsSheet(participants: participants),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final async = ref.watch(teamAppointmentsProvider(widget.teamId));
    final myId = ref.read(supabaseClientProvider).auth.currentUser?.id;

    // 재조회(invalidate) 중에도 이전 데이터를 유지해 전체 로딩 깜빡임을 막는다.
    final all = async.valueOrNull;

    Widget body;
    if (all == null) {
      body = async.hasError
          ? MoniqErrorView(
              message: '약속을 불러올 수 없습니다',
              onRetry: () =>
                  ref.invalidate(teamAppointmentsProvider(widget.teamId)),
            )
          : const MoniqLoadingView();
    } else {
      final upcoming =
          all.where((a) => !a.eventDate.isBefore(_today)).toList()
            ..sort((a, b) => a.eventDate.compareTo(b.eventDate));
      final past = all.where((a) => a.eventDate.isBefore(_today)).toList()
        ..sort((a, b) => b.eventDate.compareTo(a.eventDate));
      final list = _showPast ? past : upcoming;

      body = Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: _PillTabs(
              showPast: _showPast,
              upcomingCount: upcoming.length,
              pastCount: past.length,
              onChanged: (v) => setState(() => _showPast = v),
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? _emptyState()
                : RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView.separated(
                      padding: AppSpacing.screenAll,
                      itemCount: list.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (_, i) => _AppointmentCard(
                        appointment: list[i],
                        // 낙관적 override가 있으면 우선 적용 (즉시 반영)
                        myStatus:
                            _statusOverride[list[i].id] ?? list[i].myStatus,
                        currentUserId: myId,
                        isPast: _showPast,
                        busy: _busyId == list[i].id,
                        onAdd: () => _addToMyCalendar(list[i]),
                        onRemove: () => _removeFromMyCalendar(list[i]),
                        onDelete: () => _delete(list[i]),
                        onShowParticipants: () => _showParticipants(list[i]),
                      ),
                    ),
                  ),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: const MoniqAppBar(title: '약속 관리'),
      body: body,
    );
  }

  Widget _emptyState() {
    return MoniqEmptyState.peaceful(
      title: _showPast ? '지난 약속이 없어요' : '예정된 약속이 없어요',
      message: _showPast
          ? '아직 지나간 약속이 없습니다.'
          : '멤버 근무 현황에서 겹치는 날을 찾아\n약속을 만들어보세요.',
    );
  }
}

class _PillTabs extends StatelessWidget {
  const _PillTabs({
    required this.showPast,
    required this.upcomingCount,
    required this.pastCount,
    required this.onChanged,
  });

  final bool showPast;
  final int upcomingCount;
  final int pastCount;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget tab(String label, int count, bool selected, VoidCallback onTap) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? cs.primary : Colors.transparent,
              borderRadius: AppRadius.borderRadiusFull,
            ),
            child: Text(
              '$label $count',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: selected ? cs.onPrimary : cs.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: AppRadius.borderRadiusFull,
      ),
      child: Row(
        children: [
          tab('예정', upcomingCount, !showPast, () => onChanged(false)),
          tab('지난', pastCount, showPast, () => onChanged(true)),
        ],
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({
    required this.appointment,
    required this.myStatus,
    required this.currentUserId,
    required this.isPast,
    required this.busy,
    required this.onAdd,
    required this.onRemove,
    required this.onDelete,
    required this.onShowParticipants,
  });

  final AppointmentModel appointment;

  /// 화면에서 계산한 실효 상태(낙관적 override 반영). a.myStatus 대신 사용.
  final String myStatus;
  final String? currentUserId;
  final bool isPast;
  final bool busy;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final VoidCallback onDelete;
  final VoidCallback onShowParticipants;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final a = appointment;
    final color = a.color != null ? parseHexColor(a.color!) : AppColors.brandOrange;
    final isCreator = a.isCreator(currentUserId);
    final declined = myStatus == 'declined';

    final dateFmt = DateFormat('M월 d일 (E)', 'ko_KR');
    final timeLabel = a.isAllDay
        ? '종일'
        : '${a.startTime ?? ''} – ${a.endTime ?? ''}';

    return Opacity(
      opacity: declined ? 0.6 : 1,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: AppRadius.borderRadiusLg,
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.7)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    a.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _StatusBadge(status: myStatus),
                if (isCreator) ...[
                  const SizedBox(width: AppSpacing.xs),
                  GestureDetector(
                    onTap: busy ? null : onDelete,
                    child: Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${dateFmt.format(a.eventDate)} · $timeLabel',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            // 참여자 영역 탭 → 전체 참여자 바텀시트
            InkWell(
              onTap: onShowParticipants,
              borderRadius: AppRadius.borderRadiusFull,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    _ParticipantAvatarStack(participants: a.participants),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        _participantLabel(a),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: cs.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
            if (!isPast) ...[
              const SizedBox(height: AppSpacing.md),
              _actionButton(context, color),
            ],
          ],
        ),
      ),
    );
  }

  String _participantLabel(AppointmentModel a) {
    if (a.participants.isEmpty) return '';
    final first = a.participants.first.displayName;
    if (a.participants.length == 1) return first;
    return '$first 외 ${a.participants.length - 1}명';
  }

  Widget _actionButton(BuildContext context, Color color) {
    if (busy) {
      return const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (myStatus == 'added') {
      final cs = Theme.of(context).colorScheme;
      // 조용한 완료 상태 — 풀폭 tonal bar(앰버), "빼기"는 보조 액션.
      return Container(
        width: double.infinity,
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: cs.primaryContainer.withValues(alpha: 0.45),
          borderRadius: AppRadius.borderRadiusMd,
        ),
        child: Row(
          children: [
            Icon(Icons.check_rounded, size: 18, color: cs.onPrimaryContainer),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '내 캘린더에 추가됨',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: cs.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: onRemove,
              style: TextButton.styleFrom(
                foregroundColor: cs.onSurfaceVariant,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              ),
              child: const Text('빼기'),
            ),
          ],
        ),
      );
    }
    // invited / declined / none
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onAdd,
        icon: const Icon(Icons.event_available_rounded, size: 18),
        label: const Text('내 캘린더에 추가'),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    late final String label;
    late final Color bg;
    late final Color fg;
    Border? border;
    switch (status) {
      case 'added':
        // 활성/완료 — 앰버로 채워 "내 것" 표시
        label = '추가됨';
        bg = cs.primary.withValues(alpha: 0.18);
        fg = cs.onPrimaryContainer;
      case 'declined':
        label = '참여 안 함';
        bg = cs.surfaceContainerHigh;
        fg = cs.onSurfaceVariant.withValues(alpha: 0.7);
      default: // invited / none — 비어있는(테두리만) 대기 칩
        label = '대기 중';
        bg = Colors.transparent;
        fg = cs.onSurfaceVariant;
        border = Border.all(color: cs.outlineVariant.withValues(alpha: 0.7));
    }
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.borderRadiusFull,
        border: border,
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ParticipantAvatarStack extends StatelessWidget {
  const _ParticipantAvatarStack({required this.participants});

  final List<AppointmentParticipant> participants;

  @override
  Widget build(BuildContext context) {
    final shown = participants.take(4).toList();
    final extra = participants.length - shown.length;
    const size = 26.0;
    final width = shown.isEmpty
        ? 0.0
        : size + (shown.length - 1) * (size - 10) + (extra > 0 ? size - 10 : 0);

    return SizedBox(
      width: width,
      height: size,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * (size - 10),
              child: _SmallAvatar(participant: shown[i], size: size),
            ),
          if (extra > 0)
            Positioned(
              left: shown.length * (size - 10),
              child: _MoreCounter(count: extra, size: size),
            ),
        ],
      ),
    );
  }
}

class _SmallAvatar extends StatelessWidget {
  const _SmallAvatar({required this.participant, required this.size});

  final AppointmentParticipant participant;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = participant.displayName;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final url = participant.avatarUrl;
    final added = participant.status == 'added';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: cs.surface, width: 1.5),
      ),
      child: Stack(
        children: [
          CircleAvatar(
            radius: size / 2,
            backgroundColor: cs.primaryContainer,
            backgroundImage: (url != null && url.isNotEmpty)
                ? NetworkImage(url)
                : null,
            child: (url == null || url.isEmpty)
                ? Text(
                    initial,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: cs.onPrimaryContainer,
                    ),
                  )
                : null,
          ),
          if (added)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: cs.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: cs.surface, width: 1),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 약속 전체 참여자 + 각자 상태 목록 (바텀시트 내용).
class _ParticipantsSheet extends StatelessWidget {
  const _ParticipantsSheet({required this.participants});

  final List<AppointmentParticipant> participants;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '참여자 ${participants.length}명',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        ...participants.map(
          (p) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              children: [
                _SmallAvatar(participant: p, size: 32),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    p.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _StatusBadge(status: p.status),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MoreCounter extends StatelessWidget {
  const _MoreCounter({required this.count, required this.size});

  final int count;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: cs.primaryContainer,
        border: Border.all(color: cs.surface, width: 1.5),
      ),
      child: Text(
        '+$count',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: cs.onPrimaryContainer,
        ),
      ),
    );
  }
}
