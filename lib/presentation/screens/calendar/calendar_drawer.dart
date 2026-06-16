import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/core/utils/color_utils.dart';
import 'package:moniq/data/datasources/personal_shift_type_local_data_source.dart';
import 'package:moniq/data/providers/auth_providers.dart';
import 'package:moniq/data/providers/settings_providers.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/widgets/common/moniq_bottom_sheet.dart';

import 'calendar_providers.dart';

// ── 홈 드로어 ──

class CalendarDrawer extends HookConsumerWidget {
  const CalendarDrawer({super.key, required this.onImportCalendar});

  final VoidCallback onImportCalendar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final shiftTypes = ref.watch(personalShiftTypesProvider);
    final currentUser = ref.watch(currentUserProvider);
    final userMeta = currentUser?.userMetadata;
    final displayName = userMeta?['display_name'] as String? ?? 'OnorOff';
    final avatarUrl = userMeta?['avatar_url'] as String?;

    return Drawer(
      width: 280,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(AppRadius.xl),
          bottomRight: Radius.circular(AppRadius.xl),
        ),
      ),
      elevation: 16,
      child: SafeArea(
        child: Column(
          children: [
            // ── Profile Section ──
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xxl,
                AppSpacing.xxxl,
                AppSpacing.xxl,
                AppSpacing.lg,
              ),
              child: Row(
                children: [
                  // 팀 캘린더의 TeamProfileAvatar와 동일한 원형 표시
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: avatarUrl != null && avatarUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: avatarUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Icon(
                              Icons.person_rounded,
                              size: 36,
                              color: cs.onPrimaryContainer,
                            ),
                          )
                        : Icon(
                            Icons.person_rounded,
                            size: 36,
                            color: cs.onPrimaryContainer,
                          ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: cs.primary,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          'MY CALENDAR',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Navigation Links ──
            Expanded(
              child: Column(
                children: [
                  const SizedBox(height: AppSpacing.sm),
                  _DrawerNavItem(
                    icon: Icons.schedule_outlined,
                    accentColor: AppColors.brandBlue,
                    label: '내 근무 유형 설정',
                    badge: '${shiftTypes.length}',
                    onTap: () {
                      Navigator.pop(context);
                      _showPersonalShiftTypeManager(context);
                    },
                  ),
                  _DrawerNavItem(
                    icon: Icons.calendar_month_outlined,
                    accentColor: AppColors.success,
                    label: '외부 캘린더 일정 가져오기',
                    onTap: () {
                      Navigator.pop(context);
                      onImportCalendar();
                    },
                  ),
                  DrawerToggleItem(
                    icon: Icons.visibility_off_outlined,
                    accentColor: const Color(0xFF9F7AEA),
                    label: '팀 근무 숨기기',
                    value: ref.watch(hideTeamShiftsInPersonalProvider),
                    onChanged: (v) => ref
                        .read(hideTeamShiftsInPersonalProvider.notifier)
                        .setHide(v),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPersonalShiftTypeManager(BuildContext context) {
    // 로그아웃 시트와 동일한 MoniqBottomSheetShell 스타일로 통일.
    showMoniqBottomSheet<void>(
      context: context,
      eyebrow: 'MY SHIFT',
      title: '근무 유형 설정',
      child: const PersonalShiftTypeSheet(),
    );
  }
}

// ── Drawer Navigation Item ──

class _DrawerNavItem extends StatelessWidget {
  const _DrawerNavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.accentColor,
    this.badge,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? accentColor;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textColor = cs.onSurface;
    final accent = accentColor ?? cs.primary;
    const bgColor = Colors.transparent;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      child: Material(
        color: bgColor,
        borderRadius: AppRadius.borderRadiusFull,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.borderRadiusFull,
          hoverColor: cs.surfaceContainerLow,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                // 부드러운 컬러 칩 안에 아이콘 — 바텀시트 옵션과 동일한 톤.
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.13),
                    borderRadius: AppRadius.borderRadiusMd,
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: accent, size: 20),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xxs,
                    ),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: AppRadius.borderRadiusFull,
                    ),
                    child: Text(
                      badge!,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── PersonalShiftTypeSheet widget ──

class PersonalShiftTypeSheet extends HookConsumerWidget {
  const PersonalShiftTypeSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final shiftTypes = ref.watch(personalShiftTypesProvider);

    // 로그아웃 시트와 동일한 MoniqBottomSheetShell 스타일로 표시되므로
    // (핸들·eyebrow·타이틀·서피스는 셸이 담당) 여기서는 본문만 구성한다.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => _showAddShiftTypeForm(context, ref),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('추가'),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (shiftTypes.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
            child: Text(
              '등록된 근무 유형이 없어요',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: shiftTypes.length,
              itemBuilder: (context, index) {
                final st = shiftTypes[index];
                final color = parseHexColor(st.color);
                // 사용자가 지정한 코드를 우선 표시, 없으면 파생 라벨.
                final code = st.code.trim().toUpperCase();
                final label = code.isEmpty
                    ? displayShiftLabel(st, shiftTypes)
                    : code;
                return Card(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: ListTile(
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: AppRadius.borderRadiusSm,
                      ),
                      child: Center(
                        child: Text(
                          label,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    title: Text(st.name),
                    subtitle: st.startTime != null
                        ? Text('${st.startTime} ~ ${st.endTime ?? ''}')
                        : null,
                    trailing: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 18),
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'edit', child: Text('수정')),
                        const PopupMenuItem(value: 'delete', child: Text('삭제')),
                      ],
                      onSelected: (action) {
                        if (action == 'edit') {
                          _showEditShiftTypeForm(context, ref, st);
                        } else if (action == 'delete') {
                          ref
                              .read(personalShiftTypeDataSourceProvider)
                              .remove(st.id);
                          ref.invalidate(personalShiftTypesProvider);
                        }
                      },
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  void _showAddShiftTypeForm(BuildContext context, WidgetRef ref) {
    _showShiftTypeForm(context, ref, null);
  }

  void _showEditShiftTypeForm(
    BuildContext context,
    WidgetRef ref,
    PersonalShiftType existing,
  ) {
    _showShiftTypeForm(context, ref, existing);
  }

  void _showShiftTypeForm(
    BuildContext context,
    WidgetRef ref,
    PersonalShiftType? existing,
  ) {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final codeController = TextEditingController(text: existing?.code ?? '');
    TimeOfDay startTime = existing?.startTime != null
        ? _parseTimeOfDay(existing!.startTime!)
        : const TimeOfDay(hour: 7, minute: 0);
    TimeOfDay endTime = existing?.endTime != null
        ? _parseTimeOfDay(existing!.endTime!)
        : const TimeOfDay(hour: 15, minute: 0);
    String selectedColor = existing?.color ?? '#FF8C00';

    const colorOptions = [
      '#FFD700',
      '#FF8C00',
      '#0061A4',
      '#A0AEC0',
      '#81C784',
      '#F48FB1',
      '#B39DDB',
      '#FF8A65',
    ];

    showMoniqBottomSheet<void>(
      context: context,
      eyebrow: 'SHIFT',
      title: existing == null ? '근무 유형 추가' : '근무 유형 수정',
      child: StatefulBuilder(
        builder: (ctx, setSheetState) {
          final badgeColor = parseHexColor(selectedColor);
          final codeInput = codeController.text.trim().toUpperCase();
          final nameFallback = nameController.text.trim().isEmpty
              ? '?'
              : nameController.text.trim().characters.first.toUpperCase();
          // 미리보기 뱃지: 입력한 코드 우선, 비어 있으면 이름 첫 글자.
          final code = codeInput.isEmpty ? nameFallback : codeInput;

          String periodLabel(TimeOfDay t) {
            if (t.hour < 6) return '새벽';
            if (t.hour < 12) return '오전';
            if (t.hour < 18) return '오후';
            return '밤';
          }

          String formatTime(TimeOfDay t) =>
              '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 뱃지 + 이름
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: AppRadius.borderRadiusMd,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        code,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: TextField(
                        controller: nameController,
                        textInputAction: TextInputAction.next,
                        style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: const InputDecoration(
                          hintText: '근무 이름 입력',
                          border: UnderlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (_) => setSheetState(() {}),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.xl),

                // 근무 코드
                Text(
                  '근무 코드',
                  style: Theme.of(ctx).textTheme.labelMedium?.copyWith(
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: 96,
                    child: TextField(
                      controller: codeController,
                      textCapitalization: TextCapitalization.characters,
                      textInputAction: TextInputAction.done,
                      maxLength: 4,
                      textAlign: TextAlign.center,
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'D',
                        counterText: '',
                        border: UnderlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (_) => setSheetState(() {}),
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.xxl),

                // 근무 시간
                Text(
                  '근무 시간',
                  style: Theme.of(ctx).textTheme.labelMedium?.copyWith(
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    // 시작
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          _showTimePicker(
                            context: ctx,
                            initial: startTime,
                            onChanged: (t) =>
                                setSheetState(() => startTime = t),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.md,
                            horizontal: AppSpacing.lg,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: AppRadius.borderRadiusMd,
                            border: Border.all(
                              color: badgeColor.withValues(alpha: 0.25),
                            ),
                            color: badgeColor.withValues(alpha: 0.05),
                          ),
                          child: Column(
                            children: [
                              Text(
                                periodLabel(startTime),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: badgeColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xxs),
                              Text(
                                formatTime(startTime),
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: badgeColor,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: 18,
                        color: Theme.of(
                          ctx,
                        ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    // 종료
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          _showTimePicker(
                            context: ctx,
                            initial: endTime,
                            onChanged: (t) => setSheetState(() => endTime = t),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.md,
                            horizontal: AppSpacing.lg,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: AppRadius.borderRadiusMd,
                            border: Border.all(
                              color: badgeColor.withValues(alpha: 0.25),
                            ),
                            color: badgeColor.withValues(alpha: 0.05),
                          ),
                          child: Column(
                            children: [
                              Text(
                                periodLabel(endTime),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: badgeColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xxs),
                              Text(
                                formatTime(endTime),
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: badgeColor,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.xxl),

                // 색상
                Text(
                  '색상',
                  style: Theme.of(ctx).textTheme.labelMedium?.copyWith(
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: colorOptions.map((c) {
                    final isSelected = c == selectedColor;
                    final color = parseHexColor(c);
                    return GestureDetector(
                      onTap: () => setSheetState(() => selectedColor = c),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: isSelected ? 32 : 28,
                        height: isSelected ? 32 : 28,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: Colors.white, width: 2.5)
                              : null,
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: Theme.of(ctx).colorScheme.onSurface,
                                    blurRadius: 8,
                                  ),
                                ]
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 16,
                              )
                            : null,
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: AppSpacing.xl),

                // 저장 버튼
                FilledButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    if (name.isEmpty) return;

                    final ds = ref.read(personalShiftTypeDataSourceProvider);
                    // 사용자가 입력한 코드 우선, 비어 있으면 이름 첫 글자.
                    final autoFallback = name.characters.first.toUpperCase();
                    final inputCode = codeController.text.trim().toUpperCase();
                    final code = inputCode.isEmpty ? autoFallback : inputCode;

                    String formatT(TimeOfDay t) =>
                        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

                    final st = PersonalShiftType(
                      id:
                          existing?.id ??
                          DateTime.now().millisecondsSinceEpoch.toString(),
                      name: name,
                      code: code,
                      startTime: formatT(startTime),
                      endTime: formatT(endTime),
                      color: selectedColor,
                    );

                    if (existing == null) {
                      ds.add(st);
                    } else {
                      ds.update(existing.id, st);
                    }
                    ref.invalidate(personalShiftTypesProvider);
                    Navigator.pop(ctx);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(ctx).colorScheme.primary,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                    ),
                  ),
                  child: Text(existing == null ? '추가' : '저장'),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          );
        },
      ),
    );
  }

  TimeOfDay _parseTimeOfDay(String timeStr) {
    final parts = timeStr.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  void _showTimePicker({
    required BuildContext context,
    required TimeOfDay initial,
    required ValueChanged<TimeOfDay> onChanged,
  }) {
    var selected = initial;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => SizedBox(
        height: 280,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('취소'),
                  ),
                  TextButton(
                    onPressed: () {
                      onChanged(selected);
                      Navigator.pop(ctx);
                    },
                    child: const Text('확인'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                use24hFormat: false,
                initialDateTime: DateTime(
                  2000,
                  1,
                  1,
                  initial.hour,
                  initial.minute,
                ),
                onDateTimeChanged: (dt) {
                  selected = TimeOfDay(hour: dt.hour, minute: dt.minute);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Drawer Toggle Item — 스위치형 항목 ──

/// 캘린더 드로어/웹 flyout 공용 토글 항목. (앱·웹 동일 스타일 재사용)
class DrawerToggleItem extends StatelessWidget {
  const DrawerToggleItem({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    this.accentColor,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color? accentColor;

  /// 웹 좌측 flyout에서 옆 항목(_FlyoutTile)과 칩/폰트 크기를 맞추기 위한 축소 모드.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final accent = accentColor ?? cs.primary;
    final chipSize = compact ? 30.0 : 36.0;
    final labelStyle = compact
        ? theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w500,
            color: cs.onSurface.withValues(alpha: 0.82),
          )
        : theme.textTheme.bodyMedium?.copyWith(
            color: cs.onSurface,
            fontWeight: FontWeight.w500,
          );
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: compact ? BorderRadius.circular(8) : null,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : AppSpacing.lg,
          vertical: compact ? 8 : AppSpacing.sm,
        ),
        child: Row(
          children: [
            Container(
              width: chipSize,
              height: chipSize,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.13),
                borderRadius: compact
                    ? BorderRadius.circular(8)
                    : AppRadius.borderRadiusMd,
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: accent, size: compact ? 17 : 20),
            ),
            SizedBox(width: compact ? 10 : AppSpacing.md),
            Expanded(
              child: Text(
                label,
                style: labelStyle,
                overflow: compact ? TextOverflow.ellipsis : null,
                maxLines: compact ? 1 : null,
              ),
            ),
            Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeThumbColor: cs.primary,
              materialTapTargetSize:
                  compact ? MaterialTapTargetSize.shrinkWrap : null,
            ),
          ],
        ),
      ),
    );
  }
}
