import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moniq/data/datasources/push_service.dart';
import 'package:moniq/data/models/roster_entry.dart';
import 'package:moniq/data/models/shift_type_model.dart';
import 'package:moniq/data/providers/auth_providers.dart';
import 'package:moniq/data/providers/request_providers.dart';
import 'package:moniq/data/providers/shift_providers.dart';
import 'package:moniq/presentation/screens/request/request_create_widgets.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/request_viewmodel.dart';
import 'package:moniq/presentation/widgets/common/moniq_app_bar.dart';
import 'package:moniq/presentation/widgets/common/moniq_stepper.dart';

class RequestCreateScreen extends HookConsumerWidget {
  const RequestCreateScreen({super.key, required this.teamId});

  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: const MoniqAppBar(title: '변경 요청'),
      body: _RequestCreateForm(teamId: teamId),
    );
  }
}

class _RequestCreateForm extends ConsumerStatefulWidget {
  const _RequestCreateForm({required this.teamId});

  final String teamId;

  @override
  ConsumerState<_RequestCreateForm> createState() => _RequestCreateFormState();
}

class _RequestCreateFormState extends ConsumerState<_RequestCreateForm> {
  String _changeType = 'day_off';
  DateTime? _requestedDate;
  String? _selectedShiftTypeId;
  // 근무 교환 — 다중 entry 지원 (1행~N행)
  final List<SwapEntry> _swapEntries = [SwapEntry()];
  String _reason = '';
  String _note = '';
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _successMessage;

  List<ShiftTypeModel> _shiftTypes = [];
  List<RosterEntry> _roster = [];
  String? _myShiftTypeName;
  bool _isLoadingRoster = false;

  static const _changeTypes = [
    ('day_off', '휴무 요청', Icons.event_busy),
    ('shift_change', '근무 변경', Icons.swap_vert),
    ('swap', '근무 교환', Icons.swap_horiz),
  ];

  static const _presetReasons = [
    '개인 사유',
    '병원 방문',
    '가족 행사',
    '학업/시험',
    '기타',
  ];

  @override
  void initState() {
    super.initState();
    _requestedDate = DateTime.now();
    _loadShiftTypes();
  }

  Future<void> _loadShiftTypes() async {
    final shiftRepo = ref.read(shiftRepositoryProvider);
    _shiftTypes = await shiftRepo.getShiftTypes(widget.teamId);
    if (mounted) setState(() {});
  }

  Future<void> _loadRoster() async {
    if (_requestedDate == null) return;
    setState(() => _isLoadingRoster = true);

    final shiftRepo = ref.read(shiftRepositoryProvider);
    _roster = await shiftRepo.getTeamRoster(
      teamId: widget.teamId,
      date: _requestedDate!,
    );

    final myUserId = ref.read(currentUserProvider)?.id;
    _myShiftTypeName = null;
    for (final entry in _roster) {
      for (final w in entry.workers) {
        if (w.user.id == myUserId) {
          _myShiftTypeName = entry.shiftType.name;
          break;
        }
      }
      if (_myShiftTypeName != null) break;
    }

    if (mounted) setState(() => _isLoadingRoster = false);
  }

  /// 다중 swap entry 중 완료된(제출 가능한) 것만 추출
  List<SwapEntry> get _validSwapEntries =>
      _swapEntries.where((e) => e.isComplete).toList();

  bool get _canSubmit {
    if (_isSubmitting) return false;
    if (_changeType == 'swap') {
      // swap은 reason 불필요. 완료된 entry가 1건 이상이어야 함
      return _validSwapEntries.isNotEmpty;
    }
    if (_reason.isEmpty) return false;
    if (_changeType == 'shift_change' && _selectedShiftTypeId == null) {
      return false;
    }
    return true;
  }

  /// 0=요청 유형 · 1=상세(날짜/근무) · 2=사유/메모
  int get _currentStep {
    if (_changeType == 'swap') {
      // swap: detail 완료(entry 1건 이상)면 step=2 (사유 단계 없음)
      return _validSwapEntries.isNotEmpty ? 2 : 0;
    }
    if (_reason.isNotEmpty) return 2;
    final detailDone = switch (_changeType) {
      'day_off' => _requestedDate != null,
      'shift_change' =>
        _requestedDate != null && _selectedShiftTypeId != null,
      _ => false,
    };
    if (detailDone) return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSwap = _changeType == 'swap';

    return SingleChildScrollView(
      padding: AppSpacing.screenAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MoniqStepper.bars(current: _currentStep, total: 3),
          const SizedBox(height: AppSpacing.xxl),
          // Step 1: 요청 유형
          Text('요청 유형',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: _changeTypes.map((t) {
              final (type, label, icon) = t;
              final selected = _changeType == type;
              return ChoiceChip(
                avatar: Icon(icon, size: 18),
                label: Text(label),
                selected: selected,
                showCheckmark: false,
                onSelected: (_) {
                  setState(() {
                    _changeType = type;
                    _selectedShiftTypeId = null;
                    _swapEntries
                      ..clear()
                      ..add(SwapEntry());
                  });
                  if (type == 'shift_change' && _requestedDate != null) {
                    _loadRoster();
                  }
                },
                selectedColor:
                    theme.colorScheme.primary.withValues(alpha: 0.15),
              );
            }).toList(),
          ),

          // 휴무 / 근무 변경: 희망 날짜 상단 단계
          if (!isSwap) ...[
            const SizedBox(height: AppSpacing.xxl),
            Text('희망 날짜',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: AppSpacing.md),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _requestedDate ?? DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 90)),
                );
                if (picked != null) {
                  setState(() => _requestedDate = picked);
                  if (_changeType == 'shift_change') {
                    _loadRoster();
                  }
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant,
                  ),
                  borderRadius: AppRadius.borderRadiusMd,
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today,
                        size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: AppSpacing.md),
                    Text(
                      _requestedDate != null
                          ? DateFormat('yyyy년 MM월 dd일').format(_requestedDate!)
                          : '날짜를 선택해주세요',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: _requestedDate != null
                            ? null
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // 근무 변경 섹션
          if (_changeType == 'shift_change') ...[
            const SizedBox(height: AppSpacing.xxl),
            RequestCreateShiftChangeSection(
              isLoading: _isLoadingRoster,
              myShiftTypeName: _myShiftTypeName,
              shiftTypes: _shiftTypes,
              selectedShiftTypeId: _selectedShiftTypeId,
              onShiftTypeSelected: (id) =>
                  setState(() => _selectedShiftTypeId = id),
            ),
          ],

          // 근무 교환 섹션 — 다중 entry (팀원 → 날짜 → as-is/to-be)
          if (isSwap) ...[
            const SizedBox(height: AppSpacing.xxl),
            SwapEntriesSection(
              teamId: widget.teamId,
              myUserId: ref.read(currentUserProvider)?.id,
              entries: _swapEntries,
              onChanged: () => setState(() {}),
            ),
          ],

          // 사유 — 휴무/근무 변경 전용 (swap은 사유 제거)
          if (!isSwap) ...[
            const SizedBox(height: AppSpacing.xxl),
            Text('사유',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: _presetReasons.map((reason) {
                final selected = _reason == reason;
                return ChoiceChip(
                  label: Text(reason),
                  selected: selected,
                  onSelected: (_) =>
                      setState(() => _reason = selected ? '' : reason),
                  selectedColor:
                      theme.colorScheme.primary.withValues(alpha: 0.15),
                );
              }).toList(),
            ),

            const SizedBox(height: AppSpacing.xxl),

            // 메모 (선택)
            Text('메모 (선택)',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: AppSpacing.md),
            TextField(
              onChanged: (v) => _note = v,
              decoration: const InputDecoration(
                hintText: '추가 메모를 입력해주세요',
              ),
              textCapitalization: TextCapitalization.sentences,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.done,
              maxLines: 3,
            ),
          ],

          const SizedBox(height: AppSpacing.xxxl),

          // 에러/성공 메시지
          if (_errorMessage != null) ...[
            SelectableText.rich(
              TextSpan(
                text: _errorMessage,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          if (_successMessage != null) ...[
            SelectableText.rich(
              TextSpan(
                text: _successMessage,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.success,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // 제출 버튼
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _canSubmit ? () => _submit(context) : null,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('요청 제출'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit(BuildContext context) async {
    // 휴무 요청 시 이미 휴무인지 체크
    if (_changeType == 'day_off' && _requestedDate != null) {
      final shiftRepo = ref.read(shiftRepositoryProvider);
      final roster = await shiftRepo.getTeamRoster(
        teamId: widget.teamId,
        date: _requestedDate!,
      );
      final myUserId = ref.read(currentUserProvider)?.id;
      bool hasShift = false;
      for (final entry in roster) {
        if (entry.shiftType.code.toUpperCase() == 'OFF') continue;
        for (final w in entry.workers) {
          if (w.user.id == myUserId) {
            hasShift = true;
            break;
          }
        }
        if (hasShift) break;
      }
      if (!hasShift && mounted) {
        setState(() => _errorMessage = '이미 휴무인 날입니다!');
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final repo = ref.read(requestRepositoryProvider);

      String? noteText = _note.isNotEmpty ? _note : null;
      final myName = ref
              .read(currentUserProvider)
              ?.userMetadata?['display_name'] as String? ??
          '동료';

      if (_changeType == 'swap') {
        // 다중 swap entry — 완료된 항목별로 1건씩 createRequest
        final entries = _validSwapEntries;
        for (final e in entries) {
          await repo.createRequest(
            teamId: widget.teamId,
            changeType: 'swap',
            requestedDate: e.date,
            requestedShiftTypeId: e.desiredShiftType?.id,
            targetUserId: e.userId,
            reason: '${e.userName ?? '동료'}님과 근무 교환',
          );
          try {
            final dateLabel = DateFormat('M/d', 'ko_KR').format(e.date!);
            final shiftLabel = e.desiredShiftType?.name ?? '';
            await PushService.instance.sendToUsers(
              userIds: [e.userId!],
              title: '근무 교환 요청',
              body:
                  '$myName 님이 $dateLabel $shiftLabel 근무 교환을 요청했습니다',
              data: {
                'type': 'swap_request',
                'team_id': widget.teamId,
              },
            );
          } catch (_) {}
        }
      } else {
        await repo.createRequest(
          teamId: widget.teamId,
          changeType: _changeType,
          requestedDate: _requestedDate,
          requestedShiftTypeId: _selectedShiftTypeId,
          reason: _reason,
          note: noteText,
        );
      }

      ref.invalidate(
        requestListViewModelProvider(widget.teamId),
      );

      if (mounted) {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _errorMessage = '오류가 발생했습니다: $e',
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
