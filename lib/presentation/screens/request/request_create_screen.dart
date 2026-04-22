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

class RequestCreateScreen extends HookConsumerWidget {
  const RequestCreateScreen({super.key, required this.teamId});

  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('변경 요청')),
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
  // 근무 교환 플로우: 변경 후 원하는 shift_type
  String? _swapDesiredShiftTypeId;
  String? _selectedSwapUserId;
  String? _selectedSwapUserName;
  // 1:1 (single) | 1:N (multi)
  String _swapMode = 'one';
  final Set<String> _selectedSwapUserIds = {};
  final Map<String, String> _swapUserNames = {};
  // 1:N 모드 — 교환할 (팀원, 날짜, 근무) 항목들
  final List<MultiSwapItem> _multiSwapItems = [];
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

  bool get _canSubmit {
    if (_isSubmitting || _reason.isEmpty) return false;
    if (_changeType == 'shift_change' && _selectedShiftTypeId == null) {
      return false;
    }
    if (_changeType == 'swap') {
      if (_swapMode == 'one' && _selectedSwapUserId == null) return false;
      if (_swapMode == 'many' && _multiSwapItems.isEmpty) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: AppSpacing.screenAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                onSelected: (_) {
                  setState(() {
                    _changeType = type;
                    _selectedShiftTypeId = null;
                    _selectedSwapUserId = null;
                    _selectedSwapUserName = null;
                  });
                  if ((type == 'shift_change' || type == 'swap') &&
                      _requestedDate != null) {
                    _loadRoster();
                  }
                },
                selectedColor:
                    theme.colorScheme.primary.withValues(alpha: 0.15),
              );
            }).toList(),
          ),

          const SizedBox(height: AppSpacing.xxl),

          // Step 2: 희망 날짜
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
                setState(() {
                  _requestedDate = picked;
                  _selectedSwapUserId = null;
                  _selectedSwapUserName = null;
                });
                if (_changeType == 'shift_change' || _changeType == 'swap') {
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

          // 근무 교환 섹션
          if (_changeType == 'swap') ...[
            const SizedBox(height: AppSpacing.xxl),
            RequestCreateSwapSection(
              isLoading: _isLoadingRoster,
              myShiftTypeName: _myShiftTypeName,
              roster: _roster,
              shiftTypes: _shiftTypes,
              myUserId: ref.read(currentUserProvider)?.id,
              teamId: widget.teamId,
              desiredShiftTypeId: _swapDesiredShiftTypeId,
              onDesiredShiftTypeSelected: (id) => setState(() {
                _swapDesiredShiftTypeId = id;
                _selectedSwapUserId = null;
                _selectedSwapUserName = null;
                _selectedSwapUserIds.clear();
                _swapUserNames.clear();
                _multiSwapItems.clear();
              }),
              swapMode: _swapMode,
              onSwapModeChanged: (mode) {
                setState(() {
                  _swapMode = mode;
                  _selectedSwapUserId = null;
                  _selectedSwapUserName = null;
                  _selectedSwapUserIds.clear();
                  _swapUserNames.clear();
                  _multiSwapItems.clear();
                });
              },
              selectedSwapUserId: _selectedSwapUserId,
              selectedSwapUserName: _selectedSwapUserName,
              selectedSwapUserIds: _selectedSwapUserIds,
              onSwapUserSelected: (userId, userName) {
                setState(() {
                  if (userId == null) {
                    _selectedSwapUserId = null;
                    _selectedSwapUserName = null;
                  } else {
                    _selectedSwapUserId = userId;
                    _selectedSwapUserName = userName;
                  }
                });
              },
              multiSwapItems: _multiSwapItems,
              onMultiItemAdded: (item) {
                setState(() {
                  // 같은 (userId, date) 중복 방지
                  _multiSwapItems.removeWhere(
                    (e) => e.userId == item.userId && e.date == item.date,
                  );
                  _multiSwapItems.add(item);
                });
              },
              onMultiItemRemoved: (index) {
                setState(() => _multiSwapItems.removeAt(index));
              },
            ),
          ],

          const SizedBox(height: AppSpacing.xxl),

          // Step 3: 사유
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
      final dateLabel = _requestedDate != null
          ? DateFormat('M/d', 'ko_KR').format(_requestedDate!)
          : '';

      // 1:N 교환은 _multiSwapItems 각 항목마다 별도 createRequest + 푸시
      if (_changeType == 'swap' && _swapMode == 'many') {
        int success = 0;
        for (final item in _multiSwapItems) {
          final itemDateLabel = DateFormat('M/d', 'ko_KR').format(item.date);
          try {
            await repo.createRequest(
              teamId: widget.teamId,
              changeType: 'swap',
              requestedDate: item.date,
              targetUserId: item.userId,
              reason:
                  '$itemDateLabel ${item.shiftTypeName} ${item.userName} 님과 근무 교환 (1:N). $_reason',
              note: noteText,
            );
            try {
              await PushService.instance.sendToUsers(
                userIds: [item.userId],
                title: '근무 교환 요청',
                body:
                    '$myName 님이 $itemDateLabel ${item.shiftTypeName} 근무 교환을 요청했습니다',
                data: {
                  'type': 'swap_request',
                  'team_id': widget.teamId,
                },
              );
            } catch (_) {}
            success++;
          } catch (_) {}
        }
        ref.invalidate(requestListViewModelProvider(widget.teamId));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('$success/${_multiSwapItems.length}건 교환 요청 발송'),
            ),
          );
          context.pop();
        }
        return;
      }

      // 1:1 또는 다른 changeType
      String reasonText = _reason;
      if (_changeType == 'swap' && _selectedSwapUserName != null) {
        reasonText = '$_selectedSwapUserName 님과 근무 교환. $_reason';
      }

      await repo.createRequest(
        teamId: widget.teamId,
        changeType: _changeType,
        requestedDate: _requestedDate,
        requestedShiftTypeId: _selectedShiftTypeId,
        targetUserId: _changeType == 'swap' ? _selectedSwapUserId : null,
        reason: reasonText,
        note: noteText,
      );

      if (_changeType == 'swap' && _selectedSwapUserId != null) {
        try {
          await PushService.instance.sendToUsers(
            userIds: [_selectedSwapUserId!],
            title: '근무 교환 요청',
            body: '$myName 님이 $dateLabel 근무 교환을 요청했습니다',
            data: {
              'type': 'swap_request',
              'team_id': widget.teamId,
            },
          );
        } catch (_) {}
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
