import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/core/utils/color_utils.dart';
import 'package:moniq/core/utils/team_icon_utils.dart';
import 'package:moniq/data/models/team_model.dart';
import 'package:moniq/data/providers/tutorial_providers.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/team_viewmodel.dart';

/// 프로필 미리보기: 이모지 탭하면 입력, 카메라 버튼으로 이미지 선택
class TeamCreateProfilePreview extends StatelessWidget {
  const TeamCreateProfilePreview({
    super.key,
    required this.emoji,
    required this.color,
    this.imageBytes,
    this.imageUrl,
    required this.onEmojiChanged,
    required this.onPickImage,
    required this.onClearImage,
  });

  final String emoji;
  final String color;
  final Uint8List? imageBytes;
  final String? imageUrl;
  final ValueChanged<String> onEmojiChanged;
  final VoidCallback onPickImage;
  final VoidCallback onClearImage;

  bool get _hasImage =>
      imageBytes != null ||
      (imageUrl != null && imageUrl!.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final bgColor = parseHexColor(color);

    return Column(
      children: [
        Stack(
          children: [
            // 아바타
            GestureDetector(
              onTap: _hasImage ? null : () => _showEmojiInput(context),
              child: CircleAvatar(
                radius: 44,
                backgroundColor:
                    bgColor.withValues(alpha: 0.25),
                backgroundImage: _hasImage
                    ? (imageBytes != null
                        ? MemoryImage(imageBytes!)
                        : NetworkImage(imageUrl!)
                            as ImageProvider)
                    : null,
                child: _hasImage
                    ? null
                    : Text(
                        emoji,
                        style: const TextStyle(fontSize: 36),
                      ),
              ),
            ),

            // 카메라/삭제 버튼
            Positioned(
              right: 0,
              bottom: 0,
              child: GestureDetector(
                onTap: _hasImage ? onClearImage : onPickImage,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: _hasImage
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context)
                          .scaffoldBackgroundColor,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    _hasImage ? Icons.close : Icons.camera_alt,
                    size: 16,
                    color: _hasImage
                        ? Theme.of(context).colorScheme.onError
                        : Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (!_hasImage)
          Text(
            '탭하여 이모지 변경',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant,
                ),
          ),
      ],
    );
  }

  void _showEmojiInput(BuildContext context) {
    final controller = TextEditingController(text: emoji);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('이모지 입력'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 32),
          decoration: const InputDecoration(
            hintText: '이모지를 입력하세요',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) {
            final trimmed = value.trim();
            if (trimmed.isNotEmpty) {
              // 첫 번째 이모지/문자만 사용
              final chars = trimmed.characters;
              onEmojiChanged(chars.first);
            }
            Navigator.pop(ctx);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              final trimmed = controller.text.trim();
              if (trimmed.isNotEmpty) {
                final chars = trimmed.characters;
                onEmojiChanged(chars.first);
              }
              Navigator.pop(ctx);
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }
}

class TeamCreateSuccessView extends ConsumerWidget {
  const TeamCreateSuccessView({super.key, required this.team});

  final TeamModel team;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('팀 생성 완료'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.screenAll,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: TeamProfileAvatar(
                  icon: team.icon,
                  radius: 40,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text(
                '${team.name} 팀이\n생성되었습니다!',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xxxl),

              // 초대 코드 카드
              Card(
                child: Padding(
                  padding: AppSpacing.cardPadding,
                  child: Column(
                    children: [
                      Text(
                        '초대 코드',
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      SelectableText(
                        team.inviteCode ?? '',
                        style: Theme.of(context)
                            .textTheme
                            .headlineLarge
                            ?.copyWith(
                              letterSpacing: 4,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(
                              text: team.inviteCode ?? '',
                            ),
                          );
                          ScaffoldMessenger.of(context)
                              .showSnackBar(
                            const SnackBar(
                              content:
                                  Text('초대 코드가 복사되었습니다'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy),
                        label: const Text('코드 복사'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xxxl),

              ElevatedButton(
                onPressed: () {
                  // 해당 유형의 첫 팀일 때만 튜토리얼 트리거
                  final teams =
                      ref.read(teamViewModelProvider).valueOrNull ?? [];
                  final isFirstOfType = teams
                          .where((t) => t.teamType == team.teamType)
                          .length ==
                      1;
                  if (isFirstOfType) {
                    ref.read(tutorialPendingProvider.notifier).state =
                        TutorialPending(
                      teamId: team.id,
                      teamType: team.teamType,
                    );
                  }
                  context.go('/teams/${team.id}/detail');
                },
                child: const Text('팀 설정하기'),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton(
                onPressed: () => context.go('/teams'),
                child: const Text('팀 캘린더로 이동'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
