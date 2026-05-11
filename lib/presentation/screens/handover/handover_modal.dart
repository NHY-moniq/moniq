import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moniq/data/models/handover_model.dart';
import 'package:moniq/data/providers/handover_providers.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/theme/shift_theme.dart';
import 'package:moniq/presentation/viewmodels/home_viewmodel.dart';

/// 오늘의 인계 메모 — 보기 + 작성 모달
Future<void> showHandoverModal({
  required BuildContext context,
  required ShiftThemeData shiftTheme,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _HandoverModal(shiftTheme: shiftTheme),
  );
}

class _HandoverModal extends ConsumerStatefulWidget {
  const _HandoverModal({required this.shiftTheme});
  final ShiftThemeData shiftTheme;

  @override
  ConsumerState<_HandoverModal> createState() => _HandoverModalState();
}

class _HandoverModalState extends ConsumerState<_HandoverModal> {
  final _controller = TextEditingController();
  bool _submitting = false;
  String? _errorMessage;
  bool _justSubmitted = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 작성에 사용할 (teamId, shiftTypeId).
  /// 1순위: 본인 오늘 schedule된 일하는 시프트
  /// 2순위: onShiftTeamData (지금 시간 시프트 또는 다음 시프트)
  ({String teamId, String shiftTypeId})? _myWriteContext() {
    final state = ref.read(homeViewModelProvider).valueOrNull;
    if (state != null) {
      final now = DateTime.now();
      final todayKey = DateTime(now.year, now.month, now.day);
      final shifts = state.monthlyShifts[todayKey];
      if (shifts != null && shifts.isNotEmpty) {
        final s = shifts.first;
        if (s.shiftType.code.toUpperCase() != 'OFF') {
          return (teamId: s.shift.teamId, shiftTypeId: s.shiftType.id);
        }
      }
    }
    // fallback: 지금 시간 기준 시프트 (본인이 OFF여도 같은 팀이면 작성 가능)
    final onShift = ref.read(onShiftTeamDataProvider).valueOrNull;
    if (onShift?.teamId != null) {
      final shiftTypeId =
          onShift!.currentType?.id ?? onShift.nextType?.id;
      if (shiftTypeId != null) {
        return (teamId: onShift.teamId!, shiftTypeId: shiftTypeId);
      }
    }
    return null;
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() => _errorMessage = '메모 내용을 입력해주세요');
      return;
    }
    final ctx = _myWriteContext();
    if (ctx == null) {
      setState(() => _errorMessage = '작성 가능한 시프트를 찾지 못했어요');
      return;
    }
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      final repo = ref.read(handoverRepositoryProvider);
      await repo.create(
        teamId: ctx.teamId,
        shiftTypeId: ctx.shiftTypeId,
        date: DateTime.now(),
        body: text,
      );
      _controller.clear();
      ref.invalidate(todayHandoversProvider);
      if (mounted) {
        setState(() => _justSubmitted = true);
        // 2초 후 성공 표시 사라짐
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _justSubmitted = false);
        });
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = '작성 실패: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = widget.shiftTheme.accentText;
    final listAsync = ref.watch(todayHandoversProvider);
    // 작성 가능 여부가 변할 때 rebuild 되도록 dependency watch
    ref.watch(homeViewModelProvider);
    ref.watch(onShiftTeamDataProvider);
    final canWrite = _myWriteContext() != null;
    final viewInsets = MediaQuery.of(context).viewInsets;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: viewInsets.bottom),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xxl,
            AppSpacing.lg,
            AppSpacing.xxl,
            AppSpacing.xxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Text(
                    '오늘 인수인계',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: AppRadius.borderRadiusFull,
                    ),
                    child: Text(
                      DateFormat('M.dd (E)', 'ko_KR').format(DateTime.now()),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              // PII 경고 배너
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: cs.errorContainer.withValues(alpha: 0.5),
                  borderRadius: AppRadius.borderRadiusSm,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: cs.onErrorContainer,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        '환자 식별 정보(이름·병실·차트번호) 입력 금지',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: cs.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              // 메모 리스트
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: listAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.xxl),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text(
                      '인계 메모를 불러오지 못했어요',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ),
                  data: (items) {
                    if (items.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.xxl,
                        ),
                        child: Center(
                          child: Text(
                            canWrite
                                ? '아직 인계가 없어요. 처음 메모를 남겨보세요.'
                                : '아직 인계가 없어요',
                            style: TextStyle(
                              fontSize: 13,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      );
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      itemCount: items.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (_, i) =>
                          _HandoverTile(item: items[i], cs: cs),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              // 작성 폼
              if (canWrite) ...[
                Divider(color: cs.outlineVariant.withValues(alpha: 0.4)),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _controller,
                  maxLines: 2,
                  maxLength: 200,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: '다음 시프트가 알면 좋을 내용 (일반 사항만)',
                    hintStyle: TextStyle(color: cs.onSurfaceVariant),
                    filled: true,
                    fillColor: cs.surfaceContainerLow,
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.borderRadiusMd,
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: AppRadius.borderRadiusMd,
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: AppRadius.borderRadiusMd,
                      borderSide: BorderSide(
                        color: accent.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                    ),
                  ),
                  onChanged: (_) {
                    if (_errorMessage != null) {
                      setState(() => _errorMessage = null);
                    }
                  },
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: cs.errorContainer.withValues(alpha: 0.5),
                      borderRadius: AppRadius.borderRadiusSm,
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cs.onErrorContainer,
                      ),
                    ),
                  ),
                ] else if (_justSubmitted) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: AppRadius.borderRadiusSm,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 16,
                          color: accent,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          '메모를 남겼어요',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: cs.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.borderRadiusFull,
                      ),
                    ),
                    onPressed: _submitting ? null : _submit,
                    icon: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 18),
                    label: const Text('메모 남기기'),
                  ),
                ),
              ] else
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLow,
                    borderRadius: AppRadius.borderRadiusSm,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          '작성 가능한 시프트 정보를 불러오는 중이거나, 가입된 팀이 없어요',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HandoverTile extends StatelessWidget {
  const _HandoverTile({required this.item, required this.cs});
  final HandoverWithMeta item;
  final ColorScheme cs;

  Color? _parseHex(String? hex) {
    if (hex == null) return null;
    final h = hex.replaceFirst('#', '');
    if (h.length != 6) return null;
    return Color(int.parse('FF$h', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final shiftColor = _parseHex(item.shiftColor) ?? cs.primary;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: AppRadius.borderRadiusMd,
        border: Border(
          left: BorderSide(color: shiftColor, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 10,
                backgroundColor: cs.surfaceContainerHigh,
                backgroundImage: (item.authorAvatarUrl != null &&
                        item.authorAvatarUrl!.isNotEmpty)
                    ? CachedNetworkImageProvider(item.authorAvatarUrl!)
                    : null,
                child: (item.authorAvatarUrl == null ||
                        item.authorAvatarUrl!.isEmpty)
                    ? Icon(
                        Icons.person,
                        size: 12,
                        color: cs.onSurfaceVariant,
                      )
                    : null,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                item.authorName,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 1,
                ),
                decoration: BoxDecoration(
                  color: shiftColor.withValues(alpha: 0.12),
                  borderRadius: AppRadius.borderRadiusFull,
                ),
                child: Text(
                  item.shiftName,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: shiftColor,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                DateFormat('HH:mm').format(item.handover.createdAt.toLocal()),
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            item.handover.body,
            style: TextStyle(
              fontSize: 13,
              color: cs.onSurface,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
