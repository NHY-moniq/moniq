import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moniq/core/utils/color_utils.dart';
import 'package:moniq/data/models/roster_entry.dart';
import 'package:moniq/data/models/shift_type_model.dart';
import 'package:moniq/data/providers/auth_providers.dart';
import 'package:moniq/data/providers/request_providers.dart';
import 'package:moniq/data/providers/shift_providers.dart';
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
  String? _selectedSwapUserId;
  String? _selectedSwapUserName;
  String _reason = '';
  String _note = '';
  bool _isSubmitting = false;

  // 로딩 상태
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

    // 내 근무 유형 찾기
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
                selectedColor: AppColors.primary.withValues(alpha: 0.15),
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
                border: Border.all(color: AppColors.borderLight),
                borderRadius: AppRadius.borderRadiusMd,
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today,
                      size: 20, color: AppColors.primary),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    _requestedDate != null
                        ? DateFormat('yyyy년 MM월 dd일')
                            .format(_requestedDate!)
                        : '날짜를 선택해주세요',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: _requestedDate != null
                          ? null
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 근무 변경: 현재 근무 + 변경할 근무 유형 선택
          if (_changeType == 'shift_change') ...[
            const SizedBox(height: AppSpacing.xxl),
            _buildShiftChangeSection(theme),
          ],

          // 근무 교환: 해당 날짜 팀원 근무 목록
          if (_changeType == 'swap') ...[
            const SizedBox(height: AppSpacing.xxl),
            _buildSwapSection(theme),
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
                onSelected: (_) => setState(() => _reason = reason),
                selectedColor: AppColors.primary.withValues(alpha: 0.15),
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
            maxLines: 3,
          ),

          const SizedBox(height: AppSpacing.xxxl),

          // 제출 버튼
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _canSubmit ? () => _submit(context) : null,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('요청 제출'),
            ),
          ),
        ],
      ),
    );
  }

  bool get _canSubmit {
    if (_isSubmitting || _reason.isEmpty) return false;
    if (_changeType == 'shift_change' && _selectedShiftTypeId == null) {
      return false;
    }
    if (_changeType == 'swap' && _selectedSwapUserId == null) return false;
    return true;
  }

  /// 근무 변경 섹션
  Widget _buildShiftChangeSection(ThemeData theme) {
    if (_isLoadingRoster) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 현재 내 근무
        Text('현재 내 근무',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: AppSpacing.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: AppRadius.borderRadiusMd,
          ),
          child: Text(
            _myShiftTypeName ?? '해당 날짜에 배정된 근무가 없습니다',
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: _myShiftTypeName != null
                  ? null
                  : AppColors.textSecondaryLight,
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.lg),

        // 변경할 근무 유형 선택
        Text('변경할 근무 유형',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: _shiftTypes.map((st) {
            final color = parseHexColor(st.color);
            final selected = _selectedShiftTypeId == st.id;
            return ChoiceChip(
              avatar: CircleAvatar(
                backgroundColor: color,
                radius: 8,
              ),
              label: Text(st.name),
              selected: selected,
              onSelected: (_) =>
                  setState(() => _selectedShiftTypeId = st.id),
              selectedColor: color.withValues(alpha: 0.2),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// 근무 교환 섹션
  Widget _buildSwapSection(ThemeData theme) {
    if (_isLoadingRoster) {
      return const Center(child: CircularProgressIndicator());
    }

    final myUserId = ref.read(currentUserProvider)?.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 현재 내 근무
        if (_myShiftTypeName != null) ...[
          Text('현재 내 근무',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: AppRadius.borderRadiusMd,
            ),
            child: Text(
              _myShiftTypeName!,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],

        // 팀원 근무 목록
        Text('교환할 팀원 선택',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: AppSpacing.sm),

        if (_roster.isEmpty)
          Text('해당 날짜에 배정된 근무가 없습니다',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondaryLight,
              ))
        else
          ..._roster.map((entry) {
            final color = parseHexColor(entry.shiftType.color);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 근무 유형 헤더
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: AppRadius.borderRadiusSm,
                      ),
                      child: Center(
                        child: Text(
                          entry.shiftType.code,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      entry.shiftType.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                // 근무자 목록 (자기 자신 제외)
                Padding(
                  padding: const EdgeInsets.only(left: 32),
                  child: Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: entry.workers
                        .where((w) => w.user.id != myUserId)
                        .map((w) {
                      final name =
                          w.user.displayName ?? w.user.email;
                      final isSelected =
                          _selectedSwapUserId == w.user.id;

                      return ChoiceChip(
                        label: Text(name),
                        selected: isSelected,
                        onSelected: (_) {
                          setState(() {
                            _selectedSwapUserId = w.user.id;
                            _selectedSwapUserName = name;
                          });
                        },
                        selectedColor:
                            color.withValues(alpha: 0.2),
                        avatar: isSelected
                            ? Icon(Icons.check,
                                size: 16, color: color)
                            : null,
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            );
          }),

        if (_selectedSwapUserName != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: AppRadius.borderRadiusMd,
            ),
            child: Row(
              children: [
                Icon(Icons.swap_horiz,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    '$_selectedSwapUserName 님과 근무 교환 요청',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이미 휴무인 날입니다!')),
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);

    try {
      final repo = ref.read(requestRepositoryProvider);

      String? noteText = _note.isNotEmpty ? _note : null;
      String reasonText = _reason;

      // 근무 교환인 경우 사유에 상대방 정보 포함
      if (_changeType == 'swap' && _selectedSwapUserName != null) {
        reasonText =
            '$_selectedSwapUserName 님과 근무 교환. $_reason';
      }

      await repo.createRequest(
        teamId: widget.teamId,
        changeType: _changeType,
        requestedDate: _requestedDate,
        requestedShiftTypeId: _selectedShiftTypeId,
        reason: reasonText,
        note: noteText,
      );

      ref.invalidate(requestListViewModelProvider(widget.teamId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('요청이 제출되었습니다')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류가 발생했습니다: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
