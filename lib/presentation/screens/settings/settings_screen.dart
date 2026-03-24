import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/providers/settings_providers.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/auth_viewmodel.dart';

class SettingsScreen extends HookConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final fontScale = ref.watch(fontScaleProvider);
    final calendarStartDay = ref.watch(calendarStartDayProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
      ),
      body: ListView(
        children: [
          // 앱 설정
          _SectionHeader(title: '앱 설정'),

          // 테마 모드
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('테마'),
            trailing: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                    value: ThemeMode.light,
                    label: Text('라이트'),
                    icon: Icon(Icons.light_mode, size: 18)),
                ButtonSegment(
                    value: ThemeMode.dark,
                    label: Text('다크'),
                    icon: Icon(Icons.dark_mode, size: 18)),
              ],
              selected: {themeMode == ThemeMode.system ? ThemeMode.light : themeMode},
              onSelectionChanged: (modes) {
                ref
                    .read(themeModeProvider.notifier)
                    .setThemeMode(modes.first);
              },
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),

          // 글자 크기
          ListTile(
            leading: const Icon(Icons.text_fields),
            title: const Text('글자 크기'),
            subtitle: Slider(
              value: fontScale,
              min: 0.8,
              max: 1.4,
              divisions: 6,
              label: '${(fontScale * 100).round()}%',
              onChanged: (value) {
                ref.read(fontScaleProvider.notifier).setFontScale(value);
              },
            ),
            trailing: Text(
              '${(fontScale * 100).round()}%',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),

          // 캘린더 시작 요일
          ListTile(
            leading: const Icon(Icons.calendar_today),
            title: const Text('캘린더 시작 요일'),
            trailing: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'monday', label: Text('월')),
                ButtonSegment(value: 'sunday', label: Text('일')),
              ],
              selected: {calendarStartDay},
              onSelectionChanged: (days) {
                ref
                    .read(calendarStartDayProvider.notifier)
                    .setStartDay(days.first);
              },
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),

          const Divider(),

          // 알림
          _SectionHeader(title: '알림'),
          _NotificationTile(),

          const Divider(),

          // 계정
          _SectionHeader(title: '계정'),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('프로필'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/settings/profile'),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('로그아웃'),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('로그아웃'),
                  content: const Text('정말 로그아웃 하시겠습니까?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('취소'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('로그아웃'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await ref.read(authViewModelProvider.notifier).signOut();
                if (context.mounted) {
                  context.go('/login');
                }
              }
            },
          ),
          ListTile(
            leading: Icon(Icons.delete_forever, color: AppColors.error),
            title: Text(
              '계정 삭제',
              style: TextStyle(color: AppColors.error),
            ),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('계정 삭제 기능은 추후 구현 예정입니다'),
                ),
              );
            },
          ),
          const Divider(),

          // 정보
          _SectionHeader(title: '정보'),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('개인정보 처리방침'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('앱 버전'),
            trailing: Text(
              '1.0.0',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondaryLight,
                  ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEnabled = ref.watch(notificationEnabledProvider);

    return ListTile(
      leading: const Icon(Icons.notifications_outlined),
      title: const Text('푸시 알림'),
      subtitle: const Text('스케줄 변경 요청 및 일정 알림'),
      trailing: Switch(
        value: isEnabled,
        onChanged: (value) async {
          if (value) {
            final granted = await ref
                .read(notificationEnabledProvider.notifier)
                .enable();
            if (!granted && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('알림 권한이 필요합니다. 설정에서 권한을 허용해주세요.'),
                ),
              );
            }
          } else {
            await ref.read(notificationEnabledProvider.notifier).disable();
          }
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xxl,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.textSecondaryLight,
            ),
      ),
    );
  }
}

